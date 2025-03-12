import 'package:double_back_to_close_app/double_back_to_close_app.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:dairyapp/Screens/profile.dart';
import 'Settings.dart';
import 'SubscribedPage.dart';
import 'cart.dart';
import 'home.dart';
import '../Constants.dart';

class HomePage extends StatefulWidget {
  final VoidCallback onSignedOut;

  const HomePage({super.key, required this.onSignedOut});

  @override
  State<StatefulWidget> createState() {
    return HomeState();
  }
}

class HomeState extends State<HomePage> with SingleTickerProviderStateMixin {
  bool select = true;
  int currentTab = 0; // to keep track of active tab index
  final List<Widget> screens = [
    Home(),
    ProfilePage(),
    SubscribedPlan(),
    Settings(onSignedOut: () {}),
  ]; // to store nested tabs
  final PageStorageBucket bucket = PageStorageBucket();
  Widget currentScreen = Home();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: Constants.backgroundColor,
      appBar: AppBar(
        leading: Container(),
        backgroundColor: Colors.transparent,
        title: Text(
          'Daily Dairy',
          style: TextStyle(
            color: Constants.accentColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        elevation: 0.0,
      ),
      body: DoubleBackToCloseApp(
        snackBar: const SnackBar(content: Text('Tap Back to exit')),
        child: PageStorage(bucket: bucket, child: currentScreen),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => Cart()),
          );
        },
        backgroundColor: Constants.accentColor,
        child: Icon(Icons.add_shopping_cart, color: Colors.white),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        shape: CircularNotchedRectangle(),
        notchMargin: 10,
        child: SizedBox(
          height: 55,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[_buildLeftTabBar(), _buildRightTabBar()],
          ),
        ),
      ),
    );
  }

  Widget _buildLeftTabBar() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(width: 30.0),
        _buildTabBarItem(
          icon: Icons.home,
          label: 'Home',
          index: 0,
          screen: Home(),
        ),
        _buildTabBarItem(
          icon: Icons.account_box,
          label: 'Profile',
          index: 1,
          screen: ProfilePage(),
        ),
      ],
    );
  }

  Widget _buildRightTabBar() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _buildTabBarItem(
          icon: Icons.playlist_add_check,
          label: 'Subscribed\n      Plan',
          index: 2,
          screen: SubscribedPlan(),
        ),
        _buildTabBarItem(
          icon: Icons.settings,
          label: 'Settings',
          index: 3,
          screen: Settings(onSignedOut: () {}),
        ),
        SizedBox(width: 30.0),
      ],
    );
  }

  Widget _buildTabBarItem({
    required IconData icon,
    required String label,
    required int index,
    required Widget screen,
  }) {
    return MaterialButton(
      minWidth: 40,
      onPressed: () {
        setState(() {
          currentScreen = screen;
          currentTab = index;
        });
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(
            icon,
            color: currentTab == index ? Constants.accentColor : Colors.grey,
          ),
          Visibility(
            visible: currentTab == index,
            child: Text(
              label,
              style: TextStyle(
                color:
                    currentTab == index ? Constants.accentColor : Colors.grey,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
