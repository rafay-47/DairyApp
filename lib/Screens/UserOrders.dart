import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../constants.dart';

class UserOrders extends StatefulWidget {
  @override
  _UserOrdersState createState() => _UserOrdersState();
}

class _UserOrdersState extends State<UserOrders> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final User? currentUser = FirebaseAuth.instance.currentUser;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text('My Orders'),
          backgroundColor: Constants.primaryColor,
          bottom: TabBar(
            tabs: [Tab(text: 'Active Orders'), Tab(text: 'Past Orders')],
            labelColor: Colors.white,
          ),
          centerTitle: true,
          elevation: 0,
        ),
        body: TabBarView(
          children: [_buildOrdersList(true), _buildOrdersList(false)],
        ),
      ),
    );
  }

  Future<void> _deleteOrderHistory(String orderId) async {
    try {
      await _firestore.collection('orders').doc(orderId).update({
        'isHidden': true,
      });

      setState(() {});

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Order removed from history'),
          action: SnackBarAction(
            label: 'UNDO',
            onPressed: () async {
              await _firestore.collection('orders').doc(orderId).update({
                'isHidden': false,
              });
              setState(() {});
            },
          ),
        ),
      );
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to remove order from history'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Stream<QuerySnapshot> _getOrders(bool isActive) {
    if (currentUser == null) {
      return Stream.empty();
    }

    return _firestore
        .collection('orders')
        .where('userId', isEqualTo: currentUser!.uid)
        .orderBy('orderDate', descending: true)
        .snapshots();
  }

  Widget _buildOrdersList(bool isActive) {
    return StreamBuilder<QuerySnapshot>(
      stream: _getOrders(isActive),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          print('Error: ${snapshot.error}'); // For debugging
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 60, color: Colors.red),
                SizedBox(height: 16),
                Text('Error loading orders', style: TextStyle(fontSize: 18)),
                if (snapshot.error != null)
                  Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      snapshot.error.toString(),
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Constants.accentColor),
            ),
          );
        }

        final orders = snapshot.data?.docs ?? [];

        final filteredOrders =
            orders.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final status = data['status'] as String? ?? '';
              final isHidden = data['isHidden'] ?? false; // Add this line

              if (isHidden) return false; // Skip hidden orders
              return isActive
                  ? (status == 'Processing' || status == 'Shipped')
                  : (status == 'Delivered' || status == 'Cancelled');
            }).toList();

        if (filteredOrders.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.receipt_long_outlined,
                  size: 80,
                  color: Colors.grey[400],
                ),
                SizedBox(height: 16),
                Text(
                  isActive ? 'No active orders' : 'No past orders',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey[700],
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    isActive
                        ? 'Your active orders will appear here'
                        : 'Your order history will appear here',
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: EdgeInsets.all(16),
          itemCount: filteredOrders.length,
          itemBuilder: (context, index) {
            final orderData =
                filteredOrders[index].data() as Map<String, dynamic>;
            final orderItems = List<Map<String, dynamic>>.from(
              orderData['items'] ?? [],
            );
            final orderDate = orderData['orderDate'] ?? orderData['timestamp'];
            final formattedDate =
                orderDate is Timestamp ? orderDate.toDate() : DateTime.now();
            final subtotal = orderData['subtotal']?.toDouble() ?? 0.0;
            final deliveryCharge =
                orderData['deliveryCharge']?.toDouble() ?? 0.0;
            final total = orderData['total']?.toDouble() ?? 0.0;
            final orderStatus = orderData['status'] ?? 'Processing';
            final orderNumber =
                orderData['orderNumber'] ??
                filteredOrders[index].id.substring(0, 8);

            return Card(
              margin: EdgeInsets.only(bottom: 16),
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ExpansionTile(
                title: Text(
                  'Order #$orderNumber',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: 4),
                    Text(
                      'Ordered on: ${DateFormat('MMM dd, yyyy hh:mm a').format(formattedDate)}',
                      style: TextStyle(fontSize: 13),
                    ),
                    SizedBox(height: 4),
                    Row(
                      children: [
                        Text('Status: ', style: TextStyle(fontSize: 13)),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _getStatusColor(
                              orderStatus,
                            ).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            orderStatus,
                            style: TextStyle(
                              color: _getStatusColor(orderStatus),
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                trailing:
                    orderStatus == 'Cancelled'
                        ? IconButton(
                          icon: Icon(Icons.close, color: Colors.red),
                          onPressed:
                              () =>
                                  _deleteOrderHistory(filteredOrders[index].id),
                          tooltip: 'Remove from history',
                        )
                        : Icon(Icons.expand_more),
                children: [
                  Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Order Details',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Divider(),
                        ListView.builder(
                          shrinkWrap: true,
                          physics: NeverScrollableScrollPhysics(),
                          itemCount: orderItems.length,
                          itemBuilder: (context, itemIndex) {
                            final item = orderItems[itemIndex];
                            final itemName = item['name'] ?? 'Unknown Item';
                            final itemQuantity = item['quantity'] ?? 1;
                            final itemPrice = item['price']?.toDouble() ?? 0.0;
                            final itemTotal = itemPrice * itemQuantity;

                            return Padding(
                              padding: EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      '$itemName x$itemQuantity',
                                      style: TextStyle(fontSize: 14),
                                    ),
                                  ),
                                  Text(
                                    '₹${itemTotal.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                        Divider(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Subtotal'),
                            Text(
                              '₹${subtotal.toStringAsFixed(2)}',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Delivery Charge'),
                            Text(
                              deliveryCharge > 0
                                  ? '₹${deliveryCharge.toStringAsFixed(2)}'
                                  : 'FREE',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: deliveryCharge > 0 ? null : Colors.green,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Total Amount',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              '₹${total.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Constants.accentColor,
                              ),
                            ),
                          ],
                        ),
                        if (isActive && orderStatus == 'Processing') ...[
                          SizedBox(height: 16),
                          Center(
                            child: ElevatedButton(
                              onPressed:
                                  () => _cancelOrder(filteredOrders[index].id),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding: EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 12,
                                ),
                              ),
                              child: Text('Cancel Order'),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'processing':
        return Colors.orange;
      case 'shipped':
        return Colors.blue;
      case 'delivered':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Future<void> _cancelOrder(String orderId) async {
    try {
      await _firestore.collection('orders').doc(orderId).update({
        'status': 'Cancelled',
        'cancelledAt': FieldValue.serverTimestamp(),
      });

      setState(() {});

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Order cancelled successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to cancel order: $error'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
