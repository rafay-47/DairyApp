import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart' as firebase_storage;
import 'package:image_picker/image_picker.dart';

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
  final TextEditingController _productPinController =
      TextEditingController(); // For adding/updating a product

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
    _productPinController.dispose();
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

  Future<void> _addProduct() async {
    if (_nameController.text.isNotEmpty &&
        _priceController.text.isNotEmpty &&
        _stockController.text.isNotEmpty &&
        _productPinController.text.isNotEmpty) {
      String? imageURL;
      if (_selectedImage != null) {
        imageURL = await _uploadImage(_selectedImage!);
      }
      _firestore.collection('products').add({
        'name': _nameController.text,
        'price': double.parse(_priceController.text),
        'stock': int.parse(_stockController.text),
        'description': _descriptionController.text,
        'category': _categoryController.text,
        'pinCode': _productPinController.text,
        'imageURL': imageURL,
      });
      _clearFields();
    }
  }

  Future<void> _updateProduct() async {
    if (_nameController.text.isNotEmpty &&
        _priceController.text.isNotEmpty &&
        _stockController.text.isNotEmpty &&
        _selectedProductId != null &&
        _productPinController.text.isNotEmpty) {
      String? imageURL;
      if (_selectedImage != null) {
        imageURL = await _uploadImage(_selectedImage!);
      }
      _firestore.collection('products').doc(_selectedProductId).update({
        'name': _nameController.text,
        'price': double.parse(_priceController.text),
        'stock': int.parse(_stockController.text),
        'description': _descriptionController.text,
        'category': _categoryController.text,
        'pinCode': _productPinController.text,
        'imageURL': imageURL,
      });
      _clearFields();
      setState(() {
        _selectedProductId = null;
      });
    }
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
    _productPinController.clear();
    setState(() {
      _selectedImage = null;
      _selectedProductId = null;
    });
  }

  void _applyUserPinFilter() {
    setState(() {
      _userPinFilter = _userPinController.text.trim();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Build a query that filters products based on the user's PIN code
    Query productsQuery;
    if (_userPinFilter.isNotEmpty) {
      productsQuery = _firestore
          .collection('products')
          .where('pinCode', isEqualTo: _userPinFilter);
    } else {
      // If no PIN is entered, we choose to show no products until the user enters one.
      productsQuery = _firestore.collection('products');
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Manage Products'),
        backgroundColor: Colors.blue,
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      // Use SingleChildScrollView to allow scrolling if the content overflows.
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
                      TextField(
                        controller: _productPinController,
                        decoration: InputDecoration(
                          labelText: 'Product PIN Code',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
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
                          ),
                          keyboardType: TextInputType.number,
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
                          return Card(
                            margin: EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            elevation: 2,
                            child: ListTile(
                              leading:
                                  product['imageURL'] != null
                                      ? CircleAvatar(
                                        backgroundImage: NetworkImage(
                                          product['imageURL'],
                                        ),
                                      )
                                      : CircleAvatar(child: Icon(Icons.image)),
                              title: Text(product['name']),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (product['category'] != null &&
                                      product['category'].toString().isNotEmpty)
                                    Text("Category: ${product['category']}"),
                                  if (product['description'] != null &&
                                      product['description']
                                          .toString()
                                          .isNotEmpty)
                                    Text(
                                      "Description: ${product['description']}",
                                    ),
                                  Text(
                                    'Price: ₹${product['price']} | Stock: ${product['stock']}',
                                  ),
                                  Text("PIN Code: ${product['pinCode']}"),
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
                                        _nameController.text = product['name'];
                                        _priceController.text =
                                            product['price'].toString();
                                        _stockController.text =
                                            product['stock'].toString();
                                        _descriptionController.text =
                                            product['description'] ?? '';
                                        _categoryController.text =
                                            product['category'] ?? '';
                                        _productPinController.text =
                                            product['pinCode'] ?? '';
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
