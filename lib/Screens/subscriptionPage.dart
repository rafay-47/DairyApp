import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:dairyapp/Screens/cart.dart';

class SubscriptionDialog extends StatefulWidget {
  final String productId;
  final String productName;
  final String productDescription;
  final double productPrice;

  const SubscriptionDialog({
    Key? key,
    required this.productId,
    required this.productName,
    required this.productDescription,
    required this.productPrice,
  }) : super(key: key);

  @override
  _SubscriptionDialogState createState() => _SubscriptionDialogState();
}

class _SubscriptionDialogState extends State<SubscriptionDialog> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  bool _isLoading = false;

  // Add subscription to cart instead of directly subscribing
  Future<void> _addSubscriptionToCart(String planName, int duration) async {
    if (_currentUser == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Please login to subscribe')));
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Calculate the subscription price
      final subscriptionPrice = widget.productPrice * duration;

      // Create a subscription cart item
      final subscriptionItem = {
        'productId': widget.productId,
        'name': '${widget.productName} subscription for  $duration days',
        'description': widget.productDescription,
        'price': subscriptionPrice,
        'quantity': 1,
        'type': 'subscription', // Mark as subscription type
        'planName': planName,
        'duration': duration,
        'addedAt': FieldValue.serverTimestamp(),
      };

      // Generate a unique ID for the cart item
      final String cartItemId =
          'sub_${widget.productId}_${DateTime.now().millisecondsSinceEpoch}';

      // Add to cart collection
      await _firestore.collection('cart').doc(cartItemId).set(subscriptionItem);

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$planName subscription added to cart'),
          action: SnackBarAction(
            label: 'VIEW CART',
            onPressed: () {
              Navigator.of(context).pop(); // Close subscription dialog
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (context) => Cart()));
            },
          ),
        ),
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add subscription to cart: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 16,
      child: Container(
        padding: const EdgeInsets.all(20),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
          maxWidth: 400,
        ),
        child:
            _isLoading
                ? Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header with product name and description
                      Text(
                        widget.productName,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 10),
                      Text(widget.productDescription),
                      SizedBox(height: 20),
                      // Subscription plans
                      Text(
                        'Choose your subscription plan:',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      SizedBox(height: 10),
                      Row(
                        children: [
                          _buildPlanCard(
                            'Weekly',
                            7,
                            'Every 7 days',
                            widget.productPrice,
                          ),
                          SizedBox(width: 10),
                          _buildPlanCard(
                            'Monthly',
                            30,
                            'Every 30 days',
                            widget.productPrice,
                          ),
                        ],
                      ),
                      SizedBox(height: 20),
                      // Display active subscriptions
                      Text(
                        'Your Subscriptions:',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      SizedBox(height: 10),
                      Container(
                        height: 200,
                        child: StreamBuilder<QuerySnapshot>(
                          stream:
                              _firestore
                                  .collection('users')
                                  .doc(_currentUser!.uid)
                                  .collection('product_subscriptions')
                                  .where(
                                    'productId',
                                    isEqualTo: widget.productId,
                                  )
                                  .snapshots(),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) {
                              return Center(child: CircularProgressIndicator());
                            }
                            final subscriptions = snapshot.data!.docs;
                            if (subscriptions.isEmpty) {
                              return Center(
                                child: Text('No subscriptions found.'),
                              );
                            }
                            return ListView.builder(
                              itemCount: subscriptions.length,
                              itemBuilder: (context, index) {
                                final subscription = subscriptions[index];
                                return Card(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  elevation: 2,
                                  margin: EdgeInsets.symmetric(vertical: 5),
                                  child: ListTile(
                                    title: Text(subscription['planName']),
                                    subtitle: Text(
                                      'Ends on: ${subscription['endDate'].toDate().toLocal().toString().split(' ')[0]}',
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                      SizedBox(height: 10),
                      // Close button
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                          child: Text('Close'),
                        ),
                      ),
                    ],
                  ),
                ),
      ),
    );
  }

  // Builds a modern-looking card for each subscription plan
  Widget _buildPlanCard(
    String planName,
    int duration,
    String subtitle,
    double price,
  ) {
    return Expanded(
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 4,
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                planName,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 5),
              Text(
                subtitle,
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
              SizedBox(height: 10),
              ElevatedButton(
                // Update the onPressed to add to cart instead of direct subscription
                onPressed: () => _addSubscriptionToCart(planName, duration),
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text('₹${price * duration}'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
