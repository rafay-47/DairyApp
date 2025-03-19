import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:toast/toast.dart';
import 'package:flutter_stripe/flutter_stripe.dart' as stripe;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../Constants.dart';
import '../Services/wallet_service.dart';

class StripePaymentService {
  // Private constructor to prevent instantiation from outside
  StripePaymentService._();

  // Singleton instance
  static final StripePaymentService _instance = StripePaymentService._();

  // Factory constructor to return the same instance each time
  factory StripePaymentService() => _instance;

  // Initialize Stripe
  static Future<void> init() async {
    stripe.Stripe.publishableKey =
        dotenv.env['STRIPE_PUBLISHABLE_KEY'] ??
        'pk_test_51OuuwVP0XD6u4TvYIUtwCffNiD1ZpOaKxKejORfDqAPjS6KSrwUg3qrd8jyrzYtQW6B6DJG2zScHPurSvn5EA7o500bOPE7N92';
  }

  // Make payment with Stripe
  Future<void> makePayment({
    required double amount,
    required BuildContext context,
    required Function onSuccess,
    required Function(String) onError,
  }) async {
    try {
      // Calculate amount in cents (Stripe requires amount in smallest currency unit)
      final int amountInCents = (amount * 100).toInt();

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
          'amount': amountInCents.toString(),
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
      // Show success toast with proper parameters
      Toast.show(
        'Payment Successful!',
        duration: Toast.lengthShort,
        gravity: Toast.bottom,
      );

      // Call the success callback
      onSuccess();
    } catch (e) {
      // Call the error callback
      onError(e.toString());
    }
  }

  // Record payment in the database
  Future<void> recordPayment({
    required String orderId,
    required double amount,
    required String paymentMethod,
    required String userId,
    required String status,
  }) async {
    try {
      // Create a unique payment ID
      final paymentId = 'PAY${DateTime.now().millisecondsSinceEpoch}';

      // Create a payment record in Firestore
      await FirebaseFirestore.instance
          .collection('payments')
          .doc(paymentId)
          .set({
            'id': paymentId,
            'orderRef': orderId,
            'amount': amount,
            'paymentMethod': paymentMethod,
            'userId': userId,
            'status': status,
            'timestamp': FieldValue.serverTimestamp(),
            'createdAt': DateTime.now(),
            'updatedAt': DateTime.now(),
          });

      // Also update the order with payment reference if it exists
      try {
        final orderDoc =
            await FirebaseFirestore.instance
                .collection('orders')
                .where('orderNumber', isEqualTo: orderId)
                .limit(1)
                .get();

        if (orderDoc.docs.isNotEmpty) {
          await orderDoc.docs.first.reference.update({
            'paymentId': paymentId,
            'paymentStatus': status,
            'paymentMethod': paymentMethod,
            'paymentTimestamp': FieldValue.serverTimestamp(),
          });
        }
      } catch (e) {
        print('Error updating order with payment reference: $e');
        // Non-critical error, continue execution
      }

      print('Payment record saved successfully');
    } catch (e) {
      print('Error recording payment: $e');
      // Don't throw the error as this is a non-critical operation
    }
  }

  // Process the order in Firebase after successful payment
  Future<void> processOrder({
    required BuildContext context,
    required Function(String, double) onOrderComplete,
    required Function(String) onError,
    String paymentMethod =
        'Stripe', // Add payment method parameter with default
  }) async {
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
      final userName = userData['Name'] ?? '';
      final userPhone = userData['Number'] ?? '';
      final userAddress = userData['Address'] ?? '';

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
      List<Map<String, dynamic>> subscriptionItems = [];
      double totalAmount = 0;

      for (var doc in cartSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final price =
            data['price'] != null
                ? double.parse(data['price'].toString())
                : 0.0;
        final quantity = data['quantity'] ?? 1;
        totalAmount += price * quantity;

        // Check if this is a subscription item
        if (data['type'] == 'subscription') {
          subscriptionItems.add({
            'subscriptionId': doc.id,
            'productId': data['productId'] ?? '',
            'productName': data['productName'] ?? '',
            'planName': data['planName'] ?? '',
            'duration': data['duration'] ?? 30,
            'price': price,
          });
        }

        items.add({
          'productId':
              data['type'] == 'subscription' ? data['productId'] : doc.id,
          'category': data['category'] ?? '',
          'description': data['description'] ?? '',
          'imageURL': data['imageUrl'] ?? null,
          'name': data['productName'] ?? data['name'] ?? '',
          'price': price,
          'quantity': quantity,
          'type': data['type'] ?? 'product',
          'planName': data['planName'] ?? '',
          'duration': data['duration'] ?? 0,
        });
      }

      // Calculate delivery charge
      final deliveryCharge = totalAmount >= 500 ? 0 : 40;
      final finalAmount = totalAmount + deliveryCharge;

      // Generate order number
      final orderNumber = 'ORD${DateTime.now().millisecondsSinceEpoch}';

      // Create order document in Firestore
      DocumentReference orderRef = await FirebaseFirestore.instance
          .collection('orders')
          .add({
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
            'paymentMethod': paymentMethod,
            'paymentStatus': 'Paid',
            'deliveryAddress': userAddress,
            'notes': '',
          });

      // Record the payment
      await recordPayment(
        orderId: orderNumber,
        amount: finalAmount,
        paymentMethod: paymentMethod,
        userId: currentUser.uid,
        status: 'Completed',
      );

      // Process subscriptions if present
      if (subscriptionItems.isNotEmpty) {
        await _processSubscriptions(
          subscriptionItems: subscriptionItems,
          userId: currentUser.uid,
          orderNumber: orderNumber,
        );
      }

      // Clear cart after successful order
      await _clearCart();

      // Call success callback with order details
      onOrderComplete(orderNumber, finalAmount);
    } catch (error) {
      // Call the error callback
      onError(error.toString());
    }
  }

  // New method to process subscriptions
  Future<void> _processSubscriptions({
    required List<Map<String, dynamic>> subscriptionItems,
    required String userId,
    required String orderNumber,
  }) async {
    final now = DateTime.now();

    for (var item in subscriptionItems) {
      final productId = item['productId'];
      final productName = item['productName'];
      final planName = item['planName'];
      final duration = item['duration'];
      final endDate = now.add(Duration(days: duration));

      // Create subscription record
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('product_subscriptions')
          .add({
            'productId': productId,
            'productName': productName,
            'planName': planName,
            'startDate': now,
            'endDate': endDate,
            'status': 'active',
            'orderNumber': orderNumber,
            'createdAt': FieldValue.serverTimestamp(),
          });

      // You could also add to a central subscriptions collection if needed
      await FirebaseFirestore.instance.collection('subscriptions').add({
        'userId': userId,
        'productId': productId,
        'productName': productName,
        'planName': planName,
        'startDate': now,
        'endDate': endDate,
        'duration': duration,
        'status': 'active',
        'orderNumber': orderNumber,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  // Helper method to clear cart
  Future<void> _clearCart() async {
    final snapshot = await FirebaseFirestore.instance.collection('cart').get();
    for (DocumentSnapshot doc in snapshot.docs) {
      await doc.reference.delete();
    }
  }

  // Show order success dialog
  static void showOrderSuccessDialog({
    required BuildContext context,
    required String orderNumber,
    required double totalAmount,
  }) {
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
                  'Total Amount: ₹${totalAmount.toStringAsFixed(2)}',
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

  // Process payment using wallet
  Future<bool> processWalletPayment({
    required double amount,
    required BuildContext context,
    required String orderDescription,
    required String orderId,
  }) async {
    final walletService = WalletService();
    final User? currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return false;
    }

    // Check wallet balance
    final balance = await walletService.getWalletBalance();

    if (balance < amount) {
      // Record failed payment attempt due to insufficient balance
      await recordPayment(
        orderId: orderId,
        amount: amount,
        paymentMethod: 'Wallet',
        userId: currentUser.uid,
        status: 'Failed',
      );

      // Insufficient balance
      return false;
    }

    // Deduct from wallet
    final success = await walletService.deductMoney(
      amount,
      orderDescription,
      orderId,
    );

    // No need to record payment here as it will be recorded in processOrder

    return success;
  }
}
