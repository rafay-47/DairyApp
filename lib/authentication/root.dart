import 'dart:async';

import 'package:flutter/material.dart';
import 'package:dairyapp/Screens/homepage.dart';
import 'package:dairyapp/Screens/adminHomepage.dart';
import 'package:dairyapp/main.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'auth.dart';
import 'auth_provider.dart' as custom_auth_provider;

class rootpage extends StatefulWidget {
  const rootpage({super.key});

  @override
  rootpagestate createState() => rootpagestate();
}

enum AuthStatus { notDetermined, notSignedIn, signedIn }

class rootpagestate extends State<rootpage> {
  AuthStatus authStatus = AuthStatus.notDetermined;
  bool? isAdmin;
  String? userId;
  StreamSubscription<String?>? _authStateSubscription;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final BaseAuth auth = custom_auth_provider.AuthProvider.of(context).auth;
    _authStateSubscription = auth.onAuthStateChanged.listen(
      _onAuthStateChanged,
    );
  }

  void _onAuthStateChanged(String? uid) {
    setState(() {
      userId = uid;
      authStatus = uid == null ? AuthStatus.notSignedIn : AuthStatus.signedIn;

      if (uid != null) {
        checkAdminStatus(uid);
      } else {
        isAdmin = null;
      }
    });
  }

  @override
  void dispose() {
    _authStateSubscription?.cancel();
    super.dispose();
  }

  Future<void> checkAdminStatus(String uid) async {
    try {
      final userDoc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();

      if (userDoc.exists && userDoc.data() != null) {
        setState(() {
          isAdmin = userDoc.data()!['isAdmin'] == true;
        });
      } else {
        setState(() {
          isAdmin = false;
        });
      }
    } catch (e) {
      print('Error checking admin status: $e');
      setState(() {
        isAdmin = false;
      });
    }
  }

  void _signedIn() {
    if (mounted) {
      setState(() {
        authStatus = AuthStatus.signedIn;
      });
    }
  }

  void _signedOut() {
    if (mounted) {
      setState(() {
        authStatus = AuthStatus.notSignedIn;
        isAdmin = null;
        userId = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    switch (authStatus) {
      case AuthStatus.notDetermined:
        return _buildWaitingScreen();
      case AuthStatus.notSignedIn:
        return LoginPage(onSignedIn: _signedIn, key: null);
      case AuthStatus.signedIn:
        if (isAdmin == null) {
          // Still determining admin status
          return _buildWaitingScreen();
        } else if (isAdmin == true) {
          return AdminHomePage(onSignedOut: _signedOut);
        } else {
          return HomePage(onSignedOut: _signedOut);
        }
    }
  }

  Widget _buildWaitingScreen() {
    return Scaffold(
      body: Container(
        alignment: Alignment.center,
        child: CircularProgressIndicator(),
      ),
    );
  }
}
