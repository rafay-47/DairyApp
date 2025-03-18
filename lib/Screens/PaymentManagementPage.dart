// Add this class at the end of the file, after the last class definition
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dairyapp/constants.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'dart:math';

class PaymentManagementPage extends StatefulWidget {
  @override
  _PaymentManagementPageState createState() => _PaymentManagementPageState();
}

class _PaymentManagementPageState extends State<PaymentManagementPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Filter variables
  String _searchQuery = '';
  String _statusFilter = 'All';
  String _paymentMethodFilter = 'All';
  DateTime? _startDate;
  DateTime? _endDate;

  // Sort variables
  String _sortField = 'timestamp';
  bool _sortAscending = false;

  bool _isLoading = false;
  List<Map<String, dynamic>> _payments = [];
  Map<String, dynamic>? _selectedPayment;

  // For pagination
  DocumentSnapshot? _lastDocument;
  bool _hasMoreData = true;
  final int _pageSize = 20;
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchPayments();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchPayments({bool loadMore = false}) async {
    if (_isLoading ||
        (loadMore && _isLoadingMore) ||
        (loadMore && !_hasMoreData))
      return;

    setState(() {
      if (loadMore) {
        _isLoadingMore = true;
      } else {
        _isLoading = true;
        _payments = [];
        _lastDocument = null;
        _hasMoreData = true;
      }
    });

    try {
      // Start with base query
      Query query = _firestore.collection('payments');

      // Create a list to track applied filters for logging
      List<String> appliedFilters = [];

      // Apply filters one by one and check if each is valid
      if (_statusFilter != 'All') {
        query = query.where('status', isEqualTo: _statusFilter);
        appliedFilters.add('Status: $_statusFilter');
      }

      // Only apply method filter if status filter allows it (can't have multiple == conditions)
      if (_paymentMethodFilter != 'All') {
        query = query.where('paymentMethod', isEqualTo: _paymentMethodFilter);
        appliedFilters.add('Method: $_paymentMethodFilter');
      }

      // Date filtering needs to come after equality filters
      if (_startDate != null) {
        query = query.where(
          'timestamp',
          isGreaterThanOrEqualTo: Timestamp.fromDate(_startDate!),
        );
        appliedFilters.add(
          'Start date: ${_startDate!.toString().substring(0, 10)}',
        );
      }

      if (_endDate != null) {
        // Add one day to end date to include the entire day
        final nextDay = DateTime(
          _endDate!.year,
          _endDate!.month,
          _endDate!.day + 1,
        );
        query = query.where(
          'timestamp',
          isLessThan: Timestamp.fromDate(nextDay),
        );
        appliedFilters.add(
          'End date: ${_endDate!.toString().substring(0, 10)}',
        );
      }

      // Log applied filters for debugging
      print('Applied filters: ${appliedFilters.join(', ')}');

      // Apply sorting (ensure field exists in documents)
      try {
        query = query.orderBy(_sortField, descending: !_sortAscending);
      } catch (e) {
        print('Error applying sort on $_sortField: $e');
        // Fallback to timestamp if sort field causes issues
        query = query.orderBy('timestamp', descending: true);
      }

      // Apply pagination
      if (loadMore && _lastDocument != null) {
        query = query.startAfterDocument(_lastDocument!);
      }

      query = query.limit(_pageSize);

      print('Executing query: ${query.toString()}');
      final QuerySnapshot snapshot = await query.get();

      if (snapshot.docs.isEmpty) {
        setState(() {
          _hasMoreData = false;
          _isLoading = false;
          _isLoadingMore = false;
        });
        return;
      }

      print('Query returned ${snapshot.docs.length} documents');
      _lastDocument = snapshot.docs.last;

      final List<Map<String, dynamic>> newPayments = [];

      // Process documents in batches to prevent UI freezing
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final Map<String, dynamic> payment = {
          'id': doc.id,
          'userId': data['userId'] ?? '',
          'orderRef': data['orderRef'] ?? '',
          'amount': data['amount'] ?? 0.0,
          'paymentMethod': data['paymentMethod'] ?? 'Unknown',
          'status': data['status'] ?? 'Pending',
          'timestamp': data['timestamp'] ?? Timestamp.now(),
          'userEmail': '',
          'userName': '',
        };

        // Get user details if userId exists
        if (payment['userId'].toString().isNotEmpty) {
          try {
            final userDoc =
                await _firestore
                    .collection('users')
                    .doc(payment['userId'])
                    .get();
            if (userDoc.exists) {
              final userData = userDoc.data() as Map<String, dynamic>;
              payment['userEmail'] = userData['email'] ?? '';
              payment['userName'] = userData['name'] ?? 'Unknown User';
            }
          } catch (e) {
            print('Error fetching user for payment ${payment['id']}: $e');
            // Continue with default values
          }
        }

        // Apply search filter after fetching user details
        if (_searchQuery.isNotEmpty) {
          final query = _searchQuery.toLowerCase();
          final String orderRef =
              payment['orderRef']?.toString().toLowerCase() ?? '';
          final String userEmail =
              payment['userEmail']?.toString().toLowerCase() ?? '';
          final String userName =
              payment['userName']?.toString().toLowerCase() ?? '';

          if (orderRef.contains(query) ||
              userEmail.contains(query) ||
              userName.contains(query)) {
            newPayments.add(payment);
          }
        } else {
          newPayments.add(payment);
        }
      }

      setState(() {
        if (loadMore) {
          _payments.addAll(newPayments);
        } else {
          _payments = newPayments;
        }
        _hasMoreData = snapshot.docs.length == _pageSize;
        _isLoading = false;
        _isLoadingMore = false;
      });
    } catch (e) {
      print('Error fetching payments: $e');
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading payments: ${e.toString()}'),
          backgroundColor: Constants.errorColor,
          duration: Duration(seconds: 5),
          action: SnackBarAction(
            label: 'RETRY',
            onPressed: () => _fetchPayments(),
          ),
        ),
      );
    }
  }

  Future<void> _processRefund(Map<String, dynamic> payment) async {
    // Show confirmation dialog
    bool? confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Confirm Refund'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Are you sure you want to process a refund for:'),
                SizedBox(height: 12),
                Text(
                  'Order: ${payment['orderRef']}',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text('User: ${payment['userName']}'),
                Text(
                  'Amount: ₹${payment['amount'].toStringAsFixed(2)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Constants.accentColor,
                  ),
                ),
                SizedBox(height: 16),
                Row(
                  children: [
                    Icon(Icons.warning, color: Colors.amber),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This action will refund the amount to the user\'s wallet and cannot be undone.',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text('CANCEL'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Constants.primaryColor,
                ),
                onPressed: () => Navigator.of(context).pop(true),
                child: Text('CONFIRM REFUND'),
              ),
            ],
          ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);

    try {
      // 1. Update payment status in the payments collection
      await _firestore.collection('payments').doc(payment['id']).update({
        'status': 'Refunded',
        'refundedAt': FieldValue.serverTimestamp(),
        'refundedBy': FirebaseAuth.instance.currentUser?.uid,
      });

      // 2. Add the amount to user's wallet
      final userId = payment['userId'];
      if (userId != null && userId.toString().isNotEmpty) {
        final walletRef = _firestore
            .collection('users')
            .doc(userId)
            .collection('wallet')
            .doc('balance');

        // Run in a transaction to ensure data consistency
        await _firestore.runTransaction((transaction) async {
          DocumentSnapshot walletDoc = await transaction.get(walletRef);

          double currentBalance = 0.0;
          if (walletDoc.exists) {
            final data = walletDoc.data() as Map<String, dynamic>?;
            currentBalance = data?['balance'] ?? 0.0;
            if (currentBalance is! num) currentBalance = 0.0;
          }

          // Update wallet balance
          final newBalance = currentBalance + (payment['amount'] ?? 0.0);
          transaction.set(walletRef, {
            'balance': newBalance,
          }, SetOptions(merge: true));

          // Add transaction record to wallet_transactions
          final transactionRef =
              _firestore
                  .collection('users')
                  .doc(userId)
                  .collection('wallet_transactions')
                  .doc();

          final transactionData = {
            'amount': payment['amount'] ?? 0.0,
            'type': 'CREDIT',
            'description': 'Refund for order ${payment['orderRef']}',
            'refundFor': payment['orderRef'],
            'timestamp': FieldValue.serverTimestamp(),
            'processedBy': 'admin',
          };

          transaction.set(transactionRef, transactionData);
        });
      }

      // 3. Update the order status if needed
      if (payment['orderRef'] != null &&
          payment['orderRef'].toString().isNotEmpty) {
        await _firestore.collection('orders').doc(payment['orderRef']).update({
          'paymentStatus': 'Refunded',
          'refundedAt': FieldValue.serverTimestamp(),
        });
      }

      // 4. Refresh payments data
      _fetchPayments();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Refund processed successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('Error processing refund: $e');
      setState(() => _isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error processing refund: $e'),
          backgroundColor: Constants.errorColor,
        ),
      );
    }
  }

  Future<void> _adjustWalletBalance() async {
    // Show dialog to select user and amount
    final TextEditingController userIdController = TextEditingController();
    final TextEditingController emailController = TextEditingController();
    final TextEditingController amountController = TextEditingController();
    final TextEditingController reasonController = TextEditingController();
    String selectedAction = 'Add';

    await showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder: (context, setState) {
              return AlertDialog(
                title: Text('Adjust Wallet Balance'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Find User:'),
                      SizedBox(height: 8),
                      TextField(
                        controller: emailController,
                        decoration: InputDecoration(
                          labelText: 'User Email',
                          border: OutlineInputBorder(),
                          hintText: 'Enter user email',
                          suffixIcon: IconButton(
                            icon: Icon(Icons.search),
                            onPressed: () async {
                              // Search user by email
                              try {
                                final querySnapshot =
                                    await _firestore
                                        .collection('users')
                                        .where(
                                          'Email',
                                          isEqualTo:
                                              emailController.text.trim(),
                                        )
                                        .limit(1)
                                        .get();

                                if (querySnapshot.docs.isNotEmpty) {
                                  final doc = querySnapshot.docs.first;
                                  final userData = doc.data();

                                  setState(() {
                                    userIdController.text = doc.id;
                                  });

                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'User found: ${userData['name'] ?? 'Unknown'}',
                                      ),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'User not found with that email',
                                      ),
                                      backgroundColor: Colors.orange,
                                    ),
                                  );
                                }
                              } catch (e) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Error searching for user: $e',
                                    ),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            },
                          ),
                        ),
                      ),
                      SizedBox(height: 16),
                      Text('User ID:'),
                      SizedBox(height: 8),
                      TextField(
                        controller: userIdController,
                        decoration: InputDecoration(
                          labelText: 'User ID',
                          border: OutlineInputBorder(),
                          hintText: 'User ID will appear here',
                        ),
                        readOnly: true,
                      ),
                      SizedBox(height: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Text(
                              'Action:',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          // Add Money option
                          Row(
                            children: [
                              Radio<String>(
                                value: 'Add',
                                groupValue: selectedAction,
                                onChanged: (String? value) {
                                  setState(() {
                                    selectedAction = value!;
                                  });
                                },
                              ),
                              Text(
                                'Add Money',
                                style: TextStyle(
                                  color:
                                      selectedAction == 'Add'
                                          ? Constants.primaryColor
                                          : Colors.black,
                                ),
                              ),
                            ],
                          ),
                          // Deduct Money option
                          Row(
                            children: [
                              Radio<String>(
                                value: 'Deduct',
                                groupValue: selectedAction,
                                onChanged: (String? value) {
                                  setState(() {
                                    selectedAction = value!;
                                  });
                                },
                              ),
                              Text(
                                'Deduct Money',
                                style: TextStyle(
                                  color:
                                      selectedAction == 'Deduct'
                                          ? Constants.primaryColor
                                          : Colors.black,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                      Text('Amount:'),
                      SizedBox(height: 8),
                      TextField(
                        controller: amountController,
                        keyboardType: TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Amount (₹)',
                          border: OutlineInputBorder(),
                          hintText: 'Enter amount',
                          prefixText: '₹',
                        ),
                      ),
                      SizedBox(height: 16),
                      Text('Reason:'),
                      SizedBox(height: 8),
                      TextField(
                        controller: reasonController,
                        maxLines: 2,
                        decoration: InputDecoration(
                          labelText: 'Reason for adjustment',
                          border: OutlineInputBorder(),
                          hintText: 'Enter reason for this adjustment',
                        ),
                      ),
                      SizedBox(height: 16),
                      Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.amber, width: 1),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.amber),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'This action will adjust the user\'s wallet balance and will be logged for auditing purposes.',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text('CANCEL'),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Constants.primaryColor,
                    ),
                    onPressed: () async {
                      if (userIdController.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Please select a user first')),
                        );
                        return;
                      }

                      final amount = double.tryParse(amountController.text);
                      if (amount == null || amount <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Please enter a valid amount'),
                          ),
                        );
                        return;
                      }

                      if (reasonController.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Please provide a reason for this adjustment',
                            ),
                          ),
                        );
                        return;
                      }

                      Navigator.of(context).pop({
                        'userId': userIdController.text,
                        'action': selectedAction,
                        'amount': amount,
                        'reason': reasonController.text,
                      });
                    },
                    child: Text('CONFIRM'),
                  ),
                ],
              );
            },
          ),
    ).then((result) async {
      if (result == null) return;

      final Map<String, dynamic> adjustmentData =
          result as Map<String, dynamic>;

      setState(() => _isLoading = true);

      try {
        final userId = adjustmentData['userId'];
        final walletRef = _firestore
            .collection('users')
            .doc(userId)
            .collection('wallet')
            .doc('balance');

        // Run in a transaction to ensure data consistency
        await _firestore.runTransaction((transaction) async {
          DocumentSnapshot walletDoc = await transaction.get(walletRef);

          double currentBalance = 0.0;
          if (walletDoc.exists) {
            final data = walletDoc.data() as Map<String, dynamic>?;
            currentBalance = data?['balance'] ?? 0.0;
            if (currentBalance is! num) currentBalance = 0.0;
          }

          // Update wallet balance
          double newBalance;
          if (adjustmentData['action'] == 'Add') {
            newBalance = currentBalance + adjustmentData['amount'];
          } else {
            // Ensure there's enough balance for deduction
            if (currentBalance < adjustmentData['amount']) {
              throw Exception('Insufficient wallet balance for deduction');
            }
            newBalance = currentBalance - adjustmentData['amount'];
          }

          transaction.set(walletRef, {
            'balance': newBalance,
          }, SetOptions(merge: true));

          // Add transaction record to wallet_transactions
          final transactionRef =
              _firestore
                  .collection('users')
                  .doc(userId)
                  .collection('wallet_transactions')
                  .doc();

          final transactionData = {
            'amount': adjustmentData['amount'],
            'type': adjustmentData['action'] == 'Add' ? 'CREDIT' : 'DEBIT',
            'description':
                'Admin ${adjustmentData['action'] == 'Add' ? 'added' : 'deducted'} funds: ${adjustmentData['reason']}',
            'timestamp': FieldValue.serverTimestamp(),
            'processedBy': FirebaseAuth.instance.currentUser?.uid ?? 'admin',
            'adjustmentReason': adjustmentData['reason'],
          };

          transaction.set(transactionRef, transactionData);
        });

        // Log the admin action
        await _firestore.collection('admin_logs').add({
          'action': 'wallet_adjustment',
          'userId': userId,
          'adminId': FirebaseAuth.instance.currentUser?.uid,
          'amount': adjustmentData['amount'],
          'adjustmentType': adjustmentData['action'],
          'reason': adjustmentData['reason'],
          'timestamp': FieldValue.serverTimestamp(),
        });

        setState(() => _isLoading = false);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Wallet balance adjusted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        print('Error adjusting wallet balance: $e');
        setState(() => _isLoading = false);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adjusting wallet balance: $e'),
            backgroundColor: Constants.errorColor,
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Payment Management'),
        backgroundColor: Constants.primaryColor,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          tabs: [Tab(text: 'Payment Tracking'), Tab(text: 'Wallet Management')],
          labelStyle: TextStyle(color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () => _fetchPayments(),
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildPaymentTrackingTab(), _buildWalletManagementTab()],
      ),
    );
  }

  Widget _buildPaymentTrackingTab() {
    return Column(
      children: [
        _buildFiltersSection(),
        Expanded(
          child:
              _isLoading
                  ? Center(child: CircularProgressIndicator())
                  : _payments.isEmpty
                  ? _buildEmptyState()
                  : _buildPaymentsTable(),
        ),
      ],
    );
  }

  Widget _buildFiltersSection() {
    return Card(
      margin: EdgeInsets.all(16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search by order ID or user',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                      _fetchPayments();
                    },
                  ),
                ),
                SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: _adjustWalletBalance,
                  icon: Icon(Icons.account_balance_wallet),
                  label: Text('Adjust'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Constants.accentColor,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 800) {
                  return Column(
                    children: [
                      _buildStatusFilterDropdown(),
                      SizedBox(height: 12),
                      _buildPaymentMethodDropdown(),
                      SizedBox(height: 12),
                      _buildDateRangeSelector(),
                    ],
                  );
                } else {
                  return Row(
                    children: [
                      Expanded(child: _buildStatusFilterDropdown()),
                      SizedBox(width: 16),
                      Expanded(child: _buildPaymentMethodDropdown()),
                      SizedBox(width: 16),
                      Expanded(child: _buildDateRangeSelector()),
                    ],
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusFilterDropdown() {
    return DropdownButtonFormField<String>(
      decoration: InputDecoration(
        labelText: 'Payment Status',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      value: _statusFilter,
      isExpanded: true,
      items:
          ['All', 'Completed', 'Pending', 'Failed', 'Refunded']
              .map(
                (status) => DropdownMenuItem(
                  value: status,
                  child: Text(status, overflow: TextOverflow.ellipsis),
                ),
              )
              .toList(),
      onChanged: (value) {
        if (value != null) {
          setState(() {
            _statusFilter = value;
          });
          _fetchPayments();
        }
      },
    );
  }

  Widget _buildPaymentMethodDropdown() {
    return DropdownButtonFormField<String>(
      decoration: InputDecoration(
        labelText: 'Payment Method',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      value: _paymentMethodFilter,
      isExpanded: true,
      items:
          ['All', 'Stripe', 'Wallet', 'Cash', 'Other']
              .map(
                (method) => DropdownMenuItem(
                  value: method,
                  child: Text(method, overflow: TextOverflow.ellipsis),
                ),
              )
              .toList(),
      onChanged: (value) {
        if (value != null) {
          setState(() {
            _paymentMethodFilter = value;
          });
          _fetchPayments();
        }
      },
    );
  }

  Widget _buildDateRangeSelector() {
    return InkWell(
      onTap: () async {
        final DateTimeRange? pickedRange = await showDateRangePicker(
          context: context,
          firstDate: DateTime(2020),
          lastDate: DateTime.now(),
          initialDateRange:
              _startDate != null && _endDate != null
                  ? DateTimeRange(start: _startDate!, end: _endDate!)
                  : null,
          builder: (context, child) {
            return Theme(
              data: ThemeData.light().copyWith(
                colorScheme: ColorScheme.light(primary: Constants.primaryColor),
              ),
              child: child!,
            );
          },
        );

        if (pickedRange != null) {
          setState(() {
            _startDate = pickedRange.start;
            _endDate = pickedRange.end;
          });
          _fetchPayments();
        }
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(Icons.date_range, color: Constants.textLight),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                _startDate == null
                    ? 'Filter by Date'
                    : '${DateFormat('MM/dd').format(_startDate!)} - ${DateFormat('MM/dd').format(_endDate!)}',
                style: TextStyle(
                  color: _startDate == null ? Colors.grey : Colors.black,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (_startDate != null)
              IconButton(
                icon: Icon(Icons.clear, size: 16),
                onPressed: () {
                  setState(() {
                    _startDate = null;
                    _endDate = null;
                  });
                  _fetchPayments();
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.payment_outlined, size: 80, color: Colors.grey[400]),
          SizedBox(height: 16),
          Text(
            'No payments found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Try adjusting your filters or search criteria',
            style: TextStyle(color: Colors.grey[600]),
          ),
          SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              setState(() {
                _searchQuery = '';
                _statusFilter = 'All';
                _paymentMethodFilter = 'All';
                _startDate = null;
                _endDate = null;
              });
              _fetchPayments();
            },
            icon: Icon(Icons.refresh),
            label: Text('Reset Filters'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Constants.primaryColor,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentsTable() {
    return Theme(
      data: Theme.of(context).copyWith(
        dataTableTheme: DataTableThemeData(
          headingTextStyle: TextStyle(
            fontWeight: FontWeight.bold,
            color: Constants.textDark,
          ),
          dataTextStyle: TextStyle(color: Constants.textDark, fontSize: 13),
          headingRowHeight: 48,
          dataRowHeight: 56,
          dividerThickness: 1,
        ),
      ),
      child: Stack(
        children: [
          NotificationListener<ScrollNotification>(
            onNotification: (ScrollNotification scrollInfo) {
              if (scrollInfo.metrics.pixels ==
                      scrollInfo.metrics.maxScrollExtent &&
                  _hasMoreData &&
                  !_isLoadingMore) {
                _fetchPayments(loadMore: true);
              }
              return true;
            },
            child: SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowHeight: 50,
                  dataRowHeight: 56,
                  columnSpacing: 20,
                  horizontalMargin: 20,
                  columns: [
                    DataColumn(
                      label: Text('Order Ref.'),
                      onSort: (columnIndex, ascending) {
                        setState(() {
                          _sortField = 'orderRef';
                          _sortAscending = ascending;
                        });
                        _fetchPayments();
                      },
                    ),
                    DataColumn(
                      label: Text('User'),
                      onSort: (columnIndex, ascending) {
                        setState(() {
                          _sortField = 'userName';
                          _sortAscending = ascending;
                        });
                        _fetchPayments();
                      },
                    ),
                    DataColumn(
                      label: Text('Amount'),
                      numeric: true,
                      onSort: (columnIndex, ascending) {
                        setState(() {
                          _sortField = 'amount';
                          _sortAscending = ascending;
                        });
                        _fetchPayments();
                      },
                    ),
                    DataColumn(label: Text('Method')),
                    DataColumn(label: Text('Status')),
                    DataColumn(
                      label: Text('Date'),
                      onSort: (columnIndex, ascending) {
                        setState(() {
                          _sortField = 'timestamp';
                          _sortAscending = ascending;
                        });
                        _fetchPayments();
                      },
                    ),
                    DataColumn(label: Text('Actions')),
                  ],
                  rows:
                      _payments.map((payment) {
                        Color statusColor;
                        switch (payment['status']) {
                          case 'Completed':
                            statusColor = Colors.green;
                            break;
                          case 'Pending':
                            statusColor = Colors.orange;
                            break;
                          case 'Refunded':
                            statusColor = Colors.blue;
                            break;
                          case 'Failed':
                            statusColor = Colors.red;
                            break;
                          default:
                            statusColor = Colors.grey;
                        }

                        final timestamp = payment['timestamp'] as Timestamp?;
                        final date =
                            timestamp != null
                                ? DateFormat(
                                  'MMM dd, yyyy',
                                ).format(timestamp.toDate())
                                : 'Unknown';

                        return DataRow(
                          cells: [
                            DataCell(
                              Text(
                                payment['orderRef']?.toString() ??
                                    'No reference',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            DataCell(Text(payment['userName'] ?? 'Unknown')),
                            DataCell(
                              Text(
                                '₹${payment['amount']?.toStringAsFixed(2) ?? '0.00'}',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            DataCell(
                              Text(payment['paymentMethod'] ?? 'Unknown'),
                            ),
                            DataCell(
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: statusColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  payment['status'] ?? 'Unknown',
                                  style: TextStyle(
                                    color: statusColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                            DataCell(Text(date)),
                            DataCell(
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: Icon(Icons.visibility, size: 20),
                                    tooltip: 'View Details',
                                    onPressed: () {
                                      setState(
                                        () => _selectedPayment = payment,
                                      );
                                      _showPaymentDetails(payment);
                                    },
                                  ),
                                  if (payment['status'] == 'Completed')
                                    IconButton(
                                      icon: Icon(
                                        Icons.replay,
                                        size: 20,
                                        color: Colors.blue,
                                      ),
                                      tooltip: 'Process Refund',
                                      onPressed: () => _processRefund(payment),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                ),
              ),
            ),
          ),
          if (_isLoadingMore)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                color: Colors.white.withOpacity(0.8),
                padding: EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Constants.accentColor,
                        ),
                      ),
                    ),
                    SizedBox(width: 16),
                    Text('Loading more payments...'),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showPaymentDetails(Map<String, dynamic> payment) {
    final timestamp = payment['timestamp'] as Timestamp?;
    final date =
        timestamp != null
            ? DateFormat('MMM dd, yyyy').format(timestamp.toDate())
            : 'Unknown';

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Payment Details'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDetailRow('Payment ID', payment['id']),
                  _buildDetailRow('Order Reference', payment['orderRef']),
                  _buildDetailRow('User', payment['userName']),
                  _buildDetailRow('User ID', payment['userId']),
                  _buildDetailRow('Email', payment['userEmail']),
                  _buildDetailRow(
                    'Amount',
                    '₹${payment['amount']?.toStringAsFixed(2) ?? '0.00'}',
                  ),
                  _buildDetailRow('Payment Method', payment['paymentMethod']),
                  _buildDetailRow('Status', payment['status']),
                  _buildDetailRow('Date', date),
                  if (payment['status'] == 'Refunded')
                    _buildDetailRow(
                      'Refunded At',
                      payment['refundedAt'] != null
                          ? DateFormat('MMM dd, yyyy • hh:mm a').format(
                            (payment['refundedAt'] as Timestamp).toDate(),
                          )
                          : 'N/A',
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('CLOSE'),
              ),
            ],
          ),
    );
  }

  Widget _buildWalletManagementTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Wallet Management',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Constants.textDark,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Manage user wallet balances and process refunds',
                    style: TextStyle(color: Constants.textLight),
                  ),
                  SizedBox(height: 20),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      // Use Row for wider screens, Column for narrower screens
                      if (constraints.maxWidth >= 800) {
                        // For wider screens, keep the row layout
                        return Row(
                          children: [
                            Expanded(
                              child: _buildWalletActionCard(
                                'Add Balance',
                                'Credit a user\'s wallet balance',
                                Icons.add_circle_outline,
                                Colors.green,
                                () {
                                  _adjustWalletBalance();
                                },
                              ),
                            ),
                            SizedBox(width: 16),
                            Expanded(
                              child: _buildWalletActionCard(
                                'Deduct Balance',
                                'Deduct from a user\'s wallet balance',
                                Icons.remove_circle_outline,
                                Colors.orange,
                                () {
                                  _adjustWalletBalance();
                                },
                              ),
                            ),
                            SizedBox(width: 16),
                            Expanded(
                              child: _buildWalletActionCard(
                                'Process Refund',
                                'Refund a payment to user\'s wallet',
                                Icons.replay,
                                Constants.accentColor,
                                () {
                                  _tabController.animateTo(
                                    0,
                                  ); // Switch to payments tab
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Select a payment to refund from the Payments tab',
                                      ),
                                      action: SnackBarAction(
                                        label: 'OKAY',
                                        onPressed: () {},
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        );
                      } else {
                        // For smaller screens, use a column layout
                        return Column(
                          children: [
                            _buildWalletActionCard(
                              'Add Balance',
                              'Credit a user\'s wallet balance',
                              Icons.add_circle_outline,
                              Colors.green,
                              () {
                                _adjustWalletBalance();
                              },
                            ),
                            SizedBox(height: 16),
                            _buildWalletActionCard(
                              'Deduct Balance',
                              'Deduct from a user\'s wallet balance',
                              Icons.remove_circle_outline,
                              Colors.orange,
                              () {
                                _adjustWalletBalance();
                              },
                            ),
                            SizedBox(height: 16),
                            _buildWalletActionCard(
                              'Process Refund',
                              'Refund a payment to user\'s wallet',
                              Icons.replay,
                              Constants.accentColor,
                              () {
                                _tabController.animateTo(
                                  0,
                                ); // Switch to payments tab
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Select a payment to refund from the Payments tab',
                                    ),
                                    action: SnackBarAction(
                                      label: 'OKAY',
                                      onPressed: () {},
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 20),
          _buildWalletActivitySection(),
        ],
      ),
    );
  }

  Widget _buildWalletActionCard(
    String title,
    String description,
    IconData icon,
    Color color,
    VoidCallback onPressed,
  ) {
    return Card(
      elevation: 0,
      color: color.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.withOpacity(0.5), width: 1),
      ),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 36),
              SizedBox(height: 16),
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Constants.textDark,
                ),
              ),
              SizedBox(height: 8),
              Text(
                description,
                style: TextStyle(color: Constants.textLight, fontSize: 14),
              ),
              SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: Icon(Icons.arrow_forward, color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWalletActivitySection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Recent Wallet Activities',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Constants.textDark,
                    ),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Wallet activity report coming soon'),
                      ),
                    );
                  },
                  icon: Icon(Icons.receipt_long),
                  label: Text('View All'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Constants.primaryColor,
                    side: BorderSide(color: Constants.primaryColor),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            StreamBuilder<QuerySnapshot>(
              stream:
                  _firestore
                      .collectionGroup('wallet_transactions')
                      .orderBy('timestamp', descending: true)
                      .limit(10)
                      .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  print(
                    'Error in wallet transactions stream: ${snapshot.error}',
                  );
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 48,
                          color: Colors.orange,
                        ),
                        SizedBox(height: 16),
                        Text('Error loading wallet activities'),
                        SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: () {
                            setState(() {});
                          },
                          child: Text('Retry'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Constants.primaryColor,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final activities = snapshot.data?.docs ?? [];

                if (activities.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(30.0),
                      child: Column(
                        children: [
                          Icon(
                            Icons.account_balance_wallet_outlined,
                            size: 48,
                            color: Colors.grey[400],
                          ),
                          SizedBox(height: 16),
                          Text(
                            'No wallet activities yet',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return Container(
                  constraints: BoxConstraints(maxHeight: 400),
                  child: ListView.separated(
                    physics: AlwaysScrollableScrollPhysics(),
                    shrinkWrap: true,
                    itemCount: activities.length,
                    separatorBuilder: (context, index) => Divider(),
                    itemBuilder: (context, index) {
                      final activity =
                          activities[index].data() as Map<String, dynamic>;
                      final type = activity['type'] ?? 'UNKNOWN';
                      final amount = activity['amount'] ?? 0.0;
                      final description =
                          activity['description'] ?? 'Wallet transaction';
                      final timestamp =
                          activity['timestamp'] as Timestamp? ??
                          Timestamp.now();
                      final userId =
                          activities[index].reference.path.split('/')[1];

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor:
                              type == 'CREDIT'
                                  ? Colors.green.withOpacity(0.1)
                                  : Colors.red.withOpacity(0.1),
                          child: Icon(
                            type == 'CREDIT' ? Icons.add : Icons.remove,
                            color: type == 'CREDIT' ? Colors.green : Colors.red,
                          ),
                        ),
                        title: Wrap(
                          children: [
                            Text(description, overflow: TextOverflow.ellipsis),
                            if (activity['refundFor'] != null)
                              Container(
                                margin: EdgeInsets.only(left: 8),
                                padding: EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Refund',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.blue,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              DateFormat(
                                'MMM dd, yyyy • hh:mm a',
                              ).format(timestamp.toDate()),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              'User ID: ${userId.substring(0, min(4, userId.length))}...',
                              style: TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                        trailing: Text(
                          '${type == 'CREDIT' ? '+' : '-'} ₹${amount.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: type == 'CREDIT' ? Colors.green : Colors.red,
                          ),
                        ),
                        onTap:
                            () => _showTransactionDetails(
                              activity,
                              userId,
                              timestamp,
                            ),
                      );
                    },
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showTransactionDetails(
    Map<String, dynamic> activity,
    String userId,
    Timestamp timestamp,
  ) {
    final type = activity['type'] ?? 'UNKNOWN';
    final amount = activity['amount'] ?? 0.0;
    final description = activity['description'] ?? 'Wallet transaction';

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Transaction Details'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailRow('Transaction Type', type),
                _buildDetailRow('Amount', '₹${amount.toStringAsFixed(2)}'),
                _buildDetailRow('Description', description),
                _buildDetailRow('User ID', userId),
                _buildDetailRow(
                  'Date & Time',
                  DateFormat(
                    'MMM dd, yyyy • hh:mm a',
                  ).format(timestamp.toDate()),
                ),
                if (activity['processedBy'] != null)
                  _buildDetailRow('Processed By', activity['processedBy']),
                if (activity['adjustmentReason'] != null)
                  _buildDetailRow('Reason', activity['adjustmentReason']),
                if (activity['refundFor'] != null)
                  _buildDetailRow('Refund For Order', activity['refundFor']),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('CLOSE'),
              ),
            ],
          ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(value, style: TextStyle(color: Constants.textDark)),
          ),
        ],
      ),
    );
  }
}
