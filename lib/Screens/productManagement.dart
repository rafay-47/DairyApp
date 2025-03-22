import 'dart:io';
import 'package:dairyapp/constants.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart' as firebase_storage;
import 'package:image_picker/image_picker.dart';
import 'package:flutter/services.dart'; // For input formatters

class ProductsPage extends StatefulWidget {
  @override
  _ProductsPageState createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _stockController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _categoryController = TextEditingController();

  // Holds the temporary PIN user enters before pressing "Add PIN"
  final TextEditingController _tempPinController = TextEditingController();
  // Actual list of PIN codes for the product
  List<String> _pinList = [];

  // Controller and variable for user PIN filter
  final TextEditingController _userPinController = TextEditingController();
  String _userPinFilter = "";

  File? _selectedImage;
  String? _selectedProductId;

  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    _descriptionController.dispose();
    _categoryController.dispose();
    _tempPinController.dispose();
    _userPinController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    }
  }

  Future<String?> _uploadImage(File imageFile) async {
    try {
      String fileName = 'products/${DateTime.now().millisecondsSinceEpoch}.png';
      firebase_storage.Reference ref = firebase_storage.FirebaseStorage.instance
          .ref()
          .child(fileName);
      await ref.putFile(imageFile);
      String downloadURL = await ref.getDownloadURL();
      return downloadURL;
    } catch (e) {
      print("Image upload error: $e");
      return null;
    }
  }

  /// Creates a new product document, then updates it with docId
  Future<void> _addProduct() async {
    // Basic checks
    if (_nameController.text.isEmpty ||
        _priceController.text.isEmpty ||
        _stockController.text.isEmpty) {
      _showError("Please fill out all required fields.");
      return;
    }
    if (_pinList.isEmpty) {
      _showError("Please add at least one PIN code.");
      return;
    }

    String? imageURL;
    if (_selectedImage != null) {
      imageURL = await _uploadImage(_selectedImage!);
    }

    // 1. Add the document
    final docRef = await _firestore.collection('products').add({
      'name': _nameController.text.trim(),
      'price': double.parse(_priceController.text.trim()),
      'stock': int.parse(_stockController.text.trim()),
      'description': _descriptionController.text.trim(),
      'category': _categoryController.text.trim(),
      // Store multiple PIN codes as an array
      'pinCodes': _pinList,
      'imageURL': imageURL,
    });

    // 2. Update the doc to store its own docId
    await docRef.update({'docId': docRef.id});

    _clearFields();
  }

  /// Updates an existing product. We do NOT overwrite docId here.
  Future<void> _updateProduct() async {
    if (_selectedProductId == null) {
      _showError("No product selected for update.");
      return;
    }

    if (_nameController.text.isEmpty ||
        _priceController.text.isEmpty ||
        _stockController.text.isEmpty) {
      _showError("Please fill out all required fields.");
      return;
    }
    if (_pinList.isEmpty) {
      _showError("Please add at least one PIN code.");
      return;
    }

    String? imageURL;
    if (_selectedImage != null) {
      imageURL = await _uploadImage(_selectedImage!);
    }

    final productDoc = _firestore
        .collection('products')
        .doc(_selectedProductId);

    // Build an update map
    final updateData = {
      'name': _nameController.text.trim(),
      'price': double.parse(_priceController.text.trim()),
      'stock': int.parse(_stockController.text.trim()),
      'description': _descriptionController.text.trim(),
      'category': _categoryController.text.trim(),
      // Store multiple PIN codes as an array
      'pinCodes': _pinList,
    };

    // Only update imageURL if new image is uploaded
    if (imageURL != null) {
      updateData['imageURL'] = imageURL;
    }

    await productDoc.update(updateData);

    _clearFields();
    setState(() {
      _selectedProductId = null;
    });
  }

  void _deleteProduct(String productId) {
    _firestore.collection('products').doc(productId).delete();
  }

  void _clearFields() {
    _nameController.clear();
    _priceController.clear();
    _stockController.clear();
    _descriptionController.clear();
    _categoryController.clear();
    _tempPinController.clear();
    _pinList.clear();
    setState(() {
      _selectedImage = null;
      _selectedProductId = null;
    });
  }

  /// Add a single PIN to _pinList after validation
  void _addPinToList() {
    final pin = _tempPinController.text.trim();
    // Validate: must be exactly 6 digits
    if (pin.isEmpty) {
      _showError("PIN code cannot be empty.");
      return;
    }
    if (pin.length != 6) {
      _showError("PIN code must be exactly 6 digits.");
      return;
    }
    if (!RegExp(r'^\d{6}$').hasMatch(pin)) {
      _showError("PIN code must be numeric and exactly 6 digits.");
      return;
    }
    if (_pinList.contains(pin)) {
      _showError("PIN code '$pin' is already added.");
      return;
    }

    setState(() {
      _pinList.add(pin);
      _tempPinController.clear();
    });
  }

  /// Remove a single PIN from _pinList
  void _removePinFromList(String pin) {
    setState(() {
      _pinList.remove(pin);
    });
  }

  void _applyUserPinFilter() {
    setState(() {
      _userPinFilter = _userPinController.text.trim();
    });
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
    );
  }

  @override
  Widget build(BuildContext context) {
    // If the user has entered a PIN, filter products with arrayContains
    // If empty, show no products (or you could remove the filter).
    Query productsQuery;
    if (_userPinFilter.isNotEmpty) {
      productsQuery = _firestore
          .collection('products')
          .where('pinCodes', arrayContains: _userPinFilter);
    } else {
      // Show no products if no PIN code is entered
      productsQuery = _firestore
          .collection('products')
          .where('pinCodes', arrayContains: '_no_pin_');
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Manage Products'),
        backgroundColor: Constants.primaryColor,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Product management form (admin functionality)
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      // Image preview and upload button
                      if (_selectedImage != null)
                        Container(
                          height: 150,
                          width: 150,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            image: DecorationImage(
                              image: FileImage(_selectedImage!),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: _pickImage,
                        icon: Icon(Icons.image),
                        label: Text("Upload Image"),
                      ),
                      SizedBox(height: 16),
                      TextField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          labelText: 'Product Name',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      SizedBox(height: 16),
                      TextField(
                        controller: _priceController,
                        decoration: InputDecoration(
                          labelText: 'Price',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      SizedBox(height: 16),
                      TextField(
                        controller: _stockController,
                        decoration: InputDecoration(
                          labelText: 'Stock',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      SizedBox(height: 16),
                      TextField(
                        controller: _descriptionController,
                        decoration: InputDecoration(
                          labelText: 'Description',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 2,
                      ),
                      SizedBox(height: 16),
                      TextField(
                        controller: _categoryController,
                        decoration: InputDecoration(
                          labelText: 'Category',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      SizedBox(height: 16),

                      // Single PIN entry + Add button
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _tempPinController,
                              decoration: InputDecoration(
                                labelText: 'Add a PIN code (max 6 digits)',
                                border: OutlineInputBorder(),
                                counterText: '', // hide default counter
                              ),
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(6),
                              ],
                              maxLength: 6,
                            ),
                          ),
                          SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: _addPinToList,
                            child: Text("Add PIN"),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),

                      // Display the list of added PINs as chips
                      if (_pinList.isNotEmpty)
                        Wrap(
                          spacing: 8.0,
                          runSpacing: 4.0,
                          children:
                              _pinList.map((pin) {
                                return Chip(
                                  label: Text(pin),
                                  deleteIcon: Icon(Icons.close),
                                  onDeleted: () => _removePinFromList(pin),
                                );
                              }).toList(),
                        ),

                      SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          ElevatedButton(
                            onPressed:
                                _selectedProductId == null
                                    ? _addProduct
                                    : _updateProduct,
                            child: Text(
                              _selectedProductId == null
                                  ? 'Add Product'
                                  : 'Update Product',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 16),

              // User PIN filter input for location-based service
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _userPinController,
                          decoration: InputDecoration(
                            labelText: 'Enter your PIN code',
                            border: OutlineInputBorder(),
                            counterText: '', // Hide the default counter
                          ),
                          keyboardType: TextInputType.number,
                          // Restrict to digits only and max length 6
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(6),
                          ],
                          maxLength: 6,
                        ),
                      ),
                      SizedBox(width: 10),
                      ElevatedButton(
                        onPressed: _applyUserPinFilter,
                        child: Text("Filter"),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 16),

              // Display product list based on the user PIN filter
              _userPinFilter.isEmpty
                  ? Container(
                    padding: EdgeInsets.all(16),
                    child: Text("Please enter your PIN code to view products."),
                  )
                  : StreamBuilder<QuerySnapshot>(
                    stream: productsQuery.snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return Center(child: CircularProgressIndicator());
                      }
                      final products = snapshot.data!.docs;
                      if (products.isEmpty) {
                        return Center(
                          child: Text("No products available in your area."),
                        );
                      }
                      return ListView.builder(
                        shrinkWrap: true,
                        physics: NeverScrollableScrollPhysics(),
                        itemCount: products.length,
                        itemBuilder: (context, index) {
                          final product = products[index];
                          final productData =
                              product.data() as Map<String, dynamic>;

                          return Card(
                            margin: EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            elevation: 2,
                            child: ListTile(
                              leading:
                                  productData['imageURL'] != null
                                      ? CircleAvatar(
                                        backgroundImage: NetworkImage(
                                          productData['imageURL'],
                                        ),
                                      )
                                      : CircleAvatar(child: Icon(Icons.image)),
                              title: Text(productData['name'] ?? 'No Name'),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (productData['category'] != null &&
                                      productData['category']
                                          .toString()
                                          .isNotEmpty)
                                    Text(
                                      "Category: ${productData['category']}",
                                    ),
                                  if (productData['description'] != null &&
                                      productData['description']
                                          .toString()
                                          .isNotEmpty)
                                    Text(
                                      "Description: ${productData['description']}",
                                    ),
                                  Text(
                                    'Price: ₹${productData['price']} | Stock: ${productData['stock']}',
                                  ),
                                  // If pinCodes is a list, join them with commas
                                  if (productData['pinCodes'] != null &&
                                      productData['pinCodes'] is List)
                                    Text(
                                      "PIN Codes: ${(productData['pinCodes'] as List).join(', ')}",
                                    ),
                                  // Optionally show the docId
                                  if (productData.containsKey('docId'))
                                    Text("Doc ID: ${productData['docId']}"),
                                ],
                              ),
                              isThreeLine: true,
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: Icon(Icons.edit, color: Colors.blue),
                                    onPressed: () {
                                      setState(() {
                                        _selectedProductId = product.id;
                                        _nameController.text =
                                            productData['name'] ?? '';
                                        _priceController.text =
                                            productData['price']?.toString() ??
                                            '';
                                        _stockController.text =
                                            productData['stock']?.toString() ??
                                            '';
                                        _descriptionController.text =
                                            productData['description'] ?? '';
                                        _categoryController.text =
                                            productData['category'] ?? '';

                                        // Load existing pins into _pinList
                                        _pinList.clear();
                                        if (productData['pinCodes'] != null &&
                                            productData['pinCodes'] is List) {
                                          List<dynamic> existingPins =
                                              productData['pinCodes'];
                                          _pinList =
                                              existingPins
                                                  .map((e) => e.toString())
                                                  .toList();
                                        }
                                        _tempPinController.clear();
                                      });
                                    },
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.delete, color: Colors.red),
                                    onPressed: () => _deleteProduct(product.id),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
            ],
          ),
        ),
      ),
    );
  }
}
