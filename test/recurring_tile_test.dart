import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bank_of_mom_and_dad/features/parent/recurring_screen.dart';

Map<String, dynamic> entry({required int amountCents, required String interval}) => {
      'kidMemberId': 'm1',
      'amountCents': amountCents,
      'reason': 'Allowance',
      'note': null,
      'interval': interval,
      'nextDueAt': Timestamp.fromDate(DateTime(2026, 8, 17)),
      'active': true,
      'createdByUid': 'u1',
    };

void main() {
  testWidgets('shows reason, signed amount, weekly chip, and fires onDelete', (tester) async {
    var deleted = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: RecurringTile(
          data: entry(amountCents: 1000, interval: 'weekly'),
          kidName: 'Alex',
          onDelete: () => deleted = true,
        ),
      ),
    ));

    expect(find.text('Allowance'), findsOneWidget);
    expect(find.textContaining('+\$10.00'), findsOneWidget);
    expect(find.text('Weekly'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pump();
    expect(deleted, true);
  });

  testWidgets('negative amount monthly interval shows deduction and Monthly chip', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: RecurringTile(
          data: entry(amountCents: -500, interval: 'monthly'),
          kidName: 'Bailey',
        ),
      ),
    ));

    expect(find.textContaining('\$5.00'), findsOneWidget);
    expect(find.text('Monthly'), findsOneWidget);
  });
}
