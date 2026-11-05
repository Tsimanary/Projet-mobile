import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';

import '../SQLite/sqlite.dart';
import 'backup_format.dart';
import 'chiffrement.dart';
import 'exceptions.dart';
import 'format.dart';

/// Fichier de sauvegarde choisi par l'utilisateur, gardé en mémoire.
class FichierSauvegarde {
  const FichierSauvegarde({required this.nom, required this.contenu});

  final String nom;
  final String contenu;

  /// Vrai si le fichier est une enveloppe chiffrée (phrase secrète requise).
  bool get estChiffre => ChiffrementSauvegarde.estChiffree(contenu);
}

/// Sauvegarde et restauration complètes de la base, via un fichier JSON.
///
/// Le fichier est écrit dans le répertoire temporaire de l'application puis
/// partagé (courriel, Drive, WhatsApp…) : l'utilisateur choisit la destination,
/// ce qui évite toute permission de stockage.
///
/// **Chiffrement** : une phrase secrète (recommandée, proposée par défaut)
/// transforme le JSON en enveloppe AES-256-GCM dont la clé est dérivée en
/// Argon2id. Sans phrase, le fichier reste lisible par quiconque l'obtient.
class Sauvegarde {
  const Sauvegarde._();

  static final DatabaseHelper _base = DatabaseHelper();

  /// Écrit la sauvegarde sur disque et retourne le fichier créé.
  ///
  /// [phraseSecrete] non vide ⇒ fichier chiffré (extension `.appharmacie`).
  static Future<File> ecrireFichier({
    DateTime? maintenant,
    String? dossier,
    String? phraseSecrete,
  }) async {
    final tables = await _base.exporterTout();
    final clair = construireSauvegarde(tables, maintenant: maintenant);

    final protege = phraseSecrete != null && phraseSecrete.isNotEmpty;
    final contenu = protege
        ? await ChiffrementSauvegarde.chiffrer(clair, phraseSecrete)
        : clair;

    final horodatage = formaterHorodatage(maintenant ?? DateTime.now())
        .replaceAll(RegExp(r'[:.]'), '-');
    final repertoire = dossier ?? Directory.systemTemp.path;
    final extension = protege ? 'appharmacie' : 'json';
    final fichier = File(
      '$repertoire${Platform.pathSeparator}'
      'sauvegarde-appharmacie-$horodatage.$extension',
    );

    await fichier.writeAsString(contenu, flush: true);
    return fichier;
  }

  /// Ouvre le partage système pour le fichier de sauvegarde.
  static Future<void> partager(File fichier, {bool chiffree = false}) async {
    await Share.shareXFiles(
      <XFile>[XFile(fichier.path)],
      subject: 'Sauvegarde AppHarmacie',
      text: chiffree
          ? 'Sauvegarde chiffrée AppHarmacie. La phrase secrète est '
              'indispensable pour la restaurer : conservez-la séparément.'
          : 'Sauvegarde AppHarmacie (non chiffrée). Conservez ce fichier en '
              'lieu sûr : il contient toutes vos données en clair.',
    );
  }

  /// Laisse l'utilisateur choisir un fichier de sauvegarde.
  ///
  /// Retourne `null` si l'utilisateur annule.
  static Future<FichierSauvegarde?> choisir() async {
    final resultat = await FilePicker.platform.pickFiles(
      withData: true,
      allowMultiple: false,
      type: FileType.any,
    );
    if (resultat == null || resultat.files.isEmpty) return null;

    final choisi = resultat.files.single;
    final octets = choisi.bytes;
    final String contenu;
    if (octets != null) {
      contenu = utf8.decode(octets, allowMalformed: true);
    } else if (choisi.path != null) {
      contenu = await File(choisi.path!).readAsString();
    } else {
      throw const OperationRefuseeException(
        'Fichier inaccessible : choisissez un fichier local.',
      );
    }

    return FichierSauvegarde(nom: choisi.name, contenu: contenu);
  }

  /// Valide le fichier (déchiffrement si nécessaire) et extrait les tables.
  ///
  /// Lève [OperationRefuseeException] si la phrase est absente ou incorrecte,
  /// ou si le fichier n'est pas une sauvegarde exploitable.
  static Future<Map<String, Object?>> analyser(
    FichierSauvegarde fichier, {
    String? phrase,
  }) async {
    if (!fichier.estChiffre) {
      return analyserSauvegarde(fichier.contenu);
    }

    final code = (phrase ?? '').trim();
    if (code.isEmpty) {
      throw const OperationRefuseeException(
        'Cette sauvegarde est chiffrée : saisissez sa phrase secrète.',
      );
    }

    final clair = await ChiffrementSauvegarde.dechiffrer(fichier.contenu, code);
    return analyserSauvegarde(clair);
  }

  /// Remplace **toutes** les données par celles de la sauvegarde.
  static Future<void> restaurer(Map<String, Object?> tables) {
    return _base.restaurerTout(tables);
  }

  /// Nombre de lignes par table (affichage avant export).
  static Future<Map<String, int>> compterDonnees() => _base.compterLignes();
}
