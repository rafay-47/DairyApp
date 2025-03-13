// import 'package:flutter/material.dart';
// import 'package:intl/intl.dart';

// class SubscriptionPage extends StatefulWidget {
//   const SubscriptionPage({Key? key}) : super(key: key);

//   @override
//   _SubscriptionPageState createState() => _SubscriptionPageState();
// }

// class _SubscriptionPageState extends State<SubscriptionPage> {
//   String? selectedPlan;
  
//   // Define color palette
//   static const Color primaryColor = Color(0xFFFAFAFA);
//   static const Color secondaryColor = Color.fromRGBO(22, 102, 225, 1);
//   static const Color backgroundColor = Color(0xFFFAFAFA);
//   static const Color accentColor = Color.fromRGBO(22, 102, 225, 1);

//   // Sample data for subscription plans
//   final List<Map<String, dynamic>> subscriptionPlans = [
//     {
//       'title': 'Weekly Plan',
//       'description': 'Fresh dairy products delivered weekly',
//       'price': 149.99,
//       'duration': 'week',
//       'benefits': ['Free delivery', '10% off on all products', 'Priority customer support'],
//       'image': 'images/weekly.png',
//       'value': 'weekly'
//     },
//     {
//       'title': 'Monthly Plan',
//       'description': 'Save more with monthly deliveries',
//       'price': 549.99,
//       'duration': 'month',
//       'benefits': ['Free delivery', '15% off on all products', 'Priority customer support', 'Exclusive monthly offers'],
//       'image': 'images/monthly.png',
//       'value': 'monthly'
//     },
//     {
//       'title': 'Yearly Plan',
//       'description': 'Best value for loyal customers',
//       'price': 5999.99,
//       'duration': 'year',
//       'benefits': ['Free delivery', '20% off on all products', 'Premium customer support', 'Exclusive yearly offers', 'Surprise gifts'],
//       'image': 'images/yearly.png',
//       'value': 'yearly'
//     },
//   ];

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: backgroundColor,
//       appBar: AppBar(
//         backgroundColor: primaryColor,
//         elevation: 0,
//         title: const Text(
//           'Subscription Plans',
//           style: TextStyle(
//             color: secondaryColor,
//             fontWeight: FontWeight.bold,
//           ),
//         ),
//         iconTheme: const IconThemeData(color: secondaryColor),
//       ),
//       body: SafeArea(
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Padding(
//               padding: const EdgeInsets.all(16.0),
//               child: Row(
//                 children: [
//                   Container(
//                     padding: const EdgeInsets.all(8),
//                     decoration: BoxDecoration(
//                       color: secondaryColor.withOpacity(0.1),
//                       borderRadius: BorderRadius.circular(8),
//                     ),
//                     child: const Icon(
//                       Icons.calendar_month,
//                       color: secondaryColor,
//                     ),
//                   ),
//                   const SizedBox(width: 12),
//                   Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       const Text(
//                         'Subscribe & Save',
//                         style: TextStyle(
//                           fontSize: 18,
//                           fontWeight: FontWeight.bold,
//                           color: Colors.black87,
//                         ),
//                       ),
//                       Text(
//                         'Choose a plan that works for you',
//                         style: TextStyle(
//                           fontSize: 14,
//                           color: Colors.black54,
//                         ),
//                       ),
//                     ],
//                   ),
//                 ],
//               ),
//             ),
//             Expanded(
//               child: ListView.builder(
//                 padding: const EdgeInsets.all(16),
//                 itemCount: subscriptionPlans.length,
//                 itemBuilder: (context, index) {
//                   final plan = subscriptionPlans[index];
//                   return SubscriptionCard(
//                     title: plan['title'],
//                     description: plan['description'],
//                     price: plan['price'],
//                     duration: plan['duration'],
//                     benefits: List<String>.from(plan['benefits']),
//                     image: plan['image'],
//                     isSelected: selectedPlan == plan['value'],
//                     onTap: () {
//                       setState(() {
//                         selectedPlan = plan['value'];
//                       });
//                       _showSubscriptionDetails(context, plan);
//                     },
//                   );
//                 },
//               ),
//             ),
//           ],
//         ),
//       ),
//       bottomNavigationBar: selectedPlan != null
//           ? Container(
//               padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
//               decoration: BoxDecoration(
//                 color: Colors.white,
//                 boxShadow: [
//                   BoxShadow(
//                     color: Colors.black12,
//                     blurRadius: 4,
//                     offset: Offset(0, -2),
//                   ),
//                 ],
//               ),
//               child: ElevatedButton(
//                 style: ElevatedButton.styleFrom(
//                   backgroundColor: secondaryColor,
//                   padding: const EdgeInsets.symmetric(vertical: 16),
//                   shape: RoundedRectangleBorder(
//                     borderRadius: BorderRadius.circular(12),
//                   ),
//                 ),
//                 onPressed: () {
//                   _confirmSubscription(context);
//                 },
//                 child: const Text(
//                   'Subscribe Now',
//                   style: TextStyle(
//                     fontSize: 16,
//                     fontWeight: FontWeight.bold,
//                   ),
//                 ),
//               ),
//             )
//           : null,
//     );
//   }

//   void _showSubscriptionDetails(BuildContext context, Map<String, dynamic> plan) {
//     showModalBottomSheet(
//       context: context,
//       backgroundColor: Colors.transparent,
//       isScrollControlled: true,
//       builder: (context) {
//         return Container(
//           decoration: const BoxDecoration(
//             color: Colors.white,
//             borderRadius: BorderRadius.only(
//               topLeft: Radius.circular(24),
//               topRight: Radius.circular(24),
//             ),
//           ),
//           padding: const EdgeInsets.all(20),
//           child: Column(
//             mainAxisSize: MainAxisSize.min,
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                 children: [
//                   Text(
//                     plan['title'],
//                     style: const TextStyle(
//                       fontSize: 22,
//                       fontWeight: FontWeight.bold,
//                     ),
//                   ),
//                   IconButton(
//                     onPressed: () => Navigator.pop(context),
//                     icon: const Icon(Icons.close),
//                   ),
//                 ],
//               ),
//               const SizedBox(height: 16),
//               Container(
//                 padding: const EdgeInsets.all(16),
//                 decoration: BoxDecoration(
//                   color: secondaryColor.withOpacity(0.05),
//                   borderRadius: BorderRadius.circular(12),
//                 ),
//                 child: Row(
//                   children: [
//                     Container(
//                       padding: const EdgeInsets.all(12),
//                       decoration: BoxDecoration(
//                         color: secondaryColor.withOpacity(0.1),
//                         borderRadius: BorderRadius.circular(12),
//                       ),
//                       child: Image.asset(
//                         plan['image'],
//                         height: 60,
//                         width: 60,
//                       ),
//                     ),
//                     const SizedBox(width: 16),
//                     Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         Text(
//                           '₹${plan['price'].toStringAsFixed(2)}',
//                           style: const TextStyle(
//                             fontSize: 24,
//                             fontWeight: FontWeight.bold,
//                             color: secondaryColor,
//                           ),
//                         ),
//                         Text(
//                           'per ${plan['duration']}',
//                           style: TextStyle(
//                             fontSize: 14,
//                             color: Colors.grey[600],
//                           ),
//                         ),
//                       ],
//                     ),
//                   ],
//                 ),
//               ),
//               const SizedBox(height: 24),
//               const Text(
//                 'What you get:',
//                 style: TextStyle(
//                   fontSize: 18,
//                   fontWeight: FontWeight.bold,
//                 ),
//               ),
//               const SizedBox(height: 12),
//               ...plan['benefits'].map<Widget>((benefit) {
//                 return Padding(
//                   padding: const EdgeInsets.only(bottom: 8),
//                   child: Row(
//                     children: [
//                       const Icon(
//                         Icons.check_circle,
//                         color: secondaryColor,
//                         size: 20,
//                       ),
//                       const SizedBox(width: 12),
//                       Text(
//                         benefit,
//                         style: const TextStyle(
//                           fontSize: 16,
//                         ),
//                       ),
//                     ],
//                   ),
//                 );
//               }).toList(),
//               const SizedBox(height: 24),
//               const Text(
//                 'Subscription Details:',
//                 style: TextStyle(
//                   fontSize: 16,
//                   fontWeight: FontWeight.bold,
//                 ),
//               ),
//               const SizedBox(height: 8),
//               Text(
//                 'Your subscription will automatically renew every ${plan['duration']}. You can cancel or pause your subscription anytime before 12 AM on the day before your next scheduled delivery.',
//                 style: TextStyle(
//                   fontSize: 14,
//                   color: Colors.grey[600],
//                 ),
//               ),
//               const SizedBox(height: 24),
//               SizedBox(
//                 width: double.infinity,
//                 child: ElevatedButton(
//                   style: ElevatedButton.styleFrom(
//                     primary: secondaryColor,
//                     padding: const EdgeInsets.symmetric(vertical: 16),
//                     shape: RoundedRectangleBorder(
//                       borderRadius: BorderRadius.circular(12),
//                     ),
//                   ),
//                   onPressed: () {
//                     Navigator.pop(context);
//                     _confirmSubscription(context);
//                   },
//                   child: const Text(
//                     'Subscribe Now',
//                     style: TextStyle(
//                       fontSize: 16,
//                       fontWeight: FontWeight.bold,
//                     ),
//                   ),
//                 ),
//               ),
//               const SizedBox(height: 16),
//             ],
//           ),
//         );
//       },
//     );
//   }

//   void _confirmSubscription(BuildContext context) {
//     final plan = subscriptionPlans.firstWhere((plan) => plan['value'] == selectedPlan);
    
//     showModalBottomSheet(
//       context: context,
//       backgroundColor: Colors.transparent,
//       isScrollControlled: true,
//       builder: (context) {
//         return StatefulBuilder(
//           builder: (context, setState) {
//             return Container(
//               decoration: const BoxDecoration(
//                 color: Colors.white,
//                 borderRadius: BorderRadius.only(
//                   topLeft: Radius.circular(24),
//                   topRight: Radius.circular(24),
//                 ),
//               ),
//               padding: const EdgeInsets.all(20),
//               child: Column(
//                 mainAxisSize: MainAxisSize.min,
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   const Text(
//                     'Confirm Subscription',
//                     style: TextStyle(
//                       fontSize: 22,
//                       fontWeight: FontWeight.bold,
//                     ),
//                   ),
//                   const SizedBox(height: 16),
//                   Container(
//                     padding: const EdgeInsets.all(16),
//                     decoration: BoxDecoration(
//                       color: secondaryColor.withOpacity(0.05),
//                       borderRadius: BorderRadius.circular(12),
//                     ),
//                     child: Column(
//                       children: [
//                         Row(
//                           mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                           children: [
//                             Text(
//                               plan['title'],
//                               style: const TextStyle(
//                                 fontSize: 18,
//                                 fontWeight: FontWeight.bold,
//                               ),
//                             ),
//                             Text(
//                               '₹${plan['price'].toStringAsFixed(2)}',
//                               style: const TextStyle(
//                                 fontSize: 18,
//                                 fontWeight: FontWeight.bold,
//                                 color: secondaryColor,
//                               ),
//                             ),
//                           ],
//                         ),
//                         const SizedBox(height: 4),
//                         Row(
//                           mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                           children: [
//                             Text(
//                               'Duration',
//                               style: TextStyle(
//                                 fontSize: 14,
//                                 color: Colors.grey[600],
//                               ),
//                             ),
//                             Text(
//                               'Per ${plan['duration']}',
//                               style: TextStyle(
//                                 fontSize: 14,
//                                 color: Colors.grey[600],
//                               ),
//                             ),
//                           ],
//                         ),
//                         const Divider(height: 24),
//                         Row(
//                           mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                           children: [
//                             const Text(
//                               'Start Date',
//                               style: TextStyle(
//                                 fontSize: 14,
//                                 fontWeight: FontWeight.bold,
//                               ),
//                             ),
//                             Text(
//                               DateFormat('MMM dd, yyyy').format(DateTime.now().add(const Duration(days: 1))),
//                               style: const TextStyle(
//                                 fontSize: 14,
//                               ),
//                             ),
//                           ],
//                         ),
//                         const SizedBox(height: 8),
//                         Row(
//                           mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                           children: [
//                             const Text(
//                               'First Delivery',
//                               style: TextStyle(
//                                 fontSize: 14,
//                                 fontWeight: FontWeight.bold,
//                               ),
//                             ),
//                             Text(
//                               DateFormat('MMM dd, yyyy').format(DateTime.now().add(const Duration(days: 1))),
//                               style: const TextStyle(
//                                 fontSize: 14,
//                               ),
//                             ),
//                           ],
//                         ),
//                       ],
//                     ),
//                   ),
//                   const SizedBox(height: 24),
//                   const Text(
//                     'Payment Method',
//                     style: TextStyle(
//                       fontSize: 18,
//                       fontWeight: FontWeight.bold,
//                     ),
//                   ),
//                   const SizedBox(height: 12),
//                   Container(
//                     padding: const EdgeInsets.all(16),
//                     decoration: BoxDecoration(
//                       border: Border.all(color: Colors.grey.shade300),
//                       borderRadius: BorderRadius.circular(12),
//                     ),
//                     child: Row(
//                       children: [
//                         Container(
//                           padding: const EdgeInsets.all(8),
//                           decoration: BoxDecoration(
//                             color: secondaryColor.withOpacity(0.1),
//                             borderRadius: BorderRadius.circular(8),
//                           ),
//                           child: const Icon(
//                             Icons.account_balance_wallet,
//                             color: secondaryColor,
//                           ),
//                         ),
//                         const SizedBox(width: 12),
//                         Column(
//                           crossAxisAlignment: CrossAxisAlignment.start,
//                           children: [
//                             const Text(
//                               'Wallet Balance',
//                               style: TextStyle(
//                                 fontSize: 16,
//                                 fontWeight: FontWeight.bold,
//                               ),
//                             ),
//                             Text(
//                               '₹1000.00',
//                               style: TextStyle(
//                                 fontSize: 14,
//                                 color: Colors.grey[600],
//                               ),
//                             ),
//                           ],
//                         ),
//                         const Spacer(),
//                         Radio(
//                           value: 'wallet',
//                           groupValue: 'wallet',
//                           activeColor: secondaryColor,
//                           onChanged: (value) {},
//                         ),
//                       ],
//                     ),
//                   ),
//                   const SizedBox(height: 8),
//                   Container(
//                     padding: const EdgeInsets.all(16),
//                     decoration: BoxDecoration(
//                       border: Border.all(color: Colors.grey.shade300),
//                       borderRadius: BorderRadius.circular(12),
//                     ),
//                     child: Row(
//                       children: [
//                         Container(
//                           padding: const EdgeInsets.all(8),
//                           decoration: BoxDecoration(
//                             color: Colors.orange.withOpacity(0.1),
//                             borderRadius: BorderRadius.circular(8),
//                           ),
//                           child: const Icon(
//                             Icons.add_card,
//                             color: Colors.orange,
//                           ),
//                         ),
//                         const SizedBox(width: 12),
//                         const Text(
//                           'Add Payment Method',
//                           style: TextStyle(
//                             fontSize: 16,
//                             fontWeight: FontWeight.bold,
//                           ),
//                         ),
//                         const Spacer(),
//                         const Icon(
//                           Icons.arrow_forward_ios,
//                           size: 16,
//                           color: Colors.grey,
//                         ),
//                       ],
//                     ),
//                   ),
//                   const SizedBox(height: 24),
//                   SizedBox(
//                     width: double.infinity,
//                     child: ElevatedButton(
//                       style: ElevatedButton.styleFrom(
//                         primary: secondaryColor,
//                         padding: const EdgeInsets.symmetric(vertical: 16),
//                         shape: RoundedRectangleBorder(
//                           borderRadius: BorderRadius.circular(12),
//                         ),
//                       ),
//                       onPressed: () {
//                         Navigator.pop(context);
//                         _showSuccessDialog(context);
//                       },
//                       child: const Text(
//                         'Confirm Subscription',
//                         style: TextStyle(
//                           fontSize: 16,
//                           fontWeight: FontWeight.bold,
//                         ),
//                       ),
//                     ),
//                   ),
//                   const SizedBox(height: 12),
//                   SizedBox(
//                     width: double.infinity,
//                     child: TextButton(
//                       onPressed: () {
//                         Navigator.pop(context);
//                       },
//                       child: const Text(
//                         'Cancel',
//                         style: TextStyle(
//                           fontSize: 16,
//                           color: Colors.grey,
//                         ),
//                       ),
//                     ),
//                   ),
//                 ],
//               ),
//             );
//           },
//         );
//       },
//     );
//   }

//   void _showSuccessDialog(BuildContext context) {
//     showDialog(
//       context: context,
//       builder: (BuildContext context) {
//         return Dialog(
//           shape: RoundedRectangleBorder(
//             borderRadius: BorderRadius.circular(20),
//           ),
//           child: Padding(
//             padding: const EdgeInsets.all(24.0),
//             child: Column(
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 Container(
//                   padding: const EdgeInsets.all(16),
//                   decoration: BoxDecoration(
//                     color: Colors.green.shade50,
//                     shape: BoxShape.circle,
//                   ),
//                   child: Icon(
//                     Icons.check_circle,
//                     color: Colors.green.shade600,
//                     size: 60,
//                   ),
//                 ),
//                 const SizedBox(height: 24),
//                 const Text(
//                   'Subscription Successful!',
//                   style: TextStyle(
//                     fontSize: 20,
//                     fontWeight: FontWeight.bold,
//                   ),
//                 ),
//                 const SizedBox(height: 16),
//                 Text(
//                   'Your subscription has been activated successfully. You will receive your first delivery tomorrow.',
//                   textAlign: TextAlign.center,
//                   style: TextStyle(
//                     fontSize: 14,
//                     color: Colors.grey[600],
//                   ),
//                 ),
//                 const SizedBox(height: 24),
//                 SizedBox(
//                   width: double.infinity,
//                   child: ElevatedButton(
//                     style: ElevatedButton.styleFrom(
//                       primary: secondaryColor,
//                       padding: const EdgeInsets.symmetric(vertical: 16),
//                       shape: RoundedRectangleBorder(
//                         borderRadius: BorderRadius.circular(12),
//                       ),
//                     ),
//                     onPressed: () {
//                       Navigator.pop(context);
//                       Navigator.pushReplacement(
//                         context,
//                         MaterialPageRoute(
//                           builder: (context) => const SubscriptionManagementPage(),
//                         ),
//                       );
//                     },
//                     child: const Text(
//                       'View My Subscriptions',
//                       style: TextStyle(
//                         fontSize: 16,
//                         fontWeight: FontWeight.bold,
//                       ),
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         );
//       },
//     );
//   }
// }

// class SubscriptionCard extends StatelessWidget {
//   final String title;
//   final String description;
//   final double price;
//   final String duration;
//   final List<String> benefits;
//   final String image;
//   final bool isSelected;
//   final VoidCallback onTap;

//   const SubscriptionCard({
//     Key? key,
//     required this.title,
//     required this.description,
//     required this.price,
//     required this.duration,
//     required this.benefits,
//     required this.image,
//     required this.isSelected,
//     required this.onTap,
//   }) : super(key: key);

//   @override
//   Widget build(BuildContext context) {
//     return GestureDetector(
//       onTap: onTap,
//       child: Container(
//         margin: const EdgeInsets.only(bottom: 16),
//         decoration: BoxDecoration(
//           color: Colors.white,
//           borderRadius: BorderRadius.circular(16),
//           border: Border.all(
//             color: isSelected ? Color.fromRGBO(22, 102, 225, 1) : Colors.transparent,
//             width: 2,
//           ),
//           boxShadow: [
//             BoxShadow(
//               color: Colors.black.withOpacity(0.05),
//               spreadRadius: 0,
//               blurRadius: 10,
//               offset: const Offset(0, 4),
//             ),
//           ],
//         ),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             // Image section
//             ClipRRect(
//               borderRadius: const BorderRadius.only(
//                 topLeft: Radius.circular(14),
//                 topRight: Radius.circular(14),
//               ),
//               child: Image.asset(
//                 image,
//                 height: 120,
//                 width: double.infinity,
//                 fit: BoxFit.cover,
//               ),
//             ),
//             // Content section
//             Padding(
//               padding: const EdgeInsets.all(16),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Row(
//                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                     children: [
//                       Text(
//                         title,
//                         style: const TextStyle(
//                           fontSize: 18,
//                           fontWeight: FontWeight.bold,
//                         ),
//                       ),
//                       Container(
//                         padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
//                         decoration: BoxDecoration(
//                           color: isSelected
//                               ? Color.fromRGBO(22, 102, 225, 1)
//                               : Color.fromRGBO(22, 102, 225, 0.1),
//                           borderRadius: BorderRadius.circular(20),
//                         ),
//                         child: Text(
//                           isSelected ? 'Selected' : 'Select',
//                           style: TextStyle(
//                             fontSize: 12,
//                             fontWeight: FontWeight.bold,
//                             color: isSelected ? Colors.white : Color.fromRGBO(22, 102, 225, 1),
//                           ),
//                         ),
//                       ),
//                     ],
//                   ),
//                   const SizedBox(height: 8),
//                   Text(
//                     description,
//                     style: TextStyle(
//                       fontSize: 14,
//                       color: Colors.grey[600],
//                     ),
//                   ),
//                   const SizedBox(height: 12),
//                   Row(
//                     children: [
//                       Text(
//                         '₹${price.toStringAsFixed(2)}',
//                         style: const TextStyle(
//                           fontSize: 20,
//                           fontWeight: FontWeight.bold,
//                           color: Color.fromRGBO(22, 102, 225, 1),
//                         ),
//                       ),
//                       Text(
//                         ' / $duration',
//                         style: TextStyle(
//                           fontSize: 14,
//                           color: Colors.grey[600],
//                         ),
//                       ),
//                     ],
//                   ),
//                   const SizedBox(height: 16),
//                   const Text(
//                     'Benefits:',
//                     style: TextStyle(
//                       fontSize: 16,
//                       fontWeight: FontWeight.bold,
//                     ),
//                   ),
//                   const SizedBox(height: 8),
//                   Column(
//                     children: benefits
//                         .take(2)
//                         .map(
//                           (benefit) => Padding(
//                             padding: const EdgeInsets.only(bottom: 6),
//                             child: Row(
//                               children: [
//                                 const Icon(
//                                   Icons.check_circle,
//                                   color: Color.fromRGBO(22, 102, 225, 1),
//                                   size: 16,
//                                 ),
//                                 const SizedBox(width: 8),
//                                 Expanded(
//                                   child: Text(
//                                     benefit,
//                                     style: const TextStyle(
//                                       fontSize: 14,
//                                     ),
//                                   ),
//                                 ),
//                               ],
//                             ),
//                           ),
//                         )
//                         .toList(),
//                   ),
//                   if (benefits.length > 2)
//                     Text(
//                       '+ ${benefits.length - 2} more benefits',
//                       style: TextStyle(
//                         fontSize: 14,
//                         color: Color.fromRGBO(22, 102, 225, 1),
//                         fontWeight: FontWeight.w500,
//                       ),
//                     ),
//                 ],
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

// class SubscriptionManagementPage extends StatefulWidget {
//   const SubscriptionManagementPage({Key? key}) : super(key: key);

//   @override
//   _SubscriptionManagementPageState createState() => _SubscriptionManagementPageState();
// }

// class _SubscriptionManagementPageState extends State<SubscriptionManagementPage> {
//   // Color palette
//   static const Color primaryColor = Color(0xFFFAFAFA);
//   static const Color secondaryColor = Color.fromRGBO(22, 102, 225, 1);
//   static const Color backgroundColor = Color(0xFFFAFAFA);
//   static const Color accentColor = Color.fromRGBO(22, 102, 225, 1);

//   // Sample active subscription
//   final Map<String, dynamic> activeSubscription = {
//     'title': 'Weekly Plan',
//     'nextDelivery': '2025-03-14',
//     'items': ['Milk (1L)', 'Yogurt (500g)', 'Butter (200g)'],
//     'price': 149.99,
//     'status': 'Active',
//     'image': 'images/weekly.png',
//     'canCancel': true,
//   };

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: backgroundColor,
//       appBar: AppBar(
//         backgroundColor: primaryColor,
//         elevation: 0,
//         title: const Text(
//           'My Subscriptions',
//           style: TextStyle(
//             color: secondaryColor,
//             fontWeight: FontWeight.bold,
//           ),
//         ),
//         iconTheme: const IconThemeData(color: secondaryColor),
//       ),
//       body: SingleChildScrollView(
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Padding(
//               padding: const EdgeInsets.all(16.0),
//               child: Row(
//                 children: [
//                   Container(
//                     padding: const EdgeInsets.all(8),
//                     decoration: BoxDecoration(
//                       color: secondaryColor.withOpacity(0.1),
//                       borderRadius: BorderRadius.circular(8),
//                     ),
//                     child: const Icon(
//                       Icons.calendar_today,
//                       color: secondaryColor,
//                     ),
//                   ),
//                   const SizedBox(width: 12),
//                   Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       const Text(
//                         'Active Subscription',
//                         style: TextStyle(
//                           fontSize: 18,
//                           fontWeight: FontWeight.bold,
//                           color: Colors.black87,
//                         ),
//                       ),
//                       Text(
//                         'Manage your current subscriptions',
//                         style: TextStyle(
//                           fontSize: 14,
//                           color: Colors.black54,
//                         ),
//                       ),
//                     ],
//                   ),
//                 ],
//               ),
//             ),
//             Padding(
//               padding: const EdgeInsets.all(16.0),
//               child: Card(
//                 shape: RoundedRectangleBorder(
//                   borderRadius: BorderRadius.circular(16),
//                 ),
//                 elevation: 4,
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Container(
//                       padding: const EdgeInsets.all(16),
//                       decoration: BoxDecoration(
//                         color: secondaryColor,
//                         borderRadius: const BorderRadius.only(
//                           topLeft: Radius.circular(16),
//                           topRight: Radius.circular(16),
//                         ),
//                       ),
//                       child: Row(
//                         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                         children: [
//                           const Text(
//                             'Weekly Plan',
//                             style: TextStyle(
//                               fontSize: 18,
//                               fontWeight: FontWeight.bold,
//                               color: Colors.white,
//                             ),
//                           ),
//                           Container(
//                             padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
//                             decoration: BoxDecoration(
//                               color: Colors.white,
//                               borderRadius: BorderRadius.circular(12),
//                             ),
//                             child: const Text(
//                               'Active',
//                               style: TextStyle(
//                                 fontSize: 12,
//                                 fontWeight: FontWeight.bold,
//                                 color: secondaryColor,
//                               ),
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),
//                     Padding(
//                       padding: const EdgeInsets.all(16),
//                       child: Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           Row(
//                             children: [
//                               const Icon(
//                                 Icons.timer,
//                                 size: 18,
//                                 color: Colors.grey,
//                               ),
//                               const SizedBox(width: 8),
//                               const Text(
//                                 'Next Delivery Date',
//                                 style: TextStyle(
//                                   fontSize: 14,
//                                   color: Colors.grey[600],
//                                 ),
//                               ),
//                               const Spacer(),
//                               Text(
//                                 '25th Dec, 2023',
//                                 style: const TextStyle(
//                                   fontSize: 14,
//                                 ),
//                               ),
//                             ],
//                           ),
//                           const SizedBox(height: 8),
//                           Row(
//                             children: [
//                               const Icon(
//                                 Icons.location_on,
//                                 size: 18,
//                                 color: Colors.grey,
//                               ),
//                               const SizedBox(width: 8),
//                               const Text(
//                                 'Delivery Address',
//                                 style: TextStyle(
//                                   fontSize: 14,
//                                   color: Colors.grey[600],
//                                 ),
//                               ),
//                               const Spacer(),
//                               Text(
//                                 '123 Main St, City, Country',
//                                 style: const TextStyle(
//                                   fontSize: 14,
//                                 ),
//                               ),
//                             ],
//                           ),
//                           const SizedBox(height: 8),
//                           Row(
//                             children: [
//                               const Icon(
//                                 Icons.payment,
//                                 size: 18,
//                                 color: Colors.grey,
//                               ),
//                               const SizedBox(width: 8),
//                               const Text(
//                                 'Payment Method',
//                                 style: TextStyle(
//                                   fontSize: 14,
//                                   color: Colors.grey[600],
//                                 ),
//                               ),
//                               const Spacer(),
//                               Text(
//                                 'Credit Card',
//                                 style: const TextStyle(
//                                   fontSize: 14,
//                                 ),
//                               ),
//                             ],
//                           ),
//                         ],
//                       ),
//                     ),
//                     const SizedBox(height: 24),
//                     const Text(
//                       'Order Summary',
//                       style: TextStyle(
//                         fontSize: 18,
//                         fontWeight: FontWeight.bold,
//                       ),
//                     ),
//                     const SizedBox(height: 12),
//                     Container(
//                       padding: const EdgeInsets.all(16),
//                       decoration: BoxDecoration(
//                         border: Border.all(color: Colors.grey.shade300),
//                         borderRadius: BorderRadius.circular(12),
//                       ),
//                       child: Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           Row(
//                             mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                             children: [
//                               const Text(
//                                 'Subtotal',
//                                 style: TextStyle(
//                                   fontSize: 16,
//                                   fontWeight: FontWeight.bold,
//                                 ),
//                               ),
//                               Text(
//                                 '₹900.00',
//                                 style: TextStyle(
//                                   fontSize: 16,
//                                   color: Colors.grey[600],
//                                 ),
//                               ),
//                             ],
//                           ),
//                           const SizedBox(height: 8),
//                           Row(
//                             mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                             children: [
//                               const Text(
//                                 'Tax',
//                                 style: TextStyle(
//                                   fontSize: 16,
//                                   fontWeight: FontWeight.bold,
//                                 ),
//                               ),
//                               Text(
//                                 '₹100.00',
//                                 style: TextStyle(
//                                   fontSize: 16,
//                                   color: Colors.grey[600],
//                                 ),
//                               ),
//                             ],
//                           ),
//                           const SizedBox(height: 8),
//                           Row(
//                             mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                             children: [
//                               const Text(
//                                 'Total',
//                                 style: TextStyle(
//                                   fontSize: 16,
//                                   fontWeight: FontWeight.bold,
//                                 ),
//                               ),
//                               Text(
//                                 '₹1000.00',
//                                 style: TextStyle(
//                                   fontSize: 16,
//                                   color: Colors.grey[600],
//                                 ),
//                               ),
//                             ],
//                           ),
//                         ],
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
