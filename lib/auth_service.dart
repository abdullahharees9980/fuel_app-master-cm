import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  User? user;

  AuthService() {
_auth.authStateChanges().listen((User? u) {
  user = u;
  print('🔄 Auth state changed: ${u?.email ?? 'No user'}');
  notifyListeners();
});
  }

  /// Save FCM token to Firestore
  Future<void> _saveFcmTokenToFirestore() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    final fcmToken = await FirebaseMessaging.instance.getToken();
    if (fcmToken != null) {
      await _firestore.collection('users').doc(currentUser.uid).set({
        'fcmToken': fcmToken,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

Future<String?> register({
  required String email,
  required String password,
  required String name,
}) async {
  try {
    // Create user in Firebase Auth
    UserCredential cred = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password.trim(),
    );

    user = _auth.currentUser;

    // Save additional info to Firestore
    await _firestore.collection('users').doc(user!.uid).set({
      'userId': user!.uid,
      'name': name.trim(),
      'email': email.trim(),
      'role': 'user',
      'address': '',
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Send email verification
    await user!.sendEmailVerification();

    // Optionally save FCM token
    await _saveFcmTokenToFirestore();

    notifyListeners();
    return null;
  } on FirebaseAuthException catch (e) {
    return e.message;
  } catch (e) {
    if (kDebugMode) print('Register error: $e');
    return 'An unexpected error occurred during registration.';
  }
}




  
  Future<String?> login({
    required String email,
    required String password,
  }) async {
    try {
      UserCredential cred = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      user = _auth.currentUser;

      await _saveFcmTokenToFirestore(); // ✅ Save FCM token after login

      notifyListeners();
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message;
    } catch (e) {
      if (kDebugMode) print('Login error: $e');
      return 'An unexpected error occurred during login.';
    }
  }

  /// Google Sign-In
 Future<String?> signInWithGoogle() async {
  try {
    final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
    if (googleUser == null) return 'Sign in aborted by user';

    final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    UserCredential userCredential = await _auth.signInWithCredential(credential);
    user = _auth.currentUser;

    // Reload user to refresh emailVerified status
    await user!.reload();
    user = _auth.currentUser;

    final userDoc = await _firestore.collection('users').doc(user!.uid).get();
    if (!userDoc.exists) {
      await _firestore.collection('users').doc(user!.uid).set({
        'userId': user!.uid,
        'name': user!.displayName ?? 'No Name',
        'email': user!.email ?? '',
        'role': 'user',
        'address': '',
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    // No email verification sent here for Google sign-in
    await _saveFcmTokenToFirestore();

    notifyListeners();
    return null;
  } catch (e) {
    if (kDebugMode) print('Google sign-in error: $e');
    return 'An error occurred during Google sign-in.';
  }
}


  /// Logout
Future<void> logout() async {
  print('Logging out...');
  try {
    await _googleSignIn.signOut(); // Google logout (safe to call even if not used)
  } catch (e) {
    if (kDebugMode) print('Google sign out error: $e');
  }

  await _auth.signOut();

  // ✅ DO NOT set user = null manually
  // ✅ Let authStateChanges handle it

  notifyListeners(); // Optional trigger for UI updates
}


}
