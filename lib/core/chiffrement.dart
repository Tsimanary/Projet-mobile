import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart' as cryptographie;

import 'empreinte.dart';
import 'exceptions.dart';
import 'securite.dart';

/// Chiffrement du fichier de sauvegarde par **phrase secrète**.
///
/// Le fichier produit est une enveloppe JSON autoportante :
///
/// ```json
/// {
///   "application": "appharmacie",
///   "type": "sauvegarde-chiffree",
///   "format": 1,
///   "kdf": {
///     "algorithme": "argon2id",
///     "memoire": 19456, "iterations": 2, "parallelisme": 1,
///     "sel": "…base64url…"
///   },
///   "chiffrement": {
///     "algorithme": "AES-256-GCM",
///     "nonce": "…", "donnees": "…", "tag": "…"
///   }
/// }
/// ```
///
/// * la **clé** n'est jamais stockée : elle est redérivée de la phrase à chaque
///   ouverture (Argon2id, mêmes paramètres que les mots de passe) ;
/// * **AES-256-GCM** authentifie le contenu : une modification, même d'un seul
///   octet, fait échouer le déchiffrement ;
/// * sel et nonce sont tirés au hasard à chaque export : deux sauvegardes du
///   même contenu n'ont rien en commun.
class ChiffrementSauvegarde {
  const ChiffrementSauvegarde._();

  static const String typeEnveloppe = 'sauvegarde-chiffree';
  static const int versionEnveloppe = 1;

  /// Longueur minimale d'une phrase secrète (contrôlée par l'interface).
  static const int longueurMinPhrase = 8;

  static const String _application = 'appharmacie';

  /// Vrai si [contenu] est une enveloppe chiffrée produite par l'application.
  static bool estChiffree(String contenu) {
    if (!contenu.trimLeft().startsWith('{')) return false;
    try {
      final decode = jsonDecode(contenu);
      if (decode is! Map) return false;
      return decode['type'] == typeEnveloppe;
    } on FormatException {
      return false;
    }
  }

  /// Chiffre [clair] avec [phrase] et retourne l'enveloppe JSON.
  static Future<String> chiffrer(
    String clair,
    String phrase, {
    ParametresArgon2id parametres = ParametresArgon2id.recommande,
  }) async {
    if (phrase.trim().length < longueurMinPhrase) {
      throw ArgumentError.value(
        phrase.length,
        'phrase',
        'La phrase secrète doit comporter au moins '
            '$longueurMinPhrase caractères.',
      );
    }

    final sel = Securite.selAleatoire();
    final cle = await Securite.deriverCle(
      secret: phrase,
      sel: sel,
      parametres: parametres,
    );

    final algorithme = cryptographie.AesGcm.with256bits();
    final nonce = _octetsAleatoires(algorithme.nonceLength);
    final boite = await algorithme.encrypt(
      utf8.encode(clair),
      secretKey: cryptographie.SecretKey(cle),
      nonce: nonce,
    );

    return jsonEncode(<String, Object?>{
      'application': _application,
      'type': typeEnveloppe,
      'format': versionEnveloppe,
      'kdf': <String, Object?>{
        'algorithme': 'argon2id',
        'memoire': parametres.memoire,
        'iterations': parametres.iterations,
        'parallelisme': parametres.parallelisme,
        'sel': _enBase64Url(sel),
      },
      'chiffrement': <String, Object?>{
        'algorithme': 'AES-256-GCM',
        'nonce': _enBase64Url(boite.nonce),
        'donnees': _enBase64Url(boite.cipherText),
        'tag': _enBase64Url(boite.mac.bytes),
      },
    });
  }

  /// Déchiffre une enveloppe produite par [chiffrer].
  ///
  /// Lève [OperationRefuseeException] si la phrase est fausse, si le fichier a
  /// été modifié ou s'il n'est pas une enveloppe valide : dans tous les cas, le
  /// message affiché à l'utilisateur reste le même (« phrase incorrecte ou
  /// fichier altéré »), pour ne rien révéler d'utile à un attaquant.
  static Future<String> dechiffrer(String enveloppe, String phrase) async {
    final contenu = _analyserEnveloppe(enveloppe);

    final cle = await Securite.deriverCle(
      secret: phrase,
      sel: contenu.sel,
      parametres: ParametresArgon2id(
        memoire: contenu.memoire,
        iterations: contenu.iterations,
        parallelisme: contenu.parallelisme,
        // AES-256 : la clé dérivée doit faire exactement 32 octets.
        longueur: 32,
      ),
    );

    final algorithme = cryptographie.AesGcm.with256bits();
    final boite = cryptographie.SecretBox(
      contenu.donnees,
      nonce: contenu.nonce,
      mac: cryptographie.Mac(contenu.tag),
    );

    try {
      final clair = await algorithme.decrypt(
        boite,
        secretKey: cryptographie.SecretKey(cle),
      );
      return utf8.decode(clair);
    } on cryptographie.SecretBoxAuthenticationError {
      throw const OperationRefuseeException(
        'Phrase secrète incorrecte, ou fichier altéré.',
      );
    } on FormatException {
      throw const OperationRefuseeException(
        'Phrase secrète incorrecte, ou fichier altéré.',
      );
    }
  }

  static _Enveloppe _analyserEnveloppe(String texte) {
    Object? decode;
    try {
      decode = jsonDecode(texte);
    } on FormatException {
      throw const OperationRefuseeException(
        "Ce fichier n'est pas une sauvegarde AppHarmacie chiffrée.",
      );
    }

    if (decode is! Map) {
      throw const OperationRefuseeException(
        "Ce fichier n'est pas une sauvegarde AppHarmacie chiffrée.",
      );
    }

    final document = Map<String, Object?>.from(decode);
    if ((document['application'] ?? '').toString() != _application ||
        (document['type'] ?? '').toString() != typeEnveloppe) {
      throw const OperationRefuseeException(
        "Ce fichier n'est pas une sauvegarde AppHarmacie chiffrée.",
      );
    }

    final format = document['format'];
    if (format is! num || format.toInt() > versionEnveloppe) {
      throw const OperationRefuseeException(
        'Sauvegarde chiffrée créée par une version plus récente de '
        "l'application. Mettez l'application à jour.",
      );
    }

    final kdf = document['kdf'];
    if (kdf is! Map || (kdf['algorithme'] ?? '') != 'argon2id') {
      throw const OperationRefuseeException(
        'Sauvegarde chiffrée illisible : méthode de dérivation inconnue.',
      );
    }

    final memoire = kdf['memoire'];
    final iterations = kdf['iterations'];
    final parallelisme = kdf['parallelisme'];
    if (memoire is! num || iterations is! num || parallelisme is! num) {
      throw const OperationRefuseeException(
        'Sauvegarde chiffrée illisible : paramètres de dérivation absents.',
      );
    }

    final chiffrement = document['chiffrement'];
    if (chiffrement is! Map) {
      throw const OperationRefuseeException(
        'Sauvegarde chiffrée illisible : aucun contenu chiffré.',
      );
    }

    final sel = _depuisBase64Url(kdf['sel']);
    final nonce = _depuisBase64Url(chiffrement['nonce']);
    final donnees = _depuisBase64Url(chiffrement['donnees']);
    final tag = _depuisBase64Url(chiffrement['tag']);

    if (sel == null ||
        nonce == null ||
        donnees == null ||
        tag == null ||
        sel.isEmpty ||
        nonce.isEmpty ||
        tag.isEmpty) {
      throw const OperationRefuseeException(
        'Sauvegarde chiffrée illisible : contenu incomplet.',
      );
    }

    return _Enveloppe(
      memoire: memoire.toInt(),
      iterations: iterations.toInt(),
      parallelisme: parallelisme.toInt(),
      sel: sel,
      nonce: nonce,
      donnees: donnees,
      tag: tag,
    );
  }

  static List<int> _octetsAleatoires(int longueur) {
    final aleatoire = Random.secure();
    return List<int>.generate(longueur, (_) => aleatoire.nextInt(256));
  }

  static String _enBase64Url(List<int> octets) {
    return base64Url.encode(octets).replaceAll('=', '');
  }

  static List<int>? _depuisBase64Url(Object? valeur) {
    if (valeur is! String || valeur.isEmpty) return null;
    final reste = valeur.length % 4;
    final complete = reste == 0 ? valeur : '$valeur${'=' * (4 - reste)}';
    try {
      return base64Url.decode(complete);
    } on FormatException {
      return null;
    }
  }
}

class _Enveloppe {
  const _Enveloppe({
    required this.memoire,
    required this.iterations,
    required this.parallelisme,
    required this.sel,
    required this.nonce,
    required this.donnees,
    required this.tag,
  });

  final int memoire;
  final int iterations;
  final int parallelisme;
  final List<int> sel;
  final List<int> nonce;
  final List<int> donnees;
  final List<int> tag;
}
