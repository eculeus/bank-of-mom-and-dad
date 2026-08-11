import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bank_of_mom_and_dad/features/parent/manage_family_screen.dart';

void main() {
  testWidgets('AddMemberDialog validates email before enabling Add', (tester) async {
    String? added;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: AddMemberDialog(role: 'kid', onAdd: (name, email) async => added = email))));
    final addBtn = find.widgetWithText(FilledButton, 'Add');
    expect(tester.widget<FilledButton>(addBtn).onPressed, isNull);
    await tester.enterText(find.byKey(const Key('memberName')), 'Drew');
    await tester.enterText(find.byKey(const Key('memberEmail')), 'drew@x.com');
    await tester.pump();
    await tester.tap(addBtn);
    await tester.pump();
    expect(added, 'drew@x.com');
  });

  testWidgets('RenameFamilyDialog Save disabled until a new name is entered, trims value',
      (tester) async {
    String? renamed;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: RenameFamilyDialog(
                currentName: 'The Smiths',
                onRename: (newName) async => renamed = newName))));
    final saveBtn = find.widgetWithText(FilledButton, 'Save');
    expect(tester.widget<FilledButton>(saveBtn).onPressed, isNull);
    await tester.enterText(find.byKey(const Key('familyNameField')), '  The Joneses  ');
    await tester.pump();
    expect(tester.widget<FilledButton>(saveBtn).onPressed, isNotNull);
    await tester.tap(saveBtn);
    await tester.pump();
    expect(renamed, 'The Joneses');
  });
}
