import 'package:firebase_auth/firebase_auth.dart';

abstract class BaseAuth {
  Future<String?> signInWithEmailAndPassword(String email, String password);
  Future<String?> createUserWithEmailAndPassword(String email, String password);
  Future<String?> currentUser();
  Future<void> signOut();
  Stream<String?> get onAuthStateChanged;
}

class Auth implements BaseAuth {
    
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;

  @override
  Future<String?> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    try {
      final userCredential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return userCredential.user?.uid;
    } catch (e) {
      print('Error signing in: $e');
      return null;
    }
  }

  @override
  Future<String?> createUserWithEmailAndPassword(
    String email,
    String password,
  ) async {
    try {
      final userCredential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      return userCredential.user?.uid;
    } catch (e) {
      print('Error creating user: $e');
      return null;
    }
  }

  @override
  Future<String?> currentUser() async {
    return _firebaseAuth.currentUser?.uid;
  }

  @override
  Future<void> signOut() async {
    try {
      await _firebaseAuth.signOut();
    } catch (e) {
      print('Error signing out: $e');
    }
  }
  
  Stream<String?> get onAuthStateChanged {
    return FirebaseAuth.instance.authStateChanges().map((user) => user?.uid);
  }
}
