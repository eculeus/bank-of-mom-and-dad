import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import '../services/auth_service.dart';
import '../services/functions_service.dart';

final authServiceProvider = Provider((ref) => AuthService());
final functionsServiceProvider = Provider((ref) => FunctionsService());

final authStateProvider =
    StreamProvider<User?>((ref) => FirebaseAuth.instance.authStateChanges());

final appUserProvider = StreamProvider<AppUser?>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value(null);
  return FirebaseFirestore.instance
      .doc('users/${user.uid}')
      .snapshots()
      .map((s) => s.exists ? AppUser.fromMap(s.id, s.data()!) : null);
});

/// Runs joinFamily once per signed-in uid per app load (links fresh invites).
final joinFamilyOnceProvider = FutureProvider.family<void, String>((ref, uid) async {
  await ref.read(functionsServiceProvider).joinFamily();
});

final activeFamilyProvider = Provider<({String id, FamilyEntry entry})?>((ref) {
  final user = ref.watch(appUserProvider).value;
  if (user == null) return null;
  final live = Map.of(user.families)..removeWhere((_, e) => e.status == 'deleted');
  if (live.isEmpty) return null;
  final id = live.containsKey(user.activeFamilyId) ? user.activeFamilyId! : live.keys.first;
  return (id: id, entry: live[id]!);
});

final membersProvider = StreamProvider.family<List<Member>, String>((ref, familyId) =>
    FirebaseFirestore.instance
        .collection('families/$familyId/members')
        .snapshots()
        .map((s) => s.docs.map((d) => Member.fromMap(d.id, d.data())).toList()));

final kidsProvider = Provider.family<List<Member>, String>((ref, familyId) {
  final members = ref.watch(membersProvider(familyId)).value ?? const <Member>[];
  final kids = members.where((m) => m.role == 'kid' && m.status != 'deleted').toList()
    ..sort((a, b) => a.displayName.compareTo(b.displayName));
  return kids;
});

final pendingRequestsProvider = StreamProvider.family<List<MoneyRequest>, String>(
    (ref, familyId) => FirebaseFirestore.instance
        .collection('families/$familyId/requests')
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => MoneyRequest.fromMap(d.id, d.data())).toList()));

final kidTransactionsProvider = StreamProvider.family<List<BankTransaction>,
    ({String familyId, String kidMemberId})>((ref, key) => FirebaseFirestore.instance
        .collection('families/${key.familyId}/transactions')
        .where('kidMemberId', isEqualTo: key.kidMemberId)
        .orderBy('date', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => BankTransaction.fromMap(d.id, d.data())).toList()));

final memberProvider = StreamProvider.family<Member?, ({String familyId, String memberId})>(
    (ref, key) => FirebaseFirestore.instance
        .doc('families/${key.familyId}/members/${key.memberId}')
        .snapshots()
        .map((s) => s.exists ? Member.fromMap(s.id, s.data()!) : null));

final myRequestsProvider = StreamProvider.family<List<MoneyRequest>,
    ({String familyId, String kidMemberId})>((ref, key) => FirebaseFirestore.instance
        .collection('families/${key.familyId}/requests')
        .where('kidMemberId', isEqualTo: key.kidMemberId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => MoneyRequest.fromMap(d.id, d.data())).toList()));

/// Recurring templates as raw (id, data) records — parent-only UI state, no shared model.
final recurringProvider = StreamProvider.family<List<(String, Map<String, dynamic>)>, String>(
    (ref, familyId) => FirebaseFirestore.instance
        .collection('families/$familyId/recurring')
        .orderBy('nextDueAt')
        .snapshots()
        .map((s) => s.docs.map((d) => (d.id, d.data())).toList()));
