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

  group('Dates de stockage (ISO)', () {
    test('formaterDateIso complète les zéros', () {
      expect(formaterDateIso(DateTime(2026, 1, 5)), '2026-01-05');
      expect(formaterDateIso(DateTime(2026, 12, 31)), '2026-12-31');
    });

    test('versIso accepte les formats historiques et ISO', () {
      expect(versIso('04/11/2026'), '2026-11-04');
      expect(versIso('04/11/26'), '2026-11-04');
      expect(versIso('2026-11-04'), '2026-11-04');
      expect(versIso(''), isNull);
      expect(versIso('n/c'), isNull);
      expect(versIso(null), isNull);
    });

    test('afficherDate rend les dates lisibles', () {
      expect(afficherDate('2026-11-04'), '04/11/2026');
      expect(afficherDate('04/11/2026'), '04/11/2026');
      expect(afficherDate(null), '—');
      expect(afficherDate(''), '—');
    });

    test('joursAvant calcule l\'écart avec aujourd\'hui', () {
      final reference = DateTime(2026, 11, 4);
      expect(joursAvant('2026-11-14', maintenant: reference), 10);
      expect(joursAvant('2026-11-04', maintenant: reference), 0);
      expect(joursAvant('2026-10-04', maintenant: reference), -31);
      expect(joursAvant(null, maintenant: reference), isNull);
      expect(joursAvant('invalide', maintenant: reference), isNull);
    });
  });
}
