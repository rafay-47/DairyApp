import 'dart:io';
import 'package:dairyapp/constants.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart' as firebase_storage;
import 'package:image_picker/image_picker.dart';

class CategoriesPage extends StatefulWidget {
  @override
  _CategoriesPageState createState() => _CategoriesPageState();
}

class _CategoriesPageState extends State<CategoriesPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _categoryController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  // Add image picker functionality
  final ImagePicker _picker = ImagePicker();
  File? _selectedImage;
  String? _selectedCategoryId;

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
      String fileName =
          'categories/${DateTime.now().millisecondsSinceEpoch}.png';
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

  Future<void> _addCategory() async {
    if (_categoryController.text.isNotEmpty) {
      // Upload image if selected
      String? imageURL;
      if (_selectedImage != null) {
        imageURL = await _uploadImage(_selectedImage!);
      }

      // Add the document with the image URL
      final docRef = await _firestore.collection('categories').add({
        'name': _categoryController.text,
        'description': _descriptionController.text,
        'imageURL': imageURL,
      });

      // Update the doc to store its own docId for reference
      await docRef.update({'docId': docRef.id});

      _clearFields();
    }
  }

  Future<void> _updateCategory() async {
    if (_categoryController.text.isNotEmpty && _selectedCategoryId != null) {
      // Upload new image if selected
      String? imageURL;
      if (_selectedImage != null) {
        imageURL = await _uploadImage(_selectedImage!);
      }

      // Build update map
      final updateData = {
        'name': _categoryController.text,
        'description': _descriptionController.text,
      };

      // Only update imageURL if a new image was uploaded
      if (imageURL != null) {
        updateData['imageURL'] = imageURL;
      }

      await _firestore
          .collection('categories')
          .doc(_selectedCategoryId)
          .update(updateData);

      _clearFields();
      setState(() {
        _selectedCategoryId = null;
      });
    }
  }

  void _deleteCategory(String categoryId) {
    _firestore.collection('categories').doc(categoryId).delete();
  }

  void _clearFields() {
    _categoryController.clear();
    _descriptionController.clear();
    setState(() {
      _selectedImage = null;
      _selectedCategoryId = null;
    });
  }

  @override
  void dispose() {
    _categoryController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Manage Categories'),
        backgroundColor: Constants.primaryColor,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Modern input form in a Card
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    // Add image preview and upload button
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
                      controller: _categoryController,
                      decoration: InputDecoration(
                        labelText: 'Category Name',
                        border: OutlineInputBorder(),
                      ),
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: _clearFields,
                          child: Text('Cancel'),
                        ),
                        SizedBox(width: 8),
                        ElevatedButton(
                          onPressed:
                              _selectedCategoryId == null
                                  ? _addCategory
                                  : _updateCategory,
                          child: Text(
                            _selectedCategoryId == null
                                ? 'Add Category'
                                : 'Update Category',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),
            // List of categories
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _firestore.collection('categories').snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return Center(child: CircularProgressIndicator());
                  }
                  final categories = snapshot.data!.docs;
                  return ListView.builder(
                    itemCount: categories.length,
                    itemBuilder: (context, index) {
                      final category = categories[index];
                      final categoryData =
                          category.data() as Map<String, dynamic>;

                      return Card(
                        margin: EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 2,
                        child: ListTile(
                          // Display the category image or a default icon
                          leading:
                              categoryData['imageURL'] != null
                                  ? CircleAvatar(
                                    backgroundImage: NetworkImage(
                                      categoryData['imageURL'],
                                    ),
                                  )
                                  : CircleAvatar(child: Icon(Icons.category)),
                          title: Text(categoryData['name']),
                          subtitle: Text(categoryData['description'] ?? ''),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(Icons.edit, color: Colors.blue),
                                onPressed: () {
                                  setState(() {
                                    _selectedCategoryId = category.id;
                                    _categoryController.text =
                                        categoryData['name'];
                                    _descriptionController.text =
                                        categoryData['description'] ?? '';
                                  });
                                },
                              ),
                              IconButton(
                                icon: Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _deleteCategory(category.id),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
