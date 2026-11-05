import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Blocage des captures d'écran et des miniatures du sélecteur d'applications.
///
/// Côté Android, l'application pose `WindowManager.LayoutParams.FLAG_SECURE`
/// sur la fenêtre de son activité. Conséquences :
///
///  * une capture d'écran de l'application est **noire** ;
///  * un enregistrement d'écran laisse un rectangle noir ;
///  * le sélecteur d'applications (« Récents ») n'affiche **aucune miniature**
///    des écrans de l'application.
///
/// Les données affichées — stock, prix d'achat, noms de clients, chiffre
/// d'affaires — n'ont aucune raison de finir dans la galerie d'un téléphone
/// prêté, ni dans une sauvegarde de photos automatique.
///
/// L'option n'est **pas réglable** dans l'application : un garde-fou qu'un
/// utilisateur peut désactiver ne protège pas d'un utilisateur mal intentionné.
/// Pour transmettre des chiffres, l'export de sauvegarde et la facture PDF
/// restent disponibles (ils ne passent pas par une capture d'écran).
class EcranSecurise {
  EcranSecurise._();

  static const String nomCanal = 'appharmacie/securite_ecran';

  static const MethodChannel canal = MethodChannel(nomCanal);

  static bool _actif = false;

  /// Le blocage est-il effectivement posé ?
  static bool get actif => _actif;

  /// Pose le drapeau. Sans effet et sans erreur hors Android (bureau, tests).
  static Future<bool> activer() => _envoyer('activer');

  /// Retire le drapeau (utilisé par les tests et un éventuel écran de support).
  static Future<bool> desactiver() => _envoyer('desactiver');

  static Future<bool> _envoyer(String methode) async {
    try {
      final reponse = await canal.invokeMethod<bool>(methode);
      final applique = reponse ?? false;
      if (applique) _actif = methode == 'activer';
      return applique;
    } on MissingPluginException {
      // Plateforme sans implémentation (bureau, tests) : on continue sans.
      _actif = false;
      return false;
    } on PlatformException {
      return false;
    }
  }

  /// Remise à zéro : réservé aux tests.
  @visibleForTesting
  static void reinitialiser() {
    _actif = false;
  }
}
