import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Coffre du système (Keystore Android, Keychain iOS) : accès aux secrets qui
/// ne doivent jamais être lisibles depuis un fichier de l'application.
///
/// Deux secrets y sont conservés :
///  - la **clé de chiffrement** de la base SQLite (32 octets aléatoires) ;
///  - le **marqueur** indiquant que le fichier de base a déjà été converti en
///    base chiffrée (évite toute migration répétée).
class Coffre {
  const Coffre._();

  static const String _cleBase = 'appharmacie.cle-base.v1';
  static const String _cleMarqueur = 'appharmacie.base-chiffree.v1';

  static const FlutterSecureStorage _stockage = FlutterSecureStorage();

  /// Retourne la clé de chiffrement, en la créant au premier lancement.
  ///
  /// La clé n'est jamais écrite dans un fichier applicatif : le système
  /// d'exploitation la protège (matériel lorsque le téléphone en dispose).
  static Future<String> cleDeLaBase() async {
    final existante = await _stockage.read(key: _cleBase);
    if (existante != null && existante.length >= 40) return existante;

    final cle = _genererCle();
    await _stockage.write(key: _cleBase, value: cle);
    return cle;
  }

  /// Vrai si le fichier de base est déjà chiffré.
  static Future<bool> baseDejaChiffree() async {
    return await _stockage.read(key: _cleMarqueur) == 'oui';
  }

  /// Marque la base comme chiffrée (appelé une fois la conversion faite).
  static Future<void> marquerBaseChiffree() async {
    await _stockage.write(key: _cleMarqueur, value: 'oui');
  }

  /// 32 octets tirés du générateur cryptographique du système.
  static String _genererCle() {
    final aleatoire = Random.secure();
    final octets = List<int>.generate(32, (_) => aleatoire.nextInt(256));
    return base64UrlEncode(octets);
  }
}
