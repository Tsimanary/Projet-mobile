import 'package:appharmacie/core/format.dart';
import 'package:appharmacie/core/validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Validators.obligatoire', () {
    test('refuse une valeur vide ou composée d\'espaces', () {
      expect(Validators.obligatoire(''), isNotNull);
      expect(Validators.obligatoire('   '), isNotNull);
      expect(Validators.obligatoire(null), isNotNull);
    });

    test('accepte une valeur renseignée', () {
      expect(Validators.obligatoire('Paracétamol'), isNull);
    });
  });

  group('Validators.entier', () {
    test('refuse le texte et les décimales', () {
      expect(Validators.entier('abc'), isNotNull);
      expect(Validators.entier('12.5'), isNotNull);
      expect(Validators.entier(''), isNotNull);
    });

    test('refuse zéro et les négatifs par défaut', () {
      expect(Validators.entier('0'), isNotNull);
      expect(Validators.entier('-2'), isNotNull);
    });

    test('accepte un entier positif', () {
      expect(Validators.entier('12'), isNull);
    });

    test('prix autorise zéro', () {
      expect(Validators.prix('0'), isNull);
      expect(Validators.prix('-1'), isNotNull);
    });
  });

  test('VersEntier ne lève jamais d\'exception', () {
    expect(Validators.versEntier('42'), 42);
    expect(Validators.versEntier(' 7 '), 7);
    expect(Validators.versEntier('abc'), isNull);
    expect(Validators.versEntier(''), isNull);
    expect(Validators.versEntier(null), isNull);
  });

  group('Formatage', () {
    test('formaterMontant sépare les milliers', () {
      expect(formaterMontant(0), '0 Ar');
      expect(formaterMontant(1500), '1 500 Ar');
      expect(formaterMontant(125000), '125 000 Ar');
    });

    test('formaterNombre gère les nombres négatifs', () {
      expect(formaterNombre(-1234), '-1 234');
    });

    test('analyserDate comprend les formats historiques', () {
      expect(analyserDate('04/11/2026'), DateTime(2026, 11, 4));
      expect(analyserDate('04/11/26'), DateTime(2026, 11, 4));
      expect(analyserDate('2026-11-04'), DateTime(2026, 11, 4));
      expect(analyserDate('n\'importe quoi'), isNull);
      expect(analyserDate(''), isNull);
    });
  });
}
