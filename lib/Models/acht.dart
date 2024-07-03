class Achat {
  int? id;
  final String numAchat;
  final String numMed;
  final String nomClient;
  final String dateAchat;
  int nbr;

  Achat({
    this.id,
    required this.numAchat,
    required this.numMed,
    required this.nomClient,
    required this.dateAchat,
    required this.nbr,
  });

  factory Achat.fromMap(Map<String, dynamic> json) => Achat(
    id: json["id"],
    numAchat: json["numAchat"].toString(),
    numMed: json["numMed"].toString(),
    nomClient: json["nomClient"].toString(),
    dateAchat: json["dateAchat"].toString(),
    nbr: json["nbr"],
  );

  Map<String, dynamic> toMap() => {
    "id": id,
    "numAchat": numAchat,
    "numMed": numMed,
    "nomClient": nomClient,
    "dateAchat": dateAchat,
    "nbr": nbr,
  };
}
