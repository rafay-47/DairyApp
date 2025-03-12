import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class users {
  String name;
  String surname;
  String email;
  String number;
  String address;
  String bill;
  bool isAdmin;

  final String uid;

  users({
    required this.uid,
    required this.name,
    required this.surname,
    required this.email,
    required this.number,
    required this.address,
    required this.bill,
    this.isAdmin = false,
  });

  final CollectionReference ref = FirebaseFirestore.instance.collection(
    'users',
  );
  final CollectionReference ref1 = FirebaseFirestore.instance.collection(
    'product',
  );

  Future addUserData(
    String name,
    String surname,
    String email,
    String number,
    String address,
    String bill,
    var arr,
    bool status,
    int cartValue,
    bool isAdmin,
    Map<dynamic, dynamic> map,
  ) async {
    return await ref.doc(uid).set({
      'Name': name,
      'Surname': surname,
      'Email': email,
      'Number': number,
      'Address': address,
      'Bill': bill,
      'Array': arr,
      'Status': status,
      'CartValue': cartValue,
      'isAdmin': isAdmin,
    });
  }

  Future<String> currentUser() async {
    final User? user = FirebaseAuth.instance.currentUser;
    final String uid = user?.uid ?? '';
    return uid;
  }

  Future addmap(Map map) async {
    return await ref1.doc(uid).set(map);
  }
}
