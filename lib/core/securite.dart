import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// Hachage des mots de passe.
///
/// Un sel aléatoire est généré par utilisateur, puis le mot de passe est
/// haché en SHA-256 sur `sel::motDePasse`.
///
/// Remarque : SHA-256 salé protège contre la lecture directe de la base,
/// mais n'est pas une fonction de dérivation lente. Le passage à Argon2id
/// (ou bcrypt) reste recommandé pour une mise en production (voir audit).
class Securite {
  const Securite._();

  static String genererSel({int longueurOctets = 16}) {
    final aleatoire = Random.secure();
    final octets = List<int>.generate(
      longueurOctets,
      (_) => aleatoire.nextInt(256),
    );
    return base64UrlEncode(octets);
  }

  static String hasher(String motDePasse, String sel) {
    return sha256.convert(utf8.encode('$sel::$motDePasse')).toString();
  }

  static bool verifier({
    required String motDePasse,
    required String sel,
    required String hashAttendu,
  }) {
    if (sel.isEmpty || hashAttendu.isEmpty) return false;
    return hasher(motDePasse, sel) == hashAttendu;
  }
}
