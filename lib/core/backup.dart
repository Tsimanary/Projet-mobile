import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';

import '../SQLite/sqlite.dart';
import 'backup_format.dart';
import 'exceptions.dart';
import 'format.dart';

/// Sauvegarde et restauration complètes de la base, via un fichier JSON.
///
/// Le fichier est écrit dans le répertoire temporaire de l'application puis
/// partagé (courriel, Drive, WhatsApp…) : l'utilisateur choisit la destination,
/// ce qui évite toute permission de stockage.
class Sauvegarde {
  const Sauvegarde._();

  static final DatabaseHelper _base = DatabaseHelper();

  /// Écrit la sauvegarde sur disque et retourne le fichier créé.
  static Future<File> ecrireFichier({
    DateTime? maintenant,
    String? dossier,
  }) async {
    final tables = await _base.exporterTout();
    final contenu = construireSauvegarde(tables, maintenant: maintenant);

    final horodatage = formaterHorodatage(maintenant ?? DateTime.now())
        .replaceAll(RegExp(r'[:.]'), '-');
    final repertoire = dossier ?? Directory.systemTemp.path;
    final fichier = File(
      '$repertoire${Platform.pathSeparator}'
      'sauvegarde-appharmacie-$horodatage.json',
    );

    await fichier.writeAsString(contenu, flush: true);
    return fichier;
  }

  /// Ouvre le partage système pour le fichier de sauvegarde.
  static Future<void> partager(File fichier) async {
    await Share.shareXFiles(
      <XFile>[XFile(fichier.path, mimeType: 'application/json')],
      subject: 'Sauvegarde AppHarmacie',
      text: 'Sauvegarde des données AppHarmacie. '
          'Conservez ce fichier en lieu sûr : il permet de tout restaurer.',
    );
  }

  /// Laisse l'utilisateur choisir une sauvegarde et la valide.
  ///
  /// Retourne `null` si l'utilisateur annule. Lève
  /// [OperationRefuseeException] si le fichier n'est pas exploitable.
  static Future<Map<String, Object?>?> choisirEtAnalyser() async {
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

    return analyserSauvegarde(contenu);
  }

  /// Remplace **toutes** les données par celles de la sauvegarde.
  static Future<void> restaurer(Map<String, Object?> tables) {
    return _base.restaurerTout(tables);
  }

  /// Nombre de lignes par table (affichage avant export).
  static Future<Map<String, int>> compterDonnees() => _base.compterLignes();
}
