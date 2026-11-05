/// Règles du code d'accès, sans dépendance Flutter ni base de données.
///
/// Isolées ici pour être testables et pour que la politique de sécurité
/// (longueur, nombre d'essais, durée de blocage) soit écrite à un seul endroit.
class ReglesPin {
  const ReglesPin._();

  static const int longueurMin = 4;
  static const int longueurMax = 6;

  /// Essais ratés autorisés avant blocage temporaire.
  static const int tentativesMax = 5;

  /// Durée du blocage une fois le quota d'essais épuisé.
  static const Duration dureeBlocage = Duration(minutes: 5);

  static final RegExp _chiffres = RegExp(r'^\d+$');

  /// Un code valide fait 4 à 6 chiffres, rien d'autre.
  static bool estValide(String pin) {
    if (pin.length < longueurMin || pin.length > longueurMax) return false;
    return _chiffres.hasMatch(pin);
  }

  static bool doitBloquer(int echecs) => echecs >= tentativesMax;

  /// Fin du blocage si [echecs] essais ont été consommés, sinon `null`.
  static DateTime? finBlocage({
    required int echecs,
    required DateTime dernierEchec,
  }) {
    return doitBloquer(echecs) ? dernierEchec.add(dureeBlocage) : null;
  }

  /// Temps restant avant la fin d'un blocage (jamais négatif).
  static Duration blocageRestant({
    required DateTime fin,
    DateTime? maintenant,
  }) {
    final reste = fin.difference(maintenant ?? DateTime.now());
    return reste.isNegative ? Duration.zero : reste;
  }

  /// Durée lisible : `45 s`, `4 min`.
  static String formaterDuree(Duration duree) {
    final secondes = duree.inSeconds;
    if (secondes <= 0) return '0 s';
    if (secondes < 60) return '$secondes s';
    final minutes = (secondes + 59) ~/ 60;
    return '$minutes min';
  }
}
