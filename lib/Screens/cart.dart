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

class Cart extends StatefulWidget {
  const Cart({Key? key}) : super(key: key);

  @override
  _CartState createState() => _CartState();
}

class _CartState extends State<Cart> {
  bool isLoading = false;

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

  @override
  void initState() {
    super.initState();
    // Initialize Stripe
    stripe.Stripe.publishableKey =
        'pk_test_51OuuwVP0XD6u4TvYIUtwCffNiD1ZpOaKxKejORfDqAPjS6KSrwUg3qrd8jyrzYtQW6B6DJG2zScHPurSvn5EA7o500bOPE7N92';
    _fetchInitialData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    ToastContext().init(context);
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

  /// Stripe Payment
  Future<void> makeStripePayment() async {
    setState(() {
      isLoading = true;
    });
    try {
      final int amount = (finalAmount * 100).toInt();
      final secretKey =
          dotenv.env['STRIPE_SECRET_KEY'] ??
          'sk_test_51OuuwVP0XD6u4TvYAOHTI6hGBzvkk596TUI5PLxmb79l7G8Q3xJR5GD3bwueOsejljjNgrrMqyR5OYyHI6N4Pcor00XXSrwjmU';

      final response = await http.post(
        Uri.parse('https://api.stripe.com/v1/payment_intents'),
        headers: {
          'Authorization': 'Bearer $secretKey',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'amount': amount.toString(),
          'currency': 'inr',
          'payment_method_types[]': 'card',
        },
      );

      final jsonResponse = jsonDecode(response.body);
      await stripe.Stripe.instance.initPaymentSheet(
        paymentSheetParameters: stripe.SetupPaymentSheetParameters(
          paymentIntentClientSecret: jsonResponse['client_secret'],
          merchantDisplayName: 'Dairy App',
          style: ThemeMode.light,
        ),
      );
      await stripe.Stripe.instance.presentPaymentSheet();
      handlePaymentSuccess();
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Payment failed: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void handlePaymentSuccess() {
    setState(() {
      isLoading = false;
    });
    Toast.show(
      'Payment Successful!',
      duration: Toast.lengthShort,
      gravity: Toast.bottom,
    );
    _processOrderInFirestore();
  }

  /// Process the order in Firestore
  Future<void> _processOrderInFirestore() async {
    try {
      final User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) throw 'Please login to place order';

      final userDoc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(currentUser.uid)
              .get();
      if (!userDoc.exists) throw 'User profile not found';

      final userData = userDoc.data() ?? {};
      final userEmail = currentUser.email ?? '';
      final userName = userData['name'] ?? '';
      final userPhone = userData['phone'] ?? '';

      final cartSnap =
          await FirebaseFirestore.instance.collection('cart').get();
      if (cartSnap.docs.isEmpty) throw 'Cart is empty';

      final prefs = await SharedPreferences.getInstance();
      final pinCode = prefs.getString('user_pin_code');
      if (pinCode == null) throw 'Please set your delivery location';

      // Build items array
      List<Map<String, dynamic>> items = [];
      double totalAmount = 0;
      for (var doc in cartSnap.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final price =
            data['price'] != null
                ? double.parse(data['price'].toString())
                : 0.0;
        final quantity = data['quantity'] ?? 1;
        totalAmount += price * quantity;

        items.add({
          'productId': data['productId'] ?? doc.id,
          'category': data['category'] ?? '',
          'description': data['description'] ?? '',
          'imageURL': data['imageUrl'] ?? null,
          'name': data['name'] ?? '',
          'price': price,
          'quantity': quantity,
          'stock': data['stock'] ?? 0,
        });
      }

      subtotal = totalAmount;
      deliveryCharge = subtotal >= 500 ? 0 : 40;
      couponDiscount = 0;
      String? usedCouponId;

      if (_selectedCoupon != null) {
        final coupon = _selectedCoupon!;
        final type = coupon['type'];
        final discountVal = double.tryParse(coupon['discount'].toString()) ?? 0;

        if (type == 'Percentage') {
          couponDiscount = subtotal * (discountVal / 100);
          if (coupon.containsKey('maxDiscount')) {
            final maxDisc =
                double.tryParse(coupon['maxDiscount'].toString()) ?? 0;
            if (couponDiscount > maxDisc) couponDiscount = maxDisc;
          }
        } else if (type == 'Fixed') {
          couponDiscount = discountVal;
          if (couponDiscount > subtotal) couponDiscount = subtotal;
        } else if (type == 'Free Delivery') {
          // Always free shipping
          deliveryCharge = 0;
          // If discountVal > 0, also apply that discount
          if (discountVal > 0) {
            couponDiscount = discountVal;
            if (couponDiscount > subtotal) couponDiscount = subtotal;
          }
        }
        usedCouponId = coupon['id'];
      }

      final computedTotal = subtotal + deliveryCharge - couponDiscount;
      finalAmount = computedTotal < 0 ? 0 : computedTotal;

      final orderNumber = 'ORD${DateTime.now().millisecondsSinceEpoch}';

      // Save order
      await FirebaseFirestore.instance.collection('orders').add({
        'userId': currentUser.uid,
        'userEmail': userEmail,
        'userName': userName,
        'userPhone': userPhone,
        'userPinCode': pinCode,
        'orderNumber': orderNumber,
        'timestamp': FieldValue.serverTimestamp(),
        'orderDate': DateTime.now(),
        'status': 'Processing',
        'isActive': true,
        'items': items,
        'subtotal': subtotal,
        'deliveryCharge': deliveryCharge,
        'couponDiscount': couponDiscount,
        'total': finalAmount,
        'paymentMethod': 'Stripe',
        'paymentStatus': 'Paid',
        'deliveryAddress': userData['address'] ?? '',
        'notes': '',
        'couponId': usedCouponId,
      });

      // If the coupon has usage limit, increment usedCount
      if (usedCouponId != null) {
        final usedIndex = _allCoupons.indexWhere(
          (c) => c['id'] == usedCouponId,
        );
        if (usedIndex != -1) {
          final couponDocId = _allCoupons[usedIndex]['id'];
          final couponUsedCount = _allCoupons[usedIndex]['usedCount'] ?? 0;
          await FirebaseFirestore.instance
              .collection('coupons')
              .doc(couponDocId)
              .update({'usedCount': couponUsedCount + 1});
        }
      }

      _clearCart();

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder:
              (context) => AlertDialog(
                title: Text('Order Placed Successfully'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle, color: Colors.green, size: 60),
                    SizedBox(height: 16),
                    Text(
                      'Your order #$orderNumber has been placed successfully!',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Total Amount: ₹${finalAmount.toStringAsFixed(2)}',
                      style: TextStyle(
                        color: Constants.accentColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'You can track your order in the Orders section.',
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).pop();
                    },
                    child: Text(
                      'OK',
                      style: TextStyle(color: Constants.accentColor),
                    ),
                  ),
                ],
              ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to process order: $error'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
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

  void _updateQuantity(String cartDocId, int newQuantity) {
    if (newQuantity <= 0) {
      _removeFromCart(cartDocId);
      return;
    }
    FirebaseFirestore.instance
        .collection('cart')
        .doc(cartDocId)
        .update({'quantity': newQuantity})
        .catchError((error) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to update quantity: $error')),
          );
        });
  }

  void _removeFromCart(String cartDocId) {
    FirebaseFirestore.instance
        .collection('cart')
        .doc(cartDocId)
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

  /// Builds the coupon selection UI
  Widget _buildCouponSelection(List<QueryDocumentSnapshot> cartDocs) {
    _applicableCoupons = _getApplicableCoupons(
      cartDocs: cartDocs,
      cartSubtotal: subtotal,
      cartDelivery: deliveryCharge,
    );
    if (_selectedCoupon != null &&
        !_applicableCoupons.any((c) => c['id'] == _selectedCoupon!['id'])) {
      _selectedCoupon = null;
    }

    return Container(
      padding: EdgeInsets.all(16),
      margin: EdgeInsets.only(bottom: 16),
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
          Text(
            'Apply Coupon',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          SizedBox(height: 8),
          DropdownButton<Map<String, dynamic>>(
            isExpanded: true,
            hint: Text('Select a coupon or choose "No Coupon"'),
            value: _selectedCoupon,
            items: [
              DropdownMenuItem(child: Text('No Coupon'), value: null),
              ..._applicableCoupons.map((coupon) {
                final type = coupon['type'];
                final discountVal = coupon['discount'] ?? 0;
                String displayText = coupon['code'];
                if (type == 'Free Delivery') {
                  displayText += ' - Free Delivery';
                } else if (type == 'Percentage') {
                  displayText += ' - $discountVal% off';
                } else if (type == 'Fixed') {
                  displayText += ' - ₹$discountVal off';
                }
                if (coupon.containsKey('minPurchase')) {
                  displayText += ' (Min ₹${coupon['minPurchase']})';
                }
                return DropdownMenuItem(
                  value: coupon,
                  child: Text(displayText),
                );
              }).toList(),
            ],
            onChanged: (value) {
              setState(() {
                _selectedCoupon = value;
              });
            },
          ),
          if (_selectedCoupon != null) ...[
            SizedBox(height: 12),
            Text(
              'Coupon Details',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            SizedBox(height: 4),
            _buildCouponDetails(),
          ],
        ],
      ),
    );
  }

  Widget _buildCouponDetails() {
    final coupon = _selectedCoupon!;
    final type = coupon['type'];
    final discountVal = double.tryParse(coupon['discount'].toString()) ?? 0;

    // Show type & discount info
    if (type == 'Free Delivery') {
      // If discountVal > 0, "Free Delivery + ₹X off"
      if (discountVal > 0) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Discount: Free Delivery + ₹$discountVal off'),
            if (coupon.containsKey('minPurchase'))
              Text('Minimum Purchase: ₹${coupon['minPurchase']}'),
            if (coupon.containsKey('maxDiscount') && type == 'Percentage')
              Text('Max Discount: ₹${coupon['maxDiscount']}'),
          ],
        );
      } else {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Discount: Free Delivery'),
            if (coupon.containsKey('minPurchase'))
              Text('Minimum Purchase: ₹${coupon['minPurchase']}'),
          ],
        );
      }
    } else if (type == 'Fixed') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Discount: ₹$discountVal off'),
          if (coupon.containsKey('minPurchase'))
            Text('Minimum Purchase: ₹${coupon['minPurchase']}'),
        ],
      );
    } else if (type == 'Percentage') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Discount: $discountVal% off'),
          Text('You Saved: ₹${couponDiscount.toStringAsFixed(2)}'),
          if (coupon.containsKey('minPurchase'))
            Text('Minimum Purchase: ₹${coupon['minPurchase']}'),
          if (coupon.containsKey('maxDiscount'))
            Text('Max Discount: ₹${coupon['maxDiscount']}'),
        ],
      );
    }
    return SizedBox.shrink();
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
                onPressed: _showClearCartDialog,
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
              // If discountVal > 0, apply that to the subtotal
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

          return Column(
            children: [
              // Cart items
              Expanded(
                child: ListView.builder(
                  padding: EdgeInsets.all(16),
                  itemCount: cartItems.length,
                  itemBuilder: (context, index) {
                    final item = cartItems[index];
                    final data = item.data() as Map<String, dynamic>;
                    final cartDocId = item.id;
                    final name = data['name'] ?? 'Unnamed Product';
                    final price =
                        data['price'] != null
                            ? data['price'].toString()
                            : 'N/A';
                    final quantity = data['quantity'] ?? 1;
                    final imageUrl = data['imageUrl'] ?? '';

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
                                  Row(
                                    children: [
                                      InkWell(
                                        onTap:
                                            () => _updateQuantity(
                                              cartDocId,
                                              quantity - 1,
                                            ),
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
                                        onTap:
                                            () => _updateQuantity(
                                              cartDocId,
                                              quantity + 1,
                                            ),
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
                            IconButton(
                              icon: Icon(
                                Icons.delete_outline,
                                color: Colors.red[400],
                              ),
                              onPressed: () => _removeFromCart(cartDocId),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Coupon selection
              _buildCouponSelection(cartItems),

              // Summary & checkout
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
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Column(
                  children: [
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
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: isLoading ? null : () => makeStripePayment(),
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
                                ? CircularProgressIndicator(color: Colors.white)
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
          );
        },
      ),
    );
  }
}
