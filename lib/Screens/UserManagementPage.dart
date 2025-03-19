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
  bool _isCreating = false;
  List<Map<String, dynamic>> _users = [];
  final DateFormat dateFormatter = DateFormat('MMM dd, yyyy HH:mm');

  // Controllers for edit user form
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _surnameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _numberController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();

  // At the beginning of the class, add these controllers
  final TextEditingController _adminNameController = TextEditingController();
  final TextEditingController _adminSurnameController = TextEditingController();
  final TextEditingController _adminEmailController = TextEditingController();
  final TextEditingController _adminNumberController = TextEditingController();
  final TextEditingController _adminPasswordController =
      TextEditingController();
  final TextEditingController _adminConfirmPasswordController =
      TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _surnameController.dispose();
    _emailController.dispose();
    _numberController.dispose();
    _addressController.dispose();
    // Add these new controllers to dispose
    _adminNameController.dispose();
    _adminSurnameController.dispose();
    _adminEmailController.dispose();
    _adminNumberController.dispose();
    _adminPasswordController.dispose();
    _adminConfirmPasswordController.dispose();
    super.dispose();
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
              'createdAt': data['createdAt'],
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

  void _editUser(Map<String, dynamic> user) {
    // Set initial values to controllers
    _nameController.text = user['name'] ?? '';
    _surnameController.text = user['surname'] ?? '';
    _emailController.text = user['email'] ?? '';
    _numberController.text = user['number'] ?? '';
    _addressController.text = user['address'] ?? '';

    showDialog(
      context: context,
      builder:
          (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Container(
              width: MediaQuery.of(context).size.width * 0.9,
              padding: EdgeInsets.all(20),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Edit User',
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
                    SizedBox(height: 16),
                    TextField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: 'First Name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    SizedBox(height: 16),
                    TextField(
                      controller: _surnameController,
                      decoration: InputDecoration(
                        labelText: 'Last Name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    SizedBox(height: 16),
                    TextField(
                      controller: _emailController,
                      decoration: InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(),
                      ),
                      readOnly: true, // Email should not be editable
                      enabled: false,
                    ),
                    SizedBox(height: 16),
                    TextField(
                      controller: _numberController,
                      decoration: InputDecoration(
                        labelText: 'Phone Number',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                    SizedBox(height: 16),
                    TextField(
                      controller: _addressController,
                      decoration: InputDecoration(
                        labelText: 'Address',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                    ),
                    SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text('Cancel'),
                        ),
                        SizedBox(width: 8),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Constants.primaryColor,
                          ),
                          onPressed: () => _updateUserInfo(user['uid']),
                          child: Text('Update'),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Divider(),
                    SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Account Status',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Switch(
                          value: user['status'] ?? true,
                          activeColor: Constants.successColor,
                          inactiveTrackColor: Constants.errorColor,
                          onChanged: (value) {
                            Navigator.pop(context);
                            _toggleUserStatus(
                              user['uid'],
                              user['status'] ?? true,
                            );
                          },
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Constants.accentColor,
                        minimumSize: Size(double.infinity, 45),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        _showOrderHistory(
                          context,
                          user['uid'],
                          '${user['name']} ${user['surname']}'.trim(),
                        );
                      },
                      icon: Icon(Icons.receipt_long),
                      label: Text('View Order History'),
                    ),
                  ],
                ),
              ),
            ),
          ),
    );
  }

  Future<void> _updateUserInfo(String userId) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'Name': _nameController.text.trim(),
        'Surname': _surnameController.text.trim(),
        'Number': _numberController.text.trim(),
        'Address': _addressController.text.trim(),
      });

      Navigator.pop(context);
      await _loadUsers();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('User information updated successfully'),
          backgroundColor: Constants.successColor,
        ),
      );
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating user: $e'),
          backgroundColor: Constants.errorColor,
        ),
      );
    }
  }

  void _confirmDeleteUser(Map<String, dynamic> user) {
    final fullName = '${user['name']} ${user['surname']}'.trim();

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(
              'Delete User Account',
              style: TextStyle(color: Constants.errorColor),
            ),
            content: RichText(
              text: TextSpan(
                style: TextStyle(color: Colors.black87, fontSize: 16),
                children: [
                  TextSpan(text: 'Are you sure you want to delete '),
                  TextSpan(
                    text: fullName.isNotEmpty ? fullName : user['email'],
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(text: '\'s account? This action cannot be undone.'),
                ],
              ),
            ),
            actions: [
              TextButton(
                child: Text('Cancel'),
                onPressed: () => Navigator.pop(context),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Constants.errorColor,
                ),
                child: Text('Delete', style: TextStyle(color: Colors.white)),
                onPressed: () => _deleteUser(user['uid'], user['email']),
              ),
            ],
          ),
    );
  }

  Future<void> _deleteUser(String userId, String email) async {
    Navigator.pop(context); // Close the dialog
    setState(() {
      _isLoading = true;
    });

    try {
      // First delete their data from Firestore
      await _firestore.collection('users').doc(userId).delete();

      // Then try to delete the Auth user (requires admin SDK or cloud functions)
      // This is typically done in a Cloud Function as client-side code can't delete auth users
      // showDialog to inform the admin they need to delete the Auth user separately

      await _loadUsers();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('User data has been deleted.'),
          action: SnackBarAction(label: 'OKAY', onPressed: () {}),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting user: $e'),
          backgroundColor: Constants.errorColor,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
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
                              .where('userId', isEqualTo: userId)
                              .orderBy('timestamp', descending: true)
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
                            final items = order['items'] as List?;
                            final orderDate =
                                order['timestamp'] != null
                                    ? (order['timestamp'] as Timestamp).toDate()
                                    : null;

                            return Card(
                              margin: EdgeInsets.symmetric(vertical: 4),
                              child: ExpansionTile(
                                title: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Order #${order['orderNumber'] ?? orders[index].id.substring(0, 8)}',
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
                                    if (orderDate != null)
                                      Text(
                                        'Date: ${dateFormatter.format(orderDate)}',
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
                                              order['status'],
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: Text(
                                            order['status']?.toString() ??
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
                                children: [
                                  Padding(
                                    padding: EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Order Details',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                        Divider(),
                                        if (items != null && items.isNotEmpty)
                                          ...items.map((item) {
                                            return ListTile(
                                              dense: true,
                                              title: Text(
                                                item['name'] ?? 'Unknown Item',
                                              ),
                                              subtitle: Text(
                                                'Qty: ${item['quantity'] ?? 1}',
                                              ),
                                              trailing: Text(
                                                '₹${item['price'] ?? '0'}',
                                              ),
                                            );
                                          }).toList()
                                        else
                                          Text('No item details available'),
                                        Divider(),
                                        _buildInfoRow(
                                          Icons.attach_money,
                                          'Subtotal',
                                          '₹${order['subtotal'] ?? '0'}',
                                        ),
                                        _buildInfoRow(
                                          Icons.local_shipping,
                                          'Delivery Charge',
                                          '₹${order['deliveryCharge'] ?? '0'}',
                                        ),
                                        if ((order['couponDiscount'] ?? 0) > 0)
                                          _buildInfoRow(
                                            Icons.discount,
                                            'Coupon Discount',
                                            '-₹${order['couponDiscount'] ?? '0'}',
                                          ),
                                        Divider(),
                                        _buildInfoRow(
                                          Icons.payment,
                                          'Payment Method',
                                          order['paymentMethod'] ?? 'Unknown',
                                        ),
                                        _buildInfoRow(
                                          Icons.home,
                                          'Delivery Address',
                                          order['deliveryAddress'] ??
                                              'No address provided',
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('User Management'),
        backgroundColor: Constants.primaryColor,
        actions: [
          IconButton(icon: Icon(Icons.refresh), onPressed: _loadUsers),
          IconButton(
            icon: Icon(Icons.admin_panel_settings),
            onPressed: _showCreateAdminDialog,
            tooltip: 'Create Admin Account',
          ),
        ],
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
                      child: InkWell(
                        onTap: () => _showUserDetails(user),
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Row(
                            children: [
                              CircleAvatar(
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
                              SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      fullName.isNotEmpty
                                          ? fullName
                                          : 'Unnamed User',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      user['email'] ?? 'No email',
                                      style: TextStyle(
                                        color: Constants.textLight,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.phone,
                                          size: 14,
                                          color: Constants.textLight,
                                        ),
                                        SizedBox(width: 4),
                                        Text(
                                          user['number'] ?? 'No phone',
                                          style: TextStyle(
                                            color: Constants.textLight,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                children: [
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          (user['status'] ?? true)
                                              ? Constants.successColor
                                              : Constants.errorColor,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      (user['status'] ?? true)
                                          ? 'Active'
                                          : 'Inactive',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: Icon(
                                          Icons.edit,
                                          color: Constants.accentColor,
                                        ),
                                        onPressed: () => _editUser(user),
                                        iconSize: 20,
                                        padding: EdgeInsets.all(4),
                                        constraints: BoxConstraints(),
                                      ),
                                      SizedBox(width: 8),
                                      IconButton(
                                        icon: Icon(
                                          Icons.delete,
                                          color: Constants.errorColor,
                                        ),
                                        onPressed:
                                            () => _confirmDeleteUser(user),
                                        iconSize: 20,
                                        padding: EdgeInsets.all(4),
                                        constraints: BoxConstraints(),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
      ),
    );
  }

  void _showUserDetails(Map<String, dynamic> user) {
    final fullName = '${user['name']} ${user['surname']}'.trim();

    showDialog(
      context: context,
      builder:
          (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Container(
              width: MediaQuery.of(context).size.width * 0.9,
              padding: EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'User Details',
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
                  CircleAvatar(
                    backgroundColor: Constants.primaryColor,
                    radius: 35,
                    child: Text(
                      fullName.isNotEmpty ? fullName[0].toUpperCase() : '?',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 24,
                      ),
                    ),
                  ),
                  SizedBox(height: 16),
                  Text(
                    fullName.isNotEmpty ? fullName : 'Unnamed User',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 16),
                  _buildInfoRow(
                    Icons.email,
                    'Email',
                    user['email'] ?? 'No email provided',
                  ),
                  _buildInfoRow(
                    Icons.phone,
                    'Phone',
                    user['number'] ?? 'No phone provided',
                  ),
                  _buildInfoRow(
                    Icons.home,
                    'Address',
                    user['address'] ?? 'No address provided',
                  ),
                  Divider(),
                  _buildInfoRow(
                    Icons.shopping_basket,
                    'Total Orders',
                    '...', // We'll need to fetch this from Firestore
                  ),
                  _buildInfoRow(
                    Icons.credit_card,
                    'Current Bill',
                    '₹${user['bill'] ?? '0'}',
                  ),
                  Divider(),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Constants.primaryColor,
                          ),
                          onPressed: () {
                            Navigator.pop(context);
                            _editUser(user);
                          },
                          icon: Icon(Icons.edit),
                          label: Text('Edit User'),
                        ),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Constants.accentColor,
                          ),
                          onPressed: () {
                            Navigator.pop(context);
                            _showOrderHistory(
                              context,
                              user['uid'],
                              fullName.isNotEmpty ? fullName : user['email'],
                            );
                          },
                          icon: Icon(Icons.receipt_long),
                          label: Text('View Orders'),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Constants.errorColor,
                      minimumSize: Size(double.infinity, 45),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      _confirmDeleteUser(user);
                    },
                    icon: Icon(Icons.delete_forever),
                    label: Text('Delete Account'),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  // Fetch order count for a specific user
  Future<String> _getUserOrderCount(String userId) async {
    try {
      final QuerySnapshot orderSnap =
          await FirebaseFirestore.instance
              .collection('orders')
              .where('userId', isEqualTo: userId)
              .get();

      return orderSnap.size.toString();
    } catch (e) {
      print('Error fetching order count: $e');
      return '0';
    }
  }

  // Method to show a user's wallet balance and transactions
  void _showWalletDetails(String userId, String userName) {
    showDialog(
      context: context,
      builder:
          (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Container(
              width: MediaQuery.of(context).size.width * 0.9,
              height: MediaQuery.of(context).size.height * 0.7,
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '$userName\'s Wallet',
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
                  StreamBuilder<DocumentSnapshot>(
                    stream:
                        FirebaseFirestore.instance
                            .collection('wallets')
                            .doc(userId)
                            .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Center(child: CircularProgressIndicator());
                      }

                      if (snapshot.hasError) {
                        return Center(child: Text('Error loading wallet data'));
                      }

                      if (!snapshot.hasData || !snapshot.data!.exists) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.account_balance_wallet_outlined,
                                size: 80,
                                color: Constants.textLight,
                              ),
                              SizedBox(height: 16),
                              Text(
                                'No wallet found for this user',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Constants.textLight,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      final walletData =
                          snapshot.data!.data() as Map<String, dynamic>?;
                      final balance = walletData?['balance'] ?? 0.0;

                      return Column(
                        children: [
                          Card(
                            color: Constants.primaryColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: Column(
                                children: [
                                  Text(
                                    'Current Balance',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    '₹${balance.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Constants.successColor,
                                  ),
                                  onPressed: () => _showAddFundsDialog(userId),
                                  icon: Icon(Icons.add),
                                  label: Text('Add Funds'),
                                ),
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Constants.errorColor,
                                  ),
                                  onPressed:
                                      () => _showDeductFundsDialog(userId),
                                  icon: Icon(Icons.remove),
                                  label: Text('Deduct Funds'),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Transaction History',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Divider(),
                          Expanded(
                            child: StreamBuilder<QuerySnapshot>(
                              stream:
                                  FirebaseFirestore.instance
                                      .collection('wallet_transactions')
                                      .where('userId', isEqualTo: userId)
                                      .orderBy('timestamp', descending: true)
                                      .limit(20)
                                      .snapshots(),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState ==
                                    ConnectionState.waiting) {
                                  return Center(
                                    child: CircularProgressIndicator(),
                                  );
                                }

                                if (snapshot.hasError) {
                                  return Center(
                                    child: Text('Error loading transactions'),
                                  );
                                }

                                final transactions = snapshot.data?.docs ?? [];

                                if (transactions.isEmpty) {
                                  return Center(
                                    child: Text('No transaction history'),
                                  );
                                }

                                return ListView.builder(
                                  itemCount: transactions.length,
                                  itemBuilder: (context, index) {
                                    final transaction =
                                        transactions[index].data()
                                            as Map<String, dynamic>;
                                    final isCredit =
                                        transaction['type'] == 'credit';
                                    final amount = transaction['amount'] ?? 0.0;
                                    final timestamp =
                                        transaction['timestamp'] as Timestamp?;
                                    final date =
                                        timestamp?.toDate() ?? DateTime.now();
                                    final description =
                                        transaction['description'] ?? '';

                                    return ListTile(
                                      leading: CircleAvatar(
                                        backgroundColor:
                                            isCredit
                                                ? Constants.successColor
                                                : Constants.errorColor,
                                        child: Icon(
                                          isCredit
                                              ? Icons.arrow_downward
                                              : Icons.arrow_upward,
                                          color: Colors.white,
                                        ),
                                      ),
                                      title: Text(description),
                                      subtitle: Text(
                                        dateFormatter.format(date),
                                      ),
                                      trailing: Text(
                                        '${isCredit ? '+' : '-'}₹${amount.toStringAsFixed(2)}',
                                        style: TextStyle(
                                          color:
                                              isCredit
                                                  ? Constants.successColor
                                                  : Constants.errorColor,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
    );
  }

  void _showAddFundsDialog(String userId) {
    final TextEditingController amountController = TextEditingController();
    final TextEditingController reasonController = TextEditingController();

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Add Funds to Wallet'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: amountController,
                  decoration: InputDecoration(
                    labelText: 'Amount (₹)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                ),
                SizedBox(height: 16),
                TextField(
                  controller: reasonController,
                  decoration: InputDecoration(
                    labelText: 'Reason',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Constants.successColor,
                ),
                onPressed: () {
                  final amount = double.tryParse(amountController.text);
                  if (amount == null || amount <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Please enter a valid amount')),
                    );
                    return;
                  }

                  _adjustWalletBalance(
                    userId,
                    amount,
                    'credit',
                    reasonController.text.trim(),
                  );
                  Navigator.pop(context);
                },
                child: Text('Add Funds'),
              ),
            ],
          ),
    );
  }

  void _showDeductFundsDialog(String userId) {
    final TextEditingController amountController = TextEditingController();
    final TextEditingController reasonController = TextEditingController();

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Deduct Funds from Wallet'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: amountController,
                  decoration: InputDecoration(
                    labelText: 'Amount (₹)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                ),
                SizedBox(height: 16),
                TextField(
                  controller: reasonController,
                  decoration: InputDecoration(
                    labelText: 'Reason',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Constants.errorColor,
                ),
                onPressed: () {
                  final amount = double.tryParse(amountController.text);
                  if (amount == null || amount <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Please enter a valid amount')),
                    );
                    return;
                  }

                  _adjustWalletBalance(
                    userId,
                    amount,
                    'debit',
                    reasonController.text.trim(),
                  );
                  Navigator.pop(context);
                },
                child: Text('Deduct Funds'),
              ),
            ],
          ),
    );
  }

  Future<void> _adjustWalletBalance(
    String userId,
    double amount,
    String type,
    String reason,
  ) async {
    try {
      final db = FirebaseFirestore.instance;
      final walletRef = db.collection('wallets').doc(userId);
      final transactionRef = db.collection('wallet_transactions').doc();

      // Use a transaction to ensure data consistency
      await db.runTransaction((transaction) async {
        // Get current wallet balance
        final walletDoc = await transaction.get(walletRef);
        double currentBalance = 0.0;

        if (walletDoc.exists) {
          final walletData = walletDoc.data() as Map<String, dynamic>?;
          currentBalance = (walletData?['balance'] ?? 0.0).toDouble();
        }

        // Calculate new balance
        double newBalance;
        if (type == 'credit') {
          newBalance = currentBalance + amount;
        } else {
          // For debit operations, check if balance is sufficient
          if (currentBalance < amount) {
            throw 'Insufficient balance';
          }
          newBalance = currentBalance - amount;
        }

        // Update or create wallet document
        if (walletDoc.exists) {
          transaction.update(walletRef, {'balance': newBalance});
        } else {
          transaction.set(walletRef, {
            'balance': newBalance,
            'userId': userId,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }

        // Create transaction record
        transaction.set(transactionRef, {
          'amount': amount,
          'type': type,
          'description':
              reason.isEmpty
                  ? (type == 'credit' ? 'Added by admin' : 'Deducted by admin')
                  : reason,
          'userId': userId,
          'timestamp': FieldValue.serverTimestamp(),
          'reference': 'admin_adjustment',
        });
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            type == 'credit'
                ? 'Successfully added ₹${amount.toStringAsFixed(2)} to wallet'
                : 'Successfully deducted ₹${amount.toStringAsFixed(2)} from wallet',
          ),
          backgroundColor:
              type == 'credit' ? Constants.successColor : Constants.accentColor,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error adjusting wallet balance: $e'),
          backgroundColor: Constants.errorColor,
        ),
      );
    }
  }

  void _showCreateAdminDialog() {
    // Reset all admin controllers
    _adminNameController.clear();
    _adminSurnameController.clear();
    _adminEmailController.clear();
    _adminNumberController.clear();
    _adminPasswordController.clear();
    _adminConfirmPasswordController.clear();

    bool _passwordVisible = false;
    

    showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder: (context, setState) {
              return Dialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Container(
                  width: MediaQuery.of(context).size.width * 0.9,
                  padding: EdgeInsets.all(20),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Create Admin Account',
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
                        SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _adminNameController,
                                decoration: InputDecoration(
                                  labelText: 'First Name',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            SizedBox(width: 16),
                            Expanded(
                              child: TextField(
                                controller: _adminSurnameController,
                                decoration: InputDecoration(
                                  labelText: 'Last Name',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 16),
                        TextField(
                          controller: _adminEmailController,
                          decoration: InputDecoration(
                            labelText: 'Email',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.emailAddress,
                        ),
                        SizedBox(height: 16),
                        TextField(
                          controller: _adminNumberController,
                          decoration: InputDecoration(
                            labelText: 'Phone Number',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.phone,
                        ),
                        SizedBox(height: 16),
                        TextField(
                          controller: _adminPasswordController,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            border: OutlineInputBorder(),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _passwordVisible
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                              ),
                              onPressed: () {
                                setState(() {
                                  _passwordVisible = !_passwordVisible;
                                });
                              },
                            ),
                          ),
                        ),
                        SizedBox(height: 16),
                        TextField(
                          controller: _adminConfirmPasswordController,
                          decoration: InputDecoration(
                            labelText: 'Confirm Password',
                            border: OutlineInputBorder(),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _passwordVisible
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                              ),
                              onPressed: () {
                                setState(() {
                                  _passwordVisible = !_passwordVisible;
                                });
                              },
                            ),
                          ),
                        ),
                        SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Constants.primaryColor,
                              padding: EdgeInsets.symmetric(vertical: 12),
                            ),
                            onPressed:
                                _isCreating
                                    ? null
                                    : () => _createAdminAccount(setState),
                            icon:
                                _isCreating
                                    ? Container(
                                      width: 24,
                                      height: 24,
                                      padding: const EdgeInsets.all(2.0),
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 3,
                                      ),
                                    )
                                    : Icon(Icons.admin_panel_settings),
                            label: Text(
                              _isCreating
                                  ? 'Creating Admin...'
                                  : 'Create Admin Account',
                              style: TextStyle(fontSize: 16),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
    );
  }

  Future<void> _createAdminAccount(StateSetter setDialogState) async {
    // Form validation
    if (_adminNameController.text.trim().isEmpty ||
        _adminSurnameController.text.trim().isEmpty ||
        _adminEmailController.text.trim().isEmpty ||
        _adminNumberController.text.trim().isEmpty ||
        _adminPasswordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('All fields are required'),
          backgroundColor: Constants.errorColor,
        ),
      );
      return;
    }

    // Email validation
    if (!RegExp(
      r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
    ).hasMatch(_adminEmailController.text.trim())) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please enter a valid email address'),
          backgroundColor: Constants.errorColor,
        ),
      );
      return;
    }

    // Phone validation
    if (!RegExp(r'^\d{10}$').hasMatch(_adminNumberController.text.trim())) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please enter a valid 10-digit phone number'),
          backgroundColor: Constants.errorColor,
        ),
      );
      return;
    }

    // Password validation
    if (_adminPasswordController.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Password must be at least 6 characters'),
          backgroundColor: Constants.errorColor,
        ),
      );
      return;
    }

    // Confirm passwords match
    if (_adminPasswordController.text != _adminConfirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Passwords do not match'),
          backgroundColor: Constants.errorColor,
        ),
      );
      return;
    }

    // Start creating account
    setDialogState(() {
      _isCreating = true;
    });

    try {
      // Check if email already exists
      final emailCheck =
          await _firestore
              .collection('users')
              .where('Email', isEqualTo: _adminEmailController.text.trim())
              .get();

      if (emailCheck.docs.isNotEmpty) {
        throw 'This email is already registered';
      }

      // Check if phone number already exists
      final phoneCheck =
          await _firestore
              .collection('users')
              .where('Number', isEqualTo: _adminNumberController.text.trim())
              .get();

      if (phoneCheck.docs.isNotEmpty) {
        throw 'This phone number is already registered';
      }

      // Create admin user with Firebase Auth
      UserCredential userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: _adminEmailController.text.trim(),
            password: _adminPasswordController.text,
          );

      // Create an empty map for cart
      var map = <dynamic, dynamic>{};

      // Save admin user data to Firestore
      await _firestore.collection('users').doc(userCredential.user!.uid).set({
        'Name': _adminNameController.text.trim(),
        'Surname': _adminSurnameController.text.trim(),
        'Email': _adminEmailController.text.trim(),
        'Number': _adminNumberController.text.trim(),
        'Address': '',
        'Bill': '0',
        'Plan': '',
        'Days': {},
        'CartValue': 0,
        'Status': true,
        'isAdmin': true, // This is an admin account
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': FirebaseAuth.instance.currentUser?.uid ?? 'unknown',
      });

      // Create empty cart
      await _firestore.collection('cart').doc(userCredential.user!.uid).set({
        'product': map,
      });

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Admin account created successfully'),
          backgroundColor: Constants.successColor,
        ),
      );

      // Close the dialog
      Navigator.pop(context);

      // Refresh user list (though admins won't appear in the list)
      await _loadUsers();
    } catch (e) {
      setDialogState(() {
        _isCreating = false;
      });

      String errorMessage;
      if (e is FirebaseAuthException) {
        switch (e.code) {
          case 'weak-password':
            errorMessage = 'The password is too weak';
            break;
          case 'email-already-in-use':
            errorMessage = 'This email is already registered';
            break;
          case 'invalid-email':
            errorMessage = 'Invalid email address';
            break;
          default:
            errorMessage = e.message ?? 'An error occurred';
        }
      } else {
        errorMessage = e.toString();
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error creating admin account: $errorMessage'),
          backgroundColor: Constants.errorColor,
        ),
      );
    }
  }
}
