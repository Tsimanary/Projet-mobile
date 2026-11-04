/// Ligne de vente (« achat » côté client).
///
/// Une vente multi-lignes = plusieurs enregistrements partageant le même
/// [numAchat].
class Achat {
  final int? id;
  final String numAchat;
  final String numMed;
  final String nomClient;
  final String dateAchat;
  final int nbr;

  /// Prix unitaire **figé au moment de la vente**.
  ///
  /// Null pour les lignes enregistrées avant la migration : dans ce cas le
  /// prix courant du médicament est utilisé comme repli.
  final int? prixUnitaire;

  const Achat({
    this.id,
    required this.numAchat,
    required this.numMed,
    required this.nomClient,
    required this.dateAchat,
    required this.nbr,
    this.prixUnitaire,
  });

  /// Montant de la ligne (0 si le prix n'est pas connu).
  int get montant => (prixUnitaire ?? 0) * nbr;

  factory Achat.fromMap(Map<String, dynamic> json) => Achat(
        id: (json['id'] as num?)?.toInt(),
        numAchat: (json['numAchat'] ?? '').toString(),
        numMed: (json['numMed'] ?? '').toString(),
        nomClient: (json['nomClient'] ?? '').toString(),
        dateAchat: (json['dateAchat'] ?? '').toString(),
        nbr: (json['nbr'] as num?)?.toInt() ?? 0,
        prixUnitaire: (json['prixUnitaire'] as num?)?.toInt(),
      );

  Map<String, dynamic> toMap() => <String, dynamic>{
        if (id != null) 'id': id,
        'numAchat': numAchat,
        'numMed': numMed,
        'nomClient': nomClient,
        'dateAchat': dateAchat,
        'nbr': nbr,
        'prixUnitaire': prixUnitaire,
      };

  Achat copyWith({int? id, int? prixUnitaire}) => Achat(
        id: id ?? this.id,
        numAchat: numAchat,
        numMed: numMed,
        nomClient: nomClient,
        dateAchat: dateAchat,
        nbr: nbr,
        prixUnitaire: prixUnitaire ?? this.prixUnitaire,
      );
}
