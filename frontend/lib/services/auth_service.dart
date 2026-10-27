// Login with Firebase (Google + email/password with a verification link) when it is set up,
// otherwise the backend's own email/password login. Screens only call AuthService.
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../config.dart';
import 'api.dart';

/// Thrown when the e-mail address has not been verified yet.
class NeedsVerification implements Exception {
  final String email;
  NeedsVerification(this.email);
  @override
  String toString() => 'Please verify your email first. We sent a link to $email - open it, then sign in again.';
}

class AuthService {
  /// True when both the app and the backend are set up for Firebase.
  static bool get useFirebase => AppConfig.firebaseReady && AppConfig.backendFirebase;

  static String _friendly(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'This email already has an account. Try signing in.';
      case 'invalid-email':
        return 'That email address does not look right.';
      case 'weak-password':
        return 'Choose a stronger password (at least 6 characters).';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Wrong email or password.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a few minutes and try again.';
      case 'popup-closed-by-user':
      case 'cancelled-popup-request':
      case 'canceled':
        return 'Sign-in was cancelled.';
      case 'network-request-failed':
        return 'No internet connection.';
      default:
        return e.message ?? 'Sign-in failed (${e.code})';
    }
  }

  static Future<bool> _exchange(User u, {String? role}) async {
    final idToken = await u.getIdToken(true);
    return Api.I.firebaseLogin(idToken!, role: role, fullName: u.displayName, language: Api.I.language);
  }

  /// Google sign-in. Returns true when this is a brand new account (the app then asks for the role).
  static Future<bool> google() async {
    try {
      final provider = GoogleAuthProvider();
      final cred = kIsWeb ? await FirebaseAuth.instance.signInWithPopup(provider) : await FirebaseAuth.instance.signInWithProvider(provider);
      return await _exchange(cred.user!);
    } on FirebaseAuthException catch (e) {
      throw ApiException(0, _friendly(e));
    }
  }

  /// Creates the account and e-mails a verification link. The user is signed out until the link is opened.
  static Future<void> register({required String name, required String email, required String password, required String role}) async {
    try {
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(email: email, password: password);
      await cred.user!.updateDisplayName(name);
      await cred.user!.sendEmailVerification();
      await Api.I.savePendingRole(email, role);
      await FirebaseAuth.instance.signOut();
    } on FirebaseAuthException catch (e) {
      throw ApiException(0, _friendly(e));
    }
  }

  static Future<void> signIn(String email, String password) async {
    try {
      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(email: email, password: password);
      await cred.user!.reload();
      final u = FirebaseAuth.instance.currentUser!;
      if (!u.emailVerified) {
        await FirebaseAuth.instance.signOut();
        throw NeedsVerification(email);
      }
      await _exchange(u, role: await Api.I.takePendingRole(email));
    } on FirebaseAuthException catch (e) {
      throw ApiException(0, _friendly(e));
    }
  }

  static Future<void> resendVerification(String email, String password) async {
    try {
      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(email: email, password: password);
      if (!cred.user!.emailVerified) await cred.user!.sendEmailVerification();
      await FirebaseAuth.instance.signOut();
    } on FirebaseAuthException catch (e) {
      throw ApiException(0, _friendly(e));
    }
  }

  static Future<void> resetPassword(String email) async {
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw ApiException(0, _friendly(e));
    }
  }

  static Future<void> signOut() async {
    if (AppConfig.firebaseReady) {
      try {
        await FirebaseAuth.instance.signOut();
      } catch (_) {}
    }
    await Api.I.logout();
  }
}
