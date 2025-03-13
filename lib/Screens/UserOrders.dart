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
          backgroundColor: Constants.accentColor,
          bottom: TabBar(
            tabs: [Tab(text: 'Active Orders'), Tab(text: 'Past Orders')],
          ),
        ),
        body: TabBarView(
          children: [
            _buildOrdersList(true), // Active orders
            _buildOrdersList(false), // Past orders
          ],
        ),
      ),
    );
  }

  Stream<QuerySnapshot> _getOrders(bool isActive) {
    if (currentUser == null) {
      return Stream.empty();
    }

    return _firestore
        .collection('orders')
        .where('userId', isEqualTo: currentUser!.uid)
        .where('isActive', isEqualTo: isActive)
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  Widget _buildOrdersList(bool isActive) {
    return StreamBuilder<QuerySnapshot>(
      stream: _getOrders(isActive),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error loading orders'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        final orders = snapshot.data?.docs ?? [];

        if (orders.isEmpty) {
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
                  style: TextStyle(fontSize: 18, color: Colors.grey[700]),
                ),
                SizedBox(height: 8),
                Text(
                  isActive
                      ? 'Your active orders will appear here'
                      : 'Your order history will appear here',
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: EdgeInsets.all(16),
          itemCount: orders.length,
          itemBuilder: (context, index) {
            final orderData = orders[index].data() as Map<String, dynamic>;
            final orderItems = orderData['items'] as List<dynamic>;
            final orderDate = (orderData['timestamp'] as Timestamp).toDate();
            final orderTotal = orderData['total'] ?? 0.0;
            final orderStatus = orderData['status'] ?? 'Processing';
            final orderNumber =
                orderData['orderNumber'] ?? orders[index].id.substring(0, 8);
            final deliveryCharge = orderData['deliveryCharge'] ?? 0.0;

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
                      'Ordered on: ${DateFormat('MMM dd, yyyy hh:mm a').format(orderDate)}',
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
                        ...orderItems
                            .map(
                              (item) => Padding(
                                padding: EdgeInsets.symmetric(vertical: 4),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '${item['name']} x${item['quantity']}',
                                        style: TextStyle(fontSize: 14),
                                      ),
                                    ),
                                    Text(
                                      '₹${(item['price'] * (item['quantity'] ?? 1)).toStringAsFixed(2)}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                            .toList(),
                        Divider(),
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
                              '₹${orderTotal.toStringAsFixed(2)}',
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
                              onPressed: () => _cancelOrder(orders[index].id),
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
        'isActive': false,
        'cancelledAt': FieldValue.serverTimestamp(),
      });

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
