import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dairyapp/Screens/homepage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:dairyapp/Animations/FadeAnimation.dart';
import 'package:dairyapp/users.dart';

import '../main.dart';
import '../Constants.dart';

class RegisterPage extends StatefulWidget {
  final VoidCallback onSignedIn;

  const RegisterPage({super.key, required this.onSignedIn});

  @override
  State<StatefulWidget> createState() {
    return RegisterState();
  }
}

class RegisterState extends State<RegisterPage> {
  final GlobalKey<FormState> fkey = GlobalKey<FormState>();
  late String email, password, name, surname, number, cpassword, address;
  late bool passwordShow;
  bool _isAdmin = false;
  bool _isLoading = false;

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
                _buildAddressField(),
                SizedBox(height: Constants.textFieldSpacing),
                _buildPasswordField(),
                SizedBox(height: Constants.textFieldSpacing),
                _buildConfirmPasswordField(),
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

  Widget _buildNameFields() {
    return FadeAnimation(
      1,
      Row(
        children: <Widget>[
          Expanded(
            child: _buildTextField(
              hintText: "First Name",
              onChanged: (input) => name = input,
              validator: (input) {
                if (input == null || input.isEmpty) {
                  return "Enter name";
                }
                if (input.length < 2) {
                  return "Name must be at least 2 characters";
                }
                return null;
              },
            ),
          ),
          SizedBox(width: Constants.textFieldSpacing),
          Expanded(
            child: _buildTextField(
              hintText: "Last Name",
              onChanged: (input) => surname = input,
              validator: (input) {
                if (input == null || input.isEmpty) {
                  return "Enter surname";
                }
                if (input.length < 2) {
                  return "Surname must be at least 2 characters";
                }
                return null;
              },
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
        validator: (input) {
          if (input == null || input.isEmpty) {
            return "Enter email";
          }
          if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(input)) {
            return "Enter a valid email address";
          }
          return null;
        },
        keyboardType: TextInputType.emailAddress,
      ),
    );
  }

  Widget _buildMobileField() {
    return FadeAnimation(
      1.0,
      _buildTextField(
        hintText: "Mobile",
        onChanged: (input) => number = input,
        validator: (input) {
          if (input == null || input.isEmpty) {
            return "Enter number";
          }
          if (!RegExp(r'^\d{10}$').hasMatch(input)) {
            return "Enter a valid 10-digit number";
          }
          return null;
        },
        keyboardType: TextInputType.phone,
      ),
    );
  }

  Widget _buildAddressField() {
    return FadeAnimation(
      1.0,
      _buildTextField(
        hintText: "Delivery Address",
        onChanged: (input) => address = input,
        validator: (input) {
          if (input == null || input.isEmpty) {
            return "Enter your address";
          }
          if (input.length < 5) {
            return "Please enter a complete address";
          }
          return null;
        },
        keyboardType: TextInputType.streetAddress,
        maxLines: 2,
      ),
    );
  }

  Widget _buildPasswordField() {
    return FadeAnimation(
      1.0,
      _buildTextField(
        hintText: "Password",
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
          if (value == null || value.isEmpty) {
            return 'Please confirm password';
          }
          if (value != password) {
            return 'Passwords do not match';
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
          onPressed: _isLoading ? null : signup,
          child:
              _isLoading
                  ? SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      strokeWidth: 2,
                    ),
                  )
                  : Text(
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
    int maxLines = 1,
  }) {
    return Container(
      height: maxLines > 1 ? 80.0 : 50.0,
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
        maxLines: maxLines,
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
      setState(() {
        _isLoading = true;
      });

      try {
        // Check if email already exists
        final emailCheck =
            await FirebaseFirestore.instance
                .collection('users')
                .where('Email', isEqualTo: email)
                .get();

        if (emailCheck.docs.isNotEmpty) {
          _showError('This email is already registered');
          return;
        }

        // Check if phone number already exists
        final phoneCheck =
            await FirebaseFirestore.instance
                .collection('users')
                .where('Number', isEqualTo: number)
                .get();

        if (phoneCheck.docs.isNotEmpty) {
          _showError('This phone number is already registered');
          return;
        }

        // Create user
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
          address,
          " ",
          " ",
          true,
          0,
          _isAdmin,
          {},
        );


        widget.onSignedIn();

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder:
                  (context) => HomePage(
                    onSignedOut: () {
                      setState(() {
                        widget.onSignedIn();
                      });
                    },
                  ),
            ),
          );
        }
      } on FirebaseAuthException catch (e) {
        String errorMessage;
        switch (e.code) {
          case 'weak-password':
            errorMessage = 'The password provided is too weak';
            break;
          case 'email-already-in-use':
            errorMessage = 'This email is already registered';
            break;
          case 'invalid-email':
            errorMessage = 'Invalid email address';
            break;
          default:
            errorMessage = e.message ?? 'An error occurred during registration';
        }
        _showError(errorMessage);
      } catch (e) {
        _showError('An error occurred during registration');
        print(e);
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }
}
