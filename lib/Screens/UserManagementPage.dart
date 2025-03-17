import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:dairyapp/constants.dart';

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
        backgroundColor: Constants.primaryColor,
        actions: [IconButton(icon: Icon(Icons.refresh), onPressed: _loadUsers)],
      ),
      body: Container(
        color: Constants.backgroundColor,
        child:
            _isLoading
                ? Center(
                  child: CircularProgressIndicator(
                    color: Constants.primaryColor,
                  ),
                )
                : _users.isEmpty
                ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: EdgeInsets.all(30),
                        decoration: BoxDecoration(
                          color: Constants.primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Icon(
                          Icons.people_outline,
                          size: 80,
                          color: Constants.primaryColor,
                        ),
                      ),
                      SizedBox(height: 24),
                      Text(
                        'No users found',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Constants.textDark,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Add users to get started',
                        style: TextStyle(
                          fontSize: 16,
                          color: Constants.textLight,
                        ),
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
                      elevation: 2,
                      margin: EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        contentPadding: EdgeInsets.all(16),
                        leading: CircleAvatar(
                          backgroundColor: Constants.primaryColor,
                          radius: 25,
                          child: Text(
                            fullName.isNotEmpty
                                ? fullName[0].toUpperCase()
                                : '?',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ),
                        title: Text(
                          fullName,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        subtitle: Text(
                          user['email'] ?? 'No email',
                          style: TextStyle(color: Constants.textLight),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(
                                Icons.edit,
                                color: Constants.accentColor,
                              ),
                              onPressed: () => _editUser(user),
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.delete,
                                color: Constants.errorColor,
                              ),
                              onPressed: () => _confirmDeleteUser(user),
                            ),
                          ],
                        ),
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
          Icon(icon, color: Constants.primaryColor),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(color: Constants.textDark, fontSize: 12),
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
                          color: Constants.primaryColor,
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
                                  color: Constants.textLight,
                                ),
                                SizedBox(height: 16),
                                Text(
                                  'No orders found',
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Constants.textLight,
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
                                        color: Constants.primaryColor,
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
    if (status == null) return Constants.primaryColor;

    if (status is bool) {
      return status ? Constants.successColor : Constants.errorColor;
    }

    switch (status.toString().toLowerCase()) {
      case 'true':
      case 'delivered':
        return Constants.successColor;
      case 'false':
      case 'cancelled':
        return Constants.errorColor;
      case 'processing':
        return Constants.warningColor;
      default:
        return Constants.primaryColor;
    }
  }

  void _editUser(Map<String, dynamic> user) {
    // Implement the edit user functionality
  }

  void _confirmDeleteUser(Map<String, dynamic> user) {
    // Implement the confirm delete user functionality
  }
}
