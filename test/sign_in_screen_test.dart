import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bank_of_mom_and_dad/features/auth/sign_in_screen.dart';

void main() {
  testWidgets('sign-in screen shows Google button and branding', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: MaterialApp(home: SignInScreen())));
    expect(find.text('Bank of Mom & Dad'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
    // TEST_MODE fields hidden by default
    expect(find.text('Test sign in'), findsNothing);
  });
}
