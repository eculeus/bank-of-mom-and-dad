import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bank_of_mom_and_dad/features/kid/kid_requests_screen.dart';
import 'package:bank_of_mom_and_dad/models/models.dart';

MoneyRequest req(String status) => MoneyRequest(
    id: 'r', kidMemberId: 'm', amountCents: 3000, reason: 'Lego',
    date: DateTime(2026, 8, 9), status: status);

void main() {
  testWidgets('pending tile has no hide button', (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: KidRequestTile(request: req('pending'), onHide: null))));
    expect(find.textContaining('pending'), findsOneWidget);
    expect(find.byIcon(Icons.visibility_off), findsNothing);
  });

  testWidgets('denied tile hides via callback', (tester) async {
    var hidden = false;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: KidRequestTile(request: req('denied'), onHide: () => hidden = true))));
    await tester.tap(find.byIcon(Icons.visibility_off));
    expect(hidden, true);
  });
}
