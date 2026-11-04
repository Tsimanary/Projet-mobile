import 'exceptions.dart';

/// Règles de stock **pures** (aucune dépendance Flutter ni SQLite).
///
/// Depuis l'introduction des lots, la vérité du stock est la somme des
/// `quantiteRestante` des lots : ces fonctions ne calculent donc plus de
/// « nouveau stock », elles valident la disponibilité et allouent les lots à
/// consommer (FEFO).
class StockRules {
  const StockRules._();

  /// Vrai si [quantite] unités peuvent être prélevées sur [stock].
  static bool stockSuffisant({required int stock, required int quantite}) {
    return quantite > 0 && stock >= quantite;
  }

  /// Lève [StockInsuffisantException] si [disponible] ne couvre pas [demande].
  static void verifierDisponibilite({
    required int disponible,
    required int demande,
    required String designation,
  }) {
    if (demande <= 0) {
      throw ArgumentError.value(
        demande,
        'demande',
        'La quantité demandée doit être supérieure à zéro.',
      );
    }
    if (disponible < demande) {
      throw StockInsuffisantException(
        designation: designation,
        demande: demande,
        disponible: disponible,
      );
    }
  }

  /// Montant d'une ligne de facture.
  static int montantLigne({required int prixUnitaire, required int quantite}) {
    if (prixUnitaire < 0 || quantite < 0) {
      throw ArgumentError('Le prix et la quantité doivent être positifs.');
    }
    return prixUnitaire * quantite;
  }
}

/// Lot disponible pour une sortie de stock (vue minimale pour l'allocation).
class LotDisponible {
  const LotDisponible({
    required this.id,
    required this.quantiteRestante,
    this.datePeremption,
  });

  final int id;
  final int quantiteRestante;

  /// Date `AAAA-MM-JJ`, ou `null` si inconnue.
  final String? datePeremption;
}

/// Quantité prélevée sur un lot donné.
class AllocationLot {
  const AllocationLot({required this.lotId, required this.quantite});

  final int lotId;
  final int quantite;

  @override
  String toString() => 'Lot $lotId × $quantite';
}

/// Règle FEFO (*First Expired, First Out*) : on sort d'abord le lot dont la
/// péremption est la plus proche ; les lots sans date connue partent en dernier.
///
/// Retourne les allocations dans l'ordre de consommation. La quantité
/// réellement allouée peut être inférieure à la demande : c'est à l'appelant
/// de vérifier `quantiteAllouee(...)` (ou d'appeler
/// [StockRules.verifierDisponibilite]) avant d'écrire.
List<AllocationLot> allouerLots({
  required List<LotDisponible> lots,
  required int quantite,
}) {
  if (quantite <= 0) {
    throw ArgumentError.value(
      quantite,
      'quantite',
      'La quantité à prélever doit être supérieure à zéro.',
    );
  }

  final tries = lots
      .where((lot) => lot.quantiteRestante > 0)
      .toList(growable: false)
    ..sort((a, b) {
      final cleA = a.datePeremption ?? '9999-12-31';
      final cleB = b.datePeremption ?? '9999-12-31';
      final comparaison = cleA.compareTo(cleB);
      if (comparaison != 0) return comparaison;
      return a.id.compareTo(b.id);
    });

  final allocations = <AllocationLot>[];
  var reste = quantite;

  for (final lot in tries) {
    if (reste == 0) break;
    final prelevement =
        lot.quantiteRestante >= reste ? reste : lot.quantiteRestante;
    allocations.add(AllocationLot(lotId: lot.id, quantite: prelevement));
    reste -= prelevement;
  }

  return allocations;
}

/// Total réellement alloué par [allouerLots].
int quantiteAllouee(List<AllocationLot> allocations) {
  return allocations.fold<int>(0, (total, a) => total + a.quantite);
}
