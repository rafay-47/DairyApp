import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/material.dart';
import 'package:flutter/painting.dart';
import 'package:dairyapp/Screens/homepage.dart';
import 'package:dairyapp/authentication/auth.dart';
import 'package:dairyapp/authentication/auth_provider.dart';
import 'package:dairyapp/authentication/root.dart';
import 'package:firebase_core/firebase_core.dart';
import 'Animations/FadeAnimation.dart';
import 'Screens/register.dart';
import 'firebase_options.dart';
import 'constants.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(
    AuthProvider(
      auth: Auth(),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Daily Dairy',
        home: rootpage(),
        theme: ThemeData(
          fontFamily: 'Varela',
          primaryColor: Constants.primaryColor,
          colorScheme: ColorScheme.fromSwatch().copyWith(
            secondary: Constants.accentColor,
          ),
          scaffoldBackgroundColor: Constants.backgroundColor,
          textTheme: TextTheme(
            bodyLarge: TextStyle(color: Constants.accentColor),
            bodyMedium: TextStyle(color: Constants.accentColor),
          ),
        ),
      ),
    ),
  );
}

class LoginPage extends StatefulWidget {
  final VoidCallback onSignedIn;

  const LoginPage({super.key, required this.onSignedIn});

  @override
  State<StatefulWidget> createState() {
    // TODO: implement createState
    return LoginState();
  }
}

class LoginState extends State<LoginPage> {
  bool passwordShow = true;
  String email = '';
  String password = '';
  final GlobalKey<FormState> _formkey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    passwordShow = true;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        image: DecorationImage(
          image: AssetImage("images/Login.png"),
          fit: BoxFit.cover,
        ),
      ),
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: Colors.transparent,
        body: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 22.0,
            vertical: 150.0,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              FadeAnimation(
                1.9,
                Form(
                  key: _formkey,
                  child: Column(
                    children: <Widget>[
                      _buildTextField(
                        hintText: "Email",
                        obscureText: false,
                        onChanged: (input) => email = input,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter email';
                          }
                          if (!RegExp(
                            r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                          ).hasMatch(value)) {
                            return 'Please enter a valid email';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 15.0),
                      _buildTextField(
                        hintText: "Password",
                        obscureText: passwordShow,
                        onChanged: (input) => password = input,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter password';
                          }
                          if (value.length < 6) {
                            return 'Password must be at least 6 characters';
                          }
                          return null;
                        },
                        suffixIcon: IconButton(
                          icon: Icon(
                            passwordShow ? Icons.remove_red_eye : Icons.lock,
                            color: Constants.accentColor,
                          ),
                          onPressed: () {
                            setState(() {
                              passwordShow = !passwordShow;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 30),
              FadeAnimation(
                1.8,
                Center(
                  child: SizedBox(
                    width: 180.0,
                    child: MaterialButton(
                      color: Constants.secondaryColor,
                      elevation: 5.0,
                      height: 44.0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(22.0),
                      ),
                      onPressed: () {
                        if (_formkey.currentState!.validate()) {
                          signIn();
                        }
                      },
                      child: Text(
                        'Login',
                        style: TextStyle(
                          fontSize: 20.0,
                          color: Constants.primaryColor,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 15.0),
              FadeAnimation(
                1.8,
                SizedBox(
                  width: double.infinity,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: Constants.accentColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18.0),
                          ),
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) {
                                return RegisterPage(onSignedIn: () {});
                              },
                            ),
                          );
                        },
                        child: Text(
                          'Don\'t have an Account? Sign up',
                          style: TextStyle(
                            color: Constants.accentColor,
                            fontSize: 15.0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required String hintText,
    required bool obscureText,
    required Function(String) onChanged,
    required String? Function(String?) validator,
    Widget? suffixIcon,
  }) {
    return Container(
      padding: EdgeInsets.only(left: 20.0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.all(Radius.circular(30.0)),
        border: Border.all(color: Constants.accentColor),
      ),
      child: TextFormField(
        validator: validator,
        obscureText: obscureText,
        keyboardType: TextInputType.emailAddress,
        decoration: InputDecoration(
          border: InputBorder.none,
          hintStyle: TextStyle(
            color: Colors.grey.withOpacity(.8),
            fontFamily: 'R',
          ),
          hintText: hintText,
          suffixIcon: suffixIcon,
        ),
        onChanged: onChanged,
      ),
    );
  }

  Future<void> signIn() async {
    final formState = _formkey.currentState;
    if (formState != null && formState.validate()) {
      try {
        await firebase_auth.FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
        widget.onSignedIn();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder:
                (context) => HomePage(
                  onSignedOut: () {
                    Navigator.of(context).pop();
                  },
                ),
          ),
        );
      } on firebase_auth.FirebaseAuthException catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message ?? 'An error occurred during sign in'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
