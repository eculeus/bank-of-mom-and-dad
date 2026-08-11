import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';
import '../core/emulators.dart';
import '../firebase_options.dart';

class AuthService {
  // Lazy getter: widget tests construct screens without Firebase initialized.
  FirebaseAuth get _auth => FirebaseAuth.instance;

  // GoogleSignIn.instance.initialize() may only be called once per app
  // lifetime; memoize it on this (singleton, provider-owned) instance.
  Future<void>? _googleSignInInit;

  Future<void> signInWithGoogle() async {
    if (!kIsWeb) {
      await _signInWithGoogleNative();
      return;
    }
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

  /// Native (iOS/Android) Google sign-in via the google_sign_in v7 API.
  Future<void> _signInWithGoogleNative() async {
    final googleSignIn = GoogleSignIn.instance;
    _googleSignInInit ??= googleSignIn.initialize(
      clientId: DefaultFirebaseOptions.ios.iosClientId,
    );
    await _googleSignInInit;

    final GoogleSignInAccount account;
    try {
      account = await googleSignIn.authenticate();
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        return; // User backed out of the account picker; not an error.
      }
      rethrow;
    }

    final idToken = account.authentication.idToken;
    final authorization =
        await account.authorizationClient.authorizationForScopes(['email']);

    final credential = GoogleAuthProvider.credential(
      idToken: idToken,
      accessToken: authorization?.accessToken,
    );
    await _auth.signInWithCredential(credential);
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
