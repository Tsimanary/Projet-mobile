import 'exceptions.dart';

/// Règles de calcul de stock.
///
/// Ces fonctions sont **pures** (aucune dépendance Flutter ni SQLite) :
/// c'est le cœur métier de l'application, et c'est donc la partie qui doit
/// être testée en priorité (voir `test/stock_rules_test.dart`).
class StockRules {
  const StockRules._();

  /// Vrai si [quantite] unités peuvent être prélevées sur [stock].
  static bool stockSuffisant({required int stock, required int quantite}) {
    return quantite > 0 && stock >= quantite;
  }

  /// Stock après réception de [quantiteEntree] unités.
  static int apresEntree({
    required int stockActuel,
    required int quantiteEntree,
  }) {
    if (quantiteEntree <= 0) {
      throw ArgumentError.value(
        quantiteEntree,
        'quantiteEntree',
        'La quantité entrée doit être supérieure à zéro.',
      );
    }
    return stockActuel + quantiteEntree;
  }

  /// Stock après vente de [quantiteVendue] unités.
  ///
  /// Lève [StockInsuffisantException] si le stock ne couvre pas la quantité.
  static int apresVente({
    required int stockActuel,
    required int quantiteVendue,
    required String designation,
  }) {
    if (quantiteVendue <= 0) {
      throw ArgumentError.value(
        quantiteVendue,
        'quantiteVendue',
        'La quantité vendue doit être supérieure à zéro.',
      );
    }
    if (stockActuel < quantiteVendue) {
      throw StockInsuffisantException(
        designation: designation,
        demande: quantiteVendue,
        disponible: stockActuel,
      );
    }
    return stockActuel - quantiteVendue;
  }

  /// Stock après modification de la quantité d'une entrée existante.
  static int apresModificationEntree({
    required int stockActuel,
    required int ancienneQuantite,
    required int nouvelleQuantite,
  }) {
    if (ancienneQuantite <= 0 || nouvelleQuantite <= 0) {
      throw ArgumentError(
        'Les quantités d\'entrée doivent être supérieures à zéro.',
      );
    }
    return stockActuel + (nouvelleQuantite - ancienneQuantite);
  }

  /// Stock après modification de la quantité d'une vente existante.
  static int apresModificationVente({
    required int stockActuel,
    required int ancienneQuantite,
    required int nouvelleQuantite,
    required String designation,
  }) {
    if (ancienneQuantite <= 0 || nouvelleQuantite <= 0) {
      throw ArgumentError(
        'Les quantités vendues doivent être supérieures à zéro.',
      );
    }
    final variation = nouvelleQuantite - ancienneQuantite;
    if (variation > 0 && stockActuel < variation) {
      throw StockInsuffisantException(
        designation: designation,
        demande: variation,
        disponible: stockActuel,
      );
    }
    return stockActuel - variation;
  }

  /// Montant d'une ligne de facture.
  static int montantLigne({required int prixUnitaire, required int quantite}) {
    if (prixUnitaire < 0 || quantite < 0) {
      throw ArgumentError('Le prix et la quantité doivent être positifs.');
    }
    return prixUnitaire * quantite;
  }
}
