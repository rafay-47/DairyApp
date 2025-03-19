import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../constants.dart';

class AdminOrders extends StatefulWidget {
  @override
  _AdminOrdersState createState() => _AdminOrdersState();
}

class _AdminOrdersState extends State<AdminOrders> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Order Management'),
          backgroundColor: Constants.primaryColor,
          bottom: TabBar(
            tabs: [
              Tab(text: 'Processing'),
              Tab(text: 'Shipped'),
              Tab(text: 'Delivered/Cancelled'),
            ],
            labelColor: Constants.accentColor,
            unselectedLabelColor: Colors.white ,
          ),
        ),
        body: TabBarView(
          children: [
            _buildOrdersList('Processing'),
            _buildOrdersList('Shipped'),
            _buildOrdersList('Completed'),
          ],
        ),
      ),
    );
  }

  Stream<QuerySnapshot> _getOrders(String status) {
    if (status == 'Completed') {
      return _firestore
          .collection('orders')
          .where('status', whereIn: ['Delivered', 'Cancelled'])
          .orderBy('orderDate', descending: true)
          .snapshots();
    }
    return _firestore
        .collection('orders')
        .where('status', isEqualTo: status)
        .orderBy('orderDate', descending: true)
        .snapshots();
  }

  Widget _buildOrdersList(String status) {
    return StreamBuilder<QuerySnapshot>(
      stream: _getOrders(status),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        final orders = snapshot.data?.docs ?? [];

        if (orders.isEmpty) {
          return Center(child: Text('No ${status.toLowerCase()} orders'));
        }

        return ListView.builder(
          padding: EdgeInsets.all(16),
          itemCount: orders.length,
          itemBuilder: (context, index) {
            final orderData = orders[index].data() as Map<String, dynamic>;
            final orderDate = orderData['orderDate'] as Timestamp;
            final orderStatus = orderData['status'] as String;
            final orderItems = List<Map<String, dynamic>>.from(
              orderData['items'] ?? [],
            );
            final total = orderData['total']?.toDouble() ?? 0.0;
            final userEmail = orderData['userEmail'] as String?;
            final orderNumber =
                orderData['orderNumber'] ?? orders[index].id.substring(0, 8);

            // ... in the _buildOrdersList method ...

            return Card(
              elevation: 1,
              margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Order #$orderNumber',
                          style: TextStyle(
                            color: Colors.blue,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Ordered on: ${DateFormat('MMM dd, yyyy hh:mm a').format(orderDate.toDate())}',
                          style: TextStyle(fontSize: 14),
                        ),
                        Text(
                          'Customer: ${userEmail ?? "Unknown"}',
                          style: TextStyle(fontSize: 14),
                        ),
                        SizedBox(height: 4),
                        Row(
                          children: [
                            Text('Status: ', style: TextStyle(fontSize: 14)),
                            Text(
                              orderStatus,
                              style: TextStyle(
                                color:
                                    orderStatus == 'Processing'
                                        ? Colors.orange[700]
                                        : orderStatus == 'Shipped'
                                        ? Colors.green
                                        : Colors.red,
                                fontWeight: FontWeight.w500,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  ExpansionTile(
                    tilePadding: EdgeInsets.symmetric(horizontal: 16),
                    title: Text(
                      'Order Details',
                      style: TextStyle(
                        color: Colors.blue,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    children: [
                      Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
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
                                          '₹${(item['price'] * item['quantity']).toStringAsFixed(2)}',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                                .toList(),
                            SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Subtotal',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.blue,
                                  ),
                                ),
                                Text(
                                  '₹${total.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Delivery Charge',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.blue,
                                  ),
                                ),
                                Text(
                                  'FREE',
                                  style: TextStyle(
                                    color: Colors.green,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
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
                                    fontSize: 14,
                                    color: Colors.blue,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  '₹${total.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.blue,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            if (orderStatus == 'Processing' ||
                                orderStatus == 'Shipped')
                              Center(
                                child: Padding(
                                  padding: EdgeInsets.symmetric(vertical: 16),
                                  child: ElevatedButton(
                                    onPressed:
                                        () => _updateOrderStatus(
                                          orders[index].id,
                                          orderStatus == 'Processing'
                                              ? 'Shipped'
                                              : 'Delivered',
                                        ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                          orderStatus == 'Processing'
                                              ? Colors.orange[700]
                                              : Colors.green,
                                      minimumSize: Size(140, 36),
                                      maximumSize: Size(180, 36),
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 16,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      elevation: 0,
                                    ),
                                    child: Text(
                                      orderStatus == 'Processing'
                                          ? 'Mark as Shipped'
                                          : 'Mark as Delivered',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _updateOrderStatus(String orderId, String newStatus) async {
    try {
      await _firestore.collection('orders').doc(orderId).update({
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Order marked as $newStatus'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update order status: $error'),
          backgroundColor: Colors.red,
        ),
      );
    }
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
}
