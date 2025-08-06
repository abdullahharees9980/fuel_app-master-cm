// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables, deprecated_member_use, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:fuel_app/screens/register_screen.dart';
import 'package:provider/provider.dart';
import '../auth_service.dart';


import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  String email = '';
  String password = '';
  String? error;
  bool loading = false;

  late final AnimationController _errorAnimController;
  late final Animation<double> _errorFade;

  @override
  void initState() {
    super.initState();
    _errorAnimController = AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
    _errorFade = CurvedAnimation(parent: _errorAnimController, curve: Curves.easeIn);
  }

  @override
  void dispose() {
    _errorAnimController.dispose();
    super.dispose();
  }

  void _showError(String? message) {
    setState(() {
      error = message;
      if (error != null) {
        _errorAnimController.forward();
      } else {
        _errorAnimController.reverse();
      }
    });
  }

  Future<void> saveFcmTokenToFirestore() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final token = await FirebaseMessaging.instance.getToken();
    if (token != null) {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'fcmToken': token,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.black,

      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1A1A1A), Color(0xFF0D0D0D)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Stack(
          children: [
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[900]?.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.amber.withOpacity(0.3),
                        blurRadius: 24,
                        spreadRadius: 1,
                        offset: const Offset(0, 10),
                      ),
                      BoxShadow(
                        color: Colors.black.withOpacity(0.6),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 32),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Welcome Back',
                          style: TextStyle(
                            color: Colors.amber,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Login to continue fueling your journey',
                          style: TextStyle(
                            color: Colors.amber[300],
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        const SizedBox(height: 28),

                        // Animated error message
                        SizeTransition(
                          sizeFactor: _errorFade,
                          axisAlignment: -1,
                          child: error != null
                              ? Container(
                                  margin: const EdgeInsets.only(bottom: 20),
                                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                  decoration: BoxDecoration(
                                    color: Colors.redAccent.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.error_outline, color: Colors.redAccent),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          error!,
                                          style: const TextStyle(
                                            color: Colors.redAccent,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      InkWell(
                                        borderRadius: BorderRadius.circular(12),
                                        onTap: () => _showError(null),
                                        child: const Padding(
                                          padding: EdgeInsets.all(4.0),
                                          child: Icon(Icons.close, size: 20, color: Colors.redAccent),
                                        ),
                                      )
                                    ],
                                  ),
                                )
                              : const SizedBox.shrink(),
                        ),

                        _buildTextField(
                          label: 'Email',
                          icon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                          onChanged: (val) => email = val,
                          validator: (val) =>
                              val == null || !val.contains('@') ? 'Please enter a valid email' : null,
                        ),
                        const SizedBox(height: 20),
                        _buildTextField(
                          label: 'Password',
                          icon: Icons.lock_outline,
                          obscureText: true,
                          onChanged: (val) => password = val,
                          validator: (val) =>
                              val == null || val.length < 6 ? 'Password must be at least 6 characters' : null,
                        ),
                        const SizedBox(height: 12),

                        _buildGradientButton(
                          text: 'Login',
                          onPressed: () async {
                            if (_formKey.currentState!.validate()) {
                              setState(() {
                                loading = true;
                                _showError(null);
                              });

                      final res = await auth.login(email: email.trim(), password: password.trim());

if (!mounted) return;

if (res == null) {

  await saveFcmTokenToFirestore();

  if (mounted) {
    setState(() {
      loading = false;
    });

  
    Navigator.of(context).pushReplacementNamed('/main');
  }
} else {
  setState(() {
    _showError(res);
    loading = false;
  });
}

                            }
                          },
                        ),
                        const SizedBox(height: 20),

                 _buildGoogleButton(() async {
                  setState(() {
                    loading = true;
                    _showError(null);
                  });

     final res = await auth.signInWithGoogle();

if (!mounted) return;

if (res != null) {
  setState(() {
    _showError(res);
    loading = false;
  });
} else {
  await FirebaseAuth.instance.currentUser?.reload();
  await saveFcmTokenToFirestore();

  if (mounted) {
    setState(() {
      loading = false;
    });


    Navigator.of(context).pushReplacementNamed('/main');
  }
}

                        }),

                        const SizedBox(height: 30),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "Don't have an account?",
                              style: TextStyle(color: Colors.amber[300], fontWeight: FontWeight.w500),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => const RegistrationScreen()),
                                );
                              },
                              child: const Text(
                                'Sign up',
                                style: TextStyle(
                                  color: Colors.amber,
                                  fontWeight: FontWeight.bold,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            if (loading)
              Container(
                color: Colors.black.withOpacity(0.7),
                child: const Center(
                  child: CircularProgressIndicator(color: Colors.amber),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required IconData icon,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
    required void Function(String) onChanged,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.amber),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: const BorderSide(color: Colors.amber, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: const BorderSide(color: Colors.amber, width: 2.5),
        ),
        prefixIcon: Icon(icon, color: Colors.amber),
        filled: true,
        fillColor: Colors.grey[850]?.withOpacity(0.9),
        contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
        floatingLabelBehavior: FloatingLabelBehavior.auto,
      ),
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
      onChanged: onChanged,
    );
  }

  Widget _buildGradientButton({required String text, required VoidCallback onPressed}) {
    return InkWell(
      borderRadius: BorderRadius.circular(30),
      splashColor: Colors.amberAccent.withOpacity(0.4),
      onTap: onPressed,
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFFC107), Color(0xFFFFA000)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.amber.withOpacity(0.5),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w900,
            fontSize: 18,
            letterSpacing: 1.1,
          ),
        ),
      ),
    );
  }

  Widget _buildGoogleButton(VoidCallback onPressed) {
    return InkWell(
      borderRadius: BorderRadius.circular(30),
      onTap: onPressed,
      splashColor: Colors.white24,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Colors.amber),
          color: Colors.transparent,
          boxShadow: [
            BoxShadow(
              color: Colors.amber.withOpacity(0.15),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/google_logo.png', height: 24),
            const SizedBox(width: 12),
            const Text(
              'Sign in with Google',
              style: TextStyle(
                color: Colors.amber,
                fontWeight: FontWeight.bold,
                fontSize: 16,
                letterSpacing: 0.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
