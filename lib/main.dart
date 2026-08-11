import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'core/emulators.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: _optionsForHost());
  if (kUseEmulators) await connectEmulators();
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
