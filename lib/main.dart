import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'core/emulators.dart';
import 'firebase_options.dart';

// Public reCAPTCHA Enterprise site key (safe to embed, like the Firebase config).
const _recaptchaSiteKey = '6Ld5DqItAAAAADq1qqUTmLPR5qMpHIOXrbR9AusX';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: _optionsForHost());
  if (kUseEmulators) {
    await connectEmulators();
  } else {
    // App Check attests that requests come from our genuine app — reCAPTCHA
    // Enterprise on web, App Attest on iOS. Skipped under the emulator.
    // Server-side enforcement is deliberately left OFF (monitor mode) until
    // every shipped client sends tokens and metrics confirm valid traffic.
    // The non-deprecated providerWeb/providerApple want different types in
    // 0.4.x; these params work and won't be removed until a future major.
    await FirebaseAppCheck.instance.activate(
      // ignore: deprecated_member_use
      webProvider: ReCaptchaEnterpriseProvider(_recaptchaSiteKey),
      // ignore: deprecated_member_use
      appleProvider: AppleProvider.appAttest,
    );
  }
  runApp(const ProviderScope(child: BankApp()));
}

/// Serve the OAuth handler from the domain the app itself is on (Firebase
/// Hosting proxies /__/auth/ on every site of the project). Same-origin auth
/// keeps Safari's tracking prevention from breaking the redirect sign-in.
FirebaseOptions _optionsForHost() {
  final base = DefaultFirebaseOptions.currentPlatform;
  final host = Uri.base.host;
  final onHosting = host.endsWith('.web.app') || host.endsWith('.firebaseapp.com');
  if (!kIsWeb || !onHosting) return base;
  return FirebaseOptions(
    apiKey: base.apiKey,
    appId: base.appId,
    messagingSenderId: base.messagingSenderId,
    projectId: base.projectId,
    authDomain: host,
    storageBucket: base.storageBucket,
    measurementId: base.measurementId,
  );
}
