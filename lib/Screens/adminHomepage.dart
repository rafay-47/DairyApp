import 'package:dairyapp/Screens/CategoriesManagement.dart';
import 'package:dairyapp/Screens/UserManagementPage.dart';
import 'package:dairyapp/Screens/productManagement.dart';
import 'package:dairyapp/constants.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:dairyapp/Screens/AdminOrders.dart';
import 'package:dairyapp/Screens/AdminOffers.dart';
import 'AdminSubscriptionsPage.dart';
import 'PaymentManagementPage.dart';
import 'dart:math' as Math;

/// A simple Coming Soon page.
class ComingSoonPage extends StatelessWidget {
  const ComingSoonPage({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Coming Soon"),
        backgroundColor: Constants.primaryColor,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(
                color: Constants.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(100),
              ),
              child: Icon(
                Icons.construction,
                size: 80,
                color: Constants.primaryColor,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Coming Soon',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Constants.primaryColor,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'This feature is under development',
              style: TextStyle(fontSize: 16, color: Constants.textLight),
            ),
          ],
        ),
      ),
    );
  }
}

class AdminHomePage extends StatefulWidget {
  final VoidCallback onSignedOut;
  const AdminHomePage({Key? key, required this.onSignedOut}) : super(key: key);

  @override
  _AdminHomePageState createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage> {
  int _selectedIndex = 0;
  int? _previousIndex;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Dashboard stats variables.
  Map<String, dynamic> _dashboardStats = {
    'totalOrders': 0,
    'totalRevenue': 0,
    'activeUsers': 0,
    'subscriptions': 0, // Total active subscriptions (active = endDate > now)
  };
  List<Map<String, dynamic>> _recentOrders = [];
  // Top Products: mapping from product name to percentage share (based on all items counted)
  Map<String, double> _topProducts = {};
  // Revenue chart data.
  List<FlSpot> _revenueData = [];
  int totalSales = 0;
  String _selectedRevenuePeriod =
      'month'; // Allowed values: 'week', 'month', 'year'
  bool _isLoading = true;

  // Subscription summary computed from all users' product_subscriptions subcollections.
  // Keys: 'weekly', 'monthly', 'newSubscribers'
  Map<String, int> _subscriptionSummary = {
    'weekly': 0,
    'monthly': 0,
    'newSubscribers': 0,
  };

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
    _fetchSubscriptionSummary();
  }

  void _navigateToPage(int index) {
    if (_selectedIndex != index) {
      _previousIndex = _selectedIndex;

      setState(() {
        _selectedIndex = index;
      });
    }
  }

  Future<bool> _handleBackPress() {
    if (_selectedIndex != 0) {
      setState(() {
        _selectedIndex = _previousIndex ?? 0;
      });
      return Future.value(false);
    }

    return Future.value(true);
  }

  /// Fetches all dashboard data.
  Future<void> _fetchDashboardData() async {
    setState(() {
      _isLoading = true;
    });
    try {
      // Verify current user is logged in and is an admin.
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        widget.onSignedOut();
        return;
      }
      final userDoc =
          await _firestore.collection('users').doc(currentUser.uid).get();
      if (userDoc.data()?['isAdmin'] != true) {
        widget.onSignedOut();
        return;
      }

      // 1. Total Orders.
      QuerySnapshot ordersQuery = await _firestore.collection('orders').get();
      _dashboardStats['totalOrders'] = ordersQuery.docs.length;

      // 2. Active Users: Count non-admin users.
      QuerySnapshot usersQuery =
          await _firestore
              .collection('users')
              .where('isAdmin', isEqualTo: false)
              .get();
      _dashboardStats['activeUsers'] = usersQuery.docs.length;

      // 3. Active Subscriptions: Sum each non-admin user's product_subscriptions.
      int subsCount = 0;
      for (var user in usersQuery.docs) {
        QuerySnapshot subsSnapshot =
            await _firestore
                .collection('users')
                .doc(user.id)
                .collection('product_subscriptions')
                .get();
        subsCount += subsSnapshot.docs.length;
      }
      _dashboardStats['subscriptions'] = subsCount;

      // 4. Total Revenue from "payments".
      QuerySnapshot paymentsSnapshot =
          await _firestore.collection('payments').get();
      int revenueSum = 0;
      for (var doc in paymentsSnapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>? ?? {};
        revenueSum += ((data['amount'] ?? 0) as num).toInt();
      }
      _dashboardStats['totalRevenue'] = revenueSum;

      // 5. Total Sales from "transactions".
      QuerySnapshot transactionsSnapshot =
          await _firestore.collection('payments').get();
      totalSales = transactionsSnapshot.docs.length;

      // 6. Revenue Chart Data.
      await _fetchRevenueChartDataFromPayments();

      // 7. Recent Orders (latest 5 orders).
      QuerySnapshot recentOrdersSnapshot =
          await _firestore
              .collection('orders')
              .orderBy('timestamp', descending: true)
              .limit(5)
              .get();
      _recentOrders =
          recentOrdersSnapshot.docs.map<Map<String, dynamic>>((doc) {
            final data = doc.data() as Map<String, dynamic>? ?? {};
            return <String, dynamic>{
              'id': doc.id,
              'order number': data['orderNumber'],
              'status': data['status'] ?? 'Pending',
              'amount': data['total'] ?? 0,
              'timestamp': data['timestamp'] ?? Timestamp.now(),
            };
          }).toList();

      // 8. Top Products: Compute using productId from orders → items.
      await _fetchTopProducts();
    } catch (e) {
      print("Error fetching dashboard data: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error loading dashboard data: $e"),
          backgroundColor: Constants.errorColor,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Fetches revenue chart data from the "payments" collection,
  /// grouping revenue by day (for week/month) or by month (for year)
  /// based on the selected period.
  // Fixed function to fetch revenue data with proper data validation and aggregation
  Future<void> _fetchRevenueChartDataFromPayments() async {
    try {
      DateTime now = DateTime.now();
      DateTime start, end;
      Map<int, double> revenueMap = {};

      // Initialize all periods with zero values to ensure complete data representation
      if (_selectedRevenuePeriod == 'week') {
        int currentWeekday = now.weekday; // Monday = 1
        start = DateTime(
          now.year,
          now.month,
          now.day,
        ).subtract(Duration(days: currentWeekday - 1));
        end = start.add(const Duration(days: 7));
        for (int i = 0; i < 7; i++) revenueMap[i] = 0;
      } else if (_selectedRevenuePeriod == 'month') {
        start = DateTime(now.year, now.month, 1);
        end = DateTime(now.year, now.month + 1, 1);
        int daysInMonth = DateTime(now.year, now.month + 1, 0).day;
        for (int i = 0; i < daysInMonth; i++) revenueMap[i] = 0;
      } else if (_selectedRevenuePeriod == 'year') {
        start = DateTime(now.year, 1, 1);
        end = DateTime(now.year + 1, 1, 1);
        for (int i = 0; i < 12; i++) revenueMap[i] = 0;
      } else {
        start = DateTime(now.year, now.month, 1);
        end = DateTime(now.year, now.month + 1, 1);
      }

      QuerySnapshot paymentsSnapshot =
          await _firestore
              .collection('payments')
              .where('timestamp', isGreaterThanOrEqualTo: start)
              .where('timestamp', isLessThan: end)
              .get();

      for (var doc in paymentsSnapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>? ?? {};
        Timestamp ts = data['timestamp'] as Timestamp? ?? Timestamp.now();
        DateTime dt = ts.toDate();

        // Safely convert amount to double with proper null checking
        double amount = 0;
        if (data['amount'] != null) {
          try {
            amount = double.parse(data['amount'].toString());
          } catch (e) {
            print("Error parsing amount: $e");
            amount = 0;
          }
        }

        // Ensure amount is never negative
        if (amount < 0) amount = 0;

        if (_selectedRevenuePeriod == 'week') {
          int index = dt.weekday - 1;
          revenueMap[index] = (revenueMap[index] ?? 0) + amount;
        } else if (_selectedRevenuePeriod == 'month') {
          int day = dt.day - 1; // Adjust to 0-based index for consistency
          revenueMap[day] = (revenueMap[day] ?? 0) + amount;
        } else if (_selectedRevenuePeriod == 'year') {
          int month = dt.month - 1; // Adjust to 0-based index for consistency
          revenueMap[month] = (revenueMap[month] ?? 0) + amount;
        }
      }

      List<FlSpot> spots = [];
      if (_selectedRevenuePeriod == 'week') {
        for (int i = 0; i < 7; i++) {
          spots.add(FlSpot(i.toDouble(), revenueMap[i] ?? 0));
        }
      } else if (_selectedRevenuePeriod == 'month') {
        int daysInMonth = DateTime(now.year, now.month + 1, 0).day;
        for (int i = 0; i < daysInMonth; i++) {
          spots.add(FlSpot(i.toDouble(), revenueMap[i] ?? 0));
        }
      } else if (_selectedRevenuePeriod == 'year') {
        for (int i = 0; i < 12; i++) {
          spots.add(FlSpot(i.toDouble(), revenueMap[i] ?? 0));
        }
      }

      setState(() {
        _revenueData = spots;
      });
    } catch (e) {
      print("Error fetching revenue chart data: $e");
    }
  }

  void _onRevenuePeriodChanged(String? newPeriod) {
    if (newPeriod != null && newPeriod != _selectedRevenuePeriod) {
      setState(() {
        _selectedRevenuePeriod = newPeriod;
      });
      _fetchRevenueChartDataFromPayments();
    }
  }

  /// Fetches Top Products by counting "productId" from each order's "items" list.
  Future<void> _fetchTopProducts() async {
    try {
      QuerySnapshot ordersSnapshot =
          await _firestore
              .collection('orders')
              .orderBy('timestamp', descending: true)
              .limit(100)
              .get();

      Map<String, int> productIdCounts = {};
      int totalItemsCount = 0;

      for (var orderDoc in ordersSnapshot.docs) {
        Map<String, dynamic> data =
            orderDoc.data() as Map<String, dynamic>? ?? {};
        if (data.containsKey('items') && data['items'] is List) {
          List<dynamic> items = data['items'];
          for (var item in items) {
            if (item is Map<String, dynamic>) {
              String pid = item['productId'] ?? '';
              if (pid.isNotEmpty) {
                productIdCounts[pid] = (productIdCounts[pid] ?? 0) + 1;
                totalItemsCount++;
              }
            }
          }
        }
      }

      if (productIdCounts.isNotEmpty && totalItemsCount > 0) {
        var sortedEntries =
            productIdCounts.entries.toList()
              ..sort((a, b) => b.value.compareTo(a.value));
        List<String> topProductIds =
            sortedEntries.take(4).map((e) => e.key).toList();
        Map<String, double> tempTopProducts = {};
        for (var entry in sortedEntries.take(4)) {
          double percentage = (entry.value / totalItemsCount) * 100;
          tempTopProducts[entry.key] = percentage;
        }

        // Fetch product names from the "products" collection.
        Map<String, String> productIdToName = {};
        for (String pid in topProductIds) {
          DocumentSnapshot productDoc =
              await _firestore.collection('products').doc(pid).get();
          if (productDoc.exists) {
            Map<String, dynamic> productData =
                productDoc.data() as Map<String, dynamic>? ?? {};
            productIdToName[pid] = productData['name'] ?? pid;
          } else {
            productIdToName[pid] = pid;
          }
        }

        Map<String, double> finalTopProducts = {};
        tempTopProducts.forEach((pid, perc) {
          String productName = productIdToName[pid] ?? pid;
          finalTopProducts[productName] = perc;
        });

        setState(() {
          _topProducts = finalTopProducts;
        });
      } else {
        setState(() {
          _topProducts = {};
        });
      }
    } catch (e) {
      print("Error fetching top products: $e");
      setState(() {
        _topProducts = {};
      });
    }
  }

  /// Fetches subscription summary from all users' product_subscriptions subcollections
  /// using a collection group query. It returns only active subscriptions (where endDate is in the future).
  /// Then, using the "createdAt" field, it computes:
  /// - Weekly: subscriptions created in the last 7 days.
  /// - Monthly: subscriptions created in the last 30 days.
  /// - New Subscribers: subscriptions created in the last 24 hours.
  Future<void> _fetchSubscriptionSummary() async {
    try {
      DateTime now = DateTime.now();
      // Only consider active subscriptions: those with endDate in the future.
      QuerySnapshot subsSnapshot =
          await _firestore
              .collectionGroup('product_subscriptions')
              .where('endDate', isGreaterThan: Timestamp.fromDate(now))
              .get();

      int totalSubs = subsSnapshot.docs.length;
      int weekly = 0;
      int monthly = 0;
      int newSubscribers = 0;

      for (var doc in subsSnapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>? ?? {};
        Timestamp createdAtTs =
            data['createdAt'] as Timestamp? ?? Timestamp.now();
        DateTime createdAt = createdAtTs.toDate();

        if (createdAt.isAfter(now.subtract(Duration(days: 7)))) {
          weekly++;
        }
        if (createdAt.isAfter(now.subtract(Duration(days: 30)))) {
          monthly++;
        }
        if (createdAt.isAfter(now.subtract(Duration(hours: 24)))) {
          newSubscribers++;
        }
      }

      setState(() {
        _subscriptionSummary = {
          'weekly': weekly,
          'monthly': monthly,
          'newSubscribers': newSubscribers,
        };
        _dashboardStats['subscriptions'] = totalSubs;
      });
    } catch (e) {
      print("Error fetching subscription summary: $e");
    }
  }

  // UI BUILD METHODS

  Widget _buildRevenueBottomTitle(double value, TitleMeta meta) {
    const style = TextStyle(fontSize: 12);
    if (_selectedRevenuePeriod == 'week') {
      const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      int index = value.toInt();
      if (index >= 0 && index < days.length)
        return Text(days[index], style: style);
    } else if (_selectedRevenuePeriod == 'month') {
      return Text('${value.toInt() + 1}', style: style);
    } else if (_selectedRevenuePeriod == 'year') {
      const months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      int index = value.toInt();
      if (index >= 0 && index < months.length)
        return Text(months[index], style: style);
    }
    return Container();
  }

  Widget _buildRevenueLeftTitle(double value, TitleMeta meta) {
    const style = TextStyle(fontSize: 10, color: Colors.grey);

    String formattedValue;
    if (value == 0) {
      formattedValue = '₹0';
    } else if (value >= 100000) {
      formattedValue = '₹${(value / 100000).toStringAsFixed(1)}L';
    } else if (value >= 1000) {
      formattedValue = '₹${(value / 1000).toStringAsFixed(0)}K';
    } else {
      formattedValue = '₹${value.toInt()}';
    }

    return SideTitleWidget(
      meta: meta, // Pass the required meta argument here
      fitInside: SideTitleFitInsideData.fromTitleMeta(
        meta,
      ), // Ensure fitInside is set correctly
      child: Text(formattedValue, style: style),
    );
  }

  Widget _buildWelcomeCard() {
    String greeting;
    final hour = DateTime.now().hour;
    if (hour < 12) {
      greeting = 'Good Morning';
    } else if (hour < 17) {
      greeting = 'Good Afternoon';
    } else {
      greeting = 'Good Evening';
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Constants.accentColor,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            // Greeting text on the left
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$greeting, Admin!',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Today is ${DateFormat('EEEE, MMMM d, yyyy').format(DateTime.now())}',
                    style: const TextStyle(fontSize: 16, color: Colors.white70),
                  ),
                ],
              ),
            ),

            // Small bar chart icon in a circle on the right
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              padding: const EdgeInsets.all(16),
              child: const Icon(Icons.bar_chart, size: 40, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Constants.textLight,
                    fontSize: 14,
                  ),
                ),
                Icon(icon, color: color, size: 24),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Constants.textDark,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCards() {
    final formatter = NumberFormat.currency(
      symbol: '₹',
      decimalDigits: 0,
      locale: 'en_IN',
    );
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Total Orders',
                _dashboardStats['totalOrders'].toString(),
                Icons.shopping_bag,
                Constants.accentColor,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildStatCard(
                'Total Revenue',
                formatter.format(_dashboardStats['totalRevenue']),
                Icons.currency_rupee,
                Constants.successColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Active Users',
                _dashboardStats['activeUsers'].toString(),
                Icons.people,
                Constants.warningColor,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildStatCard(
                'Active Subscriptions',
                _dashboardStats['subscriptions'].toString(),
                Icons.repeat,
                Constants.errorColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Total Sales',
                totalSales.toString(),
                Icons.shopping_cart,
                Colors.purple,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRevenueChart() {
    final screenWidth = MediaQuery.of(context).size.width;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with dropdown for revenue period.
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Revenue Overview',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Constants.textDark,
                  ),
                ),
                Flexible(
                  child: DropdownButton<String>(
                    value: _selectedRevenuePeriod,
                    underline: Container(),
                    items: const [
                      DropdownMenuItem(value: 'week', child: Text('This Week')),
                      DropdownMenuItem(
                        value: 'month',
                        child: Text('This Month'),
                      ),
                      DropdownMenuItem(value: 'year', child: Text('This Year')),
                    ],
                    onChanged: _onRevenuePeriodChanged,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              width: screenWidth,
              height: 250,
              child:
                  _revenueData.isEmpty
                      ? const Center(child: Text('No revenue data available.'))
                      : LineChart(
                        LineChartData(
                          gridData: FlGridData(
                            show: false, // Remove all grid lines
                          ),
                          titlesData: FlTitlesData(
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 30,
                                getTitlesWidget: _buildRevenueBottomTitle,
                              ),
                            ),
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 40,
                                getTitlesWidget: _buildRevenueLeftTitle,
                              ),
                            ),
                            topTitles: AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            rightTitles: AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                          ),
                          borderData: FlBorderData(show: false),
                          minX: 0,
                          maxX: _revenueData.length.toDouble() - 1,
                          minY: 0, // Ensure Y starts at 0
                          maxY:
                              _revenueData.isNotEmpty
                                  ? Math.max(
                                    1,
                                    _revenueData
                                            .map((e) => e.y)
                                            .reduce((a, b) => a > b ? a : b) *
                                        1.1,
                                  ) // Add 10% padding and ensure it's at least 1
                                  : 100,
                          lineBarsData: [
                            LineChartBarData(
                              spots: _revenueData,
                              isCurved: true,
                              preventCurveOverShooting:
                                  true, // <-- Add this line
                              barWidth: 3,
                              dotData: FlDotData(show: true),
                              belowBarData: BarAreaData(
                                show: true,
                                color: Colors.blueAccent.withOpacity(0.1),
                              ),
                              color: Colors.blueAccent,
                            ),
                          ],
                        ),
                      ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLegendItem('This Year', Constants.accentColor),
                const SizedBox(width: 20),
                _buildLegendItem('Last Year', Colors.grey),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(color: Constants.textLight, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildRecentOrders() {
    final formatter = NumberFormat.currency(
      symbol: '₹',
      decimalDigits: 0,
      locale: 'en_IN',
    );
    if (_recentOrders.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Center(child: Text('No recent orders found')),
        ),
      );
    }
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Recent Orders',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Constants.textDark,
              ),
            ),
            const SizedBox(height: 10),
            ListView.separated(
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              itemCount: _recentOrders.length,
              separatorBuilder: (context, index) => const Divider(),
              itemBuilder: (context, index) {
                final order = _recentOrders[index];
                DateTime orderDate = (order['timestamp'] as Timestamp).toDate();
                return ListTile(
                  leading: const Icon(
                    Icons.receipt_long,
                    color: Constants.accentColor,
                  ),
                  title: Text(
                    "#${order['id'].toString().substring(0, 5)} - ${order['customer'] ?? 'N/A'}",
                  ),
                  subtitle: Text(
                    "${order['status']} • ${DateFormat('MMM dd, yyyy').format(orderDate)}",
                  ),
                  trailing: Text(
                    formatter.format(order['amount'] ?? 0),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                );
              },
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () {
                // Navigate to all orders page
                _navigateToPage(3);
              },
              child: const Text('View All'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductStats() {
    // If no products, show placeholder
    if (_topProducts.isEmpty) {
      return Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Padding(
          padding: EdgeInsets.all(20),
          child: Center(child: Text("No product data available")),
        ),
      );
    }

    // Prepare pie chart sections & legend items
    List<PieChartSectionData> sections = [];
    List<Map<String, dynamic>> legendItems = [];
    final List<Color> colors = [
      Constants.accentColor,
      Colors.orangeAccent,
      Colors.pinkAccent,
      Colors.greenAccent,
    ];

    int index = 0;
    _topProducts.forEach((productName, percentage) {
      final color = colors[index % colors.length];
      sections.add(
        PieChartSectionData(
          value: percentage,
          title: '${percentage.toStringAsFixed(1)}%',
          color: color,
          radius: 60, // Increased for a bigger slice
          showTitle: true,
          titleStyle: const TextStyle(
            fontSize: 14, // Bolder & bigger label
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          // This moves the label slightly outward from center
          titlePositionPercentageOffset: 0.55,
        ),
      );
      legendItems.add({
        'product': productName,
        'color': color,
        'percentage': '${percentage.toStringAsFixed(1)}%',
      });
      index++;
    });

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Top Products',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Constants.textDark,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 220, // Slightly taller for a bigger chart
              child: PieChart(
                PieChartData(
                  sections: sections,
                  sectionsSpace: 1, // Less space between slices
                  centerSpaceRadius: 40, // More donut space in center
                  pieTouchData: PieTouchData(
                    // Enable interactions
                    enabled: true,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Build a simple legend
            Column(
              children:
                  legendItems.map((item) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: item['color'],
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              item['product'],
                              style: const TextStyle(color: Constants.textDark),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            item['percentage'],
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Constants.textDark,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubscriptionSummary() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Text(
              'Subscription Summary',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Constants.textDark,
              ),
            ),
            const SizedBox(height: 20),
            IntrinsicHeight(
              // This forces all children to have the same height
              child: Row(
                children: [
                  Expanded(
                    child: _buildSubscriptionCard(
                      'Weekly',
                      _subscriptionSummary['weekly'].toString(),
                      Icons.calendar_view_week,
                      Constants.accentColor,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildSubscriptionCard(
                      'Monthly',
                      _subscriptionSummary['monthly'].toString(),
                      Icons.calendar_month,
                      Colors.purpleAccent,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildSubscriptionCard(
                      'New\nSubscribers',
                      _subscriptionSummary['newSubscribers'].toString(),
                      Icons.person_add,
                      Colors.green,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Subscription card builder with fixed height
  Widget _buildSubscriptionCard(
    String title,
    String count,
    IconData icon,
    Color color,
  ) {
    return Container(
      height: 140, // Fixed height for all cards
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 30),
          const SizedBox(height: 12),
          Text(
            count,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 2, // Allow up to 2 lines for text
            style: const TextStyle(
              color: Constants.textDark,
              fontWeight: FontWeight.w500,
              fontSize: 14, // Slightly smaller font to fit in the space
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem(IconData icon, String title, int index) {
    return ListTile(
      leading: Icon(
        icon,
        color:
            _selectedIndex == index
                ? Constants.accentColor
                : Constants.textLight,
      ),
      title: Text(
        title,
        style: TextStyle(
          color:
              _selectedIndex == index
                  ? Constants.accentColor
                  : Constants.textDark,
          fontWeight:
              _selectedIndex == index ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: _selectedIndex == index,
      selectedTileColor: Constants.accentColor.withOpacity(0.1),
      onTap: () {
        // Special handling for logout
        if (index == 8) {
          _handleLogout();
        } else {
          _navigateToPage(index);
          Navigator.pop(context); // Close drawer after selection
        }
      },
    );
  }

  void _handleLogout() async {
    try {
      // Show a confirmation dialog
      bool confirm =
          await showDialog(
            context: context,
            builder:
                (context) => AlertDialog(
                  title: Text('Confirm Logout'),
                  content: Text('Are you sure you want to log out?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: Text('CANCEL'),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Constants.accentColor,
                      ),
                      onPressed: () => Navigator.of(context).pop(true),
                      child: Text('LOGOUT'),
                    ),
                  ],
                ),
          ) ??
          false;

      if (confirm) {
        // Close the drawer if it's open
        if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
          Navigator.of(context).pop();
        }

        // Sign out from Firebase
        await FirebaseAuth.instance.signOut();

        // Call the callback to update the app's authentication state
        widget.onSignedOut();
      }
    } catch (e) {
      print('Error during logout: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error logging out: $e'),
          backgroundColor: Constants.errorColor,
        ),
      );
    }
  }

  Widget _buildDashboard() {
    return RefreshIndicator(
      onRefresh: () async {
        await _fetchDashboardData();
        await _fetchSubscriptionSummary();
      },
      color: Constants.accentColor,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildWelcomeCard(),
            const SizedBox(height: 20),
            _buildStatCards(),
            const SizedBox(height: 20),
            _buildRevenueChart(),
            const SizedBox(height: 20),
            Column(
              children: [
                _buildRecentOrders(),
                const SizedBox(height: 20),
                _buildProductStats(),
              ],
            ),
            const SizedBox(height: 20),
            _buildSubscriptionSummary(),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    switch (_selectedIndex) {
      case 0:
        return _buildDashboard();
      case 1:
        return CategoriesPage();
      case 2:
        return ProductsPage();
      case 3:
        return AdminOrders();
      case 4:
        return UserManagement();
      case 5:
        return PaymentManagementPage();
      case 6:
        return AdminSubscriptionsPage();
      case 7:
        return AdminOffers();
      default:
        print("Warning: No widget for index $_selectedIndex");
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.construction, size: 64, color: Colors.orange),
              SizedBox(height: 16),
              Text(
                "Page Under Construction",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _selectedIndex = 0; // Return to dashboard
                  });
                },
                child: Text("Return to Dashboard"),
              ),
            ],
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _handleBackPress,
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: Constants.backgroundColor,
        appBar: AppBar(
          backgroundColor: Constants.primaryColor,
          elevation: 2,
          title: const Text(
            'Admin Dashboard',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          leading: IconButton(
            icon: const Icon(Icons.menu, color: Colors.white),
            onPressed: () {
              _scaffoldKey.currentState?.openDrawer();
            },
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              onPressed: _fetchDashboardData,
            ),
            IconButton(
              icon: const Icon(
                Icons.notifications_outlined,
                color: Colors.white,
              ),
              onPressed: () {},
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: CircleAvatar(
                backgroundColor: Colors.white.withOpacity(0.2),
                child: const Text(
                  'AD',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
        drawer: Drawer(
          child: Container(
            color: Constants.cardColor,
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                DrawerHeader(
                  decoration: const BoxDecoration(color: Constants.accentColor),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: Colors.white,
                        child: Text(
                          'AD',
                          style: TextStyle(
                            color: Constants.accentColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      SizedBox(height: 10),
                      Text(
                        'Admin User',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'admin@dairyapp.com',
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                    ],
                  ),
                ),
                _buildDrawerItem(Icons.dashboard, 'Dashboard', 0),
                _buildDrawerItem(Icons.category, 'Categories', 1),
                _buildDrawerItem(Icons.inventory, 'Products', 2),
                _buildDrawerItem(Icons.shopping_bag, 'Orders', 3),
                _buildDrawerItem(Icons.people, 'Users', 4),
                _buildDrawerItem(Icons.payments, 'Payments', 5),
                _buildDrawerItem(Icons.subscriptions, 'Subscriptions', 6),
                _buildDrawerItem(Icons.local_offer, 'Offers', 7),
                const Divider(),
                _buildDrawerItem(Icons.logout, 'Logout', 8),
              ],
            ),
          ),
        ),
        body:
            _isLoading
                ? const Center(
                  child: CircularProgressIndicator(
                    color: Constants.accentColor,
                  ),
                )
                : _buildBody(),
      ),
    );
  }
}
