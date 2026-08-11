import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

const bool kTestMode = bool.fromEnvironment('TEST_MODE');
const bool kUseEmulators = bool.fromEnvironment('USE_EMULATORS');

Future<void> connectEmulators() async {
  await FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
  FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
  FirebaseFunctions.instanceFor(region: 'us-central1')
      .useFunctionsEmulator('localhost', 5001);
}
