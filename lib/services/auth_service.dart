import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import '../core/emulators.dart';

class AuthService {
  // Lazy getter: widget tests construct screens without Firebase initialized.
  FirebaseAuth get _auth => FirebaseAuth.instance;

  Future<void> signInWithGoogle() async {
    final provider = GoogleAuthProvider()..setCustomParameters({'prompt': 'select_account'});
    // Popups die on mobile Safari (the opener tab gets backgrounded and WebKit
    // closes IndexedDB mid-sign-in: "Database is closing/hidden"), so use the
    // single-tab redirect flow on phones/tablets.
    final mobileWeb = kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.android);
    if (mobileWeb) {
      await _auth.signInWithRedirect(provider);
    } else {
      await _auth.signInWithPopup(provider);
    }
  }

  /// Emulator-only test accounts; creates on first use.
  Future<void> signInWithTestAccount(String email, String password) async {
    if (!kUseEmulators) {
      throw StateError('Test accounts are emulator-only');
    }
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        await _auth.createUserWithEmailAndPassword(email: email, password: password);
      } else {
        rethrow;
      }
    }
  }

  Future<void> signOut() => _auth.signOut();
}
