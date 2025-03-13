import 'package:flutter/material.dart';

class Constants {
  // Define the color palette
  static const Color primaryColor = Color(0xFFFAFAFA); // Blue
  static const Color secondaryColor = Color.fromRGBO(22, 102, 225, 1); // Blue
  static const Color backgroundColor = Color(0xFFFAFAFA); // Off-White
  static const Color accentColor = Color.fromRGBO(22, 102, 225, 1); // Blue
  static const Color textDark = Color(0xFF333333);
  static const Color textLight = Color(0xFF888888);
  static const Color cardColor = Colors.white;
  static const Color successColor = Color(0xFF4CAF50);
  static const Color warningColor = Color(0xFFFFC107);
  static const Color errorColor = Color(0xFFF44336);
  static const String loginImage = "images/Login.png";
  static const double horizontalPadding = 22.0;
  static const double verticalPadding = 150.0;
  static const double textFieldSpacing = 15.0;
  static const double buttonWidth = 180.0;
  static const double buttonHeight = 44.0;
  static const double buttonElevation = 5.0;
  static const double buttonBorderRadius = 22.0;
  static const double fadeAnimationDuration = 1.8;
  static const double formSpacing = 30.0;
  static const double textButtonBorderRadius = 18.0;
  static const double textButtonFontSize = 15.0;
  static const double loginButtonFontSize = 20.0;
  static const String emailHintText = "Email";
  static const String passwordHintText = "Password";
  static const String loginButtonText = "Login";
  static const String signUpText = "Don't have an Account? Sign up";
  static const String emailValidationError = "Please enter email";
  static const String emailValidationPattern =
      r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$';
  static const String emailValidationInvalid = "Please enter a valid email";
  static const String passwordValidationError = "Please enter password";
  static const int passwordMinLength = 6;
  static const String passwordLengthError =
      "Password must be at least 6 characters";
}
