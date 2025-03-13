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
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text('My Orders'),
          backgroundColor: Color.fromRGBO(22, 102, 225, 1),
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

  Widget _buildOrdersList(bool isActive) {
    return StreamBuilder<QuerySnapshot>(
      stream:
          _firestore
              .collection('orders')
              .where('uid', isEqualTo: currentUser?.uid)
              .where('isActive', isEqualTo: isActive)
              .orderBy('timestamp', descending: true)
              .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
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
                Icon(Icons.shopping_bag_outlined, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  isActive ? 'No active orders' : 'No past orders',
                  style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: orders.length,
          itemBuilder: (context, index) {
            final order = orders[index].data() as Map<String, dynamic>;
            final orderTime = (order['timestamp'] as Timestamp).toDate();
            final canCancel = _canCancelOrder(orderTime);
            final items = order['Array'] as List<dynamic>? ?? [];

            return Card(
              margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ExpansionTile(
                title: Text(
                  'Order #${orders[index].id.substring(0, 8)}',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ordered on: ${DateFormat('MMM dd, yyyy hh:mm a').format(orderTime)}',
                    ),
                    Text(
                      'Total: ₹${order['total'] ?? '0'}',
                      style: TextStyle(
                        color: Color.fromRGBO(22, 102, 225, 1),
                        fontWeight: FontWeight.bold,
                      ),
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
                          'Items:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 8),
                        ...items
                            .map(
                              (item) => Padding(
                                padding: EdgeInsets.only(bottom: 4),
                                child: Text('• $item'),
                              ),
                            )
                            .toList(),
                        SizedBox(height: 16),
                        if (isActive && canCancel)
                          Center(
                            child: ElevatedButton.icon(
                              onPressed:
                                  () =>
                                      _showCancelConfirmation(orders[index].id),
                              icon: Icon(Icons.cancel),
                              label: Text('Cancel Order'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                padding: EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 12,
                                ),
                              ),
                            ),
                          ),
                        if (isActive && !canCancel)
                          Center(
                            child: Text(
                              'Orders can only be cancelled before 12 AM',
                              style: TextStyle(
                                color: Colors.red,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
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

  bool _canCancelOrder(DateTime orderTime) {
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day + 1);
    return orderTime.isBefore(midnight);
  }

  Future<void> _showCancelConfirmation(String orderId) async {
    return showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Cancel Order'),
            content: Text('Are you sure you want to cancel this order?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('No'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _cancelOrder(orderId);
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: Text('Yes, Cancel'),
              ),
            ],
          ),
    );
  }

  Future<void> _cancelOrder(String orderId) async {
    setState(() {
      _isLoading = true;
    });

    try {
      await _firestore.collection('orders').doc(orderId).update({
        'isActive': false,
        'status': 'cancelled',
        'cancelledAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Order cancelled successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error cancelling order: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
}
