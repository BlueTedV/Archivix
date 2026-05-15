import 'package:archivix/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('startup loading screen shows the app brand', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: StartupLoadingScreen()));

    expect(find.text('Archivix'), findsOneWidget);
    expect(find.text('Preparing your archive...'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('startup error app shows the error message', (tester) async {
    await tester.pumpWidget(
      const StartupErrorApp(error: 'Supabase configuration missing'),
    );

    expect(find.text('App failed to start'), findsOneWidget);
    expect(
      find.textContaining('Supabase configuration missing'),
      findsOneWidget,
    );
  });
}
