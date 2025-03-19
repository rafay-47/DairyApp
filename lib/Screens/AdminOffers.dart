import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'dart:math';

class AdminOffers extends StatefulWidget {
  const AdminOffers({Key? key}) : super(key: key);

  @override
  _AdminOffersState createState() => _AdminOffersState();
}

class _AdminOffersState extends State<AdminOffers>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Form controllers
  final TextEditingController _couponCodeController = TextEditingController();
  final TextEditingController _discountPercentController =
      TextEditingController();
  final TextEditingController _minPurchaseController = TextEditingController();
  final TextEditingController _maxDiscountController = TextEditingController();
  final TextEditingController _validityDaysController = TextEditingController();
  final TextEditingController _usageLimitController = TextEditingController();
  final TextEditingController _maxUsesPerUserController =
      TextEditingController();

  // Form keys
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  // Date controllers
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 30));

  // Selected values
  String _selectedCouponType = 'Percentage'; // Only 'Percentage' and 'Fixed'
  List<String> _selectedProducts = [];
  List<String> _selectedCategories = [];
  bool _isLoading = false;
  bool _applyToAll = false;
  bool _isLimitedTimeOffer = false;
  bool _isFirstPurchaseOnly = false;
  bool _isNewUserOnly = false;
  bool _isFreeDelivery = false; // Toggle for free delivery

  // Products list
  List<Map<String, dynamic>> _products = [];

  // Categories list
  Set<String> _categories = {};

  // Coupon list
  List<Map<String, dynamic>> _coupons = [];

  // Firestore instance
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchProducts();
    _fetchCoupons();

    // Set default values
    _validityDaysController.text = '30';
    _usageLimitController.text = '100';
    _maxUsesPerUserController.text = '1';
  }

  @override
  void dispose() {
    _tabController.dispose();
    _couponCodeController.dispose();
    _discountPercentController.dispose();
    _minPurchaseController.dispose();
    _maxDiscountController.dispose();
    _validityDaysController.dispose();
    _usageLimitController.dispose();
    _maxUsesPerUserController.dispose();
    super.dispose();
  }

  // Fetch products from Firestore
  Future<void> _fetchProducts() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final QuerySnapshot productSnapshot =
          await _firestore.collection('products').get();

      final List<Map<String, dynamic>> products =
          productSnapshot.docs.map((doc) {
            return {
              'id': doc.id,
              'name': (doc.data() as Map<String, dynamic>)['name'] ?? 'Unknown',
              'price': (doc.data() as Map<String, dynamic>)['price'] ?? 0,
              'imageUrl':
                  (doc.data() as Map<String, dynamic>)['imageUrl'] ?? '',
              'category':
                  (doc.data() as Map<String, dynamic>)['category'] ?? '',
              'stock': (doc.data() as Map<String, dynamic>)['stock'] ?? 0,
              'description':
                  (doc.data() as Map<String, dynamic>)['description'] ?? '',
            };
          }).toList();

      final Set<String> categories =
          products
              .map((product) => product['category'].toString())
              .where((category) => category.isNotEmpty && category != 'Unknown')
              .toSet();

      setState(() {
        _products = products;
        _categories = categories;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorDialog('Error fetching products: $e');
    }
  }

  // Fetch existing coupons
  Future<void> _fetchCoupons() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final QuerySnapshot couponSnapshot =
          await _firestore
              .collection('coupons')
              .orderBy('createdAt', descending: true)
              .get();

      setState(() {
        _coupons =
            couponSnapshot.docs.map((doc) {
              return {'id': doc.id, ...doc.data() as Map<String, dynamic>};
            }).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorDialog('Error fetching coupons: $e');
    }
  }

  // Generate random coupon code
  String _generateCouponCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890';
    final random = Random();
    return List.generate(
      8,
      (index) => chars[random.nextInt(chars.length)],
    ).join();
  }

  // Show date picker
  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStartDate ? _startDate : _endDate,
      firstDate: isStartDate ? DateTime.now() : _startDate,
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
          // Ensure end date is after start date
          if (_endDate.isBefore(_startDate)) {
            _endDate = _startDate.add(const Duration(days: 1));
          }
        } else {
          _endDate = picked;
        }
      });
    }
  }

  // Update end date when validity days change
  void _updateEndDate() {
    final int days = int.tryParse(_validityDaysController.text) ?? 30;
    setState(() {
      _endDate = _startDate.add(Duration(days: days));
    });
  }

  // Validate discount percentage or amount
  String? _validateDiscountValue(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter a discount value';
    }

    final double? discount = double.tryParse(value);
    if (discount == null) {
      return 'Please enter a valid number';
    }

    if (_selectedCouponType == 'Percentage') {
      if (discount <= 0 || discount > 100) {
        return 'Percentage must be between 0 and 100';
      }
    } else {
      if (discount <= 0) {
        return 'Discount amount must be greater than 0';
      }
    }

    return null;
  }

  // Validate min purchase
  String? _validateMinPurchase(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter minimum purchase';
    }

    final double? minPurchase = double.tryParse(value);
    if (minPurchase == null) {
      return 'Please enter a valid number';
    }

    if (minPurchase < 0) {
      return 'Minimum purchase cannot be negative';
    }

    return null;
  }

  // Validate max discount
  String? _validateMaxDiscount(String? value) {
    if (value == null || value.isEmpty) {
      return null; // Optional field
    }

    final double? maxDiscount = double.tryParse(value);
    if (maxDiscount == null) {
      return 'Please enter a valid number';
    }

    if (maxDiscount <= 0) {
      return 'Maximum discount must be greater than 0';
    }

    // if (_selectedCouponType == 'Percentage' &&
    //     _discountPercentController.text.isNotEmpty) {
    //   final double? discountPercent = double.tryParse(
    //     _discountPercentController.text,
    //   );
    //   if (discountPercent != null && _minPurchaseController.text.isNotEmpty) {
    //     final double? minPurchase = double.tryParse(
    //       _minPurchaseController.text,
    //     );
    //     if (minPurchase != null) {
    //       final double calculatedMaxDiscount =
    //           minPurchase * discountPercent / 100;
    //       if (maxDiscount > calculatedMaxDiscount) {
    //         return 'Max discount exceeds the calculated maximum (${calculatedMaxDiscount.toStringAsFixed(2)})';
    //       }
    //     }
    //   }
    // }

    return null;
  }

  // Validate validity days
  String? _validateValidityDays(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter validity days';
    }

    final int? days = int.tryParse(value);
    if (days == null) {
      return 'Please enter a valid number';
    }

    if (days <= 0 || days > 365) {
      return 'Validity must be between 1 and 365 days';
    }

    return null;
  }

  // Validate usage limit
  String? _validateUsageLimit(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter usage limit';
    }

    final int? usageLimit = int.tryParse(value);
    if (usageLimit == null) {
      return 'Please enter a valid number';
    }

    if (usageLimit <= 0) {
      return 'Usage limit must be greater than 0';
    }

    return null;
  }

  // Validate max uses per user
  String? _validateMaxUsesPerUser(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter max uses per user';
    }

    final int? maxUses = int.tryParse(value);
    if (maxUses == null) {
      return 'Please enter a valid number';
    }

    if (maxUses <= 0) {
      return 'Max uses must be greater than 0';
    }

    return null;
  }

  // Save coupon to Firestore
  Future<void> _saveCoupon() async {
    // Validate form
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Additional validation for product selection
    if (!_applyToAll &&
        _selectedProducts.isEmpty &&
        _selectedCategories.isEmpty) {
      _showErrorDialog(
        'Please select at least one product/category or apply to all',
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Prepare data
      final Map<String, dynamic> couponData = {
        'code': _couponCodeController.text.toUpperCase(),
        'startDate': Timestamp.fromDate(_startDate),
        'endDate': Timestamp.fromDate(_endDate),
        'createdAt': Timestamp.now(),
        'active': true,
        'applyToAll': _applyToAll,
        'usageLimit': int.parse(_usageLimitController.text),
        'maxUsesPerUser': int.parse(_maxUsesPerUserController.text),
        'usedCount': 0,
        'isFirstPurchaseOnly': _isFirstPurchaseOnly,
        'isNewUserOnly': _isNewUserOnly,
        'isLimitedTimeOffer': _isLimitedTimeOffer,
      };

      // Set coupon type based on free delivery toggle
      couponData['type'] =
          _isFreeDelivery ? 'Free Delivery' : _selectedCouponType;
      couponData['discount'] = double.parse(_discountPercentController.text);

      if (_minPurchaseController.text.isNotEmpty) {
        couponData['minPurchase'] = double.parse(_minPurchaseController.text);
      }

      if (!_applyToAll) {
        if (_selectedProducts.isNotEmpty) {
          couponData['productIds'] = _selectedProducts;
        }

        if (_selectedCategories.isNotEmpty) {
          couponData['categoryIds'] = _selectedCategories;
        }
      }

      // Check if coupon code already exists
      final QuerySnapshot existingCoupon =
          await _firestore
              .collection('coupons')
              .where(
                'code',
                isEqualTo: _couponCodeController.text.toUpperCase(),
              )
              .get();

      if (existingCoupon.docs.isNotEmpty) {
        setState(() {
          _isLoading = false;
        });
        _showErrorDialog(
          'Coupon code already exists. Please use a different code',
        );
        return;
      }

      // Save to Firestore
      await _firestore.collection('coupons').add(couponData);

      setState(() {
        _isLoading = false;
      });

      _showSuccessDialog('Coupon created successfully');
      _resetForm();
      _fetchCoupons();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorDialog('Error creating coupon: $e');
    }
  }

  // Duplicate coupon
  void _duplicateCoupon(Map<String, dynamic> coupon) {
    setState(() {
      _couponCodeController.text = '${coupon['code']}_COPY';
      if (coupon['type'] == 'Free Delivery') {
        _isFreeDelivery = true;
        _selectedCouponType = 'Percentage';
        _discountPercentController.text = coupon['discount'].toString();
      } else {
        _isFreeDelivery = false;
        _selectedCouponType = coupon['type'];
        _discountPercentController.text = coupon['discount'].toString();
      }

      if (coupon['minPurchase'] != null) {
        _minPurchaseController.text = coupon['minPurchase'].toString();
      } else {
        _minPurchaseController.clear();
      }

      if (coupon['maxDiscount'] != null) {
        _maxDiscountController.text = coupon['maxDiscount'].toString();
      } else {
        _maxDiscountController.clear();
      }

      _startDate = DateTime.now();
      final int daysDifference =
          (coupon['endDate'] as Timestamp)
              .toDate()
              .difference((coupon['startDate'] as Timestamp).toDate())
              .inDays;
      _validityDaysController.text = daysDifference.toString();
      _endDate = _startDate.add(Duration(days: daysDifference));

      _applyToAll = coupon['applyToAll'] ?? false;

      if (!_applyToAll && coupon['productIds'] != null) {
        _selectedProducts = List<String>.from(coupon['productIds']);
      } else {
        _selectedProducts = [];
      }

      if (!_applyToAll && coupon['categoryIds'] != null) {
        _selectedCategories = List<String>.from(coupon['categoryIds']);
      } else {
        _selectedCategories = [];
      }

      _usageLimitController.text = (coupon['usageLimit'] ?? 100).toString();
      _maxUsesPerUserController.text =
          (coupon['maxUsesPerUser'] ?? 1).toString();

      _isFirstPurchaseOnly = coupon['isFirstPurchaseOnly'] ?? false;
      _isNewUserOnly = coupon['isNewUserOnly'] ?? false;
      _isLimitedTimeOffer = coupon['isLimitedTimeOffer'] ?? false;

      // Switch to the create tab
      _tabController.animateTo(0);
    });
  }

  // Delete coupon
  Future<void> _deleteCoupon(String couponId) async {
    try {
      await _firestore.collection('coupons').doc(couponId).delete();
      _showSuccessDialog('Coupon deleted successfully');
      _fetchCoupons();
    } catch (e) {
      _showErrorDialog('Error deleting coupon: $e');
    }
  }

  // Toggle coupon active status
  Future<void> _toggleCouponStatus(String couponId, bool currentStatus) async {
    try {
      await _firestore.collection('coupons').doc(couponId).update({
        'active': !currentStatus,
      });
      _fetchCoupons();
    } catch (e) {
      _showErrorDialog('Error updating coupon status: $e');
    }
  }

  // Reset form
  void _resetForm() {
    _formKey.currentState?.reset();
    _couponCodeController.clear();
    _discountPercentController.clear();
    _minPurchaseController.clear();
    _maxDiscountController.clear();
    _validityDaysController.text = '30';
    _usageLimitController.text = '100';
    _maxUsesPerUserController.text = '1';

    setState(() {
      _selectedCouponType = 'Percentage';
      _selectedProducts = [];
      _selectedCategories = [];
      _applyToAll = false;
      _isFirstPurchaseOnly = false;
      _isNewUserOnly = false;
      _isLimitedTimeOffer = false;
      _isFreeDelivery = false;
      _startDate = DateTime.now();
      _endDate = DateTime.now().add(const Duration(days: 30));
    });
  }

  // Show error dialog
  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Error'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  // Show success dialog
  void _showSuccessDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Success'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  // Show delete confirmation dialog
  void _showDeleteConfirmationDialog(String couponId) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Coupon'),
          content: const Text('Are you sure you want to delete this coupon?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _deleteCoupon(couponId);
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  // Show coupon preview dialog
  void _showCouponPreviewDialog(Map<String, dynamic> coupon) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).primaryColor.withOpacity(0.8),
                  Theme.of(context).primaryColor.withOpacity(0.2),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            coupon['code'],
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            coupon['type'] == 'Free Delivery'
                                ? 'FREE DELIVERY'
                                : coupon['type'] == 'Percentage'
                                ? '${coupon['discount']}% OFF'
                                : 'Rs ${coupon['discount']} OFF',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color:
                            (coupon['active'] ?? false)
                                ? Colors.green
                                : Colors.grey,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        (coupon['active'] ?? false) ? Icons.check : Icons.close,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const Divider(height: 32),
                if (coupon['minPurchase'] != null)
                  _buildPreviewRow(
                    'Minimum Order:',
                    'Rs ${coupon['minPurchase']}',
                  ),
                if (coupon['maxDiscount'] != null)
                  _buildPreviewRow(
                    'Max Discount:',
                    'Rs ${coupon['maxDiscount']}',
                  ),
                _buildPreviewRow(
                  'Valid Until:',
                  DateFormat(
                    'dd MMM yyyy',
                  ).format((coupon['endDate'] as Timestamp).toDate()),
                ),
                _buildPreviewRow(
                  'Usage:',
                  '${coupon['usedCount'] ?? 0}/${coupon['usageLimit'] ?? 'Unlimited'}',
                ),
                if (coupon['isFirstPurchaseOnly'] == true)
                  _buildPreviewRow('First Purchase:', 'Only'),
                if (coupon['isNewUserOnly'] == true)
                  _buildPreviewRow('New User:', 'Only'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Theme.of(context).primaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: const Text('Close'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Build preview row
  Widget _buildPreviewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Offers & Coupons'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [Tab(text: 'Create Offer'), Tab(text: 'Manage Offers')],
        ),
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : TabBarView(
                controller: _tabController,
                children: [_buildCreateOfferTab(), _buildManageOffersTab()],
              ),
    );
  }

  // Build create offer tab
  Widget _buildCreateOfferTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Create New Offer',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: _resetForm,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Reset'),
                        ),
                      ],
                    ),
                    const Divider(),
                    const SizedBox(height: 8),

                    // Basic Information Section
                    const Text(
                      'Basic Information',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Coupon Code
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _couponCodeController,
                            decoration: const InputDecoration(
                              labelText: 'Coupon Code',
                              border: OutlineInputBorder(),
                              hintText: 'e.g. SUMMER50',
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter a coupon code';
                              }
                              if (value.length < 4 || value.length > 15) {
                                return 'Code must be 4-15 characters';
                              }
                              return null;
                            },
                            textCapitalization: TextCapitalization.characters,
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () {
                            _couponCodeController.text = _generateCouponCode();
                          },
                          child: const Text('Generate'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Coupon Type (only Percentage and Fixed)
                    DropdownButtonFormField<String>(
                      value: _selectedCouponType,
                      decoration: const InputDecoration(
                        labelText: 'Coupon Type',
                        border: OutlineInputBorder(),
                      ),
                      items:
                          ['Percentage', 'Fixed']
                              .map(
                                (type) => DropdownMenuItem<String>(
                                  value: type,
                                  child: Text(type),
                                ),
                              )
                              .toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedCouponType = value!;
                        });
                      },
                    ),
                    const SizedBox(height: 16),

                    // Free Delivery Toggle Option
                    SwitchListTile(
                      title: const Text('Free Delivery'),
                      subtitle: const Text('Toggle if delivery should be free'),
                      value: _isFreeDelivery,
                      onChanged: (value) {
                        setState(() {
                          _isFreeDelivery = value;
                        });
                      },
                      contentPadding: EdgeInsets.zero,
                    ),
                    const SizedBox(height: 16),

                    // Discount Value (always visible regardless of toggle)
                    TextFormField(
                      controller: _discountPercentController,
                      decoration: InputDecoration(
                        labelText:
                            _selectedCouponType == 'Percentage'
                                ? 'Discount Percentage'
                                : 'Discount Amount',
                        border: const OutlineInputBorder(),
                        hintText:
                            _selectedCouponType == 'Percentage'
                                ? 'e.g. 15 for 15%'
                                : 'e.g. 100 for Rs 100 off',
                        suffixText:
                            _selectedCouponType == 'Percentage' ? '%' : 'Rs',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      validator: _validateDiscountValue,
                    ),
                    const SizedBox(height: 16),

                    // Min Purchase - Now required for all coupon types
                    TextFormField(
                      controller: _minPurchaseController,
                      decoration: const InputDecoration(
                        labelText: 'Minimum Purchase (Rs)',
                        border: OutlineInputBorder(),
                        hintText: 'e.g. 500',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      validator: _validateMinPurchase,
                    ),
                    const SizedBox(height: 16),

                    // Max Discount (only for percentage)
                    if (_selectedCouponType == 'Percentage')
                      TextFormField(
                        controller: _maxDiscountController,
                        decoration: const InputDecoration(
                          labelText: 'Maximum Discount (Rs)',
                          border: OutlineInputBorder(),
                          hintText: 'e.g. 200',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        validator: _validateMaxDiscount,
                      ),
                    if (_selectedCouponType == 'Percentage')
                      const SizedBox(height: 16),

                    // Validity Section
                    const Text(
                      'Validity & Limits',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Validity days
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _validityDaysController,
                            decoration: const InputDecoration(
                              labelText: 'Validity (Days)',
                              border: OutlineInputBorder(),
                              hintText: 'e.g. 30',
                            ),
                            keyboardType: TextInputType.number,
                            validator: _validateValidityDays,
                            onChanged: (value) {
                              if (value.isNotEmpty) {
                                _updateEndDate();
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _selectDate(context, true),
                            child: Text(
                              'Start: ${DateFormat('MMM dd, yyyy').format(_startDate)}',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        const Expanded(child: SizedBox()),
                        const SizedBox(width: 16),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _selectDate(context, false),
                            child: Text(
                              'End: ${DateFormat('MMM dd, yyyy').format(_endDate)}',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Usage Limits
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _usageLimitController,
                            decoration: const InputDecoration(
                              labelText: 'Total Usage Limit',
                              border: OutlineInputBorder(),
                              hintText: 'e.g. 100',
                            ),
                            keyboardType: TextInputType.number,
                            validator: _validateUsageLimit,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _maxUsesPerUserController,
                            decoration: const InputDecoration(
                              labelText: 'Max Per User',
                              border: OutlineInputBorder(),
                              hintText: 'e.g. 1',
                            ),
                            keyboardType: TextInputType.number,
                            validator: _validateMaxUsesPerUser,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Additional Options
                    const Text(
                      'Additional Options',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Apply to all products
                    SwitchListTile(
                      title: const Text('Apply to all products'),
                      subtitle: const Text(
                        'If disabled, you can select specific products or categories',
                      ),
                      value: _applyToAll,
                      onChanged: (value) {
                        setState(() {
                          _applyToAll = value;
                          if (_applyToAll) {
                            _selectedProducts = [];
                            _selectedCategories = [];
                          }
                        });
                      },
                      contentPadding: EdgeInsets.zero,
                    ),

                    // Limited time offer
                    SwitchListTile(
                      title: const Text('Limited Time Offer'),
                      subtitle: const Text(
                        'Mark as a time-sensitive promotion',
                      ),
                      value: _isLimitedTimeOffer,
                      onChanged: (value) {
                        setState(() {
                          _isLimitedTimeOffer = value;
                        });
                      },
                      contentPadding: EdgeInsets.zero,
                    ),

                    // First purchase only
                    SwitchListTile(
                      title: const Text('First Purchase Only'),
                      subtitle: const Text(
                        'Only applies to customer\'s first order',
                      ),
                      value: _isFirstPurchaseOnly,
                      onChanged: (value) {
                        setState(() {
                          _isFirstPurchaseOnly = value;
                        });
                      },
                      contentPadding: EdgeInsets.zero,
                    ),

                    // New user only
                    SwitchListTile(
                      title: const Text('New User Only'),
                      subtitle: const Text(
                        'Only applies to new customers (registered < 7 days)',
                      ),
                      value: _isNewUserOnly,
                      onChanged: (value) {
                        setState(() {
                          _isNewUserOnly = value;
                        });
                      },
                      contentPadding: EdgeInsets.zero,
                    ),

                    // Product and Category Selection (if not applying to all)
                    if (!_applyToAll) ...[
                      const SizedBox(height: 16),
                      const Text(
                        'Product Categories',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children:
                            _categories.map((category) {
                              final bool isSelected = _selectedCategories
                                  .contains(category);
                              return FilterChip(
                                label: Text(category),
                                selected: isSelected,
                                onSelected: (selected) {
                                  setState(() {
                                    if (selected) {
                                      _selectedCategories.add(category);
                                    } else {
                                      _selectedCategories.remove(category);
                                    }
                                  });
                                },
                              );
                            }).toList(),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Specific Products',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Show only products not belonging to the selected categories
                      ...List.generate(
                        _products
                            .where(
                              (product) =>
                                  !_selectedCategories.contains(
                                    product['category'],
                                  ),
                            )
                            .toList()
                            .length,
                        (index) {
                          final product =
                              _products
                                  .where(
                                    (product) =>
                                        !_selectedCategories.contains(
                                          product['category'],
                                        ),
                                  )
                                  .toList()[index];
                          final bool isSelected = _selectedProducts.contains(
                            product['id'],
                          );
                          return CheckboxListTile(
                            title: Text(product['name']),
                            subtitle: Text(
                              'Rs ${product['price']} - ${product['category']}',
                            ),
                            value: isSelected,
                            onChanged: (selected) {
                              setState(() {
                                if (selected == true) {
                                  _selectedProducts.add(product['id']);
                                } else {
                                  _selectedProducts.remove(product['id']);
                                }
                              });
                            },
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _saveCoupon,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                ),
                child: const Text(
                  'Create Coupon',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Build manage offers tab
  Widget _buildManageOffersTab() {
    if (_coupons.isEmpty) {
      return const Center(
        child: Text('No coupons found. Create your first coupon.'),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _coupons.length,
      itemBuilder: (context, index) {
        final coupon = _coupons[index];
        final bool isActive = coupon['active'] ?? false;
        final bool isExpired = DateTime.now().isAfter(
          (coupon['endDate'] as Timestamp).toDate(),
        );

        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color:
                  isExpired
                      ? Colors.grey
                      : isActive
                      ? Theme.of(context).primaryColor
                      : Colors.orange,
              width: 1,
            ),
          ),
          child: InkWell(
            onTap: () => _showCouponPreviewDialog(coupon),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Code and badge
                      Expanded(
                        child: Row(
                          children: [
                            Text(
                              coupon['code'],
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (isExpired)
                              _buildStatusBadge('Expired', Colors.grey)
                            else if (isActive)
                              _buildStatusBadge('Active', Colors.green)
                            else
                              _buildStatusBadge('Inactive', Colors.orange),
                          ],
                        ),
                      ),

                      // Action buttons
                      Row(
                        children: [
                          IconButton(
                            onPressed: () => _duplicateCoupon(coupon),
                            icon: const Icon(Icons.copy, color: Colors.blue),
                            tooltip: 'Duplicate',
                          ),
                          Switch(
                            value: isActive,
                            onChanged:
                                isExpired
                                    ? null
                                    : (value) => _toggleCouponStatus(
                                      coupon['id'],
                                      isActive,
                                    ),
                          ),
                          IconButton(
                            onPressed:
                                () =>
                                    _showDeleteConfirmationDialog(coupon['id']),
                            icon: const Icon(Icons.delete, color: Colors.red),
                            tooltip: 'Delete',
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Discount info
                  Text(
                    coupon['type'] == 'Free Delivery'
                        ? 'Free Delivery'
                        : coupon['type'] == 'Percentage'
                        ? '${coupon['discount']}% OFF'
                        : 'Rs ${coupon['discount']} OFF',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),

                  // Validity dates
                  Text(
                    'Valid: ${DateFormat('dd MMM').format((coupon['startDate'] as Timestamp).toDate())} - ${DateFormat('dd MMM yyyy').format((coupon['endDate'] as Timestamp).toDate())}',
                    style: TextStyle(
                      color: isExpired ? Colors.grey : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Details and conditions
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (coupon['minPurchase'] != null)
                        Text('Min: Rs ${coupon['minPurchase']}'),
                      const Spacer(),
                      Text(
                        'Used: ${coupon['usedCount'] ?? 0}/${coupon['usageLimit'] ?? 'Unlimited'}',
                      ),
                    ],
                  ),

                  // Tags for special conditions
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (coupon['isLimitedTimeOffer'] == true)
                        _buildTag('Limited Time'),
                      if (coupon['isFirstPurchaseOnly'] == true)
                        _buildTag('First Purchase Only'),
                      if (coupon['isNewUserOnly'] == true)
                        _buildTag('New Users Only'),
                      if (coupon['applyToAll'] != true &&
                          coupon['categoryIds'] != null &&
                          (coupon['categoryIds'] as List).isNotEmpty)
                        _buildTag(
                          '${(coupon['categoryIds'] as List).length} Categories',
                        ),
                      if (coupon['applyToAll'] != true &&
                          coupon['productIds'] != null &&
                          (coupon['productIds'] as List).isNotEmpty)
                        _buildTag(
                          '${(coupon['productIds'] as List).length} Products',
                        ),
                      if (coupon['applyToAll'] == true)
                        _buildTag('All Products'),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // Build status badge
  Widget _buildStatusBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  // Build tag
  Widget _buildTag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
      ),
    );
  }
}
