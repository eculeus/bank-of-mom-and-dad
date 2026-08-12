import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bank_of_mom_and_dad/features/parent/transaction_sheet.dart';
import 'package:bank_of_mom_and_dad/models/models.dart';

Member kid(String id, String name) => Member(
    id: id, email: '$id@x.com', role: 'kid', displayName: name, status: 'active');

void main() {
  testWidgets('save disabled until valid; sign toggle negates cents', (tester) async {
    int? submittedCents;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: TransactionSheet(
          kids: [kid('m1', 'Alex'), kid('m2', 'Bailey')],
          onSubmit: ({required kidMemberId, required amountCents, required reason, required date, note}) async {
            submittedCents = amountCents;
          },
        ),
      ),
    ));
    final save = find.widgetWithText(FilledButton, 'Save');
    expect(tester.widget<FilledButton>(save).onPressed, isNull);

    await tester.tap(find.text('Alex'));
    await tester.enterText(find.byKey(const Key('amount')), '12.50');
    await tester.enterText(find.byKey(const Key('reason')), 'Chores');
    await tester.pump();
    expect(tester.widget<FilledButton>(save).onPressed, isNotNull);

    await tester.tap(find.text('Deduct'));
    await tester.pump();
    await tester.tap(save);
    await tester.pump();
    expect(submittedCents, -1250);
  });

  testWidgets('editing an existing transaction prefills fields', (tester) async {
    final existing = BankTransaction(
        id: 't1', kidMemberId: 'm1', amountCents: -500, reason: 'Candy',
        date: DateTime(2026, 8, 1), source: 'parent', createdByUid: 'u1');
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: TransactionSheet(
          kids: [kid('m1', 'Alex')],
          existing: existing,
          onSubmit: ({required kidMemberId, required amountCents, required reason, required date, note}) async {},
        ),
      ),
    ));
    expect(find.text('Candy'), findsOneWidget);
    expect(find.text('5.00'), findsOneWidget); // magnitude; Deduct toggle carries the sign
  });

  testWidgets('failed submit surfaces an error and does not pop the sheet', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: TransactionSheet(
          kids: [kid('m1', 'Alex')],
          onSubmit: ({required kidMemberId, required amountCents, required reason, required date, note}) async {
            throw Exception('network down');
          },
        ),
      ),
    ));

    // Single kid: picker is hidden and the kid is auto-selected, so no chip tap.
    expect(find.text('Alex'), findsNothing);
    await tester.enterText(find.byKey(const Key('amount')), '5.00');
    await tester.enterText(find.byKey(const Key('reason')), 'Allowance');
    await tester.pump();

    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pump();

    expect(find.text('New transaction'), findsOneWidget);
    expect(find.textContaining('network down'), findsOneWidget);
  });
}
