import 'package:appharmacie/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('l\'application démarre sur l\'écran de connexion', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    await tester.pump();

    expect(find.text('Gestion de pharmacie'), findsOneWidget);
    expect(find.text('SE CONNECTER'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(2));
  });

  testWidgets('la connexion refuse un formulaire vide', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    await tester.pump();

    await tester.tap(find.text('SE CONNECTER'));
    await tester.pump();

    expect(find.text("Le mot de passe est obligatoire."), findsOneWidget);
  });
}
