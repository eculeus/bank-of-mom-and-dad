import 'package:firebase_auth/firebase_auth.dart';
import '../core/emulators.dart';

class AuthService {
  // Lazy getter: widget tests construct screens without Firebase initialized.
  FirebaseAuth get _auth => FirebaseAuth.instance;

  Future<void> signInWithGoogle() async {
    final provider = GoogleAuthProvider()..setCustomParameters({'prompt': 'select_account'});
    await _auth.signInWithPopup(provider);
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
