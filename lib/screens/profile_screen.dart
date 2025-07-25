// ignore_for_file: prefer_const_constructors

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../auth_service.dart';
import '../main.dart'; 

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isOffline = false;
  late StreamSubscription<ConnectivityResult> _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = Connectivity().onConnectivityChanged.listen((result) {
      setState(() {
        _isOffline = result == ConnectivityResult.none;
      });
    });
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

@override
Widget build(BuildContext context) {
  final auth = Provider.of<AuthService>(context);
  final user = auth.user;

  return Scaffold(
    backgroundColor: const Color(0xFF121212),
    appBar: AppBar(
      title: const Text('Profile'),
      centerTitle: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      foregroundColor: Colors.amber,
    ),
    body: Stack(
      children: [
        // Main content with dimming and interaction blocking when offline
        AnimatedOpacity(
          duration: const Duration(milliseconds: 300),
          opacity: _isOffline ? 0.4 : 1.0,
          child: AbsorbPointer(
            absorbing: _isOffline,
            child: Column(
              children: [
                Expanded(
                  child: user == null
                      ? Center(
                          child: Text(
                            'No user logged in',
                            style: TextStyle(color: Colors.amber[300], fontSize: 18),
                          ),
                        )
                      : SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              CircleAvatar(
                                radius: 60,
                                backgroundColor: Colors.amber,
                                child: Text(
                                  _getInitials(user.displayName ?? 'U'),
                                  style: const TextStyle(
                                    fontSize: 40,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),
                              Text(
                                user.displayName ?? 'User',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                user.email ?? 'No email',
                                style: TextStyle(
                                  color: Colors.amber[200],
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 32),
                              _buildInfoCard(
                                icon: Icons.email_outlined,
                                title: 'Email',
                                value: user.email ?? 'N/A',
                              ),
                              const SizedBox(height: 16),
                              _buildInfoCard(
                                icon: Icons.calendar_today,
                                title: 'Joined Date',
                                value: 'July 2025',
                              ),
                              const SizedBox(height: 32),
                              ElevatedButton.icon(
                                icon: const Icon(Icons.logout, color: Colors.black),
                                label: const Text('Logout', style: TextStyle(color: Colors.black)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.amber,
                                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 48),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  elevation: 8,
                                  shadowColor: Colors.amberAccent.withOpacity(0.6),
                                  textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                                ),
                                onPressed: () async {
                                  await auth.logout();
                                  if (context.mounted) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => AuthWrapper()),
      (route) => false,
    );
  }
                                },
                              ),
                            ],
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),

 
        if (_isOffline)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: AnimatedOpacity(
              opacity: 1.0,
              duration: const Duration(milliseconds: 300),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                color: Colors.red.shade700,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.wifi_off, color: Colors.white),
                    SizedBox(width: 8),
                    Text(
                      'No Internet Connection',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          ),


        if (_isOffline)
          Positioned.fill(
            child: AbsorbPointer(
              absorbing: true,
              child: Container(
                color: Colors.black54,
              ),
            ),
          ),
      ],
    ),
  );
}


  Widget _buildInfoCard({required IconData icon, required String title, required String value}) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1F1F1F),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.amber.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
      child: Row(
        children: [
          Icon(icon, color: Colors.amber[200], size: 30),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getInitials(String name) {
    if (name.isEmpty) return 'U';
    final parts = name.trim().split(' ');
    if (parts.isEmpty) return 'U';
    return (parts[0][0] + (parts.length > 1 ? parts[1][0] : '')).toUpperCase();
  }
}
