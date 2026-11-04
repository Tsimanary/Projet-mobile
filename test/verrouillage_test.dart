import 'package:appharmacie/core/securite.dart';
import 'package:appharmacie/core/verrouillage_regles.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Règles du code d\'accès', () {
    test('accepte de 4 à 6 chiffres', () {
      expect(ReglesPin.estValide('1234'), isTrue);
      expect(ReglesPin.estValide('12345'), isTrue);
      expect(ReglesPin.estValide('123456'), isTrue);
    });

    test('refuse les longueurs et caractères invalides', () {
      expect(ReglesPin.estValide(''), isFalse);
      expect(ReglesPin.estValide('123'), isFalse);
      expect(ReglesPin.estValide('1234567'), isFalse);
      expect(ReglesPin.estValide('12a4'), isFalse);
      expect(ReglesPin.estValide('12 34'), isFalse);
      expect(ReglesPin.estValide('12.4'), isFalse);
    });

    test('le blocage intervient au cinquième échec', () {
      expect(ReglesPin.doitBloquer(0), isFalse);
      expect(ReglesPin.doitBloquer(4), isFalse);
      expect(ReglesPin.doitBloquer(5), isTrue);
      expect(ReglesPin.doitBloquer(6), isTrue);
    });

    test('la fin de blocage est le dernier échec plus la durée', () {
      final echec = DateTime(2026, 11, 5, 10, 0);
      final fin = ReglesPin.finBlocage(echecs: 5, dernierEchec: echec);

      expect(fin, isNotNull);
      expect(fin!.difference(echec), ReglesPin.dureeBlocage);
      expect(ReglesPin.finBlocage(echecs: 2, dernierEchec: echec), isNull);
    });

    test('le temps restant ne devient jamais négatif', () {
      final fin = DateTime(2026, 11, 5, 10, 5);

      expect(
        ReglesPin.blocageRestant(fin: fin, maintenant: DateTime(2026, 11, 5, 10, 2)),
        const Duration(minutes: 3),
      );
      expect(
        ReglesPin.blocageRestant(fin: fin, maintenant: DateTime(2026, 11, 5, 10, 9)),
        Duration.zero,
      );
    });

    test('les durées sont lisibles', () {
      expect(ReglesPin.formaterDuree(Duration.zero), '0 s');
      expect(ReglesPin.formaterDuree(const Duration(seconds: 45)), '45 s');
      expect(ReglesPin.formaterDuree(const Duration(seconds: 61)), '2 min');
      expect(ReglesPin.formaterDuree(const Duration(minutes: 5)), '5 min');
    });
  });

  group('Empreinte du code d\'accès', () {
    test('le bon code est reconnu, un autre est refusé', () {
      final sel = Securite.genererSel();
      final empreinte = Securite.hasher('4321', sel);

      expect(
        Securite.verifier(
          motDePasse: '4321',
          sel: sel,
          hashAttendu: empreinte,
        ),
        isTrue,
      );
      expect(
        Securite.verifier(
          motDePasse: '1234',
          sel: sel,
          hashAttendu: empreinte,
        ),
        isFalse,
      );
    });

    test('l\'empreinte ne contient pas le code en clair', () {
      const code = '4321';
      final empreinte = Securite.hasher(code, Securite.genererSel());

      expect(empreinte.contains(code), isFalse);
      expect(empreinte.length, 64);
    });

    test('deux sels produisent deux empreintes différentes', () {
      const code = '4321';
      final premiere = Securite.hasher(code, Securite.genererSel());
      final seconde = Securite.hasher(code, Securite.genererSel());

      expect(premiere, isNot(seconde));
    });
  });
}
