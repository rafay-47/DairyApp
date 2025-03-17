import 'package:dairyapp/Screens/adminHomepage.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/material.dart';
import 'package:dairyapp/Screens/homepage.dart';
import 'package:dairyapp/authentication/auth.dart';
import 'package:dairyapp/authentication/auth_provider.dart';
import 'package:dairyapp/authentication/root.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_stripe/flutter_stripe.dart' as stripe;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:toast/toast.dart';
import 'Animations/FadeAnimation.dart';
import 'Screens/register.dart';
import 'firebase_options.dart';
import 'constants.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  await dotenv.load(fileName: ".env");

  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Initialize Stripe with key from .env
  final stripePublishableKey =
      dotenv.env['STRIPE_PUBLISHABLE_KEY'] ??
      'pk_test_51OuuwVP0XD6u4TvYIUtwCffNiD1ZpOaKxKejORfDqAPjS6KSrwUg3qrd8jyrzYtQW6B6DJG2zScHPurSvn5EA7o500bOPE7N92';
  stripe.Stripe.publishableKey = stripePublishableKey;

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Initialize Toast context once the app is running and context is available
    ToastContext().init(context);

    return AuthProvider(
      auth: Auth(),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Dairy App',
        home: rootpage(),
        theme: ThemeData(
          fontFamily: 'Poppins',
          primaryColor: Constants.primaryColor,
          colorScheme: ColorScheme.fromSwatch().copyWith(
            primary: Constants.primaryColor,
            secondary: Constants.accentColor,
            background: Constants.backgroundColor,
            error: Constants.errorColor,
          ),
          appBarTheme: AppBarTheme(
            elevation: 0,
            backgroundColor: Constants.primaryColor,
            titleTextStyle: TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w600,
              fontSize: 20,
              color: Colors.white,
            ),
            iconTheme: IconThemeData(color: Colors.white),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: Constants.accentColor,
              foregroundColor: Colors.white,
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: EdgeInsets.symmetric(vertical: 14, horizontal: 20),
            ),
          ),
          cardTheme: CardTheme(
            elevation: 3,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          ),
          textTheme: TextTheme(
            displayLarge: TextStyle(
              color: Constants.textDark,
              fontWeight: FontWeight.bold,
            ),
            displayMedium: TextStyle(
              color: Constants.textDark,
              fontWeight: FontWeight.bold,
            ),
            displaySmall: TextStyle(
              color: Constants.textDark,
              fontWeight: FontWeight.w600,
            ),
            bodyLarge: TextStyle(color: Constants.textDark),
            bodyMedium: TextStyle(color: Constants.textDark),
          ),
        ),
      ),
    );
  }
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
  bool isLoading = false;
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
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Constants.secondaryColor,
                      elevation: 5.0,
                      minimumSize: Size(180.0, 44.0),
                      padding: EdgeInsets.symmetric(
                        horizontal: 24.0,
                        vertical: 10.0,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(22.0),
                      ),
                    ),
                    onPressed:
                        isLoading
                            ? null
                            : () {
                              if (_formkey.currentState!.validate()) {
                                signIn();
                              }
                            },
                    child:
                        isLoading
                            ? CircularProgressIndicator(
                              color: Constants.primaryColor,
                            )
                            : Text(
                              'Login',
                              style: TextStyle(
                                fontSize: 18.0,
                                fontWeight: FontWeight.w600,
                                color: Constants.primaryColor,
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

  // In your LoginState class, update only the signIn function
  Future<void> signIn() async {
    final formState = _formkey.currentState;
    if (formState != null && formState.validate()) {
      try {
        setState(() {
          isLoading = true;
        });

        // Check user status before login
        final userDoc =
            await FirebaseFirestore.instance
                .collection('users')
                .where('Email', isEqualTo: email)
                .get();

        if (userDoc.docs.isNotEmpty) {
          final userData = userDoc.docs.first.data();
          if (userData['Status'] == false) {
            throw firebase_auth.FirebaseAuthException(
              code: 'user-disabled',
              message: 'Account deactivated. Contact administrator.',
            );
          }
        }

        // Your existing authentication code
        await firebase_auth.FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: password,
        );

        if (mounted) {
          widget.onSignedIn();
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => rootpage()),
            (route) => false,
          );
        }
      } on firebase_auth.FirebaseAuthException catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message ?? 'An error occurred during sign in'),
            backgroundColor: Colors.red,
          ),
        );
      } finally {
        if (mounted) {
          setState(() {
            isLoading = false;
          });
        }
      }
    }
  }
}
