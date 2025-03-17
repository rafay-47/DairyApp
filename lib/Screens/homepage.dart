import 'package:dairyapp/Screens/SubscribedPage.dart';
import 'package:dairyapp/Screens/UserOrders.dart';
import 'package:dairyapp/Screens/cart.dart';
import 'package:dairyapp/Screens/subscriptionPage.dart';
import 'package:double_back_to_close_app/double_back_to_close_app.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dairyapp/Screens/profile.dart';
import 'package:dairyapp/Screens/Settings.dart' as settings;
import 'package:shared_preferences/shared_preferences.dart';
import '../Constants.dart';

class HomePage extends StatefulWidget {
  final VoidCallback onSignedOut;

  const HomePage({super.key, required this.onSignedOut});

  @override
  State<StatefulWidget> createState() {
    return HomeState();
  }
}

class HomeState extends State<HomePage> with SingleTickerProviderStateMixin {
  int currentTab = 0; // to keep track of active tab index
  String? userPinCode;
  bool isLocationVerified = false;

  // Use CategoriesList as the home screen.
  late final List<Widget> screens;
  final PageStorageBucket bucket = PageStorageBucket();
  late Widget currentScreen;

  @override
  void initState() {
    super.initState();
    _checkPinCode();
    screens = [
      CategoriesList(pinCode: userPinCode),
      ProfilePage(),
      UserOrders(),
      //OrderHistoryPage(),
      UserSubscriptionsPage(),
      settings.Settings(onSignedOut: widget.onSignedOut),
    ];
    currentScreen = screens[0];
  }

  void _checkPinCode() async {
    final prefs = await SharedPreferences.getInstance();
    final savedPinCode = prefs.getString('user_pin_code');

    setState(() {
      userPinCode = savedPinCode;
      isLocationVerified = savedPinCode != null;

      if (isLocationVerified) {
        screens[0] = CategoriesList(pinCode: userPinCode);
        if (currentTab == 0) {
          currentScreen = screens[0];
        }
      } else {
        // Don't show PIN code dialog immediately
        screens[0] = CategoriesList(pinCode: null);
        if (currentTab == 0) {
          currentScreen = screens[0];
        }
      }
    });
  }

  void _showPinCodeDialog() {
    final TextEditingController pinController = TextEditingController();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder:
            (context) => AlertDialog(
              title: Text('Enter Your PIN Code'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Please enter your PIN code to see products available in your area.',
                  ),
                  SizedBox(height: 16),
                  TextField(
                    controller: pinController,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    decoration: InputDecoration(
                      labelText: 'PIN Code',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                      fillColor: Colors.grey[100],
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () async {
                    if (pinController.text.length == 6) {
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setString(
                        'user_pin_code',
                        pinController.text,
                      );

                      setState(() {
                        userPinCode = pinController.text;
                        isLocationVerified = true;
                        screens[0] = CategoriesList(pinCode: userPinCode);
                        if (currentTab == 0) {
                          currentScreen = screens[0];
                        }
                      });

                      Navigator.of(context).pop();
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Please enter a valid 6-digit PIN code',
                          ),
                        ),
                      );
                    }
                  },
                  child: Text(
                    'CONFIRM',
                    style: TextStyle(color: Constants.accentColor),
                  ),
                ),
              ],
            ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: Constants.backgroundColor,
      appBar: AppBar(
        backgroundColor: Constants.primaryColor,
        elevation: 0,
        title: Row(
          children: [
            Icon(Icons.local_shipping_outlined, size: 22),
            SizedBox(width: 8),
            Text(
              'Dairy App',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          if (isLocationVerified)
            Container(
              margin: EdgeInsets.only(right: 16.0),
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: InkWell(
                onTap: () => _showPinCodeDialog(),
                child: Row(
                  children: [
                    Icon(Icons.location_on, size: 16),
                    SizedBox(width: 4),
                    Text(
                      userPinCode ?? '',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
        centerTitle: false,
      ),
      body: DoubleBackToCloseApp(
        snackBar: SnackBar(
          content: Text('Tap Back to exit'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: PageStorage(bucket: bucket, child: currentScreen),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => Cart()),
          );
        },
        backgroundColor: Constants.primaryColor,
        elevation: 4,
        child: Stack(
          children: [
            Icon(Icons.shopping_cart, color: Colors.white),
            Positioned(
              right: 0,
              top: 0,
              child: StreamBuilder<QuerySnapshot>(
                stream:
                    FirebaseFirestore.instance.collection('cart').snapshots(),
                builder: (context, snapshot) {
                  int count = 0;
                  if (snapshot.hasData && snapshot.data != null) {
                    count = snapshot.data!.docs.length;
                  }
                  return count > 0
                      ? Container(
                        padding: EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 2,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                        constraints: BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          count.toString(),
                          style: TextStyle(color: Colors.white, fontSize: 10),
                          textAlign: TextAlign.center,
                        ),
                      )
                      : Container();
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: Offset(0, -5),
            ),
          ],
        ),
        child: BottomAppBar(
          shape: CircularNotchedRectangle(),
          notchMargin: 10,
          color: Colors.white,
          elevation: 0,
          child: Container(
            height: 60,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[_buildLeftTabBar(), _buildRightTabBar()],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLeftTabBar() {
    return Expanded(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: <Widget>[
          _buildTabBarItem(
            icon: Icons.grid_view,
            label: 'Categories',
            index: 0,
            screen: screens[0],
          ),
          _buildTabBarItem(
            icon: Icons.shopping_bag,
            label: 'Orders',
            index: 2,
            screen: screens[2],
          ),
        ],
      ),
    );
  }

  Widget _buildRightTabBar() {
    return Expanded(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: <Widget>[
          _buildTabBarItem(
            icon: Icons.assignment,
            label: 'Subscriptions',
            index: 3,
            screen: screens[3],
          ),
          _buildTabBarItem(
            icon: Icons.settings,
            label: 'Settings',
            index: 4,
            screen: screens[4],
          ),
        ],
      ),
    );
  }

  Widget _buildTabBarItem({
    required IconData icon,
    required String label,
    required int index,
    required Widget screen,
  }) {
    return MaterialButton(
      minWidth: 0,
      padding: EdgeInsets.symmetric(horizontal: 8.0),
      onPressed: () {
        setState(() {
          currentScreen = screen;
          currentTab = index;
        });
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(
            icon,
            color: currentTab == index ? Constants.accentColor : Colors.grey,
            size: 24,
          ),
          Text(
            label,
            style: TextStyle(
              color: currentTab == index ? Constants.accentColor : Colors.grey,
              fontSize: 11,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// Updated ProductsByCategoryPage with modern UI and fixed overflow
class ProductsByCategoryPage extends StatefulWidget {
  final String category;
  final String? pinCode;

  const ProductsByCategoryPage({Key? key, required this.category, this.pinCode})
    : super(key: key);

  @override
  State<ProductsByCategoryPage> createState() => _ProductsByCategoryPageState();
}

class _ProductsByCategoryPageState extends State<ProductsByCategoryPage> {
  // Search and filter state variables
  String searchQuery = '';
  RangeValues priceRange = RangeValues(0, 500);
  String sortBy = 'Popularity';
  TextEditingController searchController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    // Create the base query
    Query productsQuery = FirebaseFirestore.instance
        .collection('products')
        .where('category', isEqualTo: widget.category);

    // Add location filtering if needed
    if (widget.pinCode != null) {
      productsQuery = productsQuery.where('pinCode', isEqualTo: widget.pinCode);
    }

    return Scaffold(
      backgroundColor: Constants.backgroundColor,
      appBar: AppBar(
        backgroundColor: Constants.primaryColor,
        elevation: 0,
        title: Row(
          children: [
            Icon(Icons.category, size: 20),
            SizedBox(width: 8),
            Text(
              widget.category,
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.search, color: Colors.white),
            onPressed: () {
              _showSearchBar();
            },
          ),
          IconButton(
            icon: Icon(Icons.filter_list, color: Colors.white),
            onPressed: () {
              _showFilterDialog(context);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar (visible when searching)
          if (searchQuery.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: Offset(0, 5),
                    ),
                  ],
                ),
                child: TextField(
                  controller: searchController,
                  decoration: InputDecoration(
                    hintText: 'Search in ${widget.category}',
                    border: InputBorder.none,
                    icon: Icon(Icons.search, color: Constants.primaryColor),
                    suffixIcon: IconButton(
                      icon: Icon(Icons.clear),
                      onPressed: () {
                        setState(() {
                          searchQuery = '';
                          searchController.clear();
                        });
                      },
                    ),
                  ),
                  onChanged: (value) {
                    setState(() {
                      searchQuery = value;
                    });
                  },
                ),
              ),
            ),

          // Active filters chips
          if (priceRange.start > 0 || priceRange.end < 500)
            Container(
              height: 50,
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  if (priceRange.start > 0 || priceRange.end < 500)
                    Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: Chip(
                        label: Text(
                          'Price: ₹${priceRange.start.toInt()} - ₹${priceRange.end.toInt()}',
                          style: TextStyle(fontSize: 12),
                        ),
                        backgroundColor: Constants.primaryColor.withOpacity(
                          0.1,
                        ),
                        deleteIcon: Icon(Icons.close, size: 16),
                        onDeleted: () {
                          setState(() {
                            priceRange = RangeValues(0, 500);
                          });
                        },
                      ),
                    ),
                ],
              ),
            ),

          // Products stream builder
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: productsQuery.snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error loading products'));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: CircularProgressIndicator(
                      color: Constants.primaryColor,
                    ),
                  );
                }

                // Filter the products based on search and filters
                var products = snapshot.data!.docs;

                // Apply search filter
                if (searchQuery.isNotEmpty) {
                  products =
                      products.where((product) {
                        final data = product.data() as Map<String, dynamic>;
                        final name =
                            data['name']?.toString().toLowerCase() ?? '';
                        final description =
                            data['description']?.toString().toLowerCase() ?? '';
                        final query = searchQuery.toLowerCase();
                        return name.contains(query) ||
                            description.contains(query);
                      }).toList();
                }

                // Apply price range filter
                products =
                    products.where((product) {
                      final data = product.data() as Map<String, dynamic>;
                      final price =
                          data['price'] != null
                              ? double.parse(data['price'].toString())
                              : 0;
                      return price >= priceRange.start &&
                          price <= priceRange.end;
                    }).toList();

                // Apply sorting
                products = _sortProducts(products, sortBy);

                if (products.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Constants.primaryColor.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.inventory_2_outlined,
                            size: 80,
                            color: Constants.primaryColor,
                          ),
                        ),
                        SizedBox(height: 24),
                        Text(
                          'No products found',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Constants.textDark,
                          ),
                        ),
                        SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 40.0),
                          child: Text(
                            searchQuery.isNotEmpty
                                ? 'No products matching "$searchQuery"'
                                : 'Try changing your filters or browse other categories',
                            style: TextStyle(
                              fontSize: 16,
                              color: Constants.textLight,
                              height: 1.4,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        SizedBox(height: 32),
                        ElevatedButton.icon(
                          onPressed: () {
                            if (searchQuery.isNotEmpty) {
                              setState(() {
                                searchQuery = '';
                                searchController.clear();
                              });
                            } else {
                              setState(() {
                                priceRange = RangeValues(0, 500);
                              });
                            }
                          },
                          icon: Icon(Icons.refresh),
                          label: Text('Clear Filters'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Constants.primaryColor,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return Column(
                  children: [
                    // Category header with product count
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${products.length} products found',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Constants.textLight,
                            ),
                          ),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 5,
                                ),
                              ],
                            ),
                            padding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            child: DropdownButton<String>(
                              value: sortBy,
                              underline: Container(),
                              icon: Icon(Icons.keyboard_arrow_down, size: 16),
                              isDense: true,
                              items:
                                  <String>[
                                    'Popularity',
                                    'Price: Low to High',
                                    'Price: High to Low',
                                    'Newest First',
                                  ].map<DropdownMenuItem<String>>((
                                    String value,
                                  ) {
                                    return DropdownMenuItem<String>(
                                      value: value,
                                      child: Text(
                                        value,
                                        style: TextStyle(fontSize: 13),
                                      ),
                                    );
                                  }).toList(),
                              onChanged: (String? newValue) {
                                if (newValue != null) {
                                  setState(() {
                                    sortBy = newValue;
                                  });
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Product grid
                    Expanded(
                      child: GridView.builder(
                        padding: const EdgeInsets.all(16.0),
                        itemCount: products.length,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                              childAspectRatio: 0.85,
                            ),
                        itemBuilder: (context, index) {
                          final productData =
                              products[index].data() as Map<String, dynamic>;
                          final productId = products[index].id;
                          final productName =
                              productData['name'] ?? 'Unnamed Product';
                          final productPrice =
                              productData['price'] != null
                                  ? productData['price'].toString()
                                  : 'N/A';
                          final imageUrl = productData['imageUrl'] ?? '';
                          final description = productData['description'] ?? '';
                          final unit = productData['unit'] ?? '';

                          return Card(
                            elevation: 3,
                            shadowColor: Colors.black12,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: InkWell(
                              onTap: () {
                                // Navigate to product detail
                              },
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Image container
                                  Expanded(
                                    flex: 6,
                                    child: Stack(
                                      children: [
                                        Positioned.fill(
                                          child:
                                              imageUrl.isNotEmpty
                                                  ? Image.network(
                                                    imageUrl,
                                                    fit: BoxFit.cover,
                                                  )
                                                  : Container(
                                                    color: Colors.grey[200],
                                                    child: Center(
                                                      child: Icon(
                                                        Icons.image,
                                                        color: Colors.grey[400],
                                                        size: 40,
                                                      ),
                                                    ),
                                                  ),
                                        ),
                                        // Add to cart button as overlay
                                        Positioned(
                                          top: 8,
                                          right: 8,
                                          child: Container(
                                            padding: EdgeInsets.all(6),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              shape: BoxShape.circle,
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black12,
                                                  blurRadius: 4,
                                                  offset: Offset(0, 2),
                                                ),
                                              ],
                                            ),
                                            child: GestureDetector(
                                              onTap: () {
                                                _addToCart(
                                                  context,
                                                  productId,
                                                  productName,
                                                  productData,
                                                );
                                              },
                                              child: Icon(
                                                Icons.add_shopping_cart,
                                                size: 18,
                                                color: Constants.primaryColor,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Product details container
                                  Padding(
                                    padding: const EdgeInsets.all(12.0),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          productName,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        SizedBox(height: 4),
                                        if (description.isNotEmpty)
                                          Text(
                                            description,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Constants.textLight,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        SizedBox(height: 8),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              '₹$productPrice${unit.isNotEmpty ? '/$unit' : ''}',
                                              style: TextStyle(
                                                color: Constants.primaryColor,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                              ),
                                            ),
                                            // Subscribe icon button
                                            GestureDetector(
                                              onTap: () {
                                                showDialog(
                                                  context: context,
                                                  builder:
                                                      (context) =>
                                                          SubscriptionDialog(
                                                            productId:
                                                                productId,
                                                            productName:
                                                                productName,
                                                            productDescription:
                                                                description,
                                                            productPrice:
                                                                double.parse(
                                                                  productPrice,
                                                                ),
                                                          ),
                                                );
                                              },
                                              child: Container(
                                                padding: EdgeInsets.all(4),
                                                decoration: BoxDecoration(
                                                  color: Colors.orange
                                                      .withOpacity(0.1),
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                ),
                                                child: Icon(
                                                  Icons.repeat,
                                                  size: 18,
                                                  color: Colors.orange,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // Show search bar dialog
  void _showSearchBar() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Search Products'),
            content: TextField(
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Enter product name or description',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onChanged: (value) {
                // Close dialog and update search
                if (value.isNotEmpty) {
                  Navigator.of(context).pop();
                  setState(() {
                    searchQuery = value;
                    searchController.text = value;
                  });
                }
              },
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: Text('Cancel'),
              ),
            ],
          ),
    );
  }

  // Filter dialog with functionality
  void _showFilterDialog(BuildContext context) {
    // Create temporary variables to hold filter state
    RangeValues tempPriceRange = priceRange;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: Offset(0, -5),
                  ),
                ],
              ),
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: 20 + MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header with title and close button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Constants.primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.filter_list,
                              color: Constants.primaryColor,
                            ),
                          ),
                          SizedBox(width: 12),
                          Text(
                            'Filter Products',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Constants.textDark,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),

                  SizedBox(height: 8),
                  Divider(),
                  SizedBox(height: 8),

                  // Price range filter
                  Text(
                    'Price Range',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Constants.textDark,
                    ),
                  ),
                  SizedBox(height: 12),
                  RangeSlider(
                    values: tempPriceRange,
                    max: 500,
                    divisions: 50,
                    activeColor: Constants.primaryColor,
                    inactiveColor: Constants.primaryColor.withOpacity(0.2),
                    labels: RangeLabels(
                      '₹${tempPriceRange.start.toInt()}',
                      '₹${tempPriceRange.end.toInt()}',
                    ),
                    onChanged: (values) {
                      setModalState(() {
                        tempPriceRange = values;
                      });
                    },
                  ),

                  // Price range display
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '₹${tempPriceRange.start.toInt()}',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: Constants.primaryColor,
                          ),
                        ),
                        Text(
                          '₹${tempPriceRange.end.toInt()}',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: Constants.primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 24),

                  // Filter buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            setModalState(() {
                              tempPriceRange = RangeValues(0, 500);
                            });
                          },
                          child: Text('Reset'),
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            side: BorderSide(color: Constants.primaryColor),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            // Apply filters
                            setState(() {
                              priceRange = tempPriceRange;
                            });
                            Navigator.of(context).pop();
                          },
                          child: Text('Apply'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Constants.primaryColor,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: 16),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
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

  // Sort products based on selected sorting option
  List<QueryDocumentSnapshot> _sortProducts(
    List<QueryDocumentSnapshot> products,
    String sortOption,
  ) {
    switch (sortOption) {
      case 'Price: Low to High':
        products.sort((a, b) {
          final priceA = (a.data() as Map<String, dynamic>)['price'] ?? 0;
          final priceB = (b.data() as Map<String, dynamic>)['price'] ?? 0;
          return (priceA is num ? priceA : double.parse(priceA.toString()))
              .compareTo(
                priceB is num ? priceB : double.parse(priceB.toString()),
              );
        });
        break;
      case 'Price: High to Low':
        products.sort((a, b) {
          final priceA = (a.data() as Map<String, dynamic>)['price'] ?? 0;
          final priceB = (b.data() as Map<String, dynamic>)['price'] ?? 0;
          return (priceB is num ? priceB : double.parse(priceB.toString()))
              .compareTo(
                priceA is num ? priceA : double.parse(priceA.toString()),
              );
        });
        break;
      case 'Newest First':
        products.sort((a, b) {
          final dateA =
              (a.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
          final dateB =
              (b.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
          if (dateA == null && dateB == null) return 0;
          if (dateA == null) return 1;
          if (dateB == null) return -1;
          return dateB.compareTo(dateA);
        });
        break;
      // For popularity (default) - you might want to implement your own logic
      default:
        // No sorting, or use a popularity field if available
        break;
    }
    return products;
  }

  // Existing add to cart method
  void _addToCart(
    BuildContext context,
    String productId,
    String productName,
    Map<String, dynamic> productData,
  ) {
    FirebaseFirestore.instance
        .collection('cart')
        .doc(productId)
        .set({
          'productId': productId,
          'name': productName,
          'price': productData['price'],
          'quantity': 1,
          'imageUrl': productData['imageUrl'] ?? '',
          'category': widget.category,
          'addedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true))
        .then((_) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '$productName added to cart',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              action: SnackBarAction(
                label: 'VIEW CART',
                textColor: Colors.white,
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => Cart()),
                  );
                },
              ),
            ),
          );
        })
        .catchError((error) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to add to cart: $error'),
              backgroundColor: Constants.errorColor,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        });
  }
}

// Displays categories in a grid layout.
class CategoriesList extends StatelessWidget {
  final String? pinCode;

  const CategoriesList({Key? key, this.pinCode}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (pinCode == null) {
      return Container(
        decoration: BoxDecoration(color: Constants.backgroundColor),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Constants.primaryColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.location_off_rounded,
                  size: 80,
                  color: Constants.primaryColor,
                ),
              ),
              SizedBox(height: 24),
              Text(
                'Location not set',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Constants.textDark,
                ),
              ),
              SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32.0),
                child: Text(
                  'Please set your PIN code to view available products in your area',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Constants.textLight,
                    height: 1.4,
                  ),
                ),
              ),
              SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () {
                  final HomeState? homeState =
                      context.findAncestorStateOfType<HomeState>();
                  if (homeState != null) {
                    homeState._showPinCodeDialog();
                  }
                },
                icon: Icon(Icons.location_on),
                label: Text('SET YOUR LOCATION'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Constants.primaryColor,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
              ),
            ],
          ),
        ),
      );
    }

    Query categoriesQuery = FirebaseFirestore.instance.collection('categories');
    print(categoriesQuery.snapshots().first);

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return <Widget>[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Constants.primaryColor,
                            Constants.primaryColor.withOpacity(0.8),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Constants.primaryColor.withOpacity(0.3),
                            blurRadius: 8,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.location_on,
                                color: Colors.white.withOpacity(0.9),
                                size: 20,
                              ),
                              SizedBox(width: 8),
                              Text(
                                "Delivering to PIN: $pinCode",
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.9),
                                  fontWeight: FontWeight.w500,
                                  fontSize: 15,
                                ),
                              ),
                              Spacer(),
                              InkWell(
                                onTap: () {
                                  final HomeState? homeState =
                                      context
                                          .findAncestorStateOfType<HomeState>();
                                  if (homeState != null) {
                                    homeState._showPinCodeDialog();
                                  }
                                },
                                child: Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Text(
                                    "Change",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w500,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 16),
                          Text(
                            "Fresh Dairy Products",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 22,
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
                            "Delivered to your doorstep",
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 24),
                    _buildFeaturedProducts(),

                    Padding(
                      padding: const EdgeInsets.only(top: 24.0, bottom: 8.0),
                      child: Row(
                        children: [
                          Container(
                            width: 4,
                            height: 20,
                            decoration: BoxDecoration(
                              color: Constants.primaryColor,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          SizedBox(width: 8),
                          Text(
                            "Categories",
                            style: TextStyle(
                              fontSize: 20.0,
                              fontWeight: FontWeight.bold,
                              color: Constants.textDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ];
        },
        body: StreamBuilder<QuerySnapshot>(
          stream: categoriesQuery.snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(child: Text('Error loading categories'));
            }
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(
                child: CircularProgressIndicator(color: Constants.primaryColor),
              );
            }
            final categories = snapshot.data!.docs;
            if (categories.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Constants.primaryColor.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.category_outlined,
                        size: 80,
                        color: Constants.primaryColor,
                      ),
                    ),
                    SizedBox(height: 24),
                    Text(
                      'No categories available',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Constants.textDark,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Try changing your location',
                      style: TextStyle(
                        fontSize: 16,
                        color: Constants.textLight,
                      ),
                    ),
                    SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () {
                        final HomeState? homeState =
                            context.findAncestorStateOfType<HomeState>();
                        if (homeState != null) {
                          homeState._showPinCodeDialog();
                        }
                      },
                      icon: Icon(Icons.refresh),
                      label: Text('Change Location'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Constants.primaryColor,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: GridView.builder(
                itemCount: categories.length,
                padding: EdgeInsets.only(top: 8, bottom: 80),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 0.8,
                ),
                itemBuilder: (context, index) {
                  final categoryData =
                      categories[index].data() as Map<String, dynamic>;
                  final categoryName =
                      categoryData['name'] ?? 'Unnamed Category';
                  final categoryDescription = categoryData['description'] ?? '';
                  final imageUrl = categoryData['imageUrl'] ?? '';

                  return Card(
                    elevation: 2,
                    shadowColor: Colors.black26,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (context) => ProductsByCategoryPage(
                                  category: categoryName,
                                  pinCode: pinCode,
                                ),
                          ),
                        );
                      },
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child:
                                imageUrl.isNotEmpty
                                    ? Image.network(imageUrl, fit: BoxFit.cover)
                                    : Container(
                                      color: Colors.grey[200],
                                      child: Icon(
                                        Icons.category,
                                        size: 40,
                                        color: Colors.grey[400],
                                      ),
                                    ),
                          ),
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.transparent,
                                    Colors.black.withOpacity(0.7),
                                  ],
                                  stops: [0.6, 1.0],
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            child: Container(
                              padding: EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    categoryName,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: Colors.white,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (categoryDescription.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4.0),
                                      child: Text(
                                        categoryDescription,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.white.withOpacity(0.9),
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildFeaturedProducts() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 4,
              height: 20,
              decoration: BoxDecoration(
                color: Constants.primaryColor,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            SizedBox(width: 8),
            Text(
              "Featured Products",
              style: TextStyle(
                fontSize: 20.0,
                fontWeight: FontWeight.bold,
                color: Constants.textDark,
              ),
            ),
            Spacer(),
            TextButton(
              onPressed: () {
                // Navigate to all products
              },
              child: Text(
                "See All",
                style: TextStyle(
                  color: Constants.primaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 12),
        Container(
          height: 180,
          child: StreamBuilder<QuerySnapshot>(
            stream:
                FirebaseFirestore.instance
                    .collection('products')
                    .limit(10)
                    .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError ||
                  !snapshot.hasData ||
                  snapshot.data!.docs.isEmpty) {
                return Center(
                  child: Text(
                    "No featured products available",
                    style: TextStyle(color: Constants.textLight),
                  ),
                );
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(
                  child: CircularProgressIndicator(
                    color: Constants.primaryColor,
                  ),
                );
              }

              final products = snapshot.data!.docs;

              return ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: products.length,
                itemBuilder: (context, index) {
                  final productData =
                      products[index].data() as Map<String, dynamic>;
                  final productName = productData['name'] ?? 'Unnamed Product';
                  final productPrice =
                      productData['price'] != null
                          ? productData['price'].toString()
                          : 'N/A';
                  final imageUrl = productData['imageUrl'] ?? '';

                  return Container(
                    width: 160,
                    margin: EdgeInsets.only(right: 16),
                    child: Card(
                      elevation: 3,
                      shadowColor: Colors.black12,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () {
                          // Navigate to product detail
                        },
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 3,
                              child: Stack(
                                children: [
                                  Positioned.fill(
                                    child:
                                        imageUrl.isNotEmpty
                                            ? Image.network(
                                              imageUrl,
                                              fit: BoxFit.cover,
                                            )
                                            : Container(
                                              color: Colors.grey[200],
                                              child: Center(
                                                child: Icon(
                                                  Icons.image,
                                                  color: Colors.grey[400],
                                                  size: 40,
                                                ),
                                              ),
                                            ),
                                  ),
                                  Positioned(
                                    top: 8,
                                    right: 8,
                                    child: Container(
                                      padding: EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black12,
                                            blurRadius: 4,
                                            offset: Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Icon(
                                        Icons.add_shopping_cart,
                                        size: 18,
                                        color: Constants.primaryColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    productName,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    '₹$productPrice',
                                    style: TextStyle(
                                      color: Constants.accentColor,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
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
  }
}
