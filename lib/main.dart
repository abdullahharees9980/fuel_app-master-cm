// ignore_for_file: unused_import

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fuel_app/screens/email_verification.dart';
import 'package:provider/provider.dart';
import 'auth_service.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/fuel_screen.dart';
import 'screens/order_tracking_screen.dart';
import 'screens/breakdown_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/order_screen.dart';
import 'widgets/bottom_navbar.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:awesome_notifications/awesome_notifications.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();

  if (message.notification != null) {
    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        channelKey: 'high_importance',
        title: message.notification!.title,
        body: message.notification!.body,
      ),
    );
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  
  AwesomeNotifications().initialize(
    null, 
    [
      NotificationChannel(
        channelKey: 'high_importance',
        channelName: 'High Importance Notifications',
        channelDescription: 'This channel is used for important notifications.',
        defaultColor: Colors.amber,
        importance: NotificationImportance.High,
        ledColor: Colors.amber,
      ),
    ],
  );

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(FuelApp());
}

class FuelApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AuthService>(
      create: (_) => AuthService(),
      child: MaterialApp(
        title: 'Fuel Delivery App',
        theme: ThemeData(
          brightness: Brightness.dark,
          textTheme: GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme),
          scaffoldBackgroundColor: Colors.black,
          primarySwatch: Colors.amber,
        ),
        home: const AuthWrapper(),
        routes: {
          '/login': (context) => LoginScreen(),
          '/register': (context) => RegistrationScreen(),
          '/dashboard': (context) => DashboardScreen(),
          '/profile': (context) => ProfileScreen(),
          '/main': (context) => MainScreen(),
        },
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snapshot.data;

        if (user == null) {
          return const LoginScreen();
        }

        return FutureBuilder<void>(
          future: user.reload(), // Refresh user data
          builder: (context, reloadSnapshot) {
            if (reloadSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            final refreshedUser = FirebaseAuth.instance.currentUser!;
            final providerIds = refreshedUser.providerData.map((p) => p.providerId).toList();


            print('User: $refreshedUser');
            print('Email Verified: ${refreshedUser.emailVerified}');
            print('Provider IDs: $providerIds');

            if (!refreshedUser.emailVerified && !providerIds.contains('google.com')) {

              return const EmailVerificationScreen();
            }

            return MainScreen();
          },
        );
      },
    );
  }
}

class MainScreen extends StatefulWidget {
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();

    FirebaseMessaging.instance.requestPermission();


    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.notification != null) {
        AwesomeNotifications().createNotification(
          content: NotificationContent(
            id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
            channelKey: 'high_importance',
            title: message.notification!.title,
            body: message.notification!.body,
          ),
        );
      }
    });


    FirebaseMessaging.instance.getToken().then((token) {
      print('FCM Token: $token');
    });
  }

  void _switchToDashboard() {
    setState(() {
      _currentIndex = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          DashboardScreen(),
          OrderScreen(),
          // FuelScreen(),
          // LubricantsScreen(),
          // BreakdownScreen(onNavigateToDashboard: _switchToDashboard),
          ProfileScreen(),
        ],
      ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
      ),
    );
  }
}
