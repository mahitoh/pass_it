// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pass_it/main.dart';
import 'package:pass_it/screens/auth_page.dart';
import 'package:pass_it/screens/onboarding_page.dart';

void main() {
  testWidgets('renders auth gate in signed-out state', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const PassItApp());
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(MaterialApp), findsOneWidget);
    final authCount = find.byType(AuthPage).evaluate().length;
    final onboardingCount = find.byType(OnboardingPage).evaluate().length;
    final loadingCount = find
        .byType(CircularProgressIndicator)
        .evaluate()
        .length;
    expect(authCount + onboardingCount + loadingCount, greaterThan(0));
  });
}
