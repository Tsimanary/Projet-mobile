import '../core/format.dart';

/// Lot de médicament : trace la réception et la péremption.
///
/// Chaque entrée de stock crée (ou complète) un lot. Les sorties se font en
/// FEFO : le lot dont la péremption est la plus proche est consommé d'abord.
class Lot {
  final int? id;
  final String numMed;
  final String? numeroLot;
  final int quantiteRecue;
  final int quantiteRestante;

  /// Date de péremption au format `AAAA-MM-JJ` (null si inconnue).
  final String? datePeremption;

  /// Date de réception au format `AAAA-MM-JJ`.
  final String dateReception;

  /// Désignation du médicament (renseignée par la jointure SQL).
  final String? designMed;

  const Lot({
    this.id,
    required this.numMed,
    this.numeroLot,
    required this.quantiteRecue,
    required this.quantiteRestante,
    this.datePeremption,
    required this.dateReception,
    this.designMed,
  });

  factory Lot.fromMap(Map<String, dynamic> json) => Lot(
        id: (json['id'] as num?)?.toInt(),
        numMed: (json['numMed'] ?? '').toString(),
        numeroLot: json['numeroLot'] as String?,
        quantiteRecue: (json['quantiteRecue'] as num?)?.toInt() ?? 0,
        quantiteRestante: (json['quantiteRestante'] as num?)?.toInt() ?? 0,
        datePeremption: json['datePeremption'] as String?,
        dateReception: (json['dateReception'] ?? '').toString(),
        designMed: json['designMed'] as String?,
      );

  Map<String, dynamic> toMap() => <String, dynamic>{
        if (id != null) 'id': id,
        'numMed': numMed,
        'numeroLot': numeroLot,
        'quantiteRecue': quantiteRecue,
        'quantiteRestante': quantiteRestante,
        'datePeremption': datePeremption,
        'dateReception': dateReception,
      };

  /// Jours restants avant péremption (négatif si dépassée, null si inconnue).
  int? joursRestants({DateTime? maintenant}) =>
      joursAvant(datePeremption, maintenant: maintenant);

  bool estPerime({DateTime? maintenant}) {
    final jours = joursRestants(maintenant: maintenant);
    return jours != null && jours < 0;
  }

  /// Vrai si la péremption tombe dans [jours] jours (lot encore valable).
  bool perimeBientot({int jours = 90, DateTime? maintenant}) {
    final restants = joursRestants(maintenant: maintenant);
    return restants != null && restants >= 0 && restants <= jours;
  }

  String get libelle => numeroLot == null || numeroLot!.trim().isEmpty
      ? 'Lot sans numéro'
      : 'Lot $numeroLot';

  @override
  String toString() =>
      'Lot($numeroLot, $numMed, reste $quantiteRestante, pér. $datePeremption)';
}
