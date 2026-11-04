import 'package:intl/intl.dart';

/// Formatage local sans dépendre des données de locale d'`intl`.
///
/// Exemple : `formaterMontant(125000)` -> `125 000 Ar`.
String formaterMontant(int montant) {
  return '${formaterNombre(montant)} Ar';
}

/// Nombre avec séparateurs de milliers, sans devise.
String formaterNombre(int nombre) {
  final texte = nombre.abs().toString();
  final tampon = StringBuffer();
  for (var i = 0; i < texte.length; i++) {
    if (i > 0 && (texte.length - i) % 3 == 0) {
      tampon.write(' ');
    }
    tampon.write(texte[i]);
  }
  return "${nombre < 0 ? '-' : ''}$tampon";
}

/// Date affichée à l'utilisateur.
String formaterDate(DateTime date) => DateFormat('dd/MM/yyyy').format(date);

final RegExp _motifIso = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');
final RegExp _motifFrancais = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{2}|\d{4})$');

/// Analyse une date saisie, quel que soit le format historique.
///
/// Accepte `JJ/MM/AAAA` (format courant), `JJ/MM/AA` (anciennes données) et
/// `AAAA-MM-JJ` (ISO). Retourne `null` si la valeur est inexploitable.
///
/// L'analyse est faite manuellement (et non via `DateFormat.parseStrict`)
/// pour éviter toute ambiguïté sur les années à deux chiffres.
DateTime? analyserDate(String texte) {
  final valeur = texte.trim();
  if (valeur.isEmpty) return null;

  final iso = _motifIso.firstMatch(valeur);
  if (iso != null) {
    return _construireDate(
      jour: int.parse(iso.group(3)!),
      mois: int.parse(iso.group(2)!),
      annee: int.parse(iso.group(1)!),
    );
  }

  final francais = _motifFrancais.firstMatch(valeur);
  if (francais != null) {
    final jour = int.parse(francais.group(1)!);
    final mois = int.parse(francais.group(2)!);
    var annee = int.parse(francais.group(3)!);
    if (annee < 100) annee += 2000;
    return _construireDate(jour: jour, mois: mois, annee: annee);
  }

  return null;
}

DateTime? _construireDate({
  required int jour,
  required int mois,
  required int annee,
}) {
  if (mois < 1 || mois > 12 || jour < 1 || jour > 31 || annee < 1900) {
    return null;
  }
  final date = DateTime(annee, mois, jour);
  // Rejette les dates inexistantes (ex. 31/02).
  if (date.day != jour || date.month != mois || date.year != annee) {
    return null;
  }
  return date;
}
