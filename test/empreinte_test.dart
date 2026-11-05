import 'package:appharmacie/core/empreinte.dart';
import 'package:appharmacie/core/securite.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Format PHC (empreinte autoportante)', () {
    test('encoder puis analyser restitue les paramètres et le sel', () {
      const empreinte = EmpreinteArgon2id(
        memoire: 19456,
        iterations: 2,
        parallelisme: 1,
        sel: <int>[1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16],
        empreinte: <int>[9, 8, 7, 6],
      );

      final texte = empreinte.encoder();
      expect(texte.startsWith(r'$argon2id$v=19$m=19456,t=2,p=1$'), isTrue);
      expect(texte.split(r'$').length, 6);

      final relue = EmpreinteArgon2id.analyser(texte);
      expect(relue, isNotNull);
      expect(relue!.memoire, 19456);
      expect(relue.iterations, 2);
      expect(relue.parallelisme, 1);
      expect(relue.sel, empreinte.sel);
      expect(relue.empreinte, empreinte.empreinte);
    });

    test('refuse tout ce qui n\'est pas une empreinte Argon2id exploitable', () {
      // Ancienne empreinte SHA-256 (hexadécimal).
      expect(EmpreinteArgon2id.analyser(List<String>.filled(64, 'a').join()), isNull);
      expect(EmpreinteArgon2id.analyser(''), isNull);
      // Mauvais algorithme.
      expect(
        EmpreinteArgon2id.analyser(r'$argon2i$v=19$m=64,t=1,p=1$c2Vs$aGFzaA'),
        isNull,
      );
      // Champ manquant.
      expect(
        EmpreinteArgon2id.analyser(r'$argon2id$v=19$m=64,t=1,p=1$c2Vs'),
        isNull,
      );
      // Paramètre non numérique.
      expect(
        EmpreinteArgon2id.analyser(r'$argon2id$v=19$m=abc,t=1,p=1$c2Vs$aGFzaA'),
        isNull,
      );
      // Sel qui n'est pas du base64.
      expect(
        EmpreinteArgon2id.analyser(r'$argon2id$v=19$m=64,t=1,p=1$!!!$aGFzaA'),
        isNull,
      );
      // Mémoire inférieure au minimum (8 blocs par fil).
      expect(
        EmpreinteArgon2id.analyser(r'$argon2id$v=19$m=4,t=1,p=1$c2Vs$aGFzaA'),
        isNull,
      );
      // Empreinte vide.
      expect(
        EmpreinteArgon2id.analyser(r'$argon2id$v=19$m=64,t=1,p=1$c2Vs$'),
        isNull,
      );
    });
  });

  group('Comparaison en temps constant', () {
    test('détecte l\'égalité, la différence et les longueurs différentes', () {
      expect(egalEnTempsConstant(<int>[1, 2, 3], <int>[1, 2, 3]), isTrue);
      expect(egalEnTempsConstant(<int>[1, 2, 3], <int>[1, 2, 4]), isFalse);
      expect(egalEnTempsConstant(<int>[0, 0, 0], <int>[0, 0, 1]), isFalse);
      expect(egalEnTempsConstant(<int>[1, 2], <int>[1, 2, 3]), isFalse);
    });
  });

  group('Argon2id', () {
    // Paramètres minimalistes : ces tests doivent rester rapides.
    const rapides = ParametresArgon2id.tests;

    test('le bon secret est accepté, un autre refusé', () async {
      final empreinte = await Securite.hacherFort('1234', parametres: rapides);

      expect(Securite.estEmpreinteArgon2id(empreinte), isTrue);
      expect(
        await Securite.verifierFort(secret: '1234', empreinte: empreinte),
        isTrue,
      );
      expect(
        await Securite.verifierFort(secret: '4321', empreinte: empreinte),
        isFalse,
      );
    });

    test('deux empreintes du même secret diffèrent (sel aléatoire)', () async {
      final premiere = await Securite.hacherFort('motdepasse', parametres: rapides);
      final seconde = await Securite.hacherFort('motdepasse', parametres: rapides);

      expect(premiere, isNot(seconde));
      expect(
        await Securite.verifierFort(secret: 'motdepasse', empreinte: premiere),
        isTrue,
      );
      expect(
        await Securite.verifierFort(secret: 'motdepasse', empreinte: seconde),
        isTrue,
      );
    });

    test('le secret n\'apparaît pas dans l\'empreinte', () async {
      final empreinte = await Securite.hacherFort('4321', parametres: rapides);
      expect(empreinte.contains('4321'), isFalse);
      expect(empreinte.length, greaterThan(50));
    });

    test('une empreinte abîmée est refusée sans lever d\'exception', () async {
      expect(
        await Securite.verifierFort(secret: '1234', empreinte: 'n/importe quoi'),
        isFalse,
      );
      expect(
        await Securite.verifierFort(
          secret: '1234',
          empreinte: r'$argon2id$v=19$m=64,t=1,p=1$c2Vs$',
        ),
        isFalse,
      );
    });
  });

  group('Migration depuis l\'ancien format', () {
    test('une empreinte SHA-256 reste vérifiable mais est reconnue comme ancienne', () {
      final sel = Securite.genererSel();
      final ancienne = Securite.hasher('1234', sel);

      expect(Securite.estEmpreinteArgon2id(ancienne), isFalse);
      expect(
        Securite.verifier(motDePasse: '1234', sel: sel, hashAttendu: ancienne),
        isTrue,
      );
      expect(
        Securite.verifier(motDePasse: '0000', sel: sel, hashAttendu: ancienne),
        isFalse,
      );
    });
  });
}
