/// Exceptions métier partagées par la couche de données et l'interface.
///
/// Chaque exception porte un message directement affichable à l'utilisateur.
class MedicamentDejaExisteException implements Exception {
  const MedicamentDejaExisteException(this.numMed);

  final String numMed;

  @override
  String toString() =>
      "Le numéro « $numMed » est déjà utilisé par un autre médicament.";
}

class MedicamentUtiliseException implements Exception {
  const MedicamentUtiliseException({
    required this.designation,
    this.ventes = 0,
    this.entrees = 0,
  });

  final String designation;
  final int ventes;
  final int entrees;

  @override
  String toString() =>
      "Suppression impossible : « $designation » possède $ventes vente(s) "
      "et $entrees entrée(s) enregistrée(s).";
}

class StockInsuffisantException implements Exception {
  const StockInsuffisantException({
    required this.designation,
    required this.demande,
    required this.disponible,
  });

  final String designation;
  final int demande;
  final int disponible;

  @override
  String toString() =>
      "Stock insuffisant pour « $designation » : $demande demandé(s), "
      "$disponible disponible(s).";
}

class EntiteIntrouvableException implements Exception {
  const EntiteIntrouvableException(this.message);

  final String message;

  @override
  String toString() => message;
}

class OperationRefuseeException implements Exception {
  const OperationRefuseeException(this.message);

  final String message;

  @override
  String toString() => message;
}

class UtilisateurDejaExisteException implements Exception {
  const UtilisateurDejaExisteException(this.nom);

  final String nom;

  @override
  String toString() => "Le nom d'utilisateur « $nom » est déjà pris.";
}
