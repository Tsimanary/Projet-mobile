import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart' as cryptographie;

import 'empreinte.dart';

/// Hachage des secrets (mots de passe de compte et code d'accès).
///
/// Deux générations cohabitent, et c'est volontaire :
///
///  * **Argon2id** ([hacherFort] / [verifierFort]) pour tout secret créé ou
///    modifié depuis la version 1.4 : fonction de dérivation **lente et
///    coûteuse en mémoire**, état de l'art pour les mots de passe ;
///  * **SHA-256 salé** ([hasher] / [verifier]) pour les empreintes héritées,
///    conservées uniquement le temps de la migration à la volée.
///
/// La migration est transparente : dès qu'un utilisateur (ou un code d'accès)
/// est vérifié avec l'ancien format, l'empreinte est réécrite en Argon2id.
class Securite {
  const Securite._();

  /// Longueur du sel, en octets.
  static const int longueurSel = 16;

  // ---------------------------------------------------------------------------
  // Argon2id (format courant)
  // ---------------------------------------------------------------------------

  /// Vrai si [valeur] est une empreinte Argon2id au format PHC exploitable.
  static bool estEmpreinteArgon2id(String valeur) {
    return EmpreinteArgon2id.analyser(valeur) != null;
  }

  /// Dérive une empreinte Argon2id autoportante (sel aléatoire inclus).
  static Future<String> hacherFort(
    String secret, {
    ParametresArgon2id parametres = ParametresArgon2id.recommande,
  }) async {
    final sel = selAleatoire(longueurOctets: longueurSel);
    final empreinte = await deriverCle(
      secret: secret,
      sel: sel,
      parametres: parametres,
    );

    return EmpreinteArgon2id(
      memoire: parametres.memoire,
      iterations: parametres.iterations,
      parallelisme: parametres.parallelisme,
      sel: sel,
      empreinte: empreinte,
    ).encoder();
  }

  /// Vérifie un secret contre une empreinte Argon2id.
  ///
  /// Les paramètres de coût sont relus dans l'empreinte : une empreinte créée
  /// avec des paramètres plus faibles reste vérifiable.
  static Future<bool> verifierFort({
    required String secret,
    required String empreinte,
  }) async {
    final analysee = EmpreinteArgon2id.analyser(empreinte);
    if (analysee == null) return false;

    final calculee = await deriverCle(
      secret: secret,
      sel: analysee.sel,
      parametres: ParametresArgon2id(
        memoire: analysee.memoire,
        iterations: analysee.iterations,
        parallelisme: analysee.parallelisme,
        longueur: analysee.empreinte.length,
      ),
    );

    return egalEnTempsConstant(calculee, analysee.empreinte);
  }

  /// Dérive [longueur] octets de clé à partir d'un secret et d'un sel.
  ///
  /// Utilisée pour les empreintes Argon2id **et** pour la clé AES-256 du
  /// fichier de sauvegarde : un seul chemin de dérivation, donc un seul endroit
  /// à auditer.
  static Future<List<int>> deriverCle({
    required String secret,
    required List<int> sel,
    required ParametresArgon2id parametres,
  }) async {
    final algorithme = cryptographie.Argon2id(
      parallelism: parametres.parallelisme,
      memory: parametres.memoire,
      iterations: parametres.iterations,
      hashLength: parametres.longueur,
    );

    final cle = await algorithme.deriveKey(
      secretKey: cryptographie.SecretKey(utf8.encode(secret)),
      nonce: sel,
    );

    return cle.extractBytes();
  }

  // ---------------------------------------------------------------------------
  // Héritage : SHA-256 salé (uniquement pour la migration)
  // ---------------------------------------------------------------------------

  /// Sel aléatoire encodé en base64url (ancien format).
  static String genererSel({int longueurOctets = longueurSel}) {
    return base64UrlEncode(selAleatoire(longueurOctets: longueurOctets));
  }

  /// Octets aléatoires issus du générateur cryptographique du système.
  static List<int> selAleatoire({int longueurOctets = longueurSel}) {
    final aleatoire = Random.secure();
    return List<int>.generate(
      longueurOctets,
      (_) => aleatoire.nextInt(256),
    );
  }

  /// Ancienne empreinte : `sha256("sel::secret")`.
  ///
  /// Conservée pour vérifier — puis migrer — les empreintes existantes.
  static String hasher(String secret, String sel) {
    return sha256.convert(utf8.encode('$sel::$secret')).toString();
  }

  /// Vérifie un secret contre l'ancien format.
  static bool verifier({
    required String motDePasse,
    required String sel,
    required String hashAttendu,
  }) {
    if (sel.isEmpty || hashAttendu.isEmpty) return false;
    return hasher(motDePasse, sel) == hashAttendu;
  }
}
