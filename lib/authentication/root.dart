import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:dairyapp/Screens/Settings.dart';
import 'package:dairyapp/Screens/home.dart';
import 'package:dairyapp/Screens/homepage.dart';
import 'package:dairyapp/main.dart';
import 'auth.dart';
import 'auth_provider.dart';

class rootpage extends StatefulWidget {
  const rootpage({super.key});

  @override
  rootpagestate createState() => rootpagestate();
}

enum AuthStatus { notDetermined, notSignedIn, signedIn }

class rootpagestate extends State<rootpage> {
  AuthStatus authStatus = AuthStatus.notDetermined;

  @override
  void didChangeDependencies() {
    // TODO: implement didChangeDependencies
    super.didChangeDependencies();
    final BaseAuth auth = AuthProvider.of(context).auth;
    auth.currentUser().then((String? userId) {
      setState(() {
        authStatus =
            userId == null ? AuthStatus.notSignedIn : AuthStatus.signedIn;
      });
    });
  }

  void _signedIn() {
    setState(() {
      authStatus = AuthStatus.signedIn;
    });
  }

  void _signedOut() {
    setState(() {
      authStatus = AuthStatus.notSignedIn;
    });
  }

  @override
  Widget build(BuildContext context) {
    switch (authStatus) {
      case AuthStatus.notDetermined:
        return _buildWaitingScreen();
      case AuthStatus.notSignedIn:
        return LoginPage(onSignedIn: _signedIn, key: null);
      case AuthStatus.signedIn:
        return HomePage(onSignedOut: _signedOut);
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
