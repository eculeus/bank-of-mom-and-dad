import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bank_of_mom_and_dad/features/auth/sign_in_screen.dart';

void main() {
  testWidgets('sign-in screen is constructible without Firebase', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: MaterialApp(home: SignInScreen())));
    expect(find.text('Bank of Mom & Dad'), findsOneWidget);
  });
}
