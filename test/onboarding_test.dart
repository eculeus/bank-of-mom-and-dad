import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bank_of_mom_and_dad/features/auth/role_chooser_screen.dart';
import 'package:bank_of_mom_and_dad/features/auth/create_family_screen.dart';
import 'package:bank_of_mom_and_dad/features/auth/no_invite_screen.dart';

void main() {
  testWidgets('role chooser offers both roles', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: MaterialApp(home: RoleChooserScreen())));
    expect(find.text("I'm a Parent"), findsOneWidget);
    expect(find.text("I'm a Kid"), findsOneWidget);
  });

  testWidgets('create family validates before enabling submit', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: MaterialApp(home: CreateFamilyScreen())));
    final submit = find.widgetWithText(FilledButton, 'Create family');
    expect(tester.widget<FilledButton>(submit).onPressed, isNull);
    await tester.enterText(find.byKey(const Key('familyName')), 'Smith Family Bank');
    await tester.pump();
    expect(tester.widget<FilledButton>(submit).onPressed, isNotNull);
  });

  testWidgets('no-invite screen shows the email and actions', (tester) async {
    await tester.pumpWidget(const ProviderScope(
        child: MaterialApp(home: NoInviteScreen(email: 'kid@x.com'))));
    expect(find.textContaining('kid@x.com'), findsOneWidget);
    expect(find.text('Check again'), findsOneWidget);
    expect(find.text('Sign out'), findsOneWidget);
  });
}
