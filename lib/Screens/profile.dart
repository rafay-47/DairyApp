import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:dairyapp/constants.dart';

String name = ' ';
String surname = ' ', email = ' ', mobile = ' ', address = ' ';
final db = FirebaseFirestore.instance;

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late DocumentSnapshot snapshot;

  void getData() async {
    final User user = FirebaseAuth.instance.currentUser!;
    final String uid = user.uid.toString();
    print(uid);
    snapshot = await db.collection('users').doc(uid).get();
    setState(() {
      name = (snapshot.data as Map<String, String>)['Name']!;
      surname = (snapshot.data as Map<String, String>)['Surname']!;
      email = (snapshot.data as Map<String, String>)['Email']!;
      mobile = (snapshot.data as Map<String, String>)['Number']!;
      address = (snapshot.data as Map<String, String>)['Address']!;
    });
    print(name);
    print(surname);
    print(email);
    print(mobile);
    print(address);
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    getData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Constants.backgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                height: 220.0,
                child: Stack(
                  children: [
                    Container(
                      height: 150,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Constants.primaryColor,
                            Constants.accentColor,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(30),
                          bottomRight: Radius.circular(30),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 4),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black12,
                                blurRadius: 10,
                                offset: Offset(0, 5),
                              ),
                            ],
                          ),
                          child: CircleAvatar(
                            radius: 60,
                            backgroundImage: AssetImage(
                              'images/UserProfile.png',
                            ),
                            backgroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 20),
              Center(
                child: Column(
                  children: [
                    Text(
                      "${name.toUpperCase()} ${surname.toUpperCase()}",
                      style: TextStyle(
                        fontSize: 26.0,
                        color: Constants.textDark,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      "@${name.toLowerCase()}",
                      style: TextStyle(
                        fontSize: 16.0,
                        color: Constants.textLight,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 30),
              // Profile info cards
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(15),
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: Offset(0, 5),
                      ),
                    ],
                  ),
                  child: ListView(
                    shrinkWrap: true,
                    physics: NeverScrollableScrollPhysics(),
                    children: [
                      _buildProfileInfoTile(Icons.email, "Email", email),
                      Divider(height: 1, thickness: 1, indent: 70),
                      _buildProfileInfoTile(Icons.phone, "Phone", "+91$mobile"),
                      Divider(height: 1, thickness: 1, indent: 70),
                      _buildProfileInfoTile(
                        Icons.location_on,
                        "Location",
                        address,
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

  Widget _buildProfileInfoTile(IconData icon, String title, String value) {
    return ListTile(
      leading: Container(
        padding: EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Constants.primaryColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: Constants.primaryColor),
      ),
      title: Text(
        title,
        style: TextStyle(color: Constants.textLight, fontSize: 14),
      ),
      subtitle: Text(
        value,
        style: TextStyle(
          color: Constants.textDark,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
