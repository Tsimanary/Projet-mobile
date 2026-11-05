/// Mouvement de stock, tel qu'inscrit dans le journal (`mouvements_stock`).
///
/// Chaque ligne est une **preuve** : une entrée ou une sortie, rattachée à un
/// lot, à une référence (`ENTREE:<id>` ou `ACHAT:<id>`) et — depuis
/// l'introduction des rôles — au compte qui l'a provoquée.
class Mouvement {
  final int? id;
  final String numMed;

  /// `ENTREE` ou `SORTIE`.
  final String type;

  /// Quantité **signée** : positive à l'entrée, négative à la sortie.
  final int quantite;

  /// Origine du mouvement : `ENTREE:12`, `ACHAT:48`…
  final String? reference;

  /// Horodatage complet (`AAAA-MM-JJ HH:MM:SS`).
  final String? dateMouvement;

  /// Compte à l'origine du mouvement (null pour les données antérieures).
  final String? auteur;

  /// Désignation du médicament, renseignée par la jointure SQL (facultative).
  final String? designMed;

  const Mouvement({
    this.id,
    required this.numMed,
    required this.type,
    required this.quantite,
    this.reference,
    this.dateMouvement,
    this.auteur,
    this.designMed,
  });

  factory Mouvement.fromMap(Map<String, dynamic> json) => Mouvement(
        id: (json['id'] as num?)?.toInt(),
        numMed: (json['numMed'] ?? '').toString(),
        type: (json['type'] ?? '').toString(),
        quantite: (json['quantite'] as num?)?.toInt() ?? 0,
        reference: json['reference']?.toString(),
        dateMouvement: json['dateMouvement']?.toString(),
        auteur: json['auteur']?.toString(),
        designMed: json['designMed']?.toString(),
      );

  bool get estEntree => type.toUpperCase() == 'ENTREE';

  /// Libellé affichable, même pour un type inattendu (donnée importée).
  String get libelleType {
    switch (type.toUpperCase()) {
      case 'ENTREE':
        return 'Entrée';
      case 'SORTIE':
        return 'Sortie';
      case '':
        return 'Mouvement';
      default:
        return type;
    }
  }

  /// Quantité affichée : toujours positive, le sens est donné par [libelleType].
  int get quantiteAffichee => quantite.abs();

  /// Nom du compte, ou une mention explicite si la ligne est antérieure aux
  /// rôles (ou restaurée depuis une sauvegarde d'avant la version 1.7).
  String get auteurAffiche {
    final nom = (auteur ?? '').trim();
    return nom.isEmpty ? 'compte non enregistré' : nom;
  }

  /// Référence lisible : `Achat 48`, `Entrée 12`, sinon la valeur brute.
  String get referenceAffichee {
    final brut = (reference ?? '').trim();
    if (brut.isEmpty) return 'sans référence';
    final morceaux = brut.split(':');
    if (morceaux.length != 2) return brut;
    final numero = morceaux[1];
    switch (morceaux[0].toUpperCase()) {
      case 'ACHAT':
        return 'Vente $numero';
      case 'ENTREE':
        return 'Réception $numero';
      default:
        return brut;
    }
  }
}
