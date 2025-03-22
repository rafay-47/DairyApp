import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../Constants.dart';
import 'package:flutter_stripe/flutter_stripe.dart' as stripe;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:toast/toast.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:dairyapp/Screens/payment.dart';
import 'package:dairyapp/Services/wallet_service.dart';

class Cart extends StatefulWidget {
  @override
  _CartState createState() => _CartState();
}

class _CartState extends State<Cart> {
  bool isLoading = false;
  double sum = 0;
  String selectedPaymentMethod = 'Stripe'; // Default payment method

  // Price calculations
  double subtotal = 0; // sum of item prices × quantity
  double deliveryCharge = 0; // default 0 or 40 if subtotal < 500
  double couponDiscount = 0; // discount from coupon
  double finalAmount = 0; // final = subtotal + delivery - discount

  // All coupons from Firestore
  List<Map<String, dynamic>> _allCoupons = [];
  // Coupons that pass logic (minPurchase, usage, etc.)
  List<Map<String, dynamic>> _applicableCoupons = [];
  // The coupon user selected
  Map<String, dynamic>? _selectedCoupon;

  // For user data & stats
  Map<String, dynamic>? _userData;
  int _userOrderCount = 0; // how many orders user has
  Map<String, int> _couponUsageByUser =
      {}; // tracks how many times user used each coupon
  String _deliveryAddress = '';
  // Delivery address text field
  final TextEditingController _addressController = TextEditingController();
  
  @override
  void initState() {
    super.initState();
    print(_userData);
    _deliveryAddress = _userData?['deliveryAddress'] ?? '';
    _addressController.text = _deliveryAddress;
    // Initialize Stripe in the payment service
    StripePaymentService.init();
    _fetchInitialData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    ToastContext().init(context);
  }

  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
  }

  /// Fetch user info, coupon usage, and all coupons
  Future<void> _fetchInitialData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await dotenv.load();

      // 1. Get user doc
      final userDoc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();
      _userData = userDoc.data() ?? {};
      _addressController.text = _userData?['deliveryAddress'] ?? '';
      // 2. Count how many orders the user has
      _userOrderCount = await _getUserOrderCount(user.uid);

      // 3. Get how many times the user has used each coupon
      _couponUsageByUser = await _getUserCouponUsageCounts(user.uid);

      // 4. Fetch active & not-expired coupons
      await _fetchAllCoupons();

      setState(() {});
    } catch (e) {
      debugPrint('Error in _fetchInitialData: $e');
    }
  }

  Future<int> _getUserOrderCount(String uid) async {
    final orderSnap =
        await FirebaseFirestore.instance
            .collection('orders')
            .where('userId', isEqualTo: uid)
            .get();
    return orderSnap.size;
  }

  Future<Map<String, int>> _getUserCouponUsageCounts(String uid) async {
    final usageCountMap = <String, int>{};
    final orderSnap =
        await FirebaseFirestore.instance
            .collection('orders')
            .where('userId', isEqualTo: uid)
            .get();
    for (var doc in orderSnap.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final couponId = data['couponId'];
      if (couponId != null) {
        usageCountMap[couponId] = (usageCountMap[couponId] ?? 0) + 1;
      }
    }
    return usageCountMap;
  }

  Future<void> _fetchAllCoupons() async {
    try {
      final now = DateTime.now();
      QuerySnapshot snapshot =
          await FirebaseFirestore.instance
              .collection('coupons')
              .where('active', isEqualTo: true)
              .where('endDate', isGreaterThan: Timestamp.fromDate(now))
              .get();

      _allCoupons =
          snapshot.docs.map((doc) {
            return {'id': doc.id, ...doc.data() as Map<String, dynamic>};
          }).toList();
    } catch (e) {
      print('Error fetching coupons: $e');
    }
  }

  /// Filter coupons by usage limit, minPurchase, productIds, etc.
  List<Map<String, dynamic>> _getApplicableCoupons({
    required List<QueryDocumentSnapshot> cartDocs,
    required double cartSubtotal,
    required double cartDelivery,
  }) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return [];

    final now = DateTime.now();
    final userCreatedAt =
        _userData?['createdAt']?.toDate() ??
        (user.metadata.creationTime ?? DateTime(2000));
    final daysSinceSignup = now.difference(userCreatedAt).inDays;
    final cartTotal = cartSubtotal + cartDelivery;
    List<Map<String, dynamic>> applicable = [];

    for (var coupon in _allCoupons) {
      bool isApplicable = true;

      // usageLimit & usedCount
      if (coupon.containsKey('usageLimit') && coupon.containsKey('usedCount')) {
        final usageLimit = coupon['usageLimit'] ?? 999999;
        final usedCount = coupon['usedCount'] ?? 0;
        if (usedCount >= usageLimit) {
          isApplicable = false;
        }
      }

      // maxUsesPerUser
      if (coupon.containsKey('maxUsesPerUser')) {
        final maxUses = coupon['maxUsesPerUser'] ?? 1;
        final userUsed = _couponUsageByUser[coupon['id']] ?? 0;
        if (userUsed >= maxUses) {
          isApplicable = false;
        }
      }

      // isFirstPurchaseOnly
      if (coupon['isFirstPurchaseOnly'] == true && _userOrderCount > 0) {
        isApplicable = false;
      }

      // isNewUserOnly
      if (coupon['isNewUserOnly'] == true && daysSinceSignup > 7) {
        isApplicable = false;
      }

      // minPurchase check
      if (coupon.containsKey('minPurchase')) {
        final minPurchase =
            double.tryParse(coupon['minPurchase'].toString()) ?? 0;
        if (cartTotal < minPurchase) {
          isApplicable = false;
        }
      }

      // If not applyToAll, check productIds/categoryIds
      bool applyToAll = coupon['applyToAll'] ?? false;
      if (!applyToAll) {
        // productIds
        if (coupon.containsKey('productIds') &&
            (coupon['productIds'] as List).isNotEmpty) {
          bool found = false;
          for (var doc in cartDocs) {
            final data = doc.data() as Map<String, dynamic>;
            final cartProductId = data['productId']?.toString() ?? '';
            if ((coupon['productIds'] as List).contains(cartProductId)) {
              found = true;
              break;
            }
          }
          if (!found) isApplicable = false;
        }
        // categoryIds
        if (coupon.containsKey('categoryIds') &&
            (coupon['categoryIds'] as List).isNotEmpty) {
          bool found = false;
          for (var doc in cartDocs) {
            final data = doc.data() as Map<String, dynamic>;
            final category = data['category']?.toString() ?? '';
            if ((coupon['categoryIds'] as List).contains(category)) {
              found = true;
              break;
            }
          }
          if (!found) isApplicable = false;
        }
      }

      if (isApplicable) {
        applicable.add(coupon);
      }
    }
    return applicable;
  }

  // 1) Update user's address in Firestore
  // 2) Then proceed with existing payment logic
  Future<void> processPayment() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Please login to place order')));
      return;
    }

    if (_addressController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter a delivery address')),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      // 1) Update the user's Address field in Firestore
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update(
        {'deliveryAddress': _addressController.text.trim()},
      );

      // 2) Proceed with payment logic
      final paymentAmount = finalAmount;
      final paymentService = StripePaymentService();

      if (selectedPaymentMethod == 'Wallet') {
        // Process wallet payment
        final orderNumber = 'ORD${DateTime.now().millisecondsSinceEpoch}';
        final success = await paymentService.processWalletPayment(
          amount: paymentAmount,
          context: context,
          orderDescription: 'Payment for order #$orderNumber',
          orderId: orderNumber,
        );

        if (success) {
          // Process the order with Wallet as payment method
          await paymentService.processOrder(
            context: context,
            onOrderComplete: (orderNumber, totalAmount) {
              StripePaymentService.showOrderSuccessDialog(
                context: context,
                orderNumber: orderNumber,
                totalAmount: totalAmount,
              );
            },
            onError: (error) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Failed to process order: $error'),
                  backgroundColor: Colors.red,
                  duration: Duration(seconds: 3),
                ),
              );
            },
            paymentMethod: 'Wallet',
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Insufficient wallet balance. Please add money or choose a different payment method.',
              ),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            ),
          );
        }
      } else {
        // Process Stripe payment
        await paymentService.makePayment(
          amount: paymentAmount,
          context: context,
          onSuccess: () async {
            final orderNumber = 'ORD${DateTime.now().millisecondsSinceEpoch}';
            await paymentService.processOrder(
              context: context,
              onOrderComplete: (orderNumber, totalAmount) {
                StripePaymentService.showOrderSuccessDialog(
                  context: context,
                  orderNumber: orderNumber,
                  totalAmount: totalAmount,
                );
              },
              onError: (error) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Failed to process order: $error'),
                    backgroundColor: Colors.red,
                    duration: Duration(seconds: 3),
                  ),
                );
              },
              paymentMethod: 'Stripe',
            );
          },
          onError: (error) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Payment failed: $error'),
                backgroundColor: Colors.red,
              ),
            );
          },
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  /// Builds the coupon selection UI
  Widget _buildCouponSelection(List<QueryDocumentSnapshot> cartDocs) {
    _applicableCoupons = _getApplicableCoupons(
      cartDocs: cartDocs,
      cartSubtotal: subtotal,
      cartDelivery: deliveryCharge,
    );

    return Container(
      padding: EdgeInsets.all(16),
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Apply Coupon',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              if (_selectedCoupon != null)
                TextButton(
                  onPressed: () {
                    setState(() {
                      _selectedCoupon = null;
                    });
                  },
                  child: Text('Remove', style: TextStyle(color: Colors.red)),
                ),
            ],
          ),
          SizedBox(height: 8),
          _applicableCoupons.isEmpty
              ? Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'No coupons available currently',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              )
              : DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  hintText: 'Select a coupon',
                ),
                value: _selectedCoupon?['id'],
                items:
                    _applicableCoupons.map((coupon) {
                      final String code = coupon['code'] ?? 'UNKNOWN';
                      final String type = coupon['type'] ?? 'Unknown';
                      final dynamic discount = coupon['discount'];

                      String displayText = '$code - ';
                      if (type == 'Percentage') {
                        displayText += '$discount% off';
                      } else if (type == 'Fixed') {
                        displayText += '₹$discount off';
                      } else if (type == 'Free Delivery') {
                        displayText += 'Free Delivery';
                      }

                      return DropdownMenuItem<String>(
                        value: coupon['id'],
                        child: Text(displayText),
                      );
                    }).toList(),
                onChanged: (String? couponId) {
                  if (couponId != null) {
                    final selectedCoupon = _applicableCoupons.firstWhere(
                      (c) => c['id'] == couponId,
                      orElse: () => {},
                    );
                    setState(() {
                      _selectedCoupon = selectedCoupon;
                    });
                  }
                },
              ),
          if (_selectedCoupon != null) ...[
            SizedBox(height: 12),
            _buildCouponDetails(),
          ],
        ],
      ),
    );
  }

  Widget _buildCouponDetails() {
    if (_selectedCoupon == null) return SizedBox.shrink();

    final coupon = _selectedCoupon!;
    final type = coupon['type'];
    final discountVal = double.tryParse(coupon['discount'].toString()) ?? 0;

    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Constants.primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Constants.primaryColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            coupon['code'] ?? 'Coupon',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Constants.primaryColor,
            ),
          ),
          SizedBox(height: 4),
          if (type == 'Free Delivery')
            Text(
              discountVal > 0
                  ? 'Free Delivery + ₹$discountVal off'
                  : 'Free Delivery',
            ),
          if (type == 'Fixed') Text('₹$discountVal off your order'),
          if (type == 'Percentage') Text('$discountVal% off your order'),
          SizedBox(height: 4),
          Text(
            'You save: ₹${couponDiscount.toStringAsFixed(2)}',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
          ),
        ],
      ),
    );
  }

  void _updateQuantity(String productId, int newQuantity) {
    if (newQuantity <= 0) {
      _removeFromCart(productId);
      return;
    }

    FirebaseFirestore.instance
        .collection('cart')
        .doc(productId)
        .update({'quantity': newQuantity})
        .catchError((error) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to update quantity: $error')),
          );
        });
  }

  void _removeFromCart(String productId) {
    FirebaseFirestore.instance
        .collection('cart')
        .doc(productId)
        .delete()
        .catchError((error) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to remove item: $error')),
          );
        });
  }

  void _showClearCartDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Clear Cart'),
            content: Text(
              'Are you sure you want to remove all items from your cart?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('CANCEL'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _clearCart();
                },
                child: Text('YES, CLEAR', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
    );
  }

  Widget _buildEmptyCart() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.shopping_cart_outlined,
            size: 100,
            color: Colors.grey[400],
          ),
          SizedBox(height: 24),
          Text(
            'Your cart is empty',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
          SizedBox(height: 16),
          Text(
            'Looks like you haven\'t added\nanything to your cart yet',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[600], fontSize: 16),
          ),
          SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
            },
            icon: Icon(Icons.shopping_bag_outlined),
            label: Text('BROWSE PRODUCTS'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Constants.accentColor,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _clearCart() {
    FirebaseFirestore.instance
        .collection('cart')
        .get()
        .then((snapshot) {
          for (DocumentSnapshot doc in snapshot.docs) {
            doc.reference.delete();
          }
        })
        .catchError((error) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to clear cart: $error')),
          );
        });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Constants.backgroundColor,
      appBar: AppBar(
        backgroundColor: Constants.accentColor,
        title: Text('My Cart', style: TextStyle(color: Constants.primaryColor)),
        actions: [
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('cart').snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Container();
              }
              return IconButton(
                icon: Icon(Icons.delete_outline, color: Constants.primaryColor),
                onPressed: () {
                  _showClearCartDialog();
                },
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('cart').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error loading cart'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          final cartItems = snapshot.data!.docs;
          if (cartItems.isEmpty) {
            return _buildEmptyCart();
          }

          // 1. Calculate subtotal
          double totalAmount = 0;
          for (var item in cartItems) {
            final data = item.data() as Map<String, dynamic>;
            final price =
                data['price'] != null
                    ? double.parse(data['price'].toString())
                    : 0.0;
            final quantity = data['quantity'] ?? 1;
            totalAmount += price * quantity;
          }
          subtotal = totalAmount;

          // 2. Base delivery logic
          deliveryCharge = subtotal >= 500 ? 0 : 40;

          // 3. Apply coupon discount
          couponDiscount = 0;
          if (_selectedCoupon != null) {
            final coupon = _selectedCoupon!;
            final type = coupon['type'];
            final discountVal =
                double.tryParse(coupon['discount'].toString()) ?? 0;

            if (type == 'Percentage') {
              couponDiscount = subtotal * (discountVal / 100);
              if (coupon.containsKey('maxDiscount')) {
                double maxDisc =
                    double.tryParse(coupon['maxDiscount'].toString()) ?? 0;
                if (couponDiscount > maxDisc) couponDiscount = maxDisc;
              }
            } else if (type == 'Fixed') {
              couponDiscount = discountVal;
              if (couponDiscount > subtotal) {
                couponDiscount = subtotal;
              }
            } else if (type == 'Free Delivery') {
              // Zero out the delivery
              deliveryCharge = 0;
              if (discountVal > 0) {
                couponDiscount = discountVal;
                if (couponDiscount > subtotal) {
                  couponDiscount = subtotal;
                }
              }
            }
          }

          // 4. Final total
          final computedTotal = subtotal + deliveryCharge - couponDiscount;
          finalAmount = computedTotal < 0 ? 0 : computedTotal;
          sum = finalAmount;

          return SingleChildScrollView(
            child: Column(
              children: [
                // Cart items
                ListView.builder(
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  padding: EdgeInsets.all(16),
                  itemCount: cartItems.length,
                  itemBuilder: (context, index) {
                    final item = cartItems[index];
                    final data = item.data() as Map<String, dynamic>;
                    final productId = item.id;
                    final name = data['name'] ?? 'Unnamed Product';
                    final price =
                        data['price'] != null
                            ? data['price'].toString()
                            : 'N/A';
                    final quantity = data['quantity'] ?? 1;
                    final imageUrl = data['imageUrl'] ?? 'https://www.nestleprofessional.com.pk/sites/default/files/styles/np_product_teaser_2x/public/2022-06/milkpak_uht_pro_choice_1_liter.png?itok=YgvMIB74';

                    return Card(
                      margin: EdgeInsets.only(bottom: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Row(
                          children: [
                            // Product Image
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                width: 80,
                                height: 80,
                                child:
                                    imageUrl.isNotEmpty
                                        ? Image.network(
                                          imageUrl,
                                          fit: BoxFit.cover,
                                        )
                                        : Container(
                                          color: Colors.grey[200],
                                          child: Icon(
                                            Icons.image,
                                            color: Colors.grey[400],
                                            size: 30,
                                          ),
                                        ),
                              ),
                            ),
                            SizedBox(width: 16),
                            // Product Details
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    '₹$price',
                                    style: TextStyle(
                                      color: Constants.accentColor,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  // Quantity controls
                                  Row(
                                    children: [
                                      InkWell(
                                        onTap: () {
                                          _updateQuantity(
                                            productId,
                                            quantity - 1,
                                          );
                                        },
                                        child: Container(
                                          padding: EdgeInsets.all(4),
                                          decoration: BoxDecoration(
                                            color: Colors.grey[200],
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                          child: Icon(Icons.remove, size: 16),
                                        ),
                                      ),
                                      Container(
                                        margin: EdgeInsets.symmetric(
                                          horizontal: 8,
                                        ),
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          border: Border.all(
                                            color: Colors.grey[300]!,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: Text(
                                          quantity.toString(),
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      InkWell(
                                        onTap: () {
                                          _updateQuantity(
                                            productId,
                                            quantity + 1,
                                          );
                                        },
                                        child: Container(
                                          padding: EdgeInsets.all(4),
                                          decoration: BoxDecoration(
                                            color: Colors.grey[200],
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                          child: Icon(Icons.add, size: 16),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            // Delete button
                            IconButton(
                              icon: Icon(
                                Icons.delete_outline,
                                color: Colors.red[400],
                              ),
                              onPressed: () {
                                _removeFromCart(productId);
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),

                // Coupon selection section
                _buildCouponSelection(cartItems),

                // Order summary and checkout
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        spreadRadius: 1,
                        blurRadius: 10,
                        offset: Offset(0, -5),
                      ),
                    ],
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                  ),
                  child: Column(
                    children: [
                      // Order summary
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Items (${cartItems.length})',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                          Text(
                            '₹${subtotal.toStringAsFixed(2)}',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Delivery',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                          Text(
                            deliveryCharge == 0
                                ? 'FREE'
                                : '₹${deliveryCharge.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: deliveryCharge == 0 ? Colors.green : null,
                            ),
                          ),
                        ],
                      ),
                      // Add coupon discount row if applicable
                      if (couponDiscount > 0)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Coupon Discount',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                            Text(
                              '-₹${couponDiscount.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                      Divider(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Total Amount',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            '₹${finalAmount.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: Constants.accentColor,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                      // Payment method selection
                      Padding(
                        padding: EdgeInsets.only(bottom: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Payment Method',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        selectedPaymentMethod = 'Stripe';
                                      });
                                    },
                                    child: Container(
                                      padding: EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                      decoration: BoxDecoration(
                                        color:
                                            selectedPaymentMethod == 'Stripe'
                                                ? Constants.primaryColor
                                                    .withOpacity(0.1)
                                                : Colors.grey[100],
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color:
                                              selectedPaymentMethod == 'Stripe'
                                                  ? Constants.primaryColor
                                                  : Colors.grey[300]!,
                                        ),
                                      ),
                                      child: Column(
                                        children: [
                                          Icon(
                                            Icons.credit_card,
                                            color:
                                                selectedPaymentMethod ==
                                                        'Stripe'
                                                    ? Constants.primaryColor
                                                    : Colors.grey[600],
                                          ),
                                          SizedBox(height: 4),
                                          Text(
                                            'Card',
                                            style: TextStyle(
                                              color:
                                                  selectedPaymentMethod ==
                                                          'Stripe'
                                                      ? Constants.primaryColor
                                                      : Colors.grey[600],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(width: 16),
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        selectedPaymentMethod = 'Wallet';
                                      });
                                    },
                                    child: Container(
                                      padding: EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                      decoration: BoxDecoration(
                                        color:
                                            selectedPaymentMethod == 'Wallet'
                                                ? Constants.primaryColor
                                                    .withOpacity(0.1)
                                                : Colors.grey[100],
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color:
                                              selectedPaymentMethod == 'Wallet'
                                                  ? Constants.primaryColor
                                                  : Colors.grey[300]!,
                                        ),
                                      ),
                                      child: Column(
                                        children: [
                                          Icon(
                                            Icons.account_balance_wallet,
                                            color:
                                                selectedPaymentMethod ==
                                                        'Wallet'
                                                    ? Constants.primaryColor
                                                    : Colors.grey[600],
                                          ),
                                          SizedBox(height: 4),
                                          Text(
                                            'Wallet',
                                            style: TextStyle(
                                              color:
                                                  selectedPaymentMethod ==
                                                          'Wallet'
                                                      ? Constants.primaryColor
                                                      : Colors.grey[600],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            // Show wallet balance if wallet is selected
                            if (selectedPaymentMethod == 'Wallet')
                              FutureBuilder<double>(
                                future: WalletService().getWalletBalance(),
                                builder: (context, snapshot) {
                                  final balance = snapshot.data ?? 0.0;
                                  final isBalanceSufficient =
                                      balance >= finalAmount;

                                  return Padding(
                                    padding: EdgeInsets.only(top: 8),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Wallet Balance:',
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                        Text(
                                          '₹ ${balance.toStringAsFixed(2)}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color:
                                                isBalanceSufficient
                                                    ? Colors.green
                                                    : Colors.red,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                          ],
                        ),
                      ),
                      // Delivery Address field (no form, just a text field)
                      TextField(
                        controller: _addressController,
                        
                        decoration: InputDecoration(
                          labelText: 'Delivery Address',
                          hintText: 'Enter your delivery address',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                      SizedBox(height: 16),
                      // Checkout button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: isLoading ? null : () => processPayment(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Constants.accentColor,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child:
                              isLoading
                                  ? CircularProgressIndicator(
                                    color: Colors.white,
                                  )
                                  : Text(
                                    'PROCEED TO CHECKOUT',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
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
    );
  }
}
