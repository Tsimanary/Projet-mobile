import 'package:flutter/foundation.dart';

/// Interface minimale du matériel biométrique (empreinte, visage, iris).
///
/// Volontairement abstraite : toute la logique — activation, comptage des
/// essais, repli sur le code d'accès — est ainsi vérifiable sans plugin, sans
/// téléphone et sans capteur.
abstract class VerificateurBiometrique {
  /// L'appareil possède-t-il un capteur **et** au moins une empreinte/visage
  /// enregistré dans les réglages du système ?
  Future<bool> estDisponible();

  /// Ouvre l'invite du système et retourne `true` si l'utilisateur s'est
  /// authentifié.
  Future<bool> verifier({required String motif});
}

/// Où l'on retient que le déverrouillage biométrique est activé.
///
/// En production : la table `parametres` de la base chiffrée. En test : la
/// mémoire.
abstract class DepotBiometrie {
  Future<bool> lireActive();
  Future<void> ecrireActive(bool valeur);
}

/// Dépôt en mémoire (valeur par défaut avant l'installation du dépôt réel).
class DepotMemoireBiometrie implements DepotBiometrie {
  bool _active = false;

  bool get valeur => _active;

  @override
  Future<bool> lireActive() async => _active;

  @override
  Future<void> ecrireActive(bool valeur) async => _active = valeur;
}

/// Issue d'une tentative de déverrouillage biométrique.
enum ResultatBiometrie {
  /// Authentifié : l'écran peut se fermer.
  reussi,

  /// Échec, mais on peut réessayer.
  echec,

  /// Trop d'échecs : seul le code d'accès est encore accepté.
  verrouillee,

  /// Pas de capteur, ou aucune empreinte enregistrée sur l'appareil.
  indisponible,

  /// L'utilisateur n'a pas activé cette option.
  desactivee,
}

/// Politique du déverrouillage biométrique.
///
/// La biométrie **remplace le code d'accès à l'ouverture**, elle ne le
/// supprime pas : après [essaisMax] échecs, le pavé numérique redevient le
/// seul chemin. C'est ce qui évite qu'un doigt récalcitrant (ou mouillé)
/// enferme l'utilisateur hors de ses données.
class ReglesBiometrie {
  ReglesBiometrie._();

  /// Nombre d'échecs consécutifs avant de rendre la main au code.
  static const int essaisMax = 3;

  /// Motif affiché par le système au moment de la vérification.
  static const String motif = 'Déverrouillez AppHarmacie';

  /// Motif affiché au moment de l'activation (l'utilisateur doit prouver que
  /// son empreinte fonctionne avant qu'on l'active).
  static const String motifActivation =
      'Confirmez votre empreinte pour activer le déverrouillage rapide';

  static const String explication =
      'Après saisie de votre code, l\'application se reverrouille au bout de '
      '30 s en arrière-plan. L\'empreinte évite de retaper le code à chaque '
      'fois. Le code d\'accès reste obligatoire après '
      '$essaisMax essais biométriques non reconnus, et reste modifiable.';

  /// Peut-on encore proposer le capteur après [echecs] échecs ?
  static bool doitProposer(int echecs) => echecs < essaisMax;

  /// Message affiché après un échec, selon le nombre d'essais restants.
  static String messageEchec(int echecs) {
    if (echecs >= essaisMax) return messageVerrouille;
    final restants = essaisMax - echecs;
    return restants == 1
        ? 'Empreinte non reconnue ou annulée. Dernier essai avant le code.'
        : 'Empreinte non reconnue ou annulée. Encore $restants essais.';
  }

  /// L'invite du système ne distingue pas un doigt non reconnu d'une annulation :
  /// le message couvre les deux cas plutôt que d'accuser l'utilisateur à tort.
  static const String messageVerrouille =
      'Empreinte non reconnue ou annulée $essaisMax fois : '
      'saisissez votre code d\'accès.';

  static const String messageIndisponible =
      'Aucune empreinte enregistrée sur cet appareil : utilisez votre code.';
}

/// Déverrouillage biométrique, en mémoire seulement.
///
/// Le réglage (activé ou non) vit dans la base chiffrée ; l'état courant et le
/// compteur d'échecs vivent en mémoire et sont remis à zéro au redémarrage —
/// un verrou qui « se souvient » d'un blocage après relance n'aurait ici aucun
/// intérêt, le code d'accès restant la clé de secours.
class Biometrie {
  Biometrie._();

  static VerificateurBiometrique? _verificateur;
  static DepotBiometrie _depot = DepotMemoireBiometrie();

  static bool _active = false;
  static bool _charge = false;
  static int _echecs = 0;

  /// Notifié quand l'option est activée ou désactivée.
  static final ValueNotifier<bool> active = ValueNotifier<bool>(false);

  /// Branche l'implémentation réelle (plugin + base) — appelé depuis `main`.
  static void installer({
    required VerificateurBiometrique verificateur,
    required DepotBiometrie depot,
  }) {
    _verificateur = verificateur;
    _depot = depot;
  }

  /// Remise à l'état initial : réservé aux tests.
  @visibleForTesting
  static void reinitialiser() {
    _verificateur = null;
    _depot = DepotMemoireBiometrie();
    _active = false;
    _charge = false;
    _echecs = 0;
    active.value = false;
  }

  static bool get estActive => _active;

  static bool get configuree => _verificateur != null;

  /// Échecs consécutifs depuis le dernier succès.
  static int get echecsConsecutifs => _echecs;

  /// Faut-il afficher le bouton du capteur sur l'écran de verrouillage ?
  static bool get peutProposer =>
      _active && configuree && ReglesBiometrie.doitProposer(_echecs);

  /// Relit le réglage enregistré (base chiffrée), une seule fois.
  ///
  /// Une erreur de lecture n'active jamais l'option : en cas de doute, on
  /// retombe sur le code d'accès.
  static Future<void> charger({bool force = false}) async {
    if (_charge && !force) return;
    var valeur = false;
    try {
      valeur = await _depot.lireActive();
    } catch (_) {
      valeur = false;
    }
    _active = valeur;
    _charge = true;
    _echecs = 0;
    active.value = _active;
  }

  /// Le matériel peut-il réellement vérifier une empreinte maintenant ?
  static Future<bool> disponible() async {
    final verificateur = _verificateur;
    if (verificateur == null) return false;
    try {
      return await verificateur.estDisponible();
    } catch (_) {
      return false;
    }
  }

  /// Tente un déverrouillage. Ne lève jamais : toute panne du capteur est
  /// traitée comme un échec, et le code reste disponible.
  static Future<ResultatBiometrie> verifier({String? motif}) async {
    if (!_active) return ResultatBiometrie.desactivee;
    if (!ReglesBiometrie.doitProposer(_echecs)) {
      return ResultatBiometrie.verrouillee;
    }

    final verificateur = _verificateur;
    if (verificateur == null) return ResultatBiometrie.indisponible;

    var reussi = false;
    try {
      reussi = await verificateur.verifier(
        motif: motif ?? ReglesBiometrie.motif,
      );
    } catch (_) {
      reussi = false;
    }

    if (reussi) {
      _echecs = 0;
      return ResultatBiometrie.reussi;
    }

    _echecs++;
    return ReglesBiometrie.doitProposer(_echecs)
        ? ResultatBiometrie.echec
        : ResultatBiometrie.verrouillee;
  }

  /// Active l'option — mais seulement après une authentification réussie :
  /// on n'active pas un verrou qu'on n'a pas essayé.
  ///
  /// Retourne `false` si le matériel est absent ou si la preuve échoue.
  static Future<bool> activer() async {
    final verificateur = _verificateur;
    if (verificateur == null) return false;
    if (!await disponible()) return false;

    var preuve = false;
    try {
      preuve = await verificateur.verifier(
        motif: ReglesBiometrie.motifActivation,
      );
    } catch (_) {
      preuve = false;
    }
    if (!preuve) return false;

    // On n'écrit l'état qu'une fois la preuve obtenue ; une erreur d'écriture
    // remonte à l'appelant (écran Sécurité) qui affiche un message.
    await _depot.ecrireActive(true);
    _active = true;
    _charge = true;
    _echecs = 0;
    active.value = true;
    return true;
  }

  /// Désactive l'option. Le code d'accès, lui, n'est pas touché.
  static Future<void> desactiver() async {
    await _depot.ecrireActive(false);
    _active = false;
    _charge = true;
    _echecs = 0;
    active.value = false;
  }

  /// Redonne sa chance au capteur (après un déverrouillage par code).
  static void reinitialiserEssais() {
    _echecs = 0;
  }
}
