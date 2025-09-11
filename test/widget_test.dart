// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:mockito/mockito.dart';

import 'package:flutter_app/main.dart';

class MockFirebaseAuth extends Mock implements FirebaseAuth {}

void main() {
  late MockFirebaseAuth mockFirebaseAuth;

  setUp(() {
    mockFirebaseAuth = MockFirebaseAuth();
  });

  testWidgets('App builds successfully', (WidgetTester tester) async {
    // Mock Firebase initialization
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: 'test-api-key',
        appId: 'test-app-id',
        messagingSenderId: '123456789',
        projectId: 'test-project',
      ),
    );

    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Wait for async operations to complete
    await tester.pumpAndSettle();

    // Verify that the MaterialApp is present
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
