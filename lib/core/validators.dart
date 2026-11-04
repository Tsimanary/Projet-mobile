/// Validateurs de formulaires réutilisables.
class Validators {
  const Validators._();

  /// Champ texte obligatoire.
  static String? obligatoire(
    String? valeur, {
    String champ = 'Ce champ',
    int longueurMin = 1,
  }) {
    final texte = (valeur ?? '').trim();
    if (texte.isEmpty) return '$champ est obligatoire.';
    if (texte.length < longueurMin) {
      return '$champ doit contenir au moins $longueurMin caractères.';
    }
    return null;
  }

  /// Nom d'utilisateur : 3 caractères minimum, sans espace.
  static String? nomUtilisateur(String? valeur) {
    final texte = (valeur ?? '').trim();
    if (texte.isEmpty) return "Le nom d'utilisateur est obligatoire.";
    if (texte.length < 3) {
      return "Le nom d'utilisateur doit contenir au moins 3 caractères.";
    }
    if (texte.contains(' ')) {
      return "Le nom d'utilisateur ne doit pas contenir d'espace.";
    }
    return null;
  }

  /// Mot de passe : 4 caractères minimum (contrainte d'officine, saisie rapide).
  static String? motDePasse(String? valeur) {
    final texte = valeur ?? '';
    if (texte.isEmpty) return 'Le mot de passe est obligatoire.';
    if (texte.length < 4) {
      return 'Le mot de passe doit contenir au moins 4 caractères.';
    }
    return null;
  }

  /// Nombre entier, positif ou nul selon [zeroAutorise].
  static String? entier(
    String? valeur, {
    String champ = 'Ce champ',
    bool zeroAutorise = false,
  }) {
    final texte = (valeur ?? '').trim();
    if (texte.isEmpty) return '$champ est obligatoire.';
    final nombre = int.tryParse(texte);
    if (nombre == null) return '$champ doit être un nombre entier.';
    if (zeroAutorise && nombre < 0) return '$champ ne peut pas être négatif.';
    if (!zeroAutorise && nombre <= 0) {
      return '$champ doit être supérieur à zéro.';
    }
    return null;
  }

  /// Prix unitaire : entier positif ou nul (l'Ariary n'a pas de sous-unité).
  static String? prix(String? valeur) =>
      entier(valeur, champ: 'Le prix', zeroAutorise: true);

  /// Conversion sûre : ne lève jamais d'exception.
  static int? versEntier(String? valeur) => int.tryParse((valeur ?? '').trim());
}
