class Medic {
  final int? id;
  final String numMed;
  final String designMed;
  int prixMed;
  int stockMed;

  Medic({
    this.id,
    required this.numMed,
    required this.designMed,
    required this.prixMed,
    required this.stockMed,
  });

  factory Medic.fromMap(Map<String, dynamic> json) => Medic(
        id: (json['id'] as num?)?.toInt(),
        numMed: (json['numMed'] ?? '').toString(),
        designMed: (json['designMed'] ?? '').toString(),
        prixMed: (json['prixMed'] as num?)?.toInt() ?? 0,
        stockMed: (json['stockMed'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toMap() => <String, dynamic>{
        if (id != null) 'id': id,
        'numMed': numMed,
        'designMed': designMed,
        'prixMed': prixMed,
        'stockMed': stockMed,
      };

  @override
  String toString() => 'Medic($numMed, $designMed, $prixMed Ar, stock $stockMed)';
}
