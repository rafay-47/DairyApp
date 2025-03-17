import 'package:flutter/material.dart';

class Constants {
  // Define the color palette
  static const Color primaryColor = Color(0xFF3F51B5); // Deep Indigo
  static const Color secondaryColor = Color(0xFF2196F3); // Bright Blue
  static const Color backgroundColor = Color(0xFFF5F7FA); // Light Gray-Blue
  static const Color accentColor = Color(0xFF536DFE); // Bright Indigo
  static const Color textDark = Color(0xFF2C3E50); // Dark Blue-Gray
  static const Color textLight = Color(0xFF7F8C8D); // Medium Gray
  static const Color cardColor = Colors.white;
  static const Color successColor = Color(0xFF4CAF50); // Green
  static const Color warningColor = Color(0xFFFFA000); // Amber
  static const Color errorColor = Color(0xFFE53935); // Red
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
