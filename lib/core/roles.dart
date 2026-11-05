import 'exceptions.dart';

/// Rôles des comptes et matrice des droits.
///
/// Deux rôles suffisent à couvrir la réalité d'une officine :
///
///  * **vendeur** — vend, consulte le stock et reçoit les livraisons ;
///  * **gestionnaire** — tout, y compris ce qui engage la comptabilité
///    (corriger ou supprimer une vente), le catalogue, les comptes et les
///    sauvegardes.
///
/// La matrice est volontairement **fermée par défaut** : toute nouvelle
/// fonctionnalité est réservée au gestionnaire tant qu'on n'a pas décidé
/// explicitement de l'ouvrir au vendeur.
enum RoleUtilisateur {
  gestionnaire,
  vendeur;

  String get libelle => switch (this) {
        RoleUtilisateur.gestionnaire => 'Gestionnaire',
        RoleUtilisateur.vendeur => 'Vendeur',
      };

  String get description => switch (this) {
        RoleUtilisateur.gestionnaire =>
          'Tous les droits : ventes, catalogue, comptes, sauvegardes.',
        RoleUtilisateur.vendeur =>
          'Ventes, réceptions et consultation. Ne peut rien supprimer.',
      };

  /// Lit un rôle stocké en base.
  ///
  /// * valeur absente (`null`/vide) → **gestionnaire** : ce sont les comptes
  ///   créés avant l'introduction des rôles, donc les propriétaires ;
  /// * valeur inconnue → **vendeur** : on ne donne jamais un droit par erreur
  ///   sur une donnée inattendue.
  static RoleUtilisateur depuis(String? texte) {
    final valeur = (texte ?? '').trim().toLowerCase();
    if (valeur.isEmpty) return RoleUtilisateur.gestionnaire;
    for (final role in RoleUtilisateur.values) {
      if (role.name == valeur) return role;
    }
    return RoleUtilisateur.vendeur;
  }

  String get valeurBase => name;
}

/// Droits accordés par un rôle.
class Permissions {
  const Permissions(this.role);

  final RoleUtilisateur role;

  bool get estGestionnaire => role == RoleUtilisateur.gestionnaire;

  // --- Ouvert aux deux rôles ------------------------------------------------

  /// Consulter le tableau de bord, le catalogue, les lots et l'historique.
  bool get peutConsulter => true;

  /// Enregistrer une vente.
  bool get peutVendre => true;

  /// Réceptionner une livraison (créer une entrée de stock).
  bool get peutCreerEntree => true;

  // --- Réservé au gestionnaire ----------------------------------------------

  /// Corriger ou supprimer une entrée déjà enregistrée.
  bool get peutModifierEntree => estGestionnaire;

  /// Supprimer une vente (et donc rendre le stock).
  bool get peutSupprimerVente => estGestionnaire;

  /// Corriger une vente (quantité, prix, client).
  bool get peutModifierVente => estGestionnaire;

  /// Créer, modifier ou supprimer un médicament — donc **fixer les prix**.
  bool get peutGererCatalogue => estGestionnaire;

  /// Créer, changer de rôle ou supprimer un compte.
  bool get peutGererUtilisateurs => estGestionnaire;

  /// Exporter une sauvegarde.
  bool get peutSauvegarder => estGestionnaire;

  /// Restaurer une sauvegarde (remplace toutes les données).
  bool get peutRestaurer => estGestionnaire;

  /// Code d'accès et réglages de sécurité.
  bool get peutGererSecurite => estGestionnaire;
}

/// Règles de gestion des comptes.
///
/// Isolées du SQL pour être vérifiables sans base de données : ce sont elles
/// qui empêchent de se retrouver dans une application sans gestionnaire,
/// c'est-à-dire sans personne pour créer un compte ou restaurer une sauvegarde.
class ReglesComptes {
  ReglesComptes._();

  static const String messageDernierGestionnaire =
      'Impossible : il doit rester au moins un gestionnaire.';

  static const String messageCompteCourant =
      'Vous ne pouvez pas supprimer le compte avec lequel vous êtes connecté.';

  static int compterGestionnaires(Iterable<RoleUtilisateur> roles) =>
      roles.where((role) => role == RoleUtilisateur.gestionnaire).length;

  /// Peut-on retirer le rôle gestionnaire à ce compte ?
  ///
  /// Retirer un droit déjà absent est toujours permis (idempotent).
  static bool peutRetirerGestionnaire({
    required int gestionnaires,
    required RoleUtilisateur roleActuel,
  }) {
    if (roleActuel != RoleUtilisateur.gestionnaire) return true;
    return gestionnaires > 1;
  }

  /// Peut-on supprimer ce compte ?
  static bool peutSupprimer({
    required int gestionnaires,
    required RoleUtilisateur roleCible,
    required bool compteConnecte,
  }) {
    if (compteConnecte) return false;
    if (roleCible != RoleUtilisateur.gestionnaire) return true;
    return gestionnaires > 1;
  }

  /// Lève [OperationRefuseeException] avec le message adapté, ou ne fait rien.
  static void verifierSuppression({
    required int gestionnaires,
    required RoleUtilisateur roleCible,
    required bool compteConnecte,
  }) {
    if (compteConnecte) {
      throw const OperationRefuseeException(messageCompteCourant);
    }
    if (!peutSupprimer(
      gestionnaires: gestionnaires,
      roleCible: roleCible,
      compteConnecte: compteConnecte,
    )) {
      throw const OperationRefuseeException(messageDernierGestionnaire);
    }
  }

  static void verifierRetraitGestionnaire({
    required int gestionnaires,
    required RoleUtilisateur roleActuel,
  }) {
    if (!peutRetirerGestionnaire(
      gestionnaires: gestionnaires,
      roleActuel: roleActuel,
    )) {
      throw const OperationRefuseeException(messageDernierGestionnaire);
    }
  }
}
