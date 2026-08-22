// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trekcure/main.dart';

void main() {
  testWidgets('TrekCure app loads successfully', (WidgetTester tester) async {
    // Build our TrekCure app and trigger a frame.
    await tester.pumpWidget(const TrekCureApp());

    // Verify that the TrekCure app exists in the widget tree.
    expect(find.byType(TrekCureApp), findsOneWidget);

    // Verify that the MaterialApp is present.
    expect(find.byType(MaterialApp), findsOneWidget);

    // Allow animations and the splash screen to proceed.
    await tester.pump();

    // Verify that the app is still running.
    expect(find.byType(TrekCureApp), findsOneWidget);
  });
}
