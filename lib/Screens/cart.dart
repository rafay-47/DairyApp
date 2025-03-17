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

// Enhanced Cart page with modern UI
class Cart extends StatefulWidget {
  @override
  _CartState createState() => _CartState();
}

class _CartState extends State<Cart> {
  bool isLoading = false;
  double sum = 0;

  @override
  void initState() {
    super.initState();
    // Initialize Stripe - this should ideally be done in your app initialization
    // but we're doing it here for simplicity
    stripe.Stripe.publishableKey =
        'pk_test_51OuuwVP0XD6u4TvYIUtwCffNiD1ZpOaKxKejORfDqAPjS6KSrwUg3qrd8jyrzYtQW6B6DJG2zScHPurSvn5EA7o500bOPE7N92';
    // No need to attach listeners as in Razorpay
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Initialize Toast here when context is fully ready
    ToastContext().init(context);
  }

  Future<void> makeStripePayment() async {
    setState(() {
      isLoading = true;
    });

    try {
      // Calculate amount in cents (Stripe requires amount in smallest currency unit)
      final int amount = (sum * 100).toInt();

      // Get the secret key from environment variables
      final secretKey =
          dotenv.env['STRIPE_SECRET_KEY'] ??
          'sk_test_51OuuwVP0XD6u4TvYAOHTI6hGBzvkk596TUI5PLxmb79l7G8Q3xJR5GD3bwueOsejljjNgrrMqyR5OYyHI6N4Pcor00XXSrwjmU';

      // 1. Create payment intent on the server - typically this would be a call to your backend
      // For testing, we'll simulate this with a direct API call
      // In production, you should NEVER expose your secret key in the app
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

      // 2. Initialize payment sheet
      await stripe.Stripe.instance.initPaymentSheet(
        paymentSheetParameters: stripe.SetupPaymentSheetParameters(
          paymentIntentClientSecret: jsonResponse['client_secret'],
          merchantDisplayName: 'Dairy App',
          style: ThemeMode.light,
        ),
      );

      // 3. Present payment sheet
      await stripe.Stripe.instance.presentPaymentSheet();

      // If we reach here, payment was successful
      handlePaymentSuccess();
    } catch (e) {
      setState(() {
        isLoading = false;
      });

      // Handle payment errors
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

    // Show success toast with proper parameters
    Toast.show(
      'Payment Successful!',
      duration: Toast.lengthShort,
      gravity: Toast.bottom,
    );

    // Process the order in Firebase
    _processOrderInFirebase();
  }

  Future<void> _processOrderInFirebase() async {
    try {
      // Get current user
      final User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw 'Please login to place order';
      }

      // Get user details from Firestore
      final userDoc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(currentUser.uid)
              .get();

      if (!userDoc.exists) {
        throw 'User profile not found';
      }

      final userData = userDoc.data() ?? {};
      final userEmail = currentUser.email ?? '';
      final userName = userData['name'] ?? '';
      final userPhone = userData['phone'] ?? '';

      // Get cart items
      QuerySnapshot cartSnapshot =
          await FirebaseFirestore.instance.collection('cart').get();
      if (cartSnapshot.docs.isEmpty) {
        throw 'Cart is empty';
      }

      // Get user's pincode
      final prefs = await SharedPreferences.getInstance();
      final pinCode = prefs.getString('user_pin_code');
      if (pinCode == null) {
        throw 'Please set your delivery location';
      }

      // Prepare items array and calculate total
      List<Map<String, dynamic>> items = [];
      double totalAmount = 0;

      for (var doc in cartSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final price =
            data['price'] != null
                ? double.parse(data['price'].toString())
                : 0.0;
        final quantity = data['quantity'] ?? 1;
        totalAmount += price * quantity;

        items.add({
          'productId': doc.id,
          'category': data['category'] ?? '',
          'description': data['description'] ?? '',
          'imageURL': data['imageUrl'] ?? null,
          'name': data['name'] ?? '',
          'price': price,
          'quantity': quantity,
          'stock': data['stock'] ?? 0,
        });
      }

      // Calculate delivery charge
      final deliveryCharge = totalAmount >= 500 ? 0 : 40;
      final finalAmount = totalAmount + deliveryCharge;

      // Generate order number
      final orderNumber = 'ORD${DateTime.now().millisecondsSinceEpoch}';

      // Create order document in Firestore
      await FirebaseFirestore.instance.collection('orders').add({
        // User Information
        'userId': currentUser.uid,
        'userEmail': userEmail,
        'userName': userName,
        'userPhone': userPhone,
        'userPinCode': pinCode,

        // Order Information
        'orderNumber': orderNumber,
        'timestamp': FieldValue.serverTimestamp(),
        'orderDate': DateTime.now(),
        'status': 'Processing',
        'isActive': true,

        // Items and Amount
        'items': items,
        'subtotal': totalAmount,
        'deliveryCharge': deliveryCharge,
        'total': finalAmount,

        // Additional Information
        'paymentMethod': 'Stripe',
        'paymentStatus': 'Paid',
        'deliveryAddress': userData['address'] ?? '',
        'notes': '',
      });

      // Clear cart after successful order
      _clearCart();

      // Show success dialog
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
                      Navigator.of(context).pop(); // Close dialog
                      Navigator.of(context).pop(); // Return to previous screen
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
      // Show error message
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

  @override
  void dispose() {
    super.dispose();
    // No need to clear Razorpay
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

          // Update the sum value for Stripe
          sum = totalAmount + (totalAmount >= 500 ? 0 : 40);

          return Column(
            children: [
              Expanded(
                child: ListView.builder(
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
              ),
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
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
                          '₹${totalAmount.toStringAsFixed(2)}',
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
                          totalAmount >= 500 ? 'FREE' : '₹40.00',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: totalAmount >= 500 ? Colors.green : null,
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
                          '₹${(totalAmount + (totalAmount >= 500 ? 0 : 40)).toStringAsFixed(2)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: Constants.accentColor,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    // Checkout button - changed to use Stripe
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed:
                            isLoading
                                ? null
                                : () {
                                  makeStripePayment();
                                },
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
}
