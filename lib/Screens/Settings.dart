import 'package:flutter/material.dart';
import 'package:dairyapp/Screens/feedback.dart';
import 'package:dairyapp/authentication/auth.dart';
import 'package:dairyapp/authentication/auth_provider.dart';
import 'package:dairyapp/main.dart';
import 'package:dairyapp/constants.dart';

class Settings extends StatefulWidget {
  final VoidCallback onSignedOut;

  const Settings({super.key, required this.onSignedOut});

  @override
  _SettingsState createState() => _SettingsState();
}

class _SettingsState extends State<Settings> {
  Future<void> _signOut(BuildContext context) async {
    try {
      final BaseAuth auth = AuthProvider.of(context).auth;
      await auth.signOut();
      widget.onSignedOut();
    } catch (e) {
      print(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Column(
          children: <Widget>[
            SizedBox(height: 10.0),
            // Container(
            //   height: 70.0,
            //   width: MediaQuery.of(context).size.width,
            //   decoration: BoxDecoration(color: Colors.white),
            //   child: Card(
            //     elevation: 4,
            //     child: Row(
            //       children: <Widget>[
            //         SizedBox(width: 10.0),
            //         Icon(Icons.edit),
            //         TextButton(
            //           child: Text(
            //             'Raise a complain',
            //             style: TextStyle(fontSize: 18.0),
            //           ),
            //           onPressed: () {
            //             Navigator.push(
            //               context,
            //               MaterialPageRoute(
            //                 builder: (context) => feedbackPage(),
            //               ),
            //             );
            //           },
            //         ),
            //       ],
            //     ),
            //   ),
            // ),
            
            Container(
              height: 70.0,
              width: MediaQuery.of(context).size.width,
              decoration: BoxDecoration(color: Colors.white),
              child: Card(
                elevation: 4,
                child: Row(
                  children: <Widget>[
                    SizedBox(width: 10.0),
                    Icon(Icons.close),
                    TextButton(
                      child: Text('Log out', style: TextStyle(fontSize: 18.0)),
                      onPressed: () {
                        _signOut(context);
                        Route route = MaterialPageRoute(
                          builder: (context) => LoginPage(onSignedIn: () {}),
                        );
                        Navigator.pushReplacement(context, route);
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
