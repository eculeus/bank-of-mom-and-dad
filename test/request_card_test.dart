import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bank_of_mom_and_dad/features/parent/requests_screen.dart';
import 'package:bank_of_mom_and_dad/models/models.dart';

void main() {
  testWidgets('request card shows details and fires decisions', (tester) async {
    bool? decided;
    final req = MoneyRequest(
        id: 'r1', kidMemberId: 'm1', amountCents: 3000, reason: 'Lego set',
        date: DateTime(2026, 8, 9), status: 'pending');
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: RequestCard(
                request: req, kidName: 'Alex',
                onDecide: (approve) async => decided = approve))));
    expect(find.text('Alex'), findsOneWidget);
    expect(find.text('Lego set'), findsOneWidget);
    expect(find.textContaining(r'+$30.00'), findsOneWidget);
    await tester.tap(find.text('Approve'));
    await tester.pump();
    expect(decided, true);
  });
}
