import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bank_of_mom_and_dad/widgets/expandable_note.dart';

void main() {
  testWidgets('short note has no toggle', (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: ExpandableNote(text: 'short note'))));
    expect(find.text('more'), findsNothing);
  });

  testWidgets('long note toggles', (tester) async {
    final long = 'x' * 200;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: ExpandableNote(text: long))));
    expect(find.text('more'), findsOneWidget);
    await tester.tap(find.text('more'));
    await tester.pump();
    expect(find.text('less'), findsOneWidget);
  });
}
