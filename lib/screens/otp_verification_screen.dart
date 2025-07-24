import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class OtpVerificationScreen extends StatefulWidget {
  final String verificationId;
  final String phoneNumber;

  const OtpVerificationScreen({
    super.key,
    required this.verificationId,
    required this.phoneNumber,
  });

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final TextEditingController _otpController = TextEditingController();
  bool loading = false;
  String? error;

  Future<void> _verifyOtp() async {
    setState(() => loading = true);
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: widget.verificationId,
        smsCode: _otpController.text.trim(),
      );
      await FirebaseAuth.instance.signInWithCredential(credential);
      if (mounted) Navigator.pushReplacementNamed(context, '/dashboard');
    } catch (e) {
      setState(() {
        loading = false;
        error = 'Invalid OTP';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Enter OTP Sent to ${widget.phoneNumber}',
                style: TextStyle(color: Colors.amber, fontSize: 18, fontWeight: FontWeight.w600)),
            SizedBox(height: 20),
            TextField(
              controller: _otpController,
              keyboardType: TextInputType.number,
              style: TextStyle(color: Colors.amber),
              decoration: InputDecoration(
                labelText: '6-digit OTP',
                labelStyle: TextStyle(color: Colors.amber),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.amber),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.amber, width: 2),
                ),
              ),
            ),
            SizedBox(height: 20),
            if (error != null) Text(error!, style: TextStyle(color: Colors.redAccent)),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _verifyOtp,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                padding: EdgeInsets.symmetric(horizontal: 40, vertical: 14),
              ),
              child: loading
                  ? CircularProgressIndicator(color: Colors.black)
                  : Text('Verify', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            )
          ],
        ),
      ),
    );
  }
}
