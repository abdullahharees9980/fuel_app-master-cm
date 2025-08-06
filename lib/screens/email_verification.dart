import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class EmailVerificationScreen extends StatefulWidget {
  const EmailVerificationScreen({Key? key}) : super(key: key);

  @override
  State<EmailVerificationScreen> createState() => _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  late Timer _timer;
  bool _isVerified = false;
  bool _isSending = false;
  String? _errorMessage;
  bool _canResend = true;
  int _cooldown = 60;
  int _resendAttempts = 0;
  Timer? _cooldownTimer;

  @override
  void initState() {
    super.initState();
    _startEmailCheckTimer();
  }

  void _startEmailCheckTimer() {
    _timer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) {
          timer.cancel();
          return;
        }
        await user.reload();
        if (user.emailVerified) {
          setState(() => _isVerified = true);
          timer.cancel();
          Navigator.of(context).pushReplacementNamed('/main');
        }
      } catch (e) {
        debugPrint('Error during email verification check: $e');
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  void _startCooldown() {
    setState(() {
      _canResend = false;
    });

    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _cooldown--;
      });

      if (_cooldown <= 0) {
        timer.cancel();
        setState(() {
          _canResend = true;
          _cooldown = 60 * (_resendAttempts + 1); // exponential backoff
        });
      }
    });
  }

  Future<void> _sendVerificationEmail() async {
    if (!_canResend) return;

    setState(() {
      _isSending = true;
      _errorMessage = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        setState(() => _errorMessage = 'User not signed in.');
        return;
      }

      if (user.emailVerified) {
        setState(() => _errorMessage = 'Email already verified.');
        return;
      }

      await user.sendEmailVerification();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Verification email sent. Please check your inbox.')),
      );

      _resendAttempts++;
      if (_resendAttempts >= 3) {
        setState(() {
          _canResend = false;
          _errorMessage = 'You have reached the maximum number of resend attempts. Please try again later.';
        });
      } else {
        _startCooldown();
      }
    } on FirebaseAuthException catch (e) {
      debugPrint('FirebaseAuthException: ${e.code} - ${e.message}');
      if (e.code == 'too-many-requests') {
        setState(() {
          _errorMessage = 'Too many requests. Please wait a while before trying again.';
          _canResend = false;
        });
      } else {
        setState(() => _errorMessage = e.message ?? 'Failed to send verification email.');
      }
    } catch (e) {
      debugPrint('Unknown error: $e');
      setState(() => _errorMessage = 'Failed to send verification email. Try again later.');
    } finally {
      setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Verify Your Email'),
          automaticallyImplyLeading: false,
        ),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: _isVerified
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.verified, size: 100, color: Colors.green),
                      SizedBox(height: 24),
                      Text(
                        'Your email has been verified!\nRedirecting...',
                        style: TextStyle(fontSize: 18),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 24),
                      CircularProgressIndicator(),
                    ],
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.email_outlined, size: 100, color: Colors.amber),
                      const SizedBox(height: 24),
                      const Text(
                        'A verification email has been sent to your email address.\n'
                        'Please check your inbox and verify your account to continue.',
                        style: TextStyle(fontSize: 18),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      if (_errorMessage != null)
                        Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.red),
                          textAlign: TextAlign.center,
                        ),
                      ElevatedButton.icon(
                        icon: _isSending
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.send),
                        label: Text(_resendAttempts >= 3
                            ? 'Limit Reached'
                            : _canResend
                                ? 'Resend Email'
                                : 'Resend in $_cooldown s'),
                        onPressed: (_isSending || !_canResend || _resendAttempts >= 3)
                            ? null
                            : _sendVerificationEmail,
                      ),
                      const SizedBox(height: 24),
                      if (_resendAttempts >= 3)
                        const Text(
                          'You have reached the maximum number of resend attempts.\nTry again later or use SMS verification.',
                          style: TextStyle(color: Colors.orange),
                          textAlign: TextAlign.center,
                        ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
