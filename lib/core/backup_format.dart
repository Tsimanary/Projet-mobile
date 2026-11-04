import 'dart:convert';

import 'exceptions.dart';

/// Version du format de sauvegarde comprise par cette application.
///
/// Le numéro n'augmente que si la structure change de façon incompatible : un
/// fichier plus ancien reste lisible, un fichier plus récent est refusé.
const int versionFormatSauvegarde = 1;

const String _application = 'appharmacie';

/// Tables exportées, dans l'ordre de restauration.
const List<String> tablesSauvegardees = <String>[
  'users',
  'medics',
  'lots',
  'mouvements_stock',
  'entrees',
  'achats',
];

/// Sérialise une sauvegarde complète (JSON lisible, versionné).
String construireSauvegarde(
  Map<String, Object?> tables, {
  DateTime? maintenant,
}) {
  final document = <String, Object?>{
    'application': _application,
    'format': versionFormatSauvegarde,
    'genereLe': (maintenant ?? DateTime.now()).toIso8601String(),
    'tables': <String, Object?>{
      for (final table in tablesSauvegardees)
        table: tables[table] ?? const <Object?>[],
    },
  };

  return const JsonEncoder.withIndent('  ').convert(document);
}

/// Valide et extrait les tables d'une sauvegarde.
///
/// Lève [OperationRefuseeException] avec un message utilisateur si le fichier
/// n'est pas une sauvegarde exploitable. Aucune écriture n'est faite ici : la
/// restauration est appliquée dans une transaction unique par la couche de
/// données.
Map<String, Object?> analyserSauvegarde(String contenu) {
  Object? decode;
  try {
    decode = jsonDecode(contenu);
  } on FormatException {
    throw const OperationRefuseeException(
      "Fichier illisible : ce n'est pas une sauvegarde AppHarmacie "
      '(JSON invalide).',
    );
  }

  if (decode is! Map) {
    throw const OperationRefuseeException(
      "Ce fichier ne contient pas une sauvegarde AppHarmacie.",
    );
  }

  final document = Map<String, Object?>.from(decode);
  if ((document['application'] ?? '').toString() != _application) {
    throw const OperationRefuseeException(
      "Ce fichier ne provient pas de l'application AppHarmacie.",
    );
  }

  final format = document['format'];
  if (format is! num) {
    throw const OperationRefuseeException(
      'Sauvegarde invalide : version de format absente.',
    );
  }
  final version = format.toInt();
  if (version < 1) {
    throw const OperationRefuseeException(
      'Sauvegarde invalide : version de format inconnue.',
    );
  }
  if (version > versionFormatSauvegarde) {
    throw const OperationRefuseeException(
      'Cette sauvegarde a été créée par une version plus récente de '
      "l'application. Mettez l'application à jour avant de la restaurer.",
    );
  }

  final tables = document['tables'];
  if (tables is! Map) {
    throw const OperationRefuseeException(
      'Sauvegarde incomplète : aucune donnée exploitable.',
    );
  }

  final resultat = <String, Object?>{};
  for (final table in tablesSauvegardees) {
    final lignes = tables[table];
    if (lignes is! List) {
      throw OperationRefuseeException(
        'Sauvegarde incomplète : la table « $table » est absente.',
      );
    }
    resultat[table] = lignes;
  }

  return resultat;
}

/// Nombre total de lignes d'une sauvegarde (message de confirmation).
int compterLignesSauvegarde(Map<String, Object?> tables) {
  var total = 0;
  for (final table in tablesSauvegardees) {
    final lignes = tables[table];
    if (lignes is List) total += lignes.length;
  }
  return total;
}
