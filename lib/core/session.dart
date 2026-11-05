import 'exceptions.dart';
import 'roles.dart';

/// Compte actuellement connecté.
class CompteConnecte {
  const CompteConnecte({required this.nom, required this.role});

  final String nom;
  final RoleUtilisateur role;
}

/// Session de travail : qui est connecté, et donc ce qu'il a le droit de faire.
///
/// Volontairement en mémoire seulement : fermer l'application (ou la
/// déconnexion) referme la session, et **sans session, l'application se comporte
/// comme un vendeur** — jamais comme un gestionnaire. Un plantage ne doit pas
/// laisser traîner des droits d'administration.
class Session {
  Session._();

  static CompteConnecte? _courant;

  static CompteConnecte? get courant => _courant;

  static bool get estOuverte => _courant != null;

  static String get nom => _courant?.nom ?? '';

  /// Rôle effectif : vendeur par défaut (principe du moindre privilège).
  static RoleUtilisateur get role =>
      _courant?.role ?? RoleUtilisateur.vendeur;

  static Permissions get permissions => Permissions(role);

  static void ouvrir({required String nom, required RoleUtilisateur role}) {
    _courant = CompteConnecte(nom: nom, role: role);
  }

  static void fermer() {
    _courant = null;
  }

  /// Lève [OperationRefuseeException] si l'utilisateur n'est pas gestionnaire.
  ///
  /// [action] complète le message affiché (« Action réservée au gestionnaire :
  /// supprimer une vente. »).
  static void exigerGestionnaire(String action) {
    if (!permissions.estGestionnaire) {
      throw OperationRefuseeException(
        'Action réservée au gestionnaire : $action.',
      );
    }
  }

  /// Lève [OperationRefuseeException] si [autorise] est faux.
  static void exiger(bool autorise, String action) {
    if (!autorise) {
      throw OperationRefuseeException('Action non autorisée : $action.');
    }
  }
}
