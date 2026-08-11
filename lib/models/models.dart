import 'package:cloud_firestore/cloud_firestore.dart';

DateTime? _toDate(Object? v) => v is Timestamp ? v.toDate() : null;
Timestamp? _toTs(DateTime? d) => d == null ? null : Timestamp.fromDate(d);

class FamilyEntry {
  final String role, memberId, status, familyName;
  final bool isOwner;
  const FamilyEntry({required this.role, required this.memberId, required this.status, required this.familyName, this.isOwner = false});
  factory FamilyEntry.fromMap(Map<String, dynamic> m) => FamilyEntry(
      role: m['role'] as String,
      memberId: m['memberId'] as String,
      status: m['status'] as String,
      familyName: (m['familyName'] as String?) ?? '',
      isOwner: (m['isOwner'] as bool?) ?? false);
}

class AppUser {
  final String uid, displayName, email;
  final Map<String, FamilyEntry> families;
  final String? activeFamilyId;
  const AppUser({required this.uid, required this.displayName, required this.email, required this.families, this.activeFamilyId});
  factory AppUser.fromMap(String uid, Map<String, dynamic> m) => AppUser(
      uid: uid,
      displayName: (m['displayName'] as String?) ?? '',
      email: (m['email'] as String?) ?? '',
      activeFamilyId: m['activeFamilyId'] as String?,
      families: ((m['families'] as Map<String, dynamic>?) ?? {})
          .map((k, v) => MapEntry(k, FamilyEntry.fromMap((v as Map).cast<String, dynamic>()))));
}

class Member {
  final String id, email, role, displayName, status;
  final String? uid;
  final bool isOwner;
  final int balanceCents, colorIndex;
  final DateTime? lastSeenAt;
  const Member({required this.id, required this.email, this.uid, required this.role, required this.displayName, required this.status, this.isOwner = false, this.balanceCents = 0, this.colorIndex = 0, this.lastSeenAt});
  factory Member.fromMap(String id, Map<String, dynamic> m) => Member(
      id: id,
      email: m['email'] as String,
      uid: m['uid'] as String?,
      role: m['role'] as String,
      displayName: m['displayName'] as String,
      status: m['status'] as String,
      isOwner: (m['isOwner'] as bool?) ?? false,
      balanceCents: (m['balanceCents'] as num?)?.toInt() ?? 0,
      colorIndex: (m['colorIndex'] as num?)?.toInt() ?? 0,
      lastSeenAt: _toDate(m['lastSeenAt']));
  Map<String, dynamic> toMap() => {
        'email': email, 'uid': uid, 'role': role, 'displayName': displayName,
        'status': status, 'isOwner': isOwner, 'balanceCents': balanceCents,
        'colorIndex': colorIndex, 'lastSeenAt': _toTs(lastSeenAt),
      };
}

class BankTransaction {
  final String id, kidMemberId, reason, source, createdByUid;
  final int amountCents;
  final DateTime date;
  final String? note, requestId;
  final DateTime? createdAt;
  final DateTime? editedAt;
  const BankTransaction({required this.id, required this.kidMemberId, required this.amountCents, required this.reason, required this.date, this.note, required this.source, this.requestId, required this.createdByUid, this.createdAt, this.editedAt});
  factory BankTransaction.fromMap(String id, Map<String, dynamic> m) => BankTransaction(
      id: id,
      kidMemberId: m['kidMemberId'] as String,
      amountCents: (m['amountCents'] as num).toInt(),
      reason: m['reason'] as String,
      date: _toDate(m['date'])!,
      note: m['note'] as String?,
      source: m['source'] as String,
      requestId: m['requestId'] as String?,
      createdByUid: m['createdByUid'] as String,
      createdAt: _toDate(m['createdAt']),
      editedAt: _toDate(m['editedAt']));
  Map<String, dynamic> toMap() => {
        'kidMemberId': kidMemberId, 'amountCents': amountCents, 'reason': reason,
        'date': _toTs(date), 'note': note, 'source': source, 'requestId': requestId,
        'createdByUid': createdByUid, 'createdAt': _toTs(createdAt), 'editedAt': _toTs(editedAt),
      };
}

class MoneyRequest {
  final String id, kidMemberId, reason, status;
  final int amountCents;
  final DateTime date;
  final String? note, decidedByUid;
  final bool hiddenByKid;
  final DateTime? createdAt;
  final String origin;
  final String? recurringId;
  const MoneyRequest({required this.id, required this.kidMemberId, required this.amountCents, required this.reason, required this.date, this.note, required this.status, this.decidedByUid, this.hiddenByKid = false, this.createdAt, this.origin = 'kid', this.recurringId});
  factory MoneyRequest.fromMap(String id, Map<String, dynamic> m) => MoneyRequest(
      id: id,
      kidMemberId: m['kidMemberId'] as String,
      amountCents: (m['amountCents'] as num).toInt(),
      reason: m['reason'] as String,
      date: _toDate(m['date'])!,
      note: m['note'] as String?,
      status: m['status'] as String,
      decidedByUid: m['decidedByUid'] as String?,
      hiddenByKid: (m['hiddenByKid'] as bool?) ?? false,
      createdAt: _toDate(m['createdAt']),
      origin: (m['origin'] as String?) ?? 'kid',
      recurringId: m['recurringId'] as String?);
  Map<String, dynamic> toMap() => {
        'kidMemberId': kidMemberId, 'amountCents': amountCents, 'reason': reason,
        'date': _toTs(date), 'note': note, 'status': status,
        'decidedByUid': decidedByUid, 'hiddenByKid': hiddenByKid, 'createdAt': _toTs(createdAt),
        'origin': origin, 'recurringId': recurringId,
      };
}

extension BankTransactionLabels on BankTransaction {
  String get editedAtLabel => editedAt == null ? '' : ' · edited';
}
