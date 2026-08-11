import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import '../app.dart' show rootScaffoldMessengerKey;
import '../core/config.dart';
import '../core/emulators.dart';

class MessagingService {
  final Set<String> _registeredUids = {};
  bool _listenerAttached = false;

  Future<void> init(String uid) async {
    if (kUseEmulators) return;
    if (!_registeredUids.contains(uid)) {
      try {
        final messaging = FirebaseMessaging.instance;
        final settings = await messaging.requestPermission();
        if (settings.authorizationStatus == AuthorizationStatus.authorized) {
          final token = await messaging.getToken(vapidKey: kVapidKey);
          if (token != null) {
            await FirebaseFirestore.instance.doc('users/$uid').set(
                {'fcmTokens': FieldValue.arrayUnion([token])}, SetOptions(merge: true));
          }
        }
        _registeredUids.add(uid);
      } catch (e) {
        debugPrint('Messaging init failed (non-fatal): $e');
      }
    }
    if (!_listenerAttached) {
      _listenerAttached = true;
      FirebaseMessaging.onMessage.listen((msg) {
        final body = msg.notification?.body;
        if (body != null) {
          rootScaffoldMessengerKey.currentState
              ?.showSnackBar(SnackBar(content: Text(body)));
        }
      });
    }
  }
}
