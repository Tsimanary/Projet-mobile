import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

import '../SQLite/sqlite.dart';
import 'biometrie.dart';

/// Implémentation réelle du capteur, via `local_auth`.
///
/// Android impose une `FlutterFragmentActivity` (voir `MainActivity.kt`) :
/// `BiometricPrompt` est un fragment du système, pas une simple activité.
class VerificateurSystemeBiometrie implements VerificateurBiometrique {
  VerificateurSystemeBiometrie({LocalAuthentication? authentification})
      : _authentification = authentification ?? LocalAuthentication();

  final LocalAuthentication _authentification;

  @override
  Future<bool> estDisponible() async {
    try {
      if (!await _authentification.isDeviceSupported()) return false;
      if (!await _authentification.canCheckBiometrics) return false;
      final types = await _authentification.getAvailableBiometrics();
      // Aucune empreinte / aucun visage enregistré : inutile de proposer.
      return types.isNotEmpty;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  @override
  Future<bool> verifier({required String motif}) async {
    try {
      return await _authentification.authenticate(
        localizedReason: motif,
        options: const AuthenticationOptions(
          // Uniquement la biométrie : le code de l'appareil ne doit pas
          // remplacer le code d'accès de l'application.
          biometricOnly: true,
          // L'invite survit à un passage de l'application en arrière-plan.
          stickyAuth: true,
        ),
      );
    } on PlatformException {
      return false;
    } on MissingPluginException {
      // Plugin absent (bureau, test, mauvaise configuration) : on retombe
      // proprement sur le code d'accès.
      return false;
    }
  }
}

/// Réglage persistant : une ligne de la table `parametres` (base chiffrée).
class DepotBiometrieBase implements DepotBiometrie {
  static const String _cle = 'securite.biometrie.active';

  final DatabaseHelper _base = DatabaseHelper();

  @override
  Future<bool> lireActive() async =>
      (await _base.lireParametre(_cle)) == '1';

  @override
  Future<void> ecrireActive(bool valeur) =>
      _base.ecrireParametre(_cle, valeur ? '1' : '0');
}

/// À appeler une fois au démarrage (aucun accès disque : simple branchement).
void installerBiometrieSysteme() {
  Biometrie.installer(
    verificateur: VerificateurSystemeBiometrie(),
    depot: DepotBiometrieBase(),
  );
}
