import 'package:appharmacie/core/biometrie.dart';
import 'package:flutter_test/flutter_test.dart';

/// Capteur simulé : reproductible, sans plugin ni téléphone.
class _FauxVerificateur implements VerificateurBiometrique {
  _FauxVerificateur({this.disponible = true, this.reussite = true});

  bool disponible;
  bool reussite;
  int appelsDisponible = 0;
  int appelsVerifier = 0;
  final List<String> motifs = <String>[];

  @override
  Future<bool> estDisponible() async {
    appelsDisponible++;
    return disponible;
  }

  @override
  Future<bool> verifier({required String motif}) async {
    appelsVerifier++;
    motifs.add(motif);
    return reussite;
  }
}

/// Capteur qui échoue au niveau matériel (plugin absent, capteur occupé).
class _VerificateurEnPanne implements VerificateurBiometrique {
  int appels = 0;

  @override
  Future<bool> estDisponible() async {
    appels++;
    throw Exception('capteur indisponible');
  }

  @override
  Future<bool> verifier({required String motif}) async {
    appels++;
    throw Exception('capteur occupé');
  }
}

/// Base chiffrée inaccessible (coffre verrouillé, disque plein…).
class _DepotEnPanne implements DepotBiometrie {
  @override
  Future<bool> lireActive() async => throw Exception('base illisible');

  @override
  Future<void> ecrireActive(bool valeur) async =>
      throw Exception('écriture impossible');
}

void main() {
  tearDown(Biometrie.reinitialiser);

  group('Politique', () {
    test('trois essais avant de rendre la main au code', () {
      expect(ReglesBiometrie.essaisMax, 3);
      expect(ReglesBiometrie.doitProposer(0), isTrue);
      expect(ReglesBiometrie.doitProposer(2), isTrue);
      expect(ReglesBiometrie.doitProposer(3), isFalse);
      expect(ReglesBiometrie.doitProposer(10), isFalse);
    });

    test('les messages sont affichables et parlent du code', () {
      expect(ReglesBiometrie.messageEchec(1), contains('essai'));
      expect(ReglesBiometrie.messageEchec(2), contains('Dernier essai'));
      expect(
        ReglesBiometrie.messageEchec(ReglesBiometrie.essaisMax),
        contains('code'),
      );
      expect(ReglesBiometrie.messageVerrouille, contains('code'));
      expect(ReglesBiometrie.messageIndisponible, contains('code'));
      expect(ReglesBiometrie.explication, contains('empreinte'));
      expect(ReglesBiometrie.motif, isNotEmpty);
      expect(ReglesBiometrie.motifActivation, isNotEmpty);
    });
  });

  group('État et activation', () {
    test('désactivée par défaut : le capteur n\'est jamais sollicité', () async {
      final capteur = _FauxVerificateur();
      Biometrie.installer(
        verificateur: capteur,
        depot: DepotMemoireBiometrie(),
      );
      await Biometrie.charger();

      expect(Biometrie.estActive, isFalse);
      expect(Biometrie.peutProposer, isFalse);
      expect(
        await Biometrie.verifier(),
        ResultatBiometrie.desactivee,
      );
      expect(capteur.appelsVerifier, 0);
    });

    test('activer exige une empreinte reconnue', () async {
      final depot = DepotMemoireBiometrie();
      final capteur = _FauxVerificateur(reussite: false);
      Biometrie.installer(verificateur: capteur, depot: depot);

      expect(await Biometrie.activer(), isFalse);
      expect(Biometrie.estActive, isFalse);
      expect(depot.valeur, isFalse);
      expect(capteur.appelsVerifier, 1);
    });

    test('activation réussie : réglage écrit et notification', () async {
      final depot = DepotMemoireBiometrie();
      Biometrie.installer(
        verificateur: _FauxVerificateur(reussite: true),
        depot: depot,
      );

      expect(await Biometrie.activer(), isTrue);
      expect(Biometrie.estActive, isTrue);
      expect(Biometrie.peutProposer, isTrue);
      expect(depot.valeur, isTrue);
      expect(Biometrie.active.value, isTrue);
    });

    test('le réglage est relu au démarrage', () async {
      final depot = DepotMemoireBiometrie();
      await depot.ecrireActive(true);
      Biometrie.installer(
        verificateur: _FauxVerificateur(),
        depot: depot,
      );

      await Biometrie.charger();
      expect(Biometrie.estActive, isTrue);
    });

    test('une base illisible laisse la biométrie désactivée', () async {
      Biometrie.installer(
        verificateur: _FauxVerificateur(),
        depot: _DepotEnPanne(),
      );

      await Biometrie.charger();
      expect(Biometrie.estActive, isFalse);
      expect(await Biometrie.verifier(), ResultatBiometrie.desactivee);
    });

    test('désactiver n\'appelle pas le capteur et éteint le drapeau', () async {
      final depot = DepotMemoireBiometrie();
      final capteur = _FauxVerificateur();
      Biometrie.installer(verificateur: capteur, depot: depot);
      await Biometrie.activer();
      final appelsApresActivation = capteur.appelsVerifier;

      await Biometrie.desactiver();
      expect(Biometrie.estActive, isFalse);
      expect(depot.valeur, isFalse);
      expect(capteur.appelsVerifier, appelsApresActivation);
    });
  });

  group('Vérification', () {
    /// Active l'option avec une preuve réussie, puis règle le capteur sur le
    /// comportement à tester (l'activation elle-même exige un succès).
    Future<_FauxVerificateur> activerAvec({bool reussite = true}) async {
      final capteur = _FauxVerificateur(reussite: true);
      Biometrie.installer(
        verificateur: capteur,
        depot: DepotMemoireBiometrie(),
      );
      await Biometrie.activer();
      capteur.reussite = reussite;
      return capteur;
    }

    test('succès : résultat reussi et compteur à zéro', () async {
      await activerAvec();

      expect(await Biometrie.verifier(), ResultatBiometrie.reussi);
      expect(Biometrie.echecsConsecutifs, 0);
    });

    test('trois échecs verrouillent, le quatrième n\'appelle plus le capteur',
        () async {
      final capteur = await activerAvec(reussite: false);
      final avant = capteur.appelsVerifier; // 1 appel : la preuve d'activation

      expect(await Biometrie.verifier(), ResultatBiometrie.echec);
      expect(await Biometrie.verifier(), ResultatBiometrie.echec);
      expect(await Biometrie.verifier(), ResultatBiometrie.verrouillee);
      expect(Biometrie.echecsConsecutifs, 3);
      expect(Biometrie.peutProposer, isFalse);

      expect(await Biometrie.verifier(), ResultatBiometrie.verrouillee);
      expect(capteur.appelsVerifier, avant + 3);
    });

    test('un succès après deux échecs remet le compteur à zéro', () async {
      final capteur = await activerAvec(reussite: false);

      await Biometrie.verifier();
      await Biometrie.verifier();
      expect(Biometrie.echecsConsecutifs, 2);

      capteur.reussite = true;
      expect(await Biometrie.verifier(), ResultatBiometrie.reussi);
      expect(Biometrie.echecsConsecutifs, 0);
      expect(Biometrie.peutProposer, isTrue);
    });

    test('un verrou biométrique se lève quand l\'utilisateur saisit son code',
        () async {
      await activerAvec(reussite: false);
      await Biometrie.verifier();
      await Biometrie.verifier();
      await Biometrie.verifier();
      expect(Biometrie.peutProposer, isFalse);

      Biometrie.reinitialiserEssais();
      expect(Biometrie.peutProposer, isTrue);
    });

    test('le capteur absent interdit l\'activation', () async {
      final capteur = _FauxVerificateur(disponible: false);
      Biometrie.installer(
        verificateur: capteur,
        depot: DepotMemoireBiometrie(),
      );

      expect(await Biometrie.disponible(), isFalse);
      expect(await Biometrie.activer(), isFalse);
      expect(capteur.appelsVerifier, 0);
      expect(Biometrie.estActive, isFalse);
    });

    test('une panne du capteur est un échec, jamais un plantage', () async {
      final capteurPanne = _VerificateurEnPanne();
      Biometrie.installer(
        verificateur: capteurPanne,
        depot: DepotMemoireBiometrie(),
      );

      expect(await Biometrie.disponible(), isFalse);
      expect(await Biometrie.activer(), isFalse);

      // On force l'état actif pour vérifier le comportement en cours d'usage.
      final depot = DepotMemoireBiometrie();
      await depot.ecrireActive(true);
      Biometrie.installer(verificateur: capteurPanne, depot: depot);
      await Biometrie.charger();

      expect(await Biometrie.verifier(), ResultatBiometrie.echec);
      expect(Biometrie.echecsConsecutifs, 1);
    });
  });
}
