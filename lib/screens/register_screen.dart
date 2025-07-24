// ignore_for_file: prefer_const_constructors

import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fuel_app/main.dart';
import 'package:provider/provider.dart';
import '../auth_service.dart';
import 'dashboard_screen.dart';

class RegistrationScreen extends StatefulWidget {
  static const routeName = '/register';
  const RegistrationScreen({Key? key}) : super(key: key);

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  String _name = '';
  String _email = '';
  String _password = '';
  bool _isLoading = false;
  String? _errorMessage;
  bool _passwordVisible = false;

  late final AnimationController _errorAnimController;
  late final Animation<double> _errorFade;
Future<void> _showEmailVerificationDialog(User user) async {
  bool isVerified = false;
  late Timer timer;


  timer = Timer.periodic(const Duration(seconds: 3), (t) async {
    await user.reload();
    final refreshedUser = FirebaseAuth.instance.currentUser;
    if (refreshedUser != null && refreshedUser.emailVerified) {
      isVerified = true;
      t.cancel();
      if (mounted) {
        Navigator.of(context).pop(); 
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => MainScreen()),
        );
      }
    }
  });


  await showDialog(
    context: context,
    barrierDismissible: false, 
    builder: (BuildContext context) {
      return WillPopScope(
        onWillPop: () async => false, 
        child: AlertDialog(
          title: const Text('Verify your email'),
          content: const Text(
            'A verification link has been sent to your email.\n\n'
            'Please check your inbox and verify your account.'
          ),
        ),
      );
    },
  );

  // Fallback cleanup
  if (!isVerified) timer.cancel();
}



  @override
  void initState() {
    super.initState();
    _passwordVisible = false;
    _errorAnimController =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
    _errorFade = CurvedAnimation(parent: _errorAnimController, curve: Curves.easeIn);
  }

  @override
  void dispose() {
    _errorAnimController.dispose();
    super.dispose();
  }

  void _showError(String? message) {
    setState(() {
      _errorMessage = message;
      if (_errorMessage != null) {
        _errorAnimController.forward();
      } else {
        _errorAnimController.reverse();
      }
    });
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    // Trim inputs explicitly to avoid whitespace issues
    _email = _email.trim();
    _name = _name.trim();
    _password = _password.trim();

    setState(() {
      _isLoading = true;
      _showError(null);
    });

    final auth = Provider.of<AuthService>(context, listen: false);
   final error = await auth.register(
  email: _email,
  password: _password,
  name: _name,
);


    if (error == null) {
      await Future.delayed(const Duration(milliseconds: 300));
      if (auth.user != null) {
        if (!mounted) return;
      await _showEmailVerificationDialog(auth.user!);

      } else {
        _showError('User creation succeeded but login failed. Try again.');
      }
    } else {
      _showError(error);
    }

    setState(() {
      _isLoading = false;
    });
  }

  Widget _buildTextField({
    required String label,
    required bool obscure,
    required TextInputType keyboardType,
    String? Function(String?)? validator,
    void Function(String?)? onSaved,
    Widget? suffixIcon,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
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
          filled: true,
          fillColor: Colors.grey[850]?.withOpacity(0.9),
          contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
          floatingLabelBehavior: FloatingLabelBehavior.auto,
          suffixIcon: suffixIcon,
        ),
        obscureText: obscure,
        keyboardType: keyboardType,
        validator: validator,
        onSaved: onSaved,
        cursorColor: Colors.amber,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.amber),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1A1A1A), Color(0xFF0D0D0D)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
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
                      'Create Account',
                      style: TextStyle(
                        color: Colors.amber,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Sign up to start your fuel journey',
                      style: TextStyle(
                        color: Colors.amber[300],
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 28),

                    SizeTransition(
                      sizeFactor: _errorFade,
                      axisAlignment: -1,
                      child: _errorMessage != null
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
                                      _errorMessage!,
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
                      label: 'Name',
                      obscure: false,
                      keyboardType: TextInputType.name,
                      validator: (val) =>
                          val == null || val.trim().isEmpty ? 'Enter name' : null,
                      onSaved: (val) => _name = val!.trim(),
                    ),

                    _buildTextField(
                      label: 'Email',
                      obscure: false,
                      keyboardType: TextInputType.emailAddress,
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'Enter email';
                        final regex = RegExp(
                            r"^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$"); // better email regex
                        return regex.hasMatch(val.trim()) ? null : 'Invalid email';
                      },
                      onSaved: (val) => _email = val!.trim(),
                    ),

             

                    _buildTextField(
                      label: 'Password',
                      obscure: !_passwordVisible,
                      keyboardType: TextInputType.visiblePassword,
                      validator: (val) =>
                          val == null || val.length < 6 ? 'At least 6 characters' : null,
                      onSaved: (val) => _password = val!.trim(),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _passwordVisible ? Icons.visibility_off : Icons.visibility,
                          color: Colors.amber,
                        ),
                        onPressed: () {
                          setState(() {
                            _passwordVisible = !_passwordVisible;
                          });
                        },
                      ),
                    ),

                    const SizedBox(height: 30),

                    InkWell(
                      borderRadius: BorderRadius.circular(30),
                      splashColor: Colors.amberAccent.withOpacity(0.4),
                      onTap: _isLoading ? null : _register,
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
                        child: _isLoading
                            ? const SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 3,
                                  color: Colors.black,
                                ),
                              )
                            : const Text(
                                'Register',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 18,
                                  letterSpacing: 1.1,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
