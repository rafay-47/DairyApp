// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:flutter/material.dart';
// import 'package:razorpay_flutter/razorpay_flutter.dart';
// import 'package:toast/toast.dart';

// late Map<dynamic, dynamic> cartProduct;
// late List<dynamic> cartNameList;
// late List<dynamic> cartQuantityList;
// late DocumentSnapshot snapshotprice;
// late DocumentSnapshot snapuser;
// int sum = 0;

// class Cart extends StatefulWidget {
//   const Cart({super.key});

//   @override
//   _CartState createState() => _CartState();
// }

// class _CartState extends State<Cart> {
//   late Razorpay razor;

//   Future<void> getAddOnData() async {
//     final User user = FirebaseAuth.instance.currentUser!;
//     final String uid = user.uid.toString();
//     DocumentSnapshot snapshot =
//         await FirebaseFirestore.instance.collection('cart').doc(uid).get();
//     snapshotprice =
//         await FirebaseFirestore.instance.collection('price').doc('1').get();
//     snapuser =
//         await FirebaseFirestore.instance.collection('users').doc(uid).get();
//     setState(() {
//       cartProduct = (snapshot.data() as Map<String, dynamic>)['product'];
//       cartNameList = cartProduct.keys.toList();
//       cartQuantityList = cartProduct.values.toList();
//       sum = (snapuser.data() as Map<String, dynamic>)['CartValue'];
//     });
//   }

//   void updatecartvalue(var index) {
//     String str = cartNameList[index];
//     String str2 = cartQuantityList[index];
//     int p = int.parse((snapshotprice.data as Map<String, dynamic>)[str]);
//     int q = int.parse(str2);
//     setState(() {
//       sum = sum - (p * q);
//     });
//   }

//   Widget displayData() {
//     return ListView.builder(
//       itemCount: cartProduct.length,
//       itemBuilder: (context, index) {
//         return Dismissible(
//           background: Container(color: Color.fromRGBO(22, 102, 225, 1)),
//           key: UniqueKey(),
//           child: Card(
//             elevation: 10.0,
//             child: ListTile(
//               title: Text('${cartNameList[index]}'),
//               trailing: Text('${cartQuantityList[index]}'),
//             ),
//           ),
//           onDismissed: (direction) {
//             Toast.show(
//               "${cartNameList[index]} removed form cart ",
//               duration: Toast.lengthShort,
//               gravity: Toast.bottom,
//               backgroundColor: Colors.black,
//               webTexColor: Colors.white,
//             );
//             setState(() {
//               updatecartvalue(index);
//               updateCart(index);
//             });
//           },
//         );
//       },
//     );
//   }

//   Future<void> updateCart(var index) async {
//     final User user = FirebaseAuth.instance.currentUser!;
//     final String uid = user.uid.toString();
//     setState(() {
//       cartProduct.remove('${cartNameList[index]}');
//       cartNameList.removeAt(index);
//       cartQuantityList.removeAt(index);
//       FirebaseFirestore.instance.collection('cart').doc(uid).update({
//         'product': cartProduct,
//       });
//       FirebaseFirestore.instance.collection('users').doc(uid).update({
//         'product': cartProduct,
//       });
//       FirebaseFirestore.instance.collection('users').doc(uid).update({
//         'CartValue': sum,
//       });
//     });
//   }

//   void openCheckout() {
//     var options = {
//       'key': 'rzp_test_0sjqCKCoIjJr2F',
//       'amount': sum * 100,
//       'name': 'Dairy App',
//       'external': {
//         'wallets': ['paytm'],
//       },
//     };

//     try {
//       razor.open(options);
//     } catch (e) {
//       debugPrint(e as String?);
//     }
//   }

//   void handlerPaymentSuccess(PaymentSuccessResponse response) {
//     Toast.show('Success${response.paymentId}');
//   }

//   void handlerPaymentError(PaymentFailureResponse response) {
//     Toast.show('Error${response.code} . ${response.message}');
//   }

//   void handlerPaymentExternal(ExternalWalletResponse response) {
//     Toast.show('External Wallet${response.walletName}');
//   }

//   @override
//   void initState() {
//     // TODO: implement initState
//     super.initState();
//     razor = Razorpay();
//     razor.on(Razorpay.EVENT_PAYMENT_SUCCESS, handlerPaymentSuccess);
//     razor.on(Razorpay.EVENT_PAYMENT_ERROR, handlerPaymentError);
//     razor.on(Razorpay.EVENT_EXTERNAL_WALLET, handlerPaymentExternal);
//     getAddOnData();
//   }

//   @override
//   void dispose() {
//     // TODO: implement dispose
//     super.dispose();
//     razor.clear();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       decoration: BoxDecoration(
//         image: DecorationImage(
//           image: AssetImage('images/cart.png'),
//           fit: BoxFit.fill,
//         ),
//       ),
//       child: Scaffold(
//         backgroundColor: Colors.transparent,
//         appBar: AppBar(
//           leading: Container(),
//           elevation: 0,
//           backgroundColor: Colors.white,
//           title: Text(
//             '🛒 Cart 🛒',
//             style: TextStyle(
//               fontSize: 30.0,
//               color: Color.fromRGBO(22, 102, 225, 1),
//               fontWeight: FontWeight.bold,
//             ),
//           ),
//           centerTitle: true,
//         ),
//         body: Column(
//           children: <Widget>[
//             Container(
//               child: Text(
//                 'Your Orders',
//                 style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
//               ),
//             ),
//             SizedBox(height: 10.0),
//             Container(
//               padding: EdgeInsets.only(
//                 left: 30.0,
//                 right: 30.0,
//                 bottom: 20.0,
//                 top: 10.0,
//               ),
//               child: Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                 children: <Widget>[Text('Product'), Text('Quantity')],
//               ),
//             ),
//             Container(
//               color: Colors.grey,
//               width: MediaQuery.of(context).size.width,
//               height: 350.0,
//               child: displayData(),
//             ),
//             SizedBox(height: 10.0),
//             Container(
//               padding: EdgeInsets.all(20.0),
//               child: Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                 children: <Widget>[Text('Total Cart Value'), Text('₹ $sum /-')],
//               ),
//             ),
//             SizedBox(
//               width: MediaQuery.of(context).size.width - 200.0,
//               child: MaterialButton(
//                 shape: RoundedRectangleBorder(
//                   borderRadius: BorderRadius.circular(22.0),
//                 ),
//                 color: Color.fromRGBO(22, 102, 225, 1),
//                 elevation: 10.0,
//                 child: Text('Buy Now', style: TextStyle(color: Colors.white)),
//                 onPressed: () {
//                   openCheckout();
//                 },
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../Constants.dart';


// Enhanced Cart page with modern UI
class Cart extends StatefulWidget {
  @override
  _CartState createState() => _CartState();
}

class _CartState extends State<Cart> {
  bool isLoading = false;

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
                    // Checkout button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed:
                            isLoading
                                ? null
                                : () {
                                  _proceedToCheckout();
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

  void _proceedToCheckout() {
    setState(() {
      isLoading = true;
    });

    // Simulate checkout process
    Future.delayed(Duration(seconds: 2), () {
      setState(() {
        isLoading = false;
      });

      // Show order confirmation
      showDialog(
        context: context,
        builder:
            (context) => AlertDialog(
              title: Text('Order Placed Successfully'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 60),
                  SizedBox(height: 16),
                  Text(
                    'Your order has been placed successfully!',
                    textAlign: TextAlign.center,
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
                    // Clear cart after successful order
                    _clearCart();
                    // Navigate back to home
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
    });
  }
}
