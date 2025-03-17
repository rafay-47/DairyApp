import 'package:dairyapp/Screens/CategoriesManagement.dart';
import 'package:dairyapp/Screens/UserManagementPage.dart';
import 'package:dairyapp/Screens/productManagement.dart';
import 'package:dairyapp/constants.dart';
import 'package:dairyapp/main.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:dairyapp/Screens/AdminOrders.dart';
import 'AdminSubscriptionsPage.dart';

class AdminHomePage extends StatefulWidget {
  final VoidCallback onSignedOut;
  const AdminHomePage({Key? key, required this.onSignedOut}) : super(key: key);

  @override
  _AdminHomePageState createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage> {
  int _selectedIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Data variables
  Map<String, dynamic> _dashboardStats = {
    'totalOrders': 0,
    'totalRevenue': 0,
    'activeUsers': 0,
    'subscriptions': 0,
    'revenueGrowth': 0.0,
  };
  List<Map<String, dynamic>> _recentOrders = [];
  Map<String, double> _topProducts = {};
  Map<String, int> _subscriptionSummary = {
    'weekly': 0,
    'monthly': 0,
    'newSubscribers': 0,
    'cancelled': 0,
  };
  List<FlSpot> _revenueData = [];

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
  }

  Future<void> _fetchDashboardData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // First verify the user is still authenticated and is an admin
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        // If user is not logged in, sign out
        widget.onSignedOut();
        return;
      }

      // Verify admin status (optional additional check)
      final userDoc =
          await _firestore.collection('users').doc(currentUser.uid).get();
      if (!userDoc.exists || userDoc.data()?['isAdmin'] != true) {
        // If not admin anymore, sign out
        widget.onSignedOut();
        return;
      }

      // Fetch dashboard stats
      final statsDoc =
          await _firestore.collection('admin').doc('dashboard_stats').get();
      if (statsDoc.exists) {
        _dashboardStats = statsDoc.data() ?? {};
      }

      // Fetch recent orders
      final ordersSnapshot =
          await _firestore
              .collection('orders')
              .orderBy('timestamp', descending: true)
              .limit(5)
              .get();

      _recentOrders =
          ordersSnapshot.docs.map((doc) {
            final data = doc.data();
            return {
              'id': doc.id,
              'customer': data['customerName'] ?? 'Unknown',
              'status': data['status'] ?? 'Pending',
              'amount': data['totalAmount'] ?? 0,
              'timestamp': data['timestamp'] ?? Timestamp.now(),
            };
          }).toList();

      // Fetch top products
      final productsSnapshot =
          await _firestore
              .collection('products')
              .orderBy('salesCount', descending: true)
              .limit(4)
              .get();

      double totalSales = 0;
      Map<String, double> tempTopProducts = {};

      for (var doc in productsSnapshot.docs) {
        final data = doc.data();
        tempTopProducts[data['name']] = (data['salesCount'] ?? 0).toDouble();
        totalSales += tempTopProducts[data['name']] ?? 0;
      }

      // Convert to percentages
      if (totalSales > 0) {
        tempTopProducts.forEach((key, value) {
          _topProducts[key] = (value / totalSales) * 100;
        });
      }

      // Fetch subscription summary
      final subscriptionDoc =
          await _firestore
              .collection('admin')
              .doc('subscription_summary')
              .get();
      if (subscriptionDoc.exists) {
        final data = subscriptionDoc.data() ?? {};
        _subscriptionSummary = {
          'weekly': data['weekly'] ?? 0,
          'monthly': data['monthly'] ?? 0,
          'newSubscribers': data['newSubscribers'] ?? 0,
          'cancelled': data['cancelled'] ?? 0,
        };
      }

      // Fetch revenue data for chart
      final revenueSnapshot =
          await _firestore
              .collection('revenue')
              .orderBy('month')
              .limit(12)
              .get();

      _revenueData =
          revenueSnapshot.docs.asMap().entries.map((entry) {
            final data = entry.value.data();
            return FlSpot(
              entry.key.toDouble(),
              (data['amount'] ?? 0) / 1000,
            ); // Convert to thousands
          }).toList();

      // If no revenue data, use placeholder
      if (_revenueData.isEmpty) {
        _revenueData = [
          const FlSpot(0, 30),
          const FlSpot(1, 38),
          const FlSpot(2, 35),
          const FlSpot(3, 50),
          const FlSpot(4, 45),
          const FlSpot(5, 60),
          const FlSpot(6, 65),
          const FlSpot(7, 75),
          const FlSpot(8, 70),
          const FlSpot(9, 85),
          const FlSpot(10, 95),
          const FlSpot(11, 90),
        ];
      }
    } catch (e) {
      print('Error fetching dashboard data: $e');
      // Show error snackbar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading dashboard data: $e'),
          backgroundColor: Constants.errorColor,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
            icon: const Icon(Icons.notifications_outlined, color: Colors.white),
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
              _buildDrawerItem(Icons.settings, 'Settings', 8),
              _buildDrawerItem(Icons.logout, 'Logout', 9),
            ],
          ),
        ),
      ),
      body:
          _isLoading
              ? const Center(
                child: CircularProgressIndicator(color: Constants.accentColor),
              )
              : _selectedIndex == 0
              ? _buildDashboard()
              : _buildComingSoon(),
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
        setState(() {
          _selectedIndex = index;
          Navigator.pop(context);
          if (index == 1) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => CategoriesPage()),
            );
          } else if (index == 2) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => ProductsPage()),
            );
          } else if (index == 9) {
            FirebaseAuth.instance.signOut();
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => LoginPage(onSignedIn: () {}),
              ),
            );
          } else if (index == 4) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => UserManagement()),
            );
          } else if (index == 3) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => AdminOrders()),
            );
          } else if (index == 6) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => AdminSubscriptionsPage()),
            );
          }
        });
      },
    );
  }

  Widget _buildComingSoon() {
    return Center(
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
              Icons.construction,
              size: 80,
              color: Constants.primaryColor,
            ),
          ),
          SizedBox(height: 24),
          Text(
            'Coming Soon',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Constants.primaryColor,
            ),
          ),
          SizedBox(height: 16),
          Text(
            'This feature is under development',
            style: TextStyle(fontSize: 16, color: Constants.textLight),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboard() {
    return RefreshIndicator(
      onRefresh: _fetchDashboardData,
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
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: _buildRecentOrders()),
                const SizedBox(width: 20),
                Expanded(flex: 2, child: _buildProductStats()),
              ],
            ),
            const SizedBox(height: 20),
            _buildSubscriptionSummary(),
            const SizedBox(height: 20),
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AdminSubscriptionsPage(),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.subscriptions,
                        size: 48,
                        color: Constants.accentColor,
                      ),
                      SizedBox(height: 12),
                      Text(
                        'Subscription Management',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
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
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      // Navigate to reports page
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (context) =>
                                  _buildComingSoon(), // Placeholder for reports page
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Constants.accentColor,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                    child: const Text('View Reports'),
                  ),
                ],
              ),
            ),
            Image.asset(
              'assets/admin_illustration.png',
              height: 120,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  height: 120,
                  width: 120,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.analytics,
                    size: 60,
                    color: Colors.white,
                  ),
                );
              },
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
                _dashboardStats['totalOrders']?.toString() ?? '0',
                Icons.shopping_bag,
                Constants.accentColor,
                _dashboardStats['orderGrowth'] ?? 0.0,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildStatCard(
                'Total Revenue',
                formatter.format(_dashboardStats['totalRevenue'] ?? 0),
                Icons.currency_rupee,
                Constants.successColor,
                _dashboardStats['revenueGrowth'] ?? 0.0,
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
                _dashboardStats['activeUsers']?.toString() ?? '0',
                Icons.people,
                Constants.warningColor,
                _dashboardStats['userGrowth'] ?? 0.0,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildStatCard(
                'Subscriptions',
                _dashboardStats['subscriptions']?.toString() ?? '0',
                Icons.repeat,
                Constants.errorColor,
                _dashboardStats['subscriptionGrowth'] ?? 0.0,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
    double growth,
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
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  growth >= 0 ? Icons.arrow_upward : Icons.arrow_downward,
                  color:
                      growth >= 0
                          ? Constants.successColor
                          : Constants.errorColor,
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  '${growth.abs().toStringAsFixed(1)}% from last month',
                  style: TextStyle(
                    fontSize: 12,
                    color:
                        growth >= 0
                            ? Constants.successColor
                            : Constants.errorColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRevenueChart() {
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
                const Text(
                  'Revenue Overview',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Constants.textDark,
                  ),
                ),
                DropdownButton<String>(
                  value: 'This Month',
                  underline: Container(),
                  items:
                      ['This Week', 'This Month', 'This Year']
                          .map(
                            (String value) => DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            ),
                          )
                          .toList(),
                  onChanged: (_) {},
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 250,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: 25,
                    getDrawingHorizontalLine: (value) {
                      return FlLine(
                        color: Colors.grey.withOpacity(0.1),
                        strokeWidth: 1,
                      );
                    },
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        getTitlesWidget: (value, meta) {
                          const style = TextStyle(
                            color: Constants.textLight,
                            fontSize: 12,
                          );
                          String text;
                          switch (value.toInt()) {
                            case 0:
                              text = 'Jan';
                              break;
                            case 2:
                              text = 'Mar';
                              break;
                            case 4:
                              text = 'May';
                              break;
                            case 6:
                              text = 'Jul';
                              break;
                            case 8:
                              text = 'Sep';
                              break;
                            case 10:
                              text = 'Nov';
                              break;
                            default:
                              return Container();
                          }
                          return Text(text, style: style);
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          const style = TextStyle(
                            color: Constants.textLight,
                            fontSize: 12,
                          );
                          String text;
                          if (value == 0) {
                            text = '₹0';
                          } else if (value == 50) {
                            text = '₹50K';
                          } else if (value == 100) {
                            text = '₹100K';
                          } else {
                            return Container();
                          }
                          return Text(text, style: style);
                        },
                      ),
                    ),
                    rightTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  minX: 0,
                  maxX: 11,
                  minY: 0,
                  maxY: 100,
                  lineBarsData: [
                    LineChartBarData(
                      spots: _revenueData,
                      isCurved: true,
                      color: Constants.accentColor,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: Constants.accentColor.withOpacity(0.1),
                      ),
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
                const Text(
                  'Recent Orders',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Constants.textDark,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    // Navigate to all orders page
                    setState(() {
                      _selectedIndex = 3; // Orders index in drawer
                    });
                  },
                  child: const Text('View All'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _recentOrders.isEmpty
                ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Text('No recent orders found'),
                  ),
                )
                : DataTable(
                  columnSpacing: 20,
                  columns: const [
                    DataColumn(
                      label: Text(
                        'Order ID',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'Customer',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'Status',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'Amount',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                  rows:
                      _recentOrders.map((order) {
                        return _buildOrderRow(
                          '#${order['id'].toString().substring(0, 5)}',
                          order['customer'] ?? 'Unknown',
                          order['status'] ?? 'Pending',
                          formatter.format(order['amount'] ?? 0),
                        );
                      }).toList(),
                ),
          ],
        ),
      ),
    );
  }

  DataRow _buildOrderRow(
    String id,
    String customer,
    String status,
    String amount,
  ) {
    Color statusColor;
    if (status == 'Delivered') {
      statusColor = Constants.successColor;
    } else if (status == 'Processing') {
      statusColor = Constants.warningColor;
    } else {
      statusColor = Constants.textLight;
    }

    return DataRow(
      cells: [
        DataCell(Text(id, style: const TextStyle(fontWeight: FontWeight.bold))),
        DataCell(Text(customer)),
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              status,
              style: TextStyle(
                color: statusColor,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ),
        DataCell(
          Text(amount, style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildProductStats() {
    List<PieChartSectionData> sections = [];
    List<Map<String, dynamic>> legendItems = [];

    // Create a list of colors for the pie sections
    final List<Color> colors = [
      Constants.accentColor,
      Colors.orangeAccent,
      Colors.pinkAccent,
      Colors.greenAccent,
    ];

    int i = 0;
    _topProducts.forEach((product, percentage) {
      final color = i < colors.length ? colors[i] : Colors.grey;
      sections.add(
        PieChartSectionData(
          value: percentage,
          title: '${percentage.toStringAsFixed(1)}%',
          color: color,
          radius: 70,
          titleStyle: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      );

      legendItems.add({
        'product': product,
        'color': color,
        'percentage': '${percentage.toStringAsFixed(1)}%',
      });

      i++;
    });

    // If no products data available, show placeholder
    if (sections.isEmpty) {
      sections = [
        PieChartSectionData(
          value: 100,
          title: 'No Data',
          color: Colors.grey.shade300,
          radius: 70,
          titleStyle: const TextStyle(
            color: Constants.textDark,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ];

      legendItems = [
        {
          'product': 'No product data available',
          'color': Colors.grey.shade300,
          'percentage': '100%',
        },
      ];
    }

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
              height: 200,
              child: PieChart(
                PieChartData(
                  sections: sections,
                  sectionsSpace: 2,
                  centerSpaceRadius: 30,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Column(
              children:
                  legendItems.map((item) {
                    return _buildProductLegend(
                      item['product'],
                      item['color'],
                      item['percentage'],
                    );
                  }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductLegend(String product, Color color, String percentage) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              product,
              style: const TextStyle(color: Constants.textDark),
            ),
          ),
          Text(
            percentage,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Constants.textDark,
            ),
          ),
        ],
      ),
    );
  }
}

Widget _buildSubscriptionSummary() {
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
              const Text(
                'Subscription Summary',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Constants.textDark,
                ),
              ),
              TextButton(onPressed: () {}, child: const Text('View Details')),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildSubscriptionCard(
                  'Weekly',
                  '312',
                  Icons.calendar_view_week,
                  Constants.accentColor,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildSubscriptionCard(
                  'Monthly',
                  '533',
                  Icons.calendar_month,
                  Colors.purpleAccent,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildSubscriptionCard(
                  'New Subscribers',
                  '48',
                  Icons.person_add,
                  Colors.greenAccent,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildSubscriptionCard(
                  'Cancelled',
                  '15',
                  Icons.cancel,
                  Colors.redAccent,
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

Widget _buildSubscriptionCard(
  String title,
  String count,
  IconData icon,
  Color color,
) {
  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 30),
        const SizedBox(height: 16),
        Text(
          count,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          title,
          style: const TextStyle(
            color: Constants.textDark,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    ),
  );
}
