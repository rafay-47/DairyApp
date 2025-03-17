import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../Constants.dart';

class AdminSubscriptionsPage extends StatefulWidget {
  const AdminSubscriptionsPage({super.key});
  @override
  _AdminSubscriptionsPageState createState() => _AdminSubscriptionsPageState();
}

class _AdminSubscriptionsPageState extends State<AdminSubscriptionsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = false;
  String _searchQuery = '';
  String _statusFilter = 'All';
  String _selectedUserId = '';
  String _selectedUserName = '';

  // List of filter options
  final List<String> _statusOptions = [
    'All',
    'active',
    'paused',
    'cancelled',
    'expired',
  ];

  // Get the start date for a subscription (today or subscription start date)
  DateTime _getStartDate(Map<String, dynamic> subscription) {
    try {
      DateTime startDate = (subscription['startDate'] as Timestamp).toDate();
      DateTime today = DateTime.now();
      return startDate.isBefore(today) ? today : startDate;
    } catch (e) {
      print('Error getting start date: $e');
      return DateTime.now();
    }
  }

  // Calculate the delivery days based on start date and plan
  List<DateTime> _getDeliveryDates(Map<String, dynamic> subscription) {
    String planName = subscription['planName'] ?? 'weekly';
    DateTime startDate = _getStartDate(subscription);

    int totalDays = planName.toLowerCase() == 'weekly' ? 7 : 30;
    List<DateTime> dates = [];

    for (int i = 0; i < totalDays; i++) {
      dates.add(startDate.add(Duration(days: i)));
    }

    return dates;
  }

  // Check if a specific day is cancelled
  bool _isDayCancelled(Map<String, dynamic> subscription, DateTime date) {
    try {
      // First check if the field exists in the document
      if (!subscription.containsKey('cancelledDays')) {
        return false; // If no cancelledDays field exists, nothing is cancelled
      }

      List<dynamic> cancelledDays = subscription['cancelledDays'] ?? [];
      String dateString = DateFormat('yyyy-MM-dd').format(date);

      return cancelledDays.any((cancelledDate) {
        if (cancelledDate is Timestamp) {
          return DateFormat('yyyy-MM-dd').format(cancelledDate.toDate()) ==
              dateString;
        } else if (cancelledDate is String) {
          return cancelledDate == dateString;
        }
        return false;
      });
    } catch (e) {
      print('Error checking cancelled days: $e');
      return false; // If any error occurs, assume the day is not cancelled
    }
  }

  // Restore a cancelled delivery
  Future<void> _restoreDelivery(
    String subscriptionId,
    Map<String, dynamic> subscription,
    DateTime date,
  ) async {
    setState(() => _isLoading = true);

    try {
      String dateString = DateFormat('yyyy-MM-dd').format(date);

      // Safely get the cancelledDays field
      if (!subscription.containsKey('cancelledDays')) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No cancelled days to restore'),
            backgroundColor: Colors.orange,
          ),
        );
        setState(() => _isLoading = false);
        return;
      }

      List<dynamic> cancelledDays = List<dynamic>.from(
        subscription['cancelledDays'] ?? [],
      );

      // Remove the date from cancelled days
      cancelledDays.removeWhere((cancelledDate) {
        if (cancelledDate is Timestamp) {
          return DateFormat('yyyy-MM-dd').format(cancelledDate.toDate()) ==
              dateString;
        } else if (cancelledDate is String) {
          return cancelledDate == dateString;
        }
        return false;
      });

      await _firestore
          .collection('users')
          .doc(_selectedUserId)
          .collection('product_subscriptions')
          .doc(subscriptionId)
          .update({
            'cancelledDays': cancelledDays,
            'lastUpdated': FieldValue.serverTimestamp(),
          });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Restored delivery on ${DateFormat('MMM d, yyyy').format(date)}',
          ),
          backgroundColor: Constants.successColor,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to restore: $e'),
          backgroundColor: Constants.errorColor,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Cancel a delivery
  Future<void> _cancelDelivery(
    String subscriptionId,
    Map<String, dynamic> subscription,
    DateTime date,
  ) async {
    setState(() => _isLoading = true);

    try {
      // Convert DateTime to a string format for consistency
      String dateString = DateFormat('yyyy-MM-dd').format(date);

      await _firestore
          .collection('users')
          .doc(_selectedUserId)
          .collection('product_subscriptions')
          .doc(subscriptionId)
          .update({
            'cancelledDays': FieldValue.arrayUnion([dateString]),
            'lastUpdated': FieldValue.serverTimestamp(),
          });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Cancelled delivery on ${DateFormat('MMM d, yyyy').format(date)}',
          ),
          backgroundColor: Constants.successColor,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to cancel: $e'),
          backgroundColor: Constants.errorColor,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Show cancelled deliveries dialog
  void _showDeliveryStatusDialog(
    String subscriptionId,
    Map<String, dynamic> subscriptionData,
  ) {
    final deliveryDates = _getDeliveryDates(subscriptionData);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.calendar_today, color: Constants.accentColor),
                    SizedBox(width: 10),
                    Text(
                      'Delivery Schedule',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 20),
                Text(
                  '${subscriptionData['productName']} - ${subscriptionData['planName']} Plan',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
                SizedBox(height: 10),
                Container(
                  height: 300,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ListView.builder(
                    itemCount: deliveryDates.length,
                    itemBuilder: (context, index) {
                      final date = deliveryDates[index];
                      final bool isCancelled = _isDayCancelled(
                        subscriptionData,
                        date,
                      );
                      final bool isPast = date.isBefore(
                        DateTime.now().subtract(Duration(days: 1)),
                      );
                      final bool isToday =
                          DateFormat('yyyyMMdd').format(date) ==
                          DateFormat('yyyyMMdd').format(DateTime.now());

                      return Container(
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: Colors.grey[300]!,
                              width: 1,
                            ),
                          ),
                          color: isToday ? Colors.yellow[50] : null,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color:
                                      isCancelled
                                          ? Colors.red[100]
                                          : isPast
                                          ? Colors.grey[200]
                                          : isToday
                                          ? Colors.amber[100]
                                          : Colors.green[100],
                                ),
                                child: Center(
                                  child: Text(
                                    '${date.day}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color:
                                          isCancelled
                                              ? Colors.red[800]
                                              : isPast
                                              ? Colors.grey[600]
                                              : isToday
                                              ? Colors.amber[800]
                                              : Colors.green[800],
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      DateFormat('EEEE, MMMM d').format(date),
                                      style: TextStyle(
                                        fontWeight: FontWeight.w500,
                                        color:
                                            isPast
                                                ? Colors.grey
                                                : Colors.black87,
                                      ),
                                    ),
                                    SizedBox(height: 2),
                                    Text(
                                      isCancelled
                                          ? 'Delivery Cancelled'
                                          : isPast
                                          ? 'Delivered'
                                          : isToday
                                          ? 'Today\'s Delivery'
                                          : 'Scheduled Delivery',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color:
                                            isCancelled
                                                ? Colors.red
                                                : isPast
                                                ? Colors.grey[600]
                                                : isToday
                                                ? Colors.amber[800]
                                                : Colors.green[700],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(width: 8),
                              if (!isPast) // Only show action buttons for non-past dates
                                isCancelled
                                    ? OutlinedButton.icon(
                                      icon: Icon(Icons.restore, size: 18),
                                      label: Text('Restore'),
                                      onPressed:
                                          _isLoading
                                              ? null
                                              : () {
                                                Navigator.pop(context);
                                                _restoreDelivery(
                                                  subscriptionId,
                                                  subscriptionData,
                                                  date,
                                                );
                                              },
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.blue[700],
                                        side: BorderSide(
                                          color: Colors.blue[700]!,
                                        ),
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 8,
                                        ),
                                      ),
                                    )
                                    : ElevatedButton.icon(
                                      icon: Icon(
                                        Icons.cancel_outlined,
                                        size: 18,
                                      ),
                                      label: Text('Cancel'),
                                      onPressed:
                                          _isLoading
                                              ? null
                                              : () {
                                                Navigator.pop(context);
                                                _cancelDelivery(
                                                  subscriptionId,
                                                  subscriptionData,
                                                  date,
                                                );
                                              },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red[50],
                                        foregroundColor: Colors.red[700],
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 8,
                                        ),
                                      ),
                                    ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      child: Text('Close'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Subscription Management'),
        backgroundColor: Constants.accentColor,
        foregroundColor: Constants.primaryColor,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () {
              setState(() {});
            },
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    return Column(
      children: [
        _buildFilters(),
        Expanded(
          child:
              _selectedUserId.isEmpty
                  ? _buildAllUsersSubscriptions()
                  : _buildUserSubscriptions(),
        ),
      ],
    );
  }

  Widget _buildFilters() {
    return Container(
      padding: EdgeInsets.all(16),
      color: Constants.accentColor.withOpacity(0.1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search by user or product name',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: EdgeInsets.symmetric(
                      vertical: 0,
                      horizontal: 16,
                    ),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value.toLowerCase();
                    });
                  },
                ),
              ),
              SizedBox(width: 12),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _statusFilter,
                    icon: Icon(Icons.filter_list),
                    items:
                        _statusOptions.map((String status) {
                          return DropdownMenuItem<String>(
                            value: status,
                            child: Text(status),
                          );
                        }).toList(),
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        setState(() {
                          _statusFilter = newValue;
                        });
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
          if (_selectedUserId.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12.0),
              child: Row(
                children: [
                  Text(
                    'Viewing: $_selectedUserName',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Spacer(),
                  TextButton.icon(
                    icon: Icon(Icons.arrow_back),
                    label: Text('Back to All Users'),
                    onPressed: () {
                      setState(() {
                        _selectedUserId = '';
                        _selectedUserName = '';
                      });
                    },
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAllUsersSubscriptions() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('users').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(child: Text('No users found'));
        }

        final users = snapshot.data!.docs;

        // Filter users based on search query if provided
        final filteredUsers =
            _searchQuery.isEmpty
                ? users
                : users.where((user) {
                  final userData = user.data() as Map<String, dynamic>;
                  final name =
                      (userData['name'] ?? '').toString().toLowerCase();
                  final email =
                      (userData['Email'] ?? '').toString().toLowerCase();
                  return name.contains(_searchQuery) ||
                      email.contains(_searchQuery);
                }).toList();

        return ListView.builder(
          itemCount: filteredUsers.length,
          padding: EdgeInsets.all(12),
          itemBuilder: (context, index) {
            final user = filteredUsers[index];
            final userData = user.data() as Map<String, dynamic>;
            final userName = userData['name'] ?? 'Unknown User';
            final userEmail = userData['Email'] ?? 'No Email';

            return Card(
              margin: EdgeInsets.only(bottom: 12),
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                title: Text(
                  userName,
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(userEmail),
                trailing: IconButton(
                  icon: Icon(Icons.arrow_forward),
                  onPressed: () {
                    setState(() {
                      _selectedUserId = user.id;
                      _selectedUserName = userName;
                    });
                  },
                ),
                leading: CircleAvatar(
                  backgroundColor: Constants.accentColor,
                  child: Text(
                    userName.isNotEmpty ? userName[0].toUpperCase() : '?',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
                onTap: () {
                  setState(() {
                    _selectedUserId = user.id;
                    _selectedUserName = userName;
                  });
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildUserSubscriptions() {
    return StreamBuilder<QuerySnapshot>(
      stream:
          _firestore
              .collection('users')
              .doc(_selectedUserId)
              .collection('product_subscriptions')
              .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(child: Text('No subscriptions found for this user'));
        }

        final subscriptions = snapshot.data!.docs;

        // Apply filters
        var filteredSubscriptions = subscriptions;

        // Filter by status
        if (_statusFilter != 'All') {
          filteredSubscriptions =
              filteredSubscriptions.where((subscription) {
                final data = subscription.data() as Map<String, dynamic>;
                return data['status'] == _statusFilter;
              }).toList();
        }

        // Filter by search query
        if (_searchQuery.isNotEmpty) {
          filteredSubscriptions =
              filteredSubscriptions.where((subscription) {
                final data = subscription.data() as Map<String, dynamic>;
                final productName =
                    (data['productName'] ?? '').toString().toLowerCase();
                final planName =
                    (data['planName'] ?? '').toString().toLowerCase();
                return productName.contains(_searchQuery) ||
                    planName.contains(_searchQuery);
              }).toList();
        }

        // Check subscription status and update if needed
        _updateExpiredSubscriptions(filteredSubscriptions);

        return ListView.builder(
          itemCount: filteredSubscriptions.length,
          padding: EdgeInsets.all(12),
          itemBuilder: (context, index) {
            final subscription = filteredSubscriptions[index];
            final data = subscription.data() as Map<String, dynamic>;

            final productName = data['productName'] ?? 'Unknown Product';
            final planName = data['planName'] ?? 'Unknown Plan';
            final status = data['status'] ?? 'unknown';

            // Parse dates
            DateTime? startDate;
            DateTime? endDate;

            try {
              startDate = (data['startDate'] as Timestamp).toDate();
              endDate = (data['endDate'] as Timestamp).toDate();
            } catch (e) {
              print('Error parsing dates: $e');
            }

            final dateFormat = DateFormat('MMM dd, yyyy');
            final startDateStr =
                startDate != null ? dateFormat.format(startDate) : 'Unknown';
            final endDateStr =
                endDate != null ? dateFormat.format(endDate) : 'Unknown';

            // Determine if subscription is expired
            final isExpired =
                endDate != null && endDate.isBefore(DateTime.now());

            // Choose color based on status
            Color statusColor;
            switch (status) {
              case 'active':
                statusColor = Constants.successColor;
                break;
              case 'paused':
                statusColor = Constants.warningColor;
                break;
              case 'cancelled':
                statusColor = Constants.errorColor;
                break;
              case 'expired':
                statusColor = Colors.grey;
                break;
              default:
                statusColor = Constants.textLight;
            }

            // Add cancelled days counter
            int cancelledDaysCount = 0;
            if (data.containsKey('cancelledDays')) {
              List<dynamic> cancelledDays = data['cancelledDays'] ?? [];
              cancelledDaysCount = cancelledDays.length;
            }

            return Card(
              margin: EdgeInsets.only(bottom: 12),
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                productName,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              SizedBox(height: 4),
                              Text(
                                '$planName Plan',
                                style: TextStyle(
                                  color: Constants.textLight,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: statusColor),
                          ),
                          child: Text(
                            status,
                            style: TextStyle(
                              color: statusColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Start Date',
                                style: TextStyle(
                                  color: Constants.textLight,
                                  fontSize: 12,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                startDateStr,
                                style: TextStyle(fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'End Date',
                                style: TextStyle(
                                  color: Constants.textLight,
                                  fontSize: 12,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                endDateStr,
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  color:
                                      isExpired ? Constants.errorColor : null,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (status == 'active')
                          TextButton.icon(
                            icon: Icon(Icons.pause),
                            label: Text('Pause'),
                            onPressed:
                                () => _updateSubscriptionStatus(
                                  subscription.id,
                                  'paused',
                                ),
                            style: TextButton.styleFrom(
                              foregroundColor: Constants.warningColor,
                            ),
                          ),
                        if (status == 'paused')
                          TextButton.icon(
                            icon: Icon(Icons.play_arrow),
                            label: Text('Resume'),
                            onPressed:
                                () => _updateSubscriptionStatus(
                                  subscription.id,
                                  'active',
                                ),
                            style: TextButton.styleFrom(
                              foregroundColor: Constants.successColor,
                            ),
                          ),
                        if (status != 'cancelled' && status != 'expired')
                          TextButton.icon(
                            icon: Icon(Icons.cancel),
                            label: Text('Cancel'),
                            onPressed:
                                () => _showCancelConfirmation(subscription.id),
                            style: TextButton.styleFrom(
                              foregroundColor: Constants.errorColor,
                            ),
                          ),
                        if (status != 'active' &&
                            endDate != null &&
                            endDate.isAfter(DateTime.now()))
                          TextButton.icon(
                            icon: Icon(Icons.refresh),
                            label: Text('Reactivate'),
                            onPressed:
                                () => _updateSubscriptionStatus(
                                  subscription.id,
                                  'active',
                                ),
                            style: TextButton.styleFrom(
                              foregroundColor: Constants.successColor,
                            ),
                          ),
                        // Add calendar button to directly view schedule
                        TextButton.icon(
                          icon: Icon(Icons.calendar_today),
                          label: Text('Schedule'),
                          onPressed:
                              () => _showDeliveryStatusDialog(
                                subscription.id,
                                data,
                              ),
                          style: TextButton.styleFrom(
                            foregroundColor: Constants.accentColor,
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.more_vert),
                          onPressed:
                              () => _showMoreOptions(subscription.id, data),
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
    );
  }

  // Update subscription status (pause, resume, cancel)
  Future<void> _updateSubscriptionStatus(
    String subscriptionId,
    String newStatus,
  ) async {
    setState(() {
      _isLoading = true;
    });

    try {
      await _firestore
          .collection('users')
          .doc(_selectedUserId)
          .collection('product_subscriptions')
          .doc(subscriptionId)
          .update({
            'status': newStatus,
            'lastUpdated': FieldValue.serverTimestamp(),
          });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Subscription $newStatus successfully'),
          backgroundColor: Constants.successColor,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update subscription: $e'),
          backgroundColor: Constants.errorColor,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Show confirmation dialog before cancelling
  void _showCancelConfirmation(String subscriptionId) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Cancel Subscription'),
          content: Text('Are you sure you want to cancel this subscription?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('No'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _updateSubscriptionStatus(subscriptionId, 'cancelled');
              },
              child: Text('Yes'),
              style: TextButton.styleFrom(
                foregroundColor: Constants.errorColor,
              ),
            ),
          ],
        );
      },
    );
  }

  // Show more options menu
  void _showMoreOptions(
    String subscriptionId,
    Map<String, dynamic> subscriptionData,
  ) {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.calendar_today),
                title: Text('View Delivery Schedule'),
                onTap: () {
                  Navigator.pop(context);
                  _showDeliveryStatusDialog(subscriptionId, subscriptionData);
                },
              ),
              ListTile(
                leading: Icon(Icons.calendar_today),
                title: Text('Extend Subscription'),
                onTap: () {
                  Navigator.pop(context);
                  _showExtendSubscriptionDialog(
                    subscriptionId,
                    subscriptionData,
                  );
                },
              ),
              ListTile(
                leading: Icon(Icons.history),
                title: Text('View History'),
                onTap: () {
                  Navigator.pop(context);
                  // TODO: Implement view history
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('History feature not implemented yet'),
                    ),
                  );
                },
              ),
              ListTile(
                leading: Icon(Icons.delete),
                title: Text('Delete Subscription'),
                textColor: Constants.errorColor,
                iconColor: Constants.errorColor,
                onTap: () {
                  Navigator.pop(context);
                  _showDeleteConfirmation(subscriptionId);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // Show dialog to extend subscription
  void _showExtendSubscriptionDialog(
    String subscriptionId,
    Map<String, dynamic> subscriptionData,
  ) {
    int extensionDays = 30; // Default 30 days

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Extend Subscription'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Current end date: ${DateFormat('MMM dd, yyyy').format((subscriptionData['endDate'] as Timestamp).toDate())}',
                  ),
                  SizedBox(height: 20),
                  Text('Extend by:'),
                  SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _extensionOption(7, extensionDays, (days) {
                        setState(() => extensionDays = days);
                      }),
                      _extensionOption(30, extensionDays, (days) {
                        setState(() => extensionDays = days);
                      }),
                      _extensionOption(90, extensionDays, (days) {
                        setState(() => extensionDays = days);
                      }),
                      _extensionOption(180, extensionDays, (days) {
                        setState(() => extensionDays = days);
                      }),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _extendSubscription(
                      subscriptionId,
                      extensionDays,
                      subscriptionData,
                    );
                  },
                  child: Text('Extend'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Constants.accentColor,
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Extension day option widget
  Widget _extensionOption(
    int days,
    int selectedDays,
    Function(int) onSelected,
  ) {
    final isSelected = days == selectedDays;

    return GestureDetector(
      onTap: () => onSelected(days),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Constants.accentColor : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          '$days days',
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  // Extend subscription end date
  Future<void> _extendSubscription(
    String subscriptionId,
    int days,
    Map<String, dynamic> subscriptionData,
  ) async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Calculate new end date
      final currentEndDate =
          (subscriptionData['endDate'] as Timestamp).toDate();
      final newEndDate = currentEndDate.add(Duration(days: days));

      // Update subscription
      await _firestore
          .collection('users')
          .doc(_selectedUserId)
          .collection('product_subscriptions')
          .doc(subscriptionId)
          .update({
            'endDate': newEndDate,
            'status': 'active', // Reactivate if it was cancelled or expired
            'lastUpdated': FieldValue.serverTimestamp(),
            'extendedBy': days,
            'extendedOn': FieldValue.serverTimestamp(),
          });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Subscription extended by $days days'),
          backgroundColor: Constants.successColor,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to extend subscription: $e'),
          backgroundColor: Constants.errorColor,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Show delete confirmation dialog
  void _showDeleteConfirmation(String subscriptionId) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Delete Subscription'),
          content: Text(
            'Are you sure you want to permanently delete this subscription? This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _deleteSubscription(subscriptionId);
              },
              child: Text('Delete'),
              style: TextButton.styleFrom(
                foregroundColor: Constants.errorColor,
              ),
            ),
          ],
        );
      },
    );
  }

  // Delete subscription
  Future<void> _deleteSubscription(String subscriptionId) async {
    setState(() {
      _isLoading = true;
    });

    try {
      await _firestore
          .collection('users')
          .doc(_selectedUserId)
          .collection('product_subscriptions')
          .doc(subscriptionId)
          .delete();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Subscription deleted successfully'),
          backgroundColor: Constants.successColor,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete subscription: $e'),
          backgroundColor: Constants.errorColor,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Update expired subscriptions
  void _updateExpiredSubscriptions(List<QueryDocumentSnapshot> subscriptions) {
    final now = DateTime.now();

    for (var subscription in subscriptions) {
      final data = subscription.data() as Map<String, dynamic>;
      final status = data['status'];

      // Skip if already expired or cancelled
      if (status == 'expired' || status == 'cancelled') continue;

      try {
        final endDate = (data['endDate'] as Timestamp).toDate();

        // Check if subscription has expired
        if (endDate.isBefore(now)) {
          // Update status to expired
          _firestore
              .collection('users')
              .doc(_selectedUserId)
              .collection('product_subscriptions')
              .doc(subscription.id)
              .update({
                'status': 'expired',
                'lastUpdated': FieldValue.serverTimestamp(),
              });
        }
      } catch (e) {
        print('Error checking subscription expiration: $e');
      }
    }
  }
}
