import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:toast/toast.dart';

late Map<dynamic, dynamic> cartProduct;
late List<dynamic> cartNameList;
late List<dynamic> cartQuantityList;
late DocumentSnapshot snapshotprice;
late DocumentSnapshot snapuser;
int sum = 0;

class Cart extends StatefulWidget {
  const Cart({super.key});

  @override
  _CartState createState() => _CartState();
}

class _CartState extends State<Cart> {

  late Razorpay razor;

  Future<void> getAddOnData() async {
    final User user = FirebaseAuth.instance.currentUser!;
    final String uid = user.uid.toString();
    DocumentSnapshot snapshot =
        await FirebaseFirestore.instance.collection('cart').doc(uid).get();
    snapshotprice =
        await FirebaseFirestore.instance.collection('price').doc('1').get();
    snapuser = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    setState(() {
      cartProduct = (snapshot.data() as Map<String, dynamic>)['product'];
      cartNameList = cartProduct.keys.toList();
      cartQuantityList = cartProduct.values.toList();
      sum = (snapuser.data() as Map<String, dynamic>)['CartValue'];
    });
  }

  void updatecartvalue(var index) {
    String str = cartNameList[index];
    String str2 = cartQuantityList[index];
    int p = int.parse((snapshotprice.data as Map<String, dynamic>)[str]);
    int q = int.parse(str2);
    setState(() {
      sum = sum - (p * q);
    });
  }

  Widget displayData() {
    return ListView.builder(
        itemCount: cartProduct.length,
        itemBuilder: (context, index) {
          return Dismissible(
            background: Container(
              color: Color.fromRGBO(22, 102, 225, 1),
            ),
            key: UniqueKey(),
            child: Card(
              elevation: 10.0,
              child: ListTile(
                title: Text('${cartNameList[index]}'),
                trailing: Text('${cartQuantityList[index]}'),
              ),
            ),
            onDismissed: (direction) {
              Toast.show(
                  "${cartNameList[index]} removed form cart ",
                  duration: Toast.lengthShort,
                  gravity: Toast.bottom,
                  backgroundColor: Colors.black,
                  webTexColor: Colors.white);
              setState(() {
                updatecartvalue(index);
                updateCart(index);
              });
            },
          );
        });
  }

  Future<void> updateCart(var index) async {
    final User user = FirebaseAuth.instance.currentUser!;
    final String uid = user.uid.toString();
    setState(() {
      cartProduct.remove('${cartNameList[index]}');
      cartNameList.removeAt(index);
      cartQuantityList.removeAt(index);
      FirebaseFirestore.instance
          .collection('cart')
          .doc(uid)
          .update({'product': cartProduct});
      FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .update({'product': cartProduct});
      FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .update({'CartValue': sum});
    });
  }

  void openCheckout()
  {
    var options={
      'key':'rzp_test_0sjqCKCoIjJr2F',
      'amount':sum*100,
      'name':'Daily Dairy',
      'external':{
        'wallets':['paytm']
      }
    };

    try{
      razor.open(options);
    }
    catch(e){
      debugPrint(e as String?);
    }
  }

  void handlerPaymentSuccess(PaymentSuccessResponse response)
  {
    Toast.show('Success${response.paymentId}');
  }

  void handlerPaymentError(PaymentFailureResponse response)
  {
    Toast.show('Error${response.code} . ${response.message}');
  }

  void handlerPaymentExternal(ExternalWalletResponse response)
  {
    Toast.show('External Wallet${response.walletName}');
  }
  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    razor=Razorpay();
    razor.on(Razorpay.EVENT_PAYMENT_SUCCESS, handlerPaymentSuccess);
    razor.on(Razorpay.EVENT_PAYMENT_ERROR, handlerPaymentError);
    razor.on(Razorpay.EVENT_EXTERNAL_WALLET, handlerPaymentExternal);
    getAddOnData();
  }

  @override
  void dispose() {
    // TODO: implement dispose
    super.dispose();
    razor.clear();
  }
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        image: DecorationImage(
          image: AssetImage(
            'images/cart.png'
          ),
          fit: BoxFit.fill
        )
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          leading: Container(),
          elevation: 0,
          backgroundColor: Colors.white,
          title: Text(
            '🛒 Cart 🛒',
            style: TextStyle(
                fontSize: 30.0,
                color: Color.fromRGBO(22, 102, 225, 1),
                fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
        ),
        body: Column(
          children: <Widget>[
            Container(
              child: Text(
                'Your Orders',
                style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
              ),
            ),
            SizedBox(
              height: 10.0,
            ),
            Container(
              padding: EdgeInsets.only(
                  left: 30.0, right: 30.0, bottom: 20.0, top: 10.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[Text('Product'), Text('Quantity')],
              ),
            ),
            Container(
              color: Colors.grey,
              width: MediaQuery.of(context).size.width,
              height: 350.0,
              child: displayData(),
            ),
            SizedBox(
              height: 10.0,
            ),
            Container(
              padding: EdgeInsets.all(20.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[Text('Total Cart Value'), Text('₹ $sum /-')],
              ),
            ),
            SizedBox(
              width: MediaQuery.of(context).size.width-200.0,
              child: MaterialButton(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22.0),
                ),
                color: Color.fromRGBO(22, 102, 225, 1),
                elevation: 10.0,
                child: Text(
                  'Buy Now',
                  style: TextStyle(
                      color: Colors.white
                  ),
                ),
                onPressed: (){
                  openCheckout();
                },
              ),
            )
          ],
        ),
      ),
    );
  }
}
