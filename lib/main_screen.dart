import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';  // add this import

import 'package:fuel_app/screens/breakdown_screen.dart';
import 'package:fuel_app/screens/order_tracking_screen.dart';
import '../widgets/bottom_navbar.dart'; // your BottomNavBar widget
import 'screens/dashboard_screen.dart';
import 'screens/fuel_screen.dart';
import 'screens/lubricants_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/order_screen.dart';

class MainScreen extends StatefulWidget {
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    DashboardScreen(),
    OrderScreen(),
    ProfileScreen(),
    // FuelPurchaseScreen(),
    // LubricantScreen(),     
    // BreakdownScreen(),     
  ];

@override
void initState() {
  super.initState();
  _initFirebaseMessaging();

  // When app is opened from a terminated state via notification tap
  FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
    if (message != null) {
      _handleMessageClick(message);
    }
  });

  // When app is in background and user taps notification
  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    _handleMessageClick(message);
  });
}

void _handleMessageClick(RemoteMessage message) {
  print('Notification caused app to open: ${message.notification?.title}');

  // Example: Navigate to order tracking screen or any relevant screen
  if (message.data['type'] == 'order_accepted') {
    final orderId = message.data['orderId'];
    if (orderId != null) {
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => OrderTrackingScreen(orderId: orderId),
      ));
    }
  }
}


  void _initFirebaseMessaging() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;

    // Request permission for iOS and Android 13+
    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    print('User granted permission: ${settings.authorizationStatus}');

    // Get FCM token for this device
    String? token = await messaging.getToken();
    print('FCM Token: $token');

    // Listen to foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('🔔 Foreground message received: ${message.notification?.title}');

      if (message.notification != null) {
        final notification = message.notification!;
        final title = notification.title ?? 'No Title';
        final body = notification.body ?? 'No body';

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$title\n$body'),
              duration: Duration(seconds: 5),
            ),
          );
        }
      }
    });
  }

  void _onTap(int index) {
    if (index == _currentIndex) return;
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavBar(
        currentIndex: _currentIndex,
        onTap: _onTap,
      ),
    );
  }
}
