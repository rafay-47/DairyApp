import 'package:flutter/cupertino.dart';

import 'auth.dart';

class AuthProvider extends InheritedWidget {
  const AuthProvider({super.key, required super.child, required this.auth});
  final BaseAuth auth;

  @override
  bool updateShouldNotify(InheritedWidget oldWidget) => true;

  static AuthProvider of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<AuthProvider>()!;
  }
}