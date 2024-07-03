class Entree {
  int? id;
  final String numEntr;
  final String numMed;
  int stockEntr;
  final String dateEntr;

  Entree({
    this.id,
    required this.numEntr,
    required this.numMed,
    required this.stockEntr,
    required this.dateEntr,
  });

  factory Entree.fromMap(Map<String, dynamic> json) => Entree(
    id: json["id"],
    numEntr: json["numEntr"].toString(),
    numMed: json["numMed"].toString(),
    stockEntr: json["stockEntr"],
    dateEntr: json["dateEntr"].toString(),
  );

  Map<String, dynamic> toMap() => {
    "id": id,
    "numEntr": numEntr,
    "numMed": numMed,
    "stockEntr": stockEntr,
    "dateEntr": dateEntr,
  };
}
