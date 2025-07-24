// ignore_for_file: prefer_const_constructors

import 'package:flutter/material.dart';
import 'package:fuel_app/main.dart';
import 'dart:async';

import 'dashboard_screen.dart'; // Or your next/main screen

class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Wait for 3 seconds, then navigate
    Timer(Duration(seconds: 3), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => AuthWrapper()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Full screen image
          Positioned.fill(
            child: Image.asset(
              'assets/icon/logo.jpeg',
              fit: BoxFit.cover,
            ),
          ),
          // Amber loader at bottom center
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: CircularProgressIndicator(
                color: Colors.amber,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
