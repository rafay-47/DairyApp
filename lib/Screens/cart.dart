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

// Enhanced Cart page with modern UI
class Cart extends StatefulWidget {
  @override
  _CartState createState() => _CartState();
}

class _CartState extends State<Cart> {
  bool isLoading = false;
  double sum = 0;
  String selectedPaymentMethod = 'Stripe'; // Default payment method

  @override
  void initState() {
    super.initState();
    // Initialize Stripe in the payment service - on app startup would be better
    StripePaymentService.init();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Initialize Toast here when context is fully ready
    ToastContext().init(context);
  }

  // Process payment using Stripe
  Future<void> processPayment() async {
    setState(() {
      isLoading = true;
    });

    final paymentService = StripePaymentService();

    if (selectedPaymentMethod == 'Wallet') {
      // Process wallet payment
      final orderNumber = 'ORD${DateTime.now().millisecondsSinceEpoch}';
      final success = await paymentService.processWalletPayment(
        amount: sum,
        context: context,
        orderDescription: 'Payment for order #$orderNumber',
        orderId: orderNumber,
      );

      if (success) {
        // Process the order with Wallet as payment method
        await paymentService.processOrder(
          context: context,
          paymentMethod: 'Wallet', // Pass payment method
          onOrderComplete: (String orderNumber, double finalAmount) {
            setState(() {
              isLoading = false;
            });

            // Show success dialog
            StripePaymentService.showOrderSuccessDialog(
              context: context,
              orderNumber: orderNumber,
              totalAmount: finalAmount,
            );
          },
          onError: (String errorMessage) {
            setState(() {
              isLoading = false;
            });

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to process order: $errorMessage'),
                backgroundColor: Colors.red,
              ),
            );
          },
        );
      } else {
        setState(() {
          isLoading = false;
        });

        // Show insufficient balance message
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
      // Process Stripe payment (existing flow)
      await paymentService.makePayment(
        amount: sum,
        context: context,
        onSuccess: () {
          // After successful payment, process the order with Stripe as payment method
          paymentService.processOrder(
            context: context,
            paymentMethod: 'Stripe', // Pass payment method explicitly
            onOrderComplete: (String orderNumber, double finalAmount) {
              setState(() {
                isLoading = false;
              });

              StripePaymentService.showOrderSuccessDialog(
                context: context,
                orderNumber: orderNumber,
                totalAmount: finalAmount,
              );
            },
            onError: (String errorMessage) {
              setState(() {
                isLoading = false;
              });

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Failed to process order: $errorMessage'),
                  backgroundColor: Colors.red,
                ),
              );
            },
          );
        },
        onError: (String errorMessage) {
          setState(() {
            isLoading = false;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Payment failed: $errorMessage'),
              backgroundColor: Colors.red,
            ),
          );
        },
      );
    }
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
                                    padding: EdgeInsets.symmetric(vertical: 12),
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
                                              selectedPaymentMethod == 'Stripe'
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
                                    padding: EdgeInsets.symmetric(vertical: 12),
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
                                              selectedPaymentMethod == 'Wallet'
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
                                final isBalanceSufficient = balance >= sum;

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
                    // Checkout button - changed to use Stripe
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed:
                            isLoading
                                ? null
                                : () {
                                  processPayment();
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
