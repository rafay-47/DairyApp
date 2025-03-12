import 'package:dairyapp/constants.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CategoriesPage extends StatefulWidget {
  @override
  _CategoriesPageState createState() => _CategoriesPageState();
}

class _CategoriesPageState extends State<CategoriesPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _categoryController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  String? _selectedCategoryId;

  Future<void> _addCategory() async {
    if (_categoryController.text.isNotEmpty) {
      _firestore.collection('categories').add({
        'name': _categoryController.text,
        'description': _descriptionController.text,
      });
      _clearFields();
    }
  }

  Future<void> _updateCategory() async {
    if (_categoryController.text.isNotEmpty && _selectedCategoryId != null) {
      _firestore.collection('categories').doc(_selectedCategoryId).update({
        'name': _categoryController.text,
        'description': _descriptionController.text,
      });
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
        backgroundColor: Constants.secondaryColor,
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
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
                        ElevatedButton(
                          onPressed: _selectedCategoryId == null
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
                      return Card(
                        margin: EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 2,
                        child: ListTile(
                          // Display a default icon as the avatar
                          leading: CircleAvatar(
                            child: Icon(Icons.category),
                          ),
                          title: Text(category['name']),
                          subtitle: Text(category['description'] ?? ''),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(Icons.edit, color: Colors.blue),
                                onPressed: () {
                                  setState(() {
                                    _selectedCategoryId = category.id;
                                    _categoryController.text = category['name'];
                                    _descriptionController.text =
                                        category['description'] ?? '';
                                  });
                                },
                              ),
                              IconButton(
                                icon: Icon(Icons.delete, color: Colors.red),
                                onPressed: () =>
                                    _deleteCategory(category.id),
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
