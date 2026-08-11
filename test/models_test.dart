import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bank_of_mom_and_dad/models/models.dart';

void main() {
  test('Member round-trip with nulls and defaults', () {
    final m = Member.fromMap('m1', {
      'email': 'kid@example.com',
      'uid': null,
      'role': 'kid',
      'displayName': 'Alex',
      'status': 'invited',
      'balanceCents': -13337,
    });
    expect(m.uid, null);
    expect(m.isOwner, false);
    expect(m.balanceCents, -13337);
    expect(m.lastSeenAt, null);
    expect(m.colorIndex, 0);
    final back = m.toMap();
    expect(back['email'], 'kid@example.com');
    expect(back['balanceCents'], -13337);
  });

  test('BankTransaction round-trip', () {
    final t = BankTransaction.fromMap('t1', {
      'kidMemberId': 'm1',
      'amountCents': 3000,
      'reason': 'Worship',
      'date': Timestamp.fromDate(DateTime(2023, 1, 1)),
      'source': 'parent',
      'createdByUid': 'u1',
      'createdAt': Timestamp.fromDate(DateTime(2023, 1, 2)),
    });
    expect(t.date, DateTime(2023, 1, 1));
    expect(t.note, null);
    expect(t.toMap()['date'], Timestamp.fromDate(DateTime(2023, 1, 1)));
  });

  test('BankTransaction editedAt defaults null and editedAtLabel reflects it', () {
    final t = BankTransaction.fromMap('t1', {
      'kidMemberId': 'm1',
      'amountCents': 3000,
      'reason': 'Worship',
      'date': Timestamp.fromDate(DateTime(2023, 1, 1)),
      'source': 'parent',
      'createdByUid': 'u1',
    });
    expect(t.editedAt, null);
    expect(t.editedAtLabel, '');

    final edited = BankTransaction.fromMap('t2', {
      'kidMemberId': 'm1',
      'amountCents': 3000,
      'reason': 'Worship',
      'date': Timestamp.fromDate(DateTime(2023, 1, 1)),
      'source': 'parent',
      'createdByUid': 'u1',
      'editedAt': Timestamp.fromDate(DateTime(2023, 1, 3)),
    });
    expect(edited.editedAt, DateTime(2023, 1, 3));
    expect(edited.editedAtLabel, ' · edited');
    expect(edited.toMap()['editedAt'], Timestamp.fromDate(DateTime(2023, 1, 3)));
  });

  test('MoneyRequest defaults hiddenByKid false and pending', () {
    final r = MoneyRequest.fromMap('r1', {
      'kidMemberId': 'm1',
      'amountCents': -2000,
      'reason': 'cash out',
      'date': Timestamp.fromDate(DateTime(2026, 8, 1)),
      'status': 'pending',
    });
    expect(r.hiddenByKid, false);
    expect(r.decidedByUid, null);
  });

  test('MoneyRequest defaults origin to kid when missing', () {
    final r = MoneyRequest.fromMap('r1', {
      'kidMemberId': 'm1',
      'amountCents': -2000,
      'reason': 'cash out',
      'date': Timestamp.fromDate(DateTime(2026, 8, 1)),
      'status': 'pending',
    });
    expect(r.origin, 'kid');
    expect(r.recurringId, null);
  });

  test('AppUser parses families map', () {
    final u = AppUser.fromMap('u1', {
      'displayName': 'Mom',
      'email': 'parent@example.com',
      'families': {
        'f1': {'role': 'parent', 'memberId': 'm9', 'status': 'active', 'isOwner': true, 'familyName': 'Smith Family Bank'}
      },
      'activeFamilyId': 'f1',
    });
    expect(u.families['f1']!.isOwner, true);
    expect(u.families['f1']!.familyName, 'Smith Family Bank');
  });
}
