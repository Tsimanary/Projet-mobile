class Medic {
  int? id;
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
    id: json["id"],
    numMed: json["numMed"].toString(),
    designMed: json["designMed"].toString(),
    prixMed: json["prixMed"] as int, // Assurez-vous que prixMed est bien de type int dans la base de données
    stockMed: json["stockMed"] as int, // Assurez-vous que stockMed est bien de type int dans la base de données
  );

  Map<String, dynamic> toMap() => {
    "id": id,
    "numMed": numMed,
    "designMed": designMed,
    "prixMed": prixMed,
    "stockMed": stockMed,
  };
}
