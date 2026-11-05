import 'dart:convert';

/// Paramètres Argon2id.
///
/// `memoire` est exprimée en **kio** (blocs de 1 kio), conformément à la RFC
/// 9106. Les paramètres sont enregistrés dans l'empreinte elle-même : les
/// durcir plus tard n'invalide donc aucune empreinte existante.
class ParametresArgon2id {
  const ParametresArgon2id({
    this.memoire = 19456,
    this.iterations = 2,
    this.parallelisme = 1,
    this.longueur = 32,
  });

  /// Recommandation OWASP : 19 Mio de mémoire, 2 passes, 1 fil.
  static const ParametresArgon2id recommande = ParametresArgon2id();

  /// Paramètres minimalistes réservés aux tests (quelques millisecondes).
  static const ParametresArgon2id tests = ParametresArgon2id(
    memoire: 64,
    iterations: 1,
    parallelisme: 1,
  );

  final int memoire;
  final int iterations;
  final int parallelisme;

  /// Longueur de l'empreinte en octets.
  final int longueur;
}

/// Empreinte Argon2id au format PHC :
/// `$argon2id$v=19$m=19456,t=2,p=1$<sel base64url>$<empreinte base64url>`
///
/// Ce format est **auto-descriptif** : la vérification relit la mémoire, les
/// itérations et le parallélisme réellement utilisés. Une montée de version des
/// paramètres ne casse donc rien, et un attaquant ne peut pas faire baisser le
/// coût en modifiant l'empreinte (le calcul serait alors faux).
class EmpreinteArgon2id {
  const EmpreinteArgon2id({
    required this.memoire,
    required this.iterations,
    required this.parallelisme,
    required this.sel,
    required this.empreinte,
    this.version = 19,
  });

  final int memoire;
  final int iterations;
  final int parallelisme;
  final List<int> sel;
  final List<int> empreinte;
  final int version;

  static const String _dollar = r'$';

  /// Préfixe permettant de reconnaître une empreinte moderne.
  static const String prefixe = r'$argon2id$';

  String encoder() {
    final selEncode = _enBase64Url(sel);
    final empreinteEncodee = _enBase64Url(empreinte);
    return '${_dollar}argon2id${_dollar}v=$version'
        '${_dollar}m=$memoire,t=$iterations,p=$parallelisme'
        '${_dollar}$selEncode${_dollar}$empreinteEncodee';
  }

  /// Analyse une empreinte PHC ; retourne `null` si elle n'est pas exploitable.
  ///
  /// Aucune exception n'est propagée : un contenu de base abîmé ne doit pas
  /// faire planter l'application, il doit faire échouer la vérification.
  static EmpreinteArgon2id? analyser(String valeur) {
    final texte = valeur.trim();
    if (!texte.startsWith(prefixe)) return null;

    final morceaux = texte.split(_dollar);
    // '' | argon2id | v=19 | m=..,t=..,p=.. | sel | empreinte
    if (morceaux.length != 6) return null;
    if (morceaux[1] != 'argon2id') return null;

    final version = _entier(morceaux[2], 'v=');
    if (version == null || version < 16) return null;

    final parametres = <String, int>{};
    for (final partie in morceaux[3].split(',')) {
      final egal = partie.indexOf('=');
      if (egal <= 0) return null;
      final valeurParametre = int.tryParse(partie.substring(egal + 1));
      if (valeurParametre == null) return null;
      parametres[partie.substring(0, egal)] = valeurParametre;
    }

    final memoire = parametres['m'];
    final iterations = parametres['t'];
    final parallelisme = parametres['p'];
    if (memoire == null || iterations == null || parallelisme == null) {
      return null;
    }
    if (memoire < 8 * parallelisme || iterations < 1 || parallelisme < 1) {
      return null;
    }

    final sel = _depuisBase64Url(morceaux[4]);
    final empreinte = _depuisBase64Url(morceaux[5]);
    if (sel == null || empreinte == null || empreinte.isEmpty) return null;

    return EmpreinteArgon2id(
      memoire: memoire,
      iterations: iterations,
      parallelisme: parallelisme,
      sel: sel,
      empreinte: empreinte,
      version: version,
    );
  }

  static int? _entier(String morceau, String prefixeAttendu) {
    if (!morceau.startsWith(prefixeAttendu)) return null;
    return int.tryParse(morceau.substring(prefixeAttendu.length));
  }

  static String _enBase64Url(List<int> octets) {
    return base64Url.encode(octets).replaceAll('=', '');
  }

  static List<int>? _depuisBase64Url(String texte) {
    if (texte.isEmpty) return null;
    final reste = texte.length % 4;
    final complete = reste == 0 ? texte : '$texte${'=' * (4 - reste)}';
    try {
      return base64Url.decode(complete);
    } on FormatException {
      return null;
    }
  }

  @override
  String toString() => encoder();
}

/// Compare deux empreintes sans révéler, par le temps de réponse, la position
/// du premier octet différent.
bool egalEnTempsConstant(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  var difference = 0;
  for (var i = 0; i < a.length; i++) {
    difference |= a[i] ^ b[i];
  }
  return difference == 0;
}
