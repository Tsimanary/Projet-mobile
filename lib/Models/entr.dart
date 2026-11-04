/// Mouvement d'entrée de stock.
///
/// Une entrée = **un** enregistrement (jamais fusionné avec une autre) :
/// l'historique des réceptions reste donc intact.
class Entree {
  final int? id;
  final String numEntr;
  final String numMed;
  final int stockEntr;

  /// Date de réception au format `AAAA-MM-JJ`.
  final String dateEntr;

  /// Numéro de lot reçu (facultatif).
  final String? numeroLot;

  /// Date de péremption du lot au format `AAAA-MM-JJ` (null si inconnue).
  final String? datePeremption;

  const Entree({
    this.id,
    required this.numEntr,
    required this.numMed,
    required this.stockEntr,
    required this.dateEntr,
    this.numeroLot,
    this.datePeremption,
  });

  factory Entree.fromMap(Map<String, dynamic> json) => Entree(
        id: (json['id'] as num?)?.toInt(),
        numEntr: (json['numEntr'] ?? '').toString(),
        numMed: (json['numMed'] ?? '').toString(),
        stockEntr: (json['stockEntr'] as num?)?.toInt() ?? 0,
        dateEntr: (json['dateEntr'] ?? '').toString(),
        numeroLot: json['numeroLot'] as String?,
        datePeremption: json['datePeremption'] as String?,
      );

  Map<String, dynamic> toMap() => <String, dynamic>{
        if (id != null) 'id': id,
        'numEntr': numEntr,
        'numMed': numMed,
        'stockEntr': stockEntr,
        'dateEntr': dateEntr,
        'numeroLot': numeroLot,
        'datePeremption': datePeremption,
      };
}
