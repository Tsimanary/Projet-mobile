import 'dart:convert';

import 'package:appharmacie/core/backup_format.dart';
import 'package:appharmacie/core/chiffrement.dart';
import 'package:appharmacie/core/empreinte.dart';
import 'package:appharmacie/core/exceptions.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Paramètres minimalistes : ces tests doivent rester rapides.
  const rapides = ParametresArgon2id.tests;
  const phrase = 'phrase-secrete-de-test';
  const clair = '{"application":"appharmacie","format":1,"tables":{}}';

  group('Enveloppe chiffrée', () {
    test('un aller-retour restitue exactement le contenu', () async {
      final enveloppe = await ChiffrementSauvegarde.chiffrer(
        clair,
        phrase,
        parametres: rapides,
      );

      expect(ChiffrementSauvegarde.estChiffree(enveloppe), isTrue);
      // Le contenu d'origine ne doit pas apparaître en clair.
      expect(enveloppe.contains('tables'), isFalse);
      expect(
        await ChiffrementSauvegarde.dechiffrer(enveloppe, phrase),
        clair,
      );
    });

    test('l\'enveloppe décrit ses paramètres de dérivation', () async {
      final enveloppe = await ChiffrementSauvegarde.chiffrer(
        clair,
        phrase,
        parametres: rapides,
      );

      final document = jsonDecode(enveloppe) as Map<String, dynamic>;
      expect(document['application'], 'appharmacie');
      expect(document['type'], ChiffrementSauvegarde.typeEnveloppe);
      expect(document['format'], ChiffrementSauvegarde.versionEnveloppe);

      final kdf = document['kdf'] as Map<String, dynamic>;
      expect(kdf['algorithme'], 'argon2id');
      expect(kdf['memoire'], rapides.memoire);
      expect(kdf['iterations'], rapides.iterations);

      final chiffrement = document['chiffrement'] as Map<String, dynamic>;
      expect(chiffrement['algorithme'], 'AES-256-GCM');
      expect((chiffrement['nonce'] as String).isNotEmpty, isTrue);
      expect((chiffrement['tag'] as String).isNotEmpty, isTrue);
    });

    test('une phrase incorrecte est refusée', () async {
      final enveloppe = await ChiffrementSauvegarde.chiffrer(
        clair,
        phrase,
        parametres: rapides,
      );

      await expectLater(
        ChiffrementSauvegarde.dechiffrer(enveloppe, 'mauvaise-phrase'),
        throwsA(isA<OperationRefuseeException>()),
      );
    });

    test('deux exports du même contenu n\'ont rien en commun', () async {
      final premiere = await ChiffrementSauvegarde.chiffrer(
        clair,
        phrase,
        parametres: rapides,
      );
      final seconde = await ChiffrementSauvegarde.chiffrer(
        clair,
        phrase,
        parametres: rapides,
      );

      expect(premiere, isNot(seconde));
      expect(await ChiffrementSauvegarde.dechiffrer(premiere, phrase), clair);
      expect(await ChiffrementSauvegarde.dechiffrer(seconde, phrase), clair);
    });

    test('une enveloppe altérée est refusée (AES-GCM authentifié)', () async {
      final enveloppe = await ChiffrementSauvegarde.chiffrer(
        clair,
        phrase,
        parametres: rapides,
      );

      final document = jsonDecode(enveloppe) as Map<String, dynamic>;
      final chiffrement = document['chiffrement'] as Map<String, dynamic>;
      final donnees = chiffrement['donnees'] as String;
      chiffrement['donnees'] = (donnees[0] == 'A' ? 'B' : 'A') + donnees.substring(1);

      await expectLater(
        ChiffrementSauvegarde.dechiffrer(jsonEncode(document), phrase),
        throwsA(isA<OperationRefuseeException>()),
      );
    });

    test('refuse une phrase trop courte', () async {
      await expectLater(
        ChiffrementSauvegarde.chiffrer(clair, 'court'),
        throwsArgumentError,
      );
    });

    test('reconnaît seulement ses propres enveloppes', () {
      expect(ChiffrementSauvegarde.estChiffree(''), isFalse);
      expect(ChiffrementSauvegarde.estChiffree('pas du json'), isFalse);
      expect(
        ChiffrementSauvegarde.estChiffree(
          '{"application":"appharmacie","format":1,"tables":{}}',
        ),
        isFalse,
      );
    });

    test('déchiffrer un fichier en clair est refusé explicitement', () async {
      await expectLater(
        ChiffrementSauvegarde.dechiffrer(clair, phrase),
        throwsA(isA<OperationRefuseeException>()),
      );
    });
  });

  group('Intégration avec le format de sauvegarde', () {
    test('une sauvegarde chiffrée redevient exploitable', () async {
      final contenu = construireSauvegarde(
        <String, Object?>{
          'medics': <Object?>[
            <String, Object?>{'numMed': 'P001', 'designMed': 'Paracétamol'},
          ],
        },
        maintenant: DateTime(2026, 11, 5),
      );

      final enveloppe = await ChiffrementSauvegarde.chiffrer(
        contenu,
        phrase,
        parametres: rapides,
      );
      final dechiffre = await ChiffrementSauvegarde.dechiffrer(
        enveloppe,
        phrase,
      );

      final tables = analyserSauvegarde(dechiffre);
      expect((tables['medics'] as List).length, 1);
      expect(compterLignesSauvegarde(tables), 1);
    });
  });
}
