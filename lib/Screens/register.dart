import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dairyapp/Screens/homepage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:dairyapp/Animations/FadeAnimation.dart';
import 'package:dairyapp/Screens/subscribeScreen.dart';
import 'package:dairyapp/users.dart';

import '../main.dart';
import '../Constants.dart';

class RegisterPage extends StatefulWidget {
  final VoidCallback onSignedIn;

  const RegisterPage({super.key, required this.onSignedIn});

  @override
  State<StatefulWidget> createState() {
    // TODO: implement createState
    return RegisterState();
  }
}

class RegisterState extends State<RegisterPage> {
  final GlobalKey<FormState> fkey = GlobalKey<FormState>();
  late String email, password, name, surname, number, cpassword;
  late bool passwordShow;
  bool _isAdmin = false;

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    passwordShow = true;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        image: DecorationImage(
          image: AssetImage(Constants.loginImage),
          fit: BoxFit.cover,
        ),
      ),
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: Colors.transparent,
        body: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Constants.horizontalPadding,
            vertical: 120.0,
          ),
          child: Form(
            key: fkey,
            child: Column(
              children: <Widget>[
                _buildNameFields(),
                SizedBox(height: Constants.textFieldSpacing),
                _buildEmailField(),
                SizedBox(height: Constants.textFieldSpacing),
                _buildMobileField(),
                SizedBox(height: Constants.textFieldSpacing),
                _buildPasswordField(),
                SizedBox(height: Constants.textFieldSpacing),
                _buildConfirmPasswordField(),
                SizedBox(height: Constants.textFieldSpacing),
                _buildAdminToggle(),
                SizedBox(height: Constants.formSpacing),
                _buildRegisterButton(),
                SizedBox(height: Constants.textFieldSpacing),
                _buildLoginTextButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAdminToggle() {
    return FadeAnimation(
      1.0,
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        child: Row(
          children: [
            Text(
              "Admin Account",
              style: TextStyle(color: Constants.accentColor),
            ),
            Spacer(),
            Switch(
              value: _isAdmin,
              activeColor: Constants.secondaryColor,
              onChanged: (value) {
                setState(() {
                  _isAdmin = value;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNameFields() {
    return FadeAnimation(
      1,
      Row(
        children: <Widget>[
          Expanded(
            child: _buildTextField(
              hintText: "First Name",
              onChanged: (input) => name = input,
              validator: (input) => input == null ? "Enter name" : null,
            ),
          ),
          SizedBox(width: Constants.textFieldSpacing),
          Expanded(
            child: _buildTextField(
              hintText: "Last Name",
              onChanged: (input) => surname = input,
              validator: (input) => input == null ? "Enter surname" : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmailField() {
    return FadeAnimation(
      1.0,
      _buildTextField(
        hintText: "Email",
        onChanged: (input) => email = input,
        validator: (input) => input == null ? "Enter email" : null,
      ),
    );
  }

  Widget _buildMobileField() {
    return FadeAnimation(
      1.0,
      _buildTextField(
        hintText: "Mobile",
        onChanged: (input) => number = input,
        validator: (input) => input == null ? "Enter number" : null,
        keyboardType: TextInputType.phone,
      ),
    );
  }

  Widget _buildPasswordField() {
    return FadeAnimation(
      1.0,
      _buildTextField(
        hintText: "Password",
        onChanged: (input) => password = input,
        validator: (value) => value == null ? 'Please enter password' : null,
        obscureText: passwordShow,
        suffixIcon: _buildPasswordToggleIcon(),
      ),
    );
  }

  Widget _buildConfirmPasswordField() {
    return FadeAnimation(
      1.0,
      _buildTextField(
        hintText: "Confirm Password",
        onChanged: (input) => cpassword = input,
        validator: (value) {
          if (value == null) return 'Please enter password';
          if (value != password) {
            return 'Confirm password must be same as password';
          }
          return null;
        },
        obscureText: passwordShow,
        suffixIcon: _buildPasswordToggleIcon(),
      ),
    );
  }

  Widget _buildRegisterButton() {
    return FadeAnimation(
      1.0,
      SizedBox(
        width: Constants.buttonWidth,
        child: MaterialButton(
          color: Constants.secondaryColor,
          elevation: Constants.buttonElevation,
          height: Constants.buttonHeight,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Constants.buttonBorderRadius),
          ),
          onPressed: () {
            if (fkey.currentState!.validate()) {
              signup();
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) {
                    return HomePage(
                      onSignedOut: () {
                        setState(() {
                          widget.onSignedIn();
                        });
                      },
                    );
                  },
                ),
              );
            }
          },
          child: Text(
            'Register',
            style: TextStyle(
              fontSize: Constants.loginButtonFontSize,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginTextButton() {
    return FadeAnimation(
      1.0,
      TextButton(
        style: TextButton.styleFrom(
          padding: EdgeInsets.only(left: 5.0),
          foregroundColor: Constants.accentColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(
              Constants.textButtonBorderRadius,
            ),
          ),
        ),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) {
                return LoginPage(
                  onSignedIn: () {
                    setState(() {
                      widget.onSignedIn();
                    });
                  },
                );
              },
            ),
          );
        },
        child: Text(
          'Already have an account? Log In',
          style: TextStyle(fontSize: Constants.textButtonFontSize),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required String hintText,
    required Function(String) onChanged,
    required String? Function(String?) validator,
    bool obscureText = false,
    Widget? suffixIcon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      height: 50.0,
      padding: EdgeInsets.only(left: 20.0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Constants.accentColor),
        color: Colors.white,
      ),
      child: TextFormField(
        decoration: InputDecoration(
          border: InputBorder.none,
          hintStyle: TextStyle(color: Colors.grey.withOpacity(.8)),
          hintText: hintText,
          suffixIcon: suffixIcon,
        ),
        validator: validator,
        onChanged: onChanged,
        obscureText: obscureText,
        keyboardType: keyboardType,
      ),
    );
  }

  Widget _buildPasswordToggleIcon() {
    return IconButton(
      icon: Icon(
        passwordShow ? Icons.remove_red_eye : Icons.lock,
        color: Constants.accentColor,
      ),
      onPressed: () {
        setState(() {
          passwordShow = !passwordShow;
        });
      },
    );
  }

  Future<void> signup() async {
    final formstate = fkey.currentState;
    if (formstate!.validate()) {
      formstate.save();
      try {
        UserCredential user = await FirebaseAuth.instance
            .createUserWithEmailAndPassword(email: email, password: password);
        var map = <dynamic, dynamic>{};
        await users(
          uid: user.user!.uid,
          name: '',
          surname: '',
          email: '',
          number: '',
          address: '',
          bill: '',
          isAdmin: false,
        ).addUserData(
          name,
          surname,
          email,
          number,
          " ",
          " ",
          " ",
          true,
          0,
          _isAdmin,
          {},
        ); // Pass _isAdmin here

        FirebaseFirestore.instance.collection('cart').doc(user.user!.uid).set({
          'product': map,
        });
        widget.onSignedIn();
      } catch (e) {
        print(e);
      }
    }
  }
}
