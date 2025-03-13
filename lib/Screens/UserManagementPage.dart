import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class UserManagement extends StatefulWidget {
  const UserManagement({Key? key}) : super(key: key);

  @override
  _UserManagementState createState() => _UserManagementState();
}

class _UserManagementState extends State<UserManagement> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = true;
  List<Map<String, dynamic>> _users = [];
  final DateFormat dateFormatter = DateFormat('MMM dd, yyyy HH:mm');

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final usersSnapshot =
          await _firestore
              .collection('users')
              .where('isAdmin', isEqualTo: false)
              .get();

      _users =
          usersSnapshot.docs.map((doc) {
            final data = doc.data();
            return {
              'uid': doc.id,
              'name': data['Name'] ?? '',
              'surname': data['Surname'] ?? '',
              'email': data['Email'] ?? '',
              'number': data['Number'] ?? '',
              'address': data['Address'] ?? '',
              'isAdmin': data['isAdmin'] ?? false,
              'status': data['Status'] ?? true,
              'bill': data['Bill'] ?? '0',
              'cartValue': data['CartValue'] ?? 0,
              'plan': data['Plan'] ?? '',
              'days': data['Days'] ?? {},
            };
          }).toList();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading users: $e')));
      }
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleUserStatus(String userId, bool currentStatus) async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            currentStatus ? 'Deactivate User?' : 'Activate User?',
            style: TextStyle(color: currentStatus ? Colors.red : Colors.green),
          ),
          content: Text(
            currentStatus
                ? 'This user will not be able to login until reactivated.'
                : 'This will allow the user to login again.',
          ),
          actions: [
            TextButton(
              child: Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: currentStatus ? Colors.red : Colors.green,
              ),
              child: Text(
                currentStatus ? 'Deactivate' : 'Activate',
                style: TextStyle(color: Colors.white),
              ),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );

    if (confirm ?? false) {
      try {
        await _firestore.collection('users').doc(userId).update({
          'Status': !currentStatus,
        });
        await _loadUsers();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                currentStatus
                    ? 'User has been deactivated'
                    : 'User has been activated',
              ),
              backgroundColor: currentStatus ? Colors.red : Colors.green,
              action: SnackBarAction(
                label: 'DISMISS',
                textColor: Colors.white,
                onPressed: () {},
              ),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error updating user status: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('User Management'),
        backgroundColor: Color.fromRGBO(22, 102, 225, 1),
        actions: [IconButton(icon: Icon(Icons.refresh), onPressed: _loadUsers)],
      ),
      body: Container(
        color: Colors.grey[100],
        child:
            _isLoading
                ? Center(child: CircularProgressIndicator())
                : _users.isEmpty
                ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.people_outline,
                        size: 80,
                        color: Colors.grey[400],
                      ),
                      SizedBox(height: 16),
                      Text(
                        'No users found',
                        style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                )
                : ListView.builder(
                  padding: EdgeInsets.all(16),
                  itemCount: _users.length,
                  itemBuilder: (context, index) {
                    final user = _users[index];
                    final fullName =
                        '${user['name']} ${user['surname']}'.trim();

                    return Card(
                      elevation: 4,
                      margin: EdgeInsets.only(bottom: 16),
                      child: ExpansionTile(
                        leading: Stack(
                          children: [
                            CircleAvatar(
                              backgroundColor: Color.fromRGBO(22, 102, 225, 1),
                              child: Text(
                                fullName.isNotEmpty
                                    ? fullName[0].toUpperCase()
                                    : '?',
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: Container(
                                padding: EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color:
                                      user['status']
                                          ? Colors.green
                                          : Colors.red,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2,
                                  ),
                                ),
                                child: Icon(
                                  user['status'] ? Icons.check : Icons.close,
                                  size: 8,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                        title: Text(
                          fullName,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color.fromRGBO(22, 102, 225, 1),
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(user['email'] ?? ''),
                            SizedBox(height: 4),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    user['status']
                                        ? Colors.green.withOpacity(0.1)
                                        : Colors.red.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color:
                                      user['status']
                                          ? Colors.green
                                          : Colors.red,
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    user['status']
                                        ? Icons.check_circle
                                        : Icons.cancel,
                                    size: 16,
                                    color:
                                        user['status']
                                            ? Colors.green
                                            : Colors.red,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    user['status'] ? 'Active' : 'Deactivated',
                                    style: TextStyle(
                                      color:
                                          user['status']
                                              ? Colors.green
                                              : Colors.red,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        trailing: Switch(
                          value: user['status'],
                          onChanged:
                              (value) => _toggleUserStatus(
                                user['uid'],
                                user['status'],
                              ),
                          activeColor: Color.fromRGBO(22, 102, 225, 1),
                          activeTrackColor: Color.fromRGBO(22, 102, 225, 0.3),
                        ),
                        children: [
                          Padding(
                            padding: EdgeInsets.all(16),
                            child: Column(
                              children: [
                                _buildInfoRow(
                                  Icons.phone,
                                  'Phone',
                                  user['number'] ?? 'Not provided',
                                ),
                                _buildInfoRow(
                                  Icons.location_on,
                                  'Address',
                                  user['address'] ?? 'Not provided',
                                ),
                                _buildInfoRow(
                                  Icons.receipt,
                                  'Current Bill',
                                  '₹${user['bill']}',
                                ),
                                _buildInfoRow(
                                  Icons.shopping_cart,
                                  'Cart Value',
                                  '₹${user['cartValue']}',
                                ),
                                if (user['plan'] != null &&
                                    user['plan'].toString().isNotEmpty)
                                  _buildInfoRow(
                                    Icons.calendar_today,
                                    'Subscription Plan',
                                    user['plan'].toString(),
                                  ),
                                SizedBox(height: 16),
                                ElevatedButton.icon(
                                  onPressed:
                                      () => _showOrderHistory(
                                        context,
                                        user['uid'],
                                        fullName,
                                      ),
                                  icon: Icon(Icons.history),
                                  label: Text('View Order History'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Color.fromRGBO(
                                      22,
                                      102,
                                      225,
                                      1,
                                    ),
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 24,
                                      vertical: 12,
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
                ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: Color.fromRGBO(22, 102, 225, 1)),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
                Text(
                  value,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showOrderHistory(BuildContext context, String userId, String userName) {
    showDialog(
      context: context,
      builder:
          (context) => Dialog(
            child: Container(
              width: MediaQuery.of(context).size.width * 0.9,
              height: MediaQuery.of(context).size.height * 0.8,
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '$userName\'s Orders',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color.fromRGBO(22, 102, 225, 1),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  Divider(),
                  Expanded(
                    child: FutureBuilder<QuerySnapshot>(
                      future:
                          FirebaseFirestore.instance
                              .collection('orders')
                              .where('uid', isEqualTo: userId)
                              .get(),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return Center(
                            child: Text(
                              'Error loading orders: ${snapshot.error}',
                            ),
                          );
                        }

                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
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
                                  'No orders found',
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        return ListView.builder(
                          itemCount: orders.length,
                          itemBuilder: (context, index) {
                            final order =
                                orders[index].data() as Map<String, dynamic>;

                            return Card(
                              margin: EdgeInsets.symmetric(vertical: 4),
                              child: ListTile(
                                title: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Order #${orders[index].id.substring(0, 8)}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      '₹${order['total'] ?? '0'}',
                                      style: TextStyle(
                                        color: Color.fromRGBO(22, 102, 225, 1),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (order['Array'] != null)
                                      Text(
                                        'Items: ${order['Array'].toString()}',
                                      ),
                                    Row(
                                      children: [
                                        Text('Status: '),
                                        Container(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: _getStatusColor(
                                              order['Status'],
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: Text(
                                            order['Status']?.toString() ??
                                                'Processing',
                                            style: TextStyle(
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  Color _getStatusColor(dynamic status) {
    if (status == null) return Colors.blue;

    if (status is bool) {
      return status ? Colors.green : Colors.red;
    }

    switch (status.toString().toLowerCase()) {
      case 'true':
      case 'delivered':
        return Colors.green;
      case 'false':
      case 'cancelled':
        return Colors.red;
      case 'processing':
        return Colors.orange;
      default:
        return Colors.blue;
    }
  }
}
