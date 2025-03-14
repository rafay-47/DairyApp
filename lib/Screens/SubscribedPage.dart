import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class UserSubscriptionsPage extends StatefulWidget {
  const UserSubscriptionsPage({Key? key}) : super(key: key);

  @override
  _UserSubscriptionsPageState createState() => _UserSubscriptionsPageState();
}

class _UserSubscriptionsPageState extends State<UserSubscriptionsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  bool _isLoading = false;

  // Get the start date for a subscription (today or subscription start date)
  DateTime _getStartDate(DocumentSnapshot subscription) {
    try {
      DateTime startDate =
          subscription['startDate']?.toDate() ?? DateTime.now();
      DateTime today = DateTime.now();
      return startDate.isBefore(today) ? today : startDate;
    } catch (e) {
      return DateTime.now();
    }
  }

  // Calculate the delivery days based on start date and plan
  List<DateTime> _getDeliveryDates(DocumentSnapshot subscription) {
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
  bool _isDayCancelled(DocumentSnapshot subscription, DateTime date) {
    try {
      // First check if the field exists in the document
      final data = subscription.data() as Map<String, dynamic>?;
      if (data == null || !data.containsKey('cancelledDays')) {
        return false; // If no cancelledDays field exists, nothing is cancelled
      }

      List<dynamic> cancelledDays = data['cancelledDays'] ?? [];
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

  // Cancel delivery for a specific day for a given subscription
  Future<void> _cancelDelivery(
    DocumentSnapshot subscription,
    DateTime date,
  ) async {
    // Check if current time is after midnight
    final now = DateTime.now();
    final currentTimeOfDay = TimeOfDay.fromDateTime(now);

    // If it's after midnight and before 6 AM, prevent cancellation
    if (currentTimeOfDay.hour >= 0 && currentTimeOfDay.hour < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Deliveries cannot be cancelled between 12 AM and 6 AM',
          ),
          backgroundColor: Colors.red[700],
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Convert DateTime to a string format for consistency
      String dateString = DateFormat('yyyy-MM-dd').format(date);

      await subscription.reference.update({
        'cancelledDays': FieldValue.arrayUnion([dateString]),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Cancelled delivery on ${DateFormat('MMM d, yyyy').format(date)}',
          ),
          backgroundColor: Colors.green[700],
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to cancel: $e'),
          backgroundColor: Colors.red[700],
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Restore a previously cancelled delivery
  Future<void> _restoreDelivery(
    DocumentSnapshot subscription,
    DateTime date,
  ) async {
    setState(() => _isLoading = true);

    try {
      String dateString = DateFormat('yyyy-MM-dd').format(date);

      // Safely get the cancelledDays field
      final data = subscription.data() as Map<String, dynamic>?;
      if (data == null || !data.containsKey('cancelledDays')) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No cancelled days to restore'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
        setState(() => _isLoading = false);
        return;
      }

      List<dynamic> cancelledDays = List<dynamic>.from(
        data['cancelledDays'] ?? [],
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

      await subscription.reference.update({'cancelledDays': cancelledDays});

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Restored delivery on ${DateFormat('MMM d, yyyy').format(date)}',
          ),
          backgroundColor: Colors.blue[700],
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to restore: $e'),
          backgroundColor: Colors.red[700],
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUser == null) {
      return Scaffold(
        appBar: AppBar(title: Text('My Subscriptions')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline, size: 60, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                'Please log in to view subscriptions',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
              ),
              SizedBox(height: 24),
              ElevatedButton.icon(
                icon: Icon(Icons.login),
                label: Text('Go to Login'),
                onPressed: () {
                  // Navigate to login page
                  Navigator.of(context).pushReplacementNamed('/login');
                },
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('My Subscriptions'),
        centerTitle: true,
        elevation: 0,
      ),
      body: Stack(
        children: [
          StreamBuilder<QuerySnapshot>(
            stream:
                _firestore
                    .collection('users')
                    .doc(_currentUser!.uid)
                    .collection('product_subscriptions')
                    .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 60,
                        color: Colors.red[300],
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Error fetching subscriptions',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(snapshot.error.toString()),
                    ],
                  ),
                );
              }

              if (!snapshot.hasData) {
                return Center(child: CircularProgressIndicator());
              }

              final subscriptions = snapshot.data!.docs;

              if (subscriptions.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.subscriptions_outlined,
                        size: 60,
                        color: Colors.grey,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'No active subscriptions found',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 24),
                      ElevatedButton.icon(
                        icon: Icon(Icons.shopping_cart),
                        label: Text('Browse Products'),
                        onPressed: () {
                          // Navigate to products page
                          Navigator.of(
                            context,
                          ).pushReplacementNamed('/products');
                        },
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: EdgeInsets.all(12),
                itemCount: subscriptions.length,
                itemBuilder: (context, index) {
                  final subscription = subscriptions[index];
                  final productName = subscription['productName'] ?? 'Product';
                  final planName = subscription['planName'] ?? 'Subscription';
                  final endDate =
                      subscription['endDate']?.toDate() ??
                      DateTime.now().add(Duration(days: 30));
                  final deliveryDates = _getDeliveryDates(subscription);

                  return Card(
                    margin: EdgeInsets.only(bottom: 16),
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Subscription header
                        Container(
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(16),
                              topRight: Radius.circular(16),
                            ),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: Theme.of(context).primaryColor,
                                child: Icon(
                                  Icons.shopping_basket,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(width: 12),
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
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      '$planName Plan • Ends ${DateFormat('MMM d, yyyy').format(endDate)}',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: Icon(Icons.info_outline),
                                onPressed: () {
                                  // Show subscription details
                                  showModalBottomSheet(
                                    context: context,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.vertical(
                                        top: Radius.circular(20),
                                      ),
                                    ),
                                    builder:
                                        (context) => Padding(
                                          padding: EdgeInsets.all(20),
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Subscription Details',
                                                style: TextStyle(
                                                  fontSize: 20,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              SizedBox(height: 20),
                                              _detailRow(
                                                'Product',
                                                productName,
                                              ),
                                              _detailRow('Plan', planName),
                                              _detailRow(
                                                'End Date',
                                                DateFormat(
                                                  'MMMM d, yyyy',
                                                ).format(endDate),
                                              ),
                                              _detailRow('Status', 'Active'),
                                              SizedBox(height: 20),
                                              SizedBox(
                                                width: double.infinity,
                                                child: ElevatedButton(
                                                  onPressed: () {
                                                    Navigator.pop(context);
                                                  },
                                                  child: Text('Close'),
                                                  style:
                                                      ElevatedButton.styleFrom(
                                                        padding:
                                                            EdgeInsets.symmetric(
                                                              vertical: 12,
                                                            ),
                                                      ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),

                        // Delivery calendar section
                        Padding(
                          padding: EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Upcoming Deliveries',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(height: 12),
                              Container(
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey[300]!),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  children:
                                      deliveryDates.map((date) {
                                        bool isCancelled = _isDayCancelled(
                                          subscription,
                                          date,
                                        );
                                        bool isPast = date.isBefore(
                                          DateTime.now().subtract(
                                            Duration(days: 1),
                                          ),
                                        );
                                        bool isToday =
                                            DateFormat(
                                              'yyyyMMdd',
                                            ).format(date) ==
                                            DateFormat(
                                              'yyyyMMdd',
                                            ).format(DateTime.now());

                                        return Container(
                                          decoration: BoxDecoration(
                                            border: Border(
                                              bottom: BorderSide(
                                                color: Colors.grey[300]!,
                                                width: 1,
                                              ),
                                            ),
                                            color:
                                                isToday
                                                    ? Colors.yellow[50]
                                                    : null,
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
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color:
                                                            isCancelled
                                                                ? Colors
                                                                    .red[800]
                                                                : isPast
                                                                ? Colors
                                                                    .grey[600]
                                                                : isToday
                                                                ? Colors
                                                                    .amber[800]
                                                                : Colors
                                                                    .green[800],
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                SizedBox(width: 16),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        DateFormat(
                                                          'EEEE, MMMM d',
                                                        ).format(date),
                                                        style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.w500,
                                                          color:
                                                              isPast
                                                                  ? Colors.grey
                                                                  : Colors
                                                                      .black87,
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
                                                                  ? Colors
                                                                      .grey[600]
                                                                  : isToday
                                                                  ? Colors
                                                                      .amber[800]
                                                                  : Colors
                                                                      .green[700],
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                SizedBox(width: 8),
                                                if (!isPast) // Only show action buttons for non-past dates
                                                  isCancelled
                                                      ? OutlinedButton.icon(
                                                        icon: Icon(
                                                          Icons.restore,
                                                          size: 18,
                                                        ),
                                                        label: Text('Restore'),
                                                        onPressed:
                                                            _isLoading
                                                                ? null
                                                                : () =>
                                                                    _restoreDelivery(
                                                                      subscription,
                                                                      date,
                                                                    ),
                                                        style: OutlinedButton.styleFrom(
                                                          foregroundColor:
                                                              Colors.blue[700],
                                                          side: BorderSide(
                                                            color:
                                                                Colors
                                                                    .blue[700]!,
                                                          ),
                                                          padding:
                                                              EdgeInsets.symmetric(
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
                                                                : () =>
                                                                    _cancelDelivery(
                                                                      subscription,
                                                                      date,
                                                                    ),
                                                        style: ElevatedButton.styleFrom(
                                                          backgroundColor:
                                                              Colors.red[50],
                                                          foregroundColor:
                                                              Colors.red[700],
                                                          padding:
                                                              EdgeInsets.symmetric(
                                                                horizontal: 12,
                                                                vertical: 8,
                                                              ),
                                                        ),
                                                      ),
                                              ],
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Subscription footer
                        Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton.icon(
                                icon: Icon(Icons.chat_outlined),
                                label: Text('Support'),
                                onPressed: () {
                                  // Open support chat or contact page
                                },
                              ),
                              SizedBox(width: 8),
                              TextButton.icon(
                                icon: Icon(Icons.payment),
                                label: Text('Billing'),
                                onPressed: () {
                                  // Open billing details
                                },
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
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  // Helper method to create detail rows in the subscription info modal
  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(value, style: TextStyle(fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}
