import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../Models/acht.dart';
import '../Models/entr.dart';
import '../Models/lot.dart';
import '../Models/medic.dart';
import '../Models/users.dart';
import '../core/backup_format.dart';
import '../core/exceptions.dart';
import '../core/format.dart';
import '../core/securite.dart';
import '../core/stock_rules.dart';

/// Accès unique à la base SQLite locale.
///
/// Invariants garantis par cette classe :
///  * `medics.stockMed` est une **projection** de `lots.quantiteRestante` :
///    il est recalculé après chaque mouvement, jamais saisi à la main ;
///  * toute écriture de stock se fait dans une transaction ;
///  * une entrée crée (ou complète) un lot, et une vente le consomme en
///    **FEFO** (péremption la plus proche d'abord) ;
///  * chaque mouvement est historisé dans `mouvements_stock` : une vente ou
///    une entrée peuvent donc être annulées sans dérive ;
///  * les dates sont stockées en `AAAA-MM-JJ` ;
///  * les mots de passe sont hachés (avec migration des comptes existants) ;
///  * un médicament possédant un historique ne peut pas être supprimé.
class DatabaseHelper {
  DatabaseHelper._();

  static final DatabaseHelper _instance = DatabaseHelper._();

  /// `DatabaseHelper()` renvoie toujours la même instance.
  factory DatabaseHelper() => _instance;

  static const String _nomBase = 'pharmacie.db';
  static const int _versionBase = 3;

  static const String _sqlLots = 'CREATE TABLE IF NOT EXISTS lots ('
      'id INTEGER PRIMARY KEY AUTOINCREMENT, '
      'numMed TEXT NOT NULL, '
      'numeroLot TEXT, '
      'quantiteRecue INTEGER NOT NULL, '
      'quantiteRestante INTEGER NOT NULL, '
      'datePeremption TEXT, '
      'dateReception TEXT NOT NULL)';

  static const String _sqlMouvements = 'CREATE TABLE IF NOT EXISTS mouvements_stock ('
      'id INTEGER PRIMARY KEY AUTOINCREMENT, '
      'numMed TEXT NOT NULL, '
      'lotId INTEGER, '
      'type TEXT NOT NULL, '
      'quantite INTEGER NOT NULL, '
      'reference TEXT, '
      'dateMouvement TEXT NOT NULL)';

  Database? _base;
  Future<Database>? _ouvertureEnCours;

  Future<Database> get database async {
    final existante = _base;
    if (existante != null) return existante;

    _ouvertureEnCours ??= _ouvrir();
    final ouverte = await _ouvertureEnCours!;
    _base = ouverte;
    return ouverte;
  }

  Future<Database> _ouvrir() async {
    final chemin = join(await getDatabasesPath(), _nomBase);

    return openDatabase(
      chemin,
      version: _versionBase,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        await db.execute(
          'CREATE TABLE users ('
          'usrId INTEGER PRIMARY KEY AUTOINCREMENT, '
          'usrName TEXT NOT NULL UNIQUE, '
          'usrPassword TEXT NOT NULL, '
          'usrSalt TEXT)',
        );
        await db.execute(
          'CREATE TABLE medics ('
          'id INTEGER PRIMARY KEY AUTOINCREMENT, '
          'numMed TEXT NOT NULL, '
          'designMed TEXT NOT NULL, '
          'prixMed INTEGER NOT NULL DEFAULT 0, '
          'stockMed INTEGER NOT NULL DEFAULT 0)',
        );
        await db.execute(
          'CREATE TABLE entrees ('
          'id INTEGER PRIMARY KEY AUTOINCREMENT, '
          'numEntr TEXT, '
          'numMed TEXT NOT NULL, '
          'stockEntr INTEGER NOT NULL, '
          'dateEntr TEXT, '
          'numeroLot TEXT, '
          'datePeremption TEXT)',
        );
        await db.execute(
          'CREATE TABLE achats ('
          'id INTEGER PRIMARY KEY AUTOINCREMENT, '
          'numAchat TEXT, '
          'numMed TEXT NOT NULL, '
          'nomClient TEXT, '
          'dateAchat TEXT, '
          'nbr INTEGER NOT NULL, '
          'prixUnitaire INTEGER)',
        );
        await db.execute(_sqlLots);
        await db.execute(_sqlMouvements);
        await _creerIndex(db);
      },
      onUpgrade: (db, ancienneVersion, nouvelleVersion) async {
        if (ancienneVersion < 2) {
          // v1 -> v2 : hachage des mots de passe + prix figé sur les ventes.
          await _ajouterColonneSiAbsente(db, 'users', 'usrSalt', 'TEXT');
          await _ajouterColonneSiAbsente(db, 'achats', 'prixUnitaire', 'INTEGER');
        }
        if (ancienneVersion < 3) {
          // v2 -> v3 : lots, mouvements de stock et dates ISO.
          await _migrerVers3(db);
        }
        await _creerIndex(db);
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Schéma, index et migrations
  // ---------------------------------------------------------------------------

  Future<void> _creerIndex(Database db) async {
    const instructions = <String>[
      'CREATE INDEX IF NOT EXISTS idx_medics_numMed ON medics(numMed)',
      'CREATE INDEX IF NOT EXISTS idx_entrees_numMed ON entrees(numMed)',
      'CREATE INDEX IF NOT EXISTS idx_achats_numMed ON achats(numMed)',
      'CREATE INDEX IF NOT EXISTS idx_achats_numAchat ON achats(numAchat)',
      'CREATE INDEX IF NOT EXISTS idx_lots_numMed ON lots(numMed, datePeremption)',
      'CREATE INDEX IF NOT EXISTS idx_mvt_reference ON mouvements_stock(reference)',
      'CREATE INDEX IF NOT EXISTS idx_mvt_numMed ON mouvements_stock(numMed)',
    ];
    for (final instruction in instructions) {
      await db.execute(instruction);
    }
  }

  Future<void> _migrerVers3(Database db) async {
    await _ajouterColonneSiAbsente(db, 'entrees', 'numeroLot', 'TEXT');
    await _ajouterColonneSiAbsente(db, 'entrees', 'datePeremption', 'TEXT');
    await db.execute(_sqlLots);
    await db.execute(_sqlMouvements);
    await _convertirDatesEnIso(db);
    await _reprendreStockExistant(db);
  }

  /// Convertit les dates `JJ/MM/AAAA` (ou `JJ/MM/AA`) héritées en `AAAA-MM-JJ`.
  Future<void> _convertirDatesEnIso(Database db) async {
    final entrees = await db.query('entrees', columns: <String>['id', 'dateEntr']);
    for (final ligne in entrees) {
      final ancienne = (ligne['dateEntr'] ?? '').toString();
      final iso = versIso(ancienne);
      if (iso != null && iso != ancienne) {
        await db.update(
          'entrees',
          <String, Object?>{'dateEntr': iso},
          where: 'id = ?',
          whereArgs: <Object?>[ligne['id']],
        );
      }
    }

    final achats = await db.query('achats', columns: <String>['id', 'dateAchat']);
    for (final ligne in achats) {
      final ancienne = (ligne['dateAchat'] ?? '').toString();
      final iso = versIso(ancienne);
      if (iso != null && iso != ancienne) {
        await db.update(
          'achats',
          <String, Object?>{'dateAchat': iso},
          where: 'id = ?',
          whereArgs: <Object?>[ligne['id']],
        );
      }
    }
  }

  /// Le stock existant (antérieur aux lots) est repris dans un lot technique
  /// « STOCK-REPRIS » sans date de péremption : aucune donnée n'est inventée,
  /// et l'invariant `stockMed == Σ quantiteRestante` est vrai dès la migration.
  Future<void> _reprendreStockExistant(Database db) async {
    final resultat = await db.rawQuery('SELECT COUNT(*) AS total FROM lots');
    final dejaMigre = ((resultat.first['total'] as num?)?.toInt() ?? 0) > 0;
    if (dejaMigre) return;

    final medicaments = await db.query(
      'medics',
      columns: <String>['numMed', 'stockMed'],
    );
    final aujourdHui = formaterDateIso(DateTime.now());

    for (final medicament in medicaments) {
      final stock = (medicament['stockMed'] as num?)?.toInt() ?? 0;
      final numMed = (medicament['numMed'] ?? '').toString();
      if (numMed.isEmpty) continue;

      if (stock < 0) {
        await db.update(
          'medics',
          <String, Object?>{'stockMed': 0},
          where: 'numMed = ?',
          whereArgs: <Object?>[numMed],
        );
        continue;
      }
      if (stock == 0) continue;

      await db.insert('lots', <String, Object?>{
        'numMed': numMed,
        'numeroLot': 'STOCK-REPRIS',
        'quantiteRecue': stock,
        'quantiteRestante': stock,
        'datePeremption': null,
        'dateReception': aujourdHui,
      });
    }
  }

  Future<void> _ajouterColonneSiAbsente(
    Database db,
    String table,
    String colonne,
    String type,
  ) async {
    final colonnes = await db.rawQuery('PRAGMA table_info($table)');
    final existe = colonnes.any((c) => c['name'] == colonne);
    if (!existe) {
      await db.execute('ALTER TABLE $table ADD COLUMN $colonne $type');
    }
  }

  // ---------------------------------------------------------------------------
  // Utilitaires internes (transactionnels)
  // ---------------------------------------------------------------------------

  Future<Medic?> _medicParNumero(
    DatabaseExecutor executeur,
    String numMed,
  ) async {
    final lignes = await executeur.query(
      'medics',
      where: 'numMed = ?',
      whereArgs: <Object?>[numMed],
      limit: 1,
    );
    if (lignes.isEmpty) return null;
    return Medic.fromMap(lignes.first);
  }

  Future<Medic> _medicParNumeroObligatoire(
    DatabaseExecutor executeur,
    String numMed,
  ) async {
    final medic = await _medicParNumero(executeur, numMed);
    if (medic == null) {
      throw EntiteIntrouvableException('Médicament « $numMed » introuvable.');
    }
    return medic;
  }

  Future<int> _stockActuel(DatabaseExecutor executeur, String numMed) async {
    final lignes = await executeur.query(
      'medics',
      columns: <String>['stockMed'],
      where: 'numMed = ?',
      whereArgs: <Object?>[numMed],
      limit: 1,
    );
    if (lignes.isEmpty) {
      throw EntiteIntrouvableException('Médicament « $numMed » introuvable.');
    }
    return (lignes.first['stockMed'] as num?)?.toInt() ?? 0;
  }

  /// Recalcule `stockMed` à partir des lots : une seule source de vérité.
  Future<void> _recalculerStock(DatabaseExecutor executeur, String numMed) async {
    final resultat = await executeur.rawQuery(
      'SELECT COALESCE(SUM(quantiteRestante), 0) AS total FROM lots WHERE numMed = ?',
      <Object?>[numMed],
    );
    final total = (resultat.first['total'] as num?)?.toInt() ?? 0;
    await executeur.update(
      'medics',
      <String, Object?>{'stockMed': total < 0 ? 0 : total},
      where: 'numMed = ?',
      whereArgs: <Object?>[numMed],
    );
  }

  Future<int> _compter(
    DatabaseExecutor executeur,
    String table,
    String numMed,
  ) async {
    final resultat = await executeur.rawQuery(
      'SELECT COUNT(*) AS total FROM $table WHERE numMed = ?',
      <Object?>[numMed],
    );
    return (resultat.first['total'] as num?)?.toInt() ?? 0;
  }

  Future<List<Map<String, Object?>>> _mouvements(
    DatabaseExecutor executeur,
    String reference,
  ) {
    return executeur.query(
      'mouvements_stock',
      where: 'reference = ?',
      whereArgs: <Object?>[reference],
    );
  }

  /// Annule les mouvements d'une vente : le stock retourne dans ses lots.
  Future<Set<String>> _restaurerReference(
    DatabaseExecutor executeur,
    String reference,
  ) async {
    final mouvements = await _mouvements(executeur, reference);
    final medicaments = <String>{};

    for (final mouvement in mouvements) {
      final numMed = (mouvement['numMed'] ?? '').toString();
      if (numMed.isNotEmpty) medicaments.add(numMed);

      final lotId = (mouvement['lotId'] as num?)?.toInt();
      final quantite = (mouvement['quantite'] as num?)?.toInt() ?? 0;
      if (lotId != null && quantite != 0) {
        // quantite est négative pour une sortie : la soustraire recrédite le lot.
        await executeur.rawUpdate(
          'UPDATE lots SET quantiteRestante = quantiteRestante - ? WHERE id = ?',
          <Object?>[quantite, lotId],
        );
      }
    }

    await executeur.delete(
      'mouvements_stock',
      where: 'reference = ?',
      whereArgs: <Object?>[reference],
    );

    return medicaments;
  }

  /// Annule une entrée : refuse si le lot a déjà été partiellement vendu.
  Future<Set<String>> _retirerEntree(
    DatabaseExecutor executeur,
    int entreeId,
  ) async {
    final reference = 'ENTREE:$entreeId';
    final mouvements = await _mouvements(executeur, reference);
    final medicaments = <String>{};

    for (final mouvement in mouvements) {
      final numMed = (mouvement['numMed'] ?? '').toString();
      if (numMed.isNotEmpty) medicaments.add(numMed);

      final lotId = (mouvement['lotId'] as num?)?.toInt();
      final quantite = (mouvement['quantite'] as num?)?.toInt() ?? 0;
      if (lotId == null || quantite == 0) continue;

      final lignes = await executeur.query(
        'lots',
        columns: <String>['quantiteRestante'],
        where: 'id = ?',
        whereArgs: <Object?>[lotId],
        limit: 1,
      );
      final restante =
          lignes.isEmpty ? 0 : (lignes.first['quantiteRestante'] as num?)?.toInt() ?? 0;
      if (restante < quantite) {
        throw const OperationRefuseeException(
          'Impossible : une partie de ce lot a déjà été vendue. '
          'Enregistrez une sortie ou une entrée de correction.',
        );
      }

      await executeur.rawUpdate(
        'UPDATE lots SET quantiteRestante = quantiteRestante - ? WHERE id = ?',
        <Object?>[quantite, lotId],
      );
    }

    await executeur.delete(
      'mouvements_stock',
      where: 'reference = ?',
      whereArgs: <Object?>[reference],
    );

    return medicaments;
  }

  /// Consomme [quantite] unités en FEFO et historise un mouvement par lot.
  Future<void> _consommerFefo(
    DatabaseExecutor executeur, {
    required String numMed,
    required int quantite,
    required String reference,
    required String designation,
  }) async {
    final lignes = await executeur.query(
      'lots',
      columns: <String>['id', 'quantiteRestante', 'datePeremption'],
      where: 'numMed = ? AND quantiteRestante > 0',
      whereArgs: <Object?>[numMed],
    );

    final disponibles = lignes
        .map(
          (ligne) => LotDisponible(
            id: (ligne['id'] as num).toInt(),
            quantiteRestante: (ligne['quantiteRestante'] as num?)?.toInt() ?? 0,
            datePeremption: ligne['datePeremption'] as String?,
          ),
        )
        .toList();

    final allocations = allouerLots(lots: disponibles, quantite: quantite);
    StockRules.verifierDisponibilite(
      disponible: quantiteAllouee(allocations),
      demande: quantite,
      designation: designation,
    );

    final horodatage = formaterHorodatage(DateTime.now());
    for (final allocation in allocations) {
      await executeur.rawUpdate(
        'UPDATE lots SET quantiteRestante = quantiteRestante - ? WHERE id = ?',
        <Object?>[allocation.quantite, allocation.lotId],
      );
      await executeur.insert('mouvements_stock', <String, Object?>{
        'numMed': numMed,
        'lotId': allocation.lotId,
        'type': 'SORTIE',
        'quantite': -allocation.quantite,
        'reference': reference,
        'dateMouvement': horodatage,
      });
    }
  }

  /// Enregistre le mouvement d'entrée : crée ou complète le lot correspondant.
  Future<void> _mouvementEntree(
    DatabaseExecutor executeur, {
    required int entreeId,
    required Entree entree,
  }) async {
    final numeroLot = (entree.numeroLot ?? '').trim();
    final peremption = entree.datePeremption;

    var lotId = 0;

    // Un même couple (numéro de lot, péremption) désigne le même lot physique :
    // une nouvelle réception l'incrémente au lieu de dupliquer la ligne.
    final lotExistant = await executeur.query(
      'lots',
      where: "numMed = ? AND IFNULL(numeroLot, '') = ? "
          "AND IFNULL(datePeremption, '') = ?",
      whereArgs: <Object?>[entree.numMed, numeroLot, peremption ?? ''],
      limit: 1,
    );

    if (lotExistant.isNotEmpty) {
      lotId = (lotExistant.first['id'] as num).toInt();
      await executeur.rawUpdate(
        'UPDATE lots SET quantiteRecue = quantiteRecue + ?, '
        'quantiteRestante = quantiteRestante + ? WHERE id = ?',
        <Object?>[entree.stockEntr, entree.stockEntr, lotId],
      );
    } else {
      lotId = await executeur.insert('lots', <String, Object?>{
        'numMed': entree.numMed,
        'numeroLot': numeroLot.isEmpty ? null : numeroLot,
        'quantiteRecue': entree.stockEntr,
        'quantiteRestante': entree.stockEntr,
        'datePeremption': peremption,
        'dateReception': entree.dateEntr,
      });
    }

    await executeur.insert('mouvements_stock', <String, Object?>{
      'numMed': entree.numMed,
      'lotId': lotId,
      'type': 'ENTREE',
      'quantite': entree.stockEntr,
      'reference': 'ENTREE:$entreeId',
      'dateMouvement': formaterHorodatage(DateTime.now()),
    });
  }

  void _verifierEntree(Entree entree) {
    if (entree.numEntr.trim().isEmpty) {
      throw ArgumentError("Le numéro d'entrée est obligatoire.");
    }
    if (entree.numMed.trim().isEmpty) {
      throw ArgumentError('Le médicament est obligatoire.');
    }
    if (entree.stockEntr <= 0) {
      throw ArgumentError.value(
        entree.stockEntr,
        'stockEntr',
        'La quantité entrée doit être supérieure à zéro.',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Utilisateurs
  // ---------------------------------------------------------------------------

  Future<bool> login(Users user) async {
    final db = await database;
    final nom = user.usrName.trim();
    if (nom.isEmpty || user.usrPassword.isEmpty) return false;

    final lignes = await db.query(
      'users',
      where: 'usrName = ?',
      whereArgs: <Object?>[nom],
      limit: 1,
    );
    if (lignes.isEmpty) return false;

    final ligne = lignes.first;
    final sel = ligne['usrSalt'] as String?;
    final motDePasseStocke = (ligne['usrPassword'] ?? '').toString();

    // Compte créé avant le hachage : comparaison en clair puis migration.
    if (sel == null || sel.isEmpty) {
      if (motDePasseStocke != user.usrPassword) return false;
      final nouveauSel = Securite.genererSel();
      await db.update(
        'users',
        <String, Object?>{
          'usrPassword': Securite.hasher(user.usrPassword, nouveauSel),
          'usrSalt': nouveauSel,
        },
        where: 'usrName = ?',
        whereArgs: <Object?>[nom],
      );
      return true;
    }

    return Securite.verifier(
      motDePasse: user.usrPassword,
      sel: sel,
      hashAttendu: motDePasseStocke,
    );
  }

  Future<int> signup(Users user) async {
    final nom = user.usrName.trim();
    if (nom.isEmpty) {
      throw ArgumentError("Le nom d'utilisateur ne peut pas être vide.");
    }
    final db = await database;

    final existant = await db.query(
      'users',
      columns: <String>['usrId'],
      where: 'usrName = ?',
      whereArgs: <Object?>[nom],
      limit: 1,
    );
    if (existant.isNotEmpty) {
      throw UtilisateurDejaExisteException(nom);
    }

    final sel = Securite.genererSel();
    try {
      return await db.insert('users', <String, Object?>{
        'usrName': nom,
        'usrPassword': Securite.hasher(user.usrPassword, sel),
        'usrSalt': sel,
      });
    } on DatabaseException {
      throw UtilisateurDejaExisteException(nom);
    }
  }

  // ---------------------------------------------------------------------------
  // Médicaments
  // ---------------------------------------------------------------------------

  Future<List<Medic>> getAllMedics() async {
    final db = await database;
    final lignes = await db.query(
      'medics',
      orderBy: 'designMed COLLATE NOCASE ASC',
    );
    return lignes.map((ligne) => Medic.fromMap(ligne)).toList();
  }

  Future<Medic> getMedicById(int id) async {
    final db = await database;
    final lignes = await db.query(
      'medics',
      where: 'id = ?',
      whereArgs: <Object?>[id],
      limit: 1,
    );
    if (lignes.isEmpty) {
      throw const EntiteIntrouvableException('Médicament introuvable.');
    }
    return Medic.fromMap(lignes.first);
  }

  Future<bool> _numeroMedicamentExiste(String numMed, {int? saufId}) async {
    final db = await database;
    final lignes = await db.query(
      'medics',
      columns: <String>['id'],
      where: saufId == null ? 'numMed = ?' : 'numMed = ? AND id <> ?',
      whereArgs:
          saufId == null ? <Object?>[numMed] : <Object?>[numMed, saufId],
      limit: 1,
    );
    return lignes.isNotEmpty;
  }

  Future<int> insertMedic(Medic medic) async {
    final db = await database;
    final numero = medic.numMed.trim();
    final designation = medic.designMed.trim();

    if (numero.isEmpty) {
      throw ArgumentError('Le numéro du médicament est obligatoire.');
    }
    if (designation.isEmpty) {
      throw ArgumentError('La désignation du médicament est obligatoire.');
    }
    if (medic.prixMed < 0) {
      throw ArgumentError('Le prix ne peut pas être négatif.');
    }
    if (await _numeroMedicamentExiste(numero)) {
      throw MedicamentDejaExisteException(numero);
    }

    return db.insert('medics', <String, Object?>{
      'numMed': numero,
      'designMed': designation,
      'prixMed': medic.prixMed,
      'stockMed': 0,
    });
  }

  /// Met à jour le médicament **sans toucher au stock** : le stock est
  /// exclusivement piloté par les lots, les entrées et les ventes.
  Future<int> updateMedic(Medic medic) async {
    final db = await database;
    final id = medic.id;
    if (id == null) {
      throw ArgumentError('Identifiant du médicament manquant.');
    }

    final numero = medic.numMed.trim();
    final designation = medic.designMed.trim();
    if (numero.isEmpty) {
      throw ArgumentError('Le numéro du médicament est obligatoire.');
    }
    if (designation.isEmpty) {
      throw ArgumentError('La désignation du médicament est obligatoire.');
    }
    if (medic.prixMed < 0) {
      throw ArgumentError('Le prix ne peut pas être négatif.');
    }

    final actuel = await getMedicById(id);

    if (actuel.numMed != numero) {
      final nombreVentes = await _compter(db, 'achats', actuel.numMed);
      final nombreEntrees = await _compter(db, 'entrees', actuel.numMed);
      final historique = nombreVentes + nombreEntrees;
      if (historique > 0) {
        throw const OperationRefuseeException(
          'Le numéro ne peut pas être modifié : ce médicament possède déjà '
          'un historique de ventes ou d\'entrées.',
        );
      }
      if (await _numeroMedicamentExiste(numero, saufId: id)) {
        throw MedicamentDejaExisteException(numero);
      }
    }

    return db.update(
      'medics',
      <String, Object?>{
        'numMed': numero,
        'designMed': designation,
        'prixMed': medic.prixMed,
      },
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
  }

  Future<int> deleteMedic(int id) async {
    final db = await database;
    final medic = await getMedicById(id);

    final ventes = await _compter(db, 'achats', medic.numMed);
    final entrees = await _compter(db, 'entrees', medic.numMed);
    if (ventes > 0 || entrees > 0) {
      throw MedicamentUtiliseException(
        designation: medic.designMed,
        ventes: ventes,
        entrees: entrees,
      );
    }

    return db.transaction((txn) async {
      final stock = await _stockActuel(txn, medic.numMed);
      if (stock > 0) {
        throw OperationRefuseeException(
          'Suppression impossible : « ${medic.designMed} » possède encore '
          '$stock unité(s) en stock.',
        );
      }
      await txn.delete(
        'lots',
        where: 'numMed = ?',
        whereArgs: <Object?>[medic.numMed],
      );
      return txn.delete(
        'medics',
        where: 'id = ?',
        whereArgs: <Object?>[id],
      );
    });
  }

  Future<List<String>> getAllMedNum() async {
    final db = await database;
    final lignes = await db.query(
      'medics',
      columns: <String>['numMed'],
      orderBy: 'numMed COLLATE NOCASE ASC',
    );
    return lignes
        .map((ligne) => (ligne['numMed'] ?? '').toString())
        .where((numero) => numero.isNotEmpty)
        .toList();
  }

  // ---------------------------------------------------------------------------
  // Entrées de stock
  // ---------------------------------------------------------------------------

  Future<List<Entree>> getAllEntrees() async {
    final db = await database;
    final lignes = await db.query('entrees', orderBy: 'dateEntr DESC, id DESC');
    return lignes.map((ligne) => Entree.fromMap(ligne)).toList();
  }

  Future<int> insertEntree(Entree entree) async {
    _verifierEntree(entree);
    final db = await database;

    return db.transaction((txn) async {
      await _medicParNumeroObligatoire(txn, entree.numMed);

      final id = await txn.insert('entrees', <String, Object?>{
        'numEntr': entree.numEntr.trim(),
        'numMed': entree.numMed,
        'stockEntr': entree.stockEntr,
        'dateEntr': entree.dateEntr,
        'numeroLot': _numeroLot(entree.numeroLot),
        'datePeremption': entree.datePeremption,
      });

      await _mouvementEntree(txn, entreeId: id, entree: entree);
      await _recalculerStock(txn, entree.numMed);

      return id;
    });
  }

  Future<int> updateEntree(Entree entree) async {
    final id = entree.id;
    if (id == null) {
      throw ArgumentError("Identifiant de l'entrée manquant.");
    }
    _verifierEntree(entree);
    final db = await database;

    return db.transaction((txn) async {
      final lignes = await txn.query(
        'entrees',
        columns: <String>['id'],
        where: 'id = ?',
        whereArgs: <Object?>[id],
        limit: 1,
      );
      if (lignes.isEmpty) {
        throw const EntiteIntrouvableException('Entrée introuvable.');
      }
      await _medicParNumeroObligatoire(txn, entree.numMed);

      // Retire l'ancienne entrée (refusé si le lot a déjà été vendu),
      // puis applique la nouvelle : aucune dérive possible.
      final touches = await _retirerEntree(txn, id);

      final nombreModifie = await txn.update(
        'entrees',
        <String, Object?>{
          'numEntr': entree.numEntr.trim(),
          'numMed': entree.numMed,
          'stockEntr': entree.stockEntr,
          'dateEntr': entree.dateEntr,
          'numeroLot': _numeroLot(entree.numeroLot),
          'datePeremption': entree.datePeremption,
        },
        where: 'id = ?',
        whereArgs: <Object?>[id],
      );

      await _mouvementEntree(txn, entreeId: id, entree: entree);

      for (final numMed in <String>{...touches, entree.numMed}) {
        await _recalculerStock(txn, numMed);
      }

      return nombreModifie;
    });
  }

  Future<int> deleteEntree(int id) async {
    final db = await database;

    return db.transaction((txn) async {
      final lignes = await txn.query(
        'entrees',
        columns: <String>['id'],
        where: 'id = ?',
        whereArgs: <Object?>[id],
        limit: 1,
      );
      if (lignes.isEmpty) return 0;

      final touches = await _retirerEntree(txn, id);
      final nombreSupprime = await txn.delete(
        'entrees',
        where: 'id = ?',
        whereArgs: <Object?>[id],
      );

      for (final numMed in touches) {
        await _recalculerStock(txn, numMed);
      }

      return nombreSupprime;
    });
  }

  String? _numeroLot(String? numero) {
    final valeur = (numero ?? '').trim();
    return valeur.isEmpty ? null : valeur;
  }

  // ---------------------------------------------------------------------------
  // Lots et péremptions
  // ---------------------------------------------------------------------------

  /// Lots avec leur désignation de médicament, triés par péremption (FEFO).
  Future<List<Lot>> getAllLots({bool disponiblesSeulement = true}) async {
    final db = await database;
    final filtre = disponiblesSeulement ? 'WHERE l.quantiteRestante > 0 ' : '';
    final lignes = await db.rawQuery(
      'SELECT l.*, m.designMed AS designMed '
      'FROM lots l LEFT JOIN medics m ON m.numMed = l.numMed '
      '$filtre'
      'ORDER BY CASE WHEN l.datePeremption IS NULL THEN 1 ELSE 0 END, '
      'l.datePeremption ASC, l.id ASC',
    );
    return lignes.map((ligne) => Lot.fromMap(ligne)).toList();
  }

  /// Lots périmés ou dont la péremption tombe dans [jours] jours.
  Future<List<Lot>> getLotsEnAlerte({int jours = 90, DateTime? maintenant}) async {
    final lots = await getAllLots();
    return lots.where((lot) {
      final restants = lot.joursRestants(maintenant: maintenant);
      return restants != null && restants <= jours;
    }).toList();
  }

  // ---------------------------------------------------------------------------
  // Sauvegarde et restauration
  // ---------------------------------------------------------------------------

  /// Contenu complet de la base, table par table (ordre de restauration).
  Future<Map<String, Object?>> exporterTout() async {
    final db = await database;
    final tables = <String, Object?>{};
    for (final table in tablesSauvegardees) {
      tables[table] = await db.query(table);
    }
    return tables;
  }

  /// Remplace **toutes** les données par celles de [tables].
  ///
  /// Une transaction unique : en cas d'erreur (fichier incomplet, ligne
  /// corrompue), la base reste exactement dans son état précédent.
  Future<void> restaurerTout(Map<String, Object?> tables) async {
    final db = await database;

    await db.transaction((txn) async {
      for (final table in tablesSauvegardees) {
        final lignes = tables[table];
        if (lignes is! List) {
          throw OperationRefuseeException(
            'Sauvegarde incomplète : la table « $table » est absente.',
          );
        }

        await txn.delete(table);

        for (final ligne in lignes) {
          if (ligne is! Map) {
            throw OperationRefuseeException(
              'Sauvegarde corrompue : ligne invalide dans « $table ».',
            );
          }
          await txn.insert(table, Map<String, Object?>.from(ligne));
        }
      }

      // Le stock est dérivé des lots : on le recalcule après restauration.
      final medicaments = await txn.query('medics', columns: <String>['numMed']);
      for (final medicament in medicaments) {
        await _recalculerStock(txn, (medicament['numMed'] ?? '').toString());
      }
    });
  }

  /// Nombre de lignes par table (indicateur d'occupation).
  Future<Map<String, int>> compterLignes() async {
    final db = await database;
    final resultat = <String, int>{};
    for (final table in tablesSauvegardees) {
      final lignes = await db.rawQuery('SELECT COUNT(*) AS total FROM $table');
      resultat[table] = (lignes.first['total'] as num?)?.toInt() ?? 0;
    }
    return resultat;
  }

  // ---------------------------------------------------------------------------
  // Ventes
  // ---------------------------------------------------------------------------

  Future<List<Achat>> getAllAchats() async {
    final db = await database;
    final lignes = await db.query('achats', orderBy: 'dateAchat DESC, id DESC');
    return lignes.map((ligne) => Achat.fromMap(ligne)).toList();
  }

  /// Enregistre **toutes** les lignes d'une vente dans une seule transaction.
  ///
  /// Lève [StockInsuffisantException] sans rien écrire si une seule ligne
  /// n'est pas couverte par le stock.
  Future<int> insertAchats(List<Achat> lignesVente) async {
    if (lignesVente.isEmpty) {
      throw ArgumentError('Aucune ligne de vente à enregistrer.');
    }
    final db = await database;

    return db.transaction((txn) async {
      final quantitesParMedicament = <String, int>{};
      final medicsParNumero = <String, Medic>{};

      // 1. Validation complète, sans écriture.
      for (final ligne in lignesVente) {
        if (ligne.nbr <= 0) {
          throw ArgumentError.value(
            ligne.nbr,
            'nbr',
            'La quantité vendue doit être supérieure à zéro.',
          );
        }
        final medic = medicsParNumero[ligne.numMed] ??
            (await _medicParNumeroObligatoire(txn, ligne.numMed));
        medicsParNumero[ligne.numMed] = medic;
        quantitesParMedicament[ligne.numMed] =
            (quantitesParMedicament[ligne.numMed] ?? 0) + ligne.nbr;
      }

      for (final entree in quantitesParMedicament.entries) {
        final stock = await _stockActuel(txn, entree.key);
        StockRules.verifierDisponibilite(
          disponible: stock,
          demande: entree.value,
          designation: medicsParNumero[entree.key]!.designMed,
        );
      }

      // 2. Écriture, une fois tout validé.
      int? premierId;
      for (final ligne in lignesVente) {
        final medic = medicsParNumero[ligne.numMed]!;
        final id = await txn.insert('achats', <String, Object?>{
          'numAchat': ligne.numAchat,
          'numMed': ligne.numMed,
          'nomClient': ligne.nomClient,
          'dateAchat': ligne.dateAchat,
          'nbr': ligne.nbr,
          'prixUnitaire': ligne.prixUnitaire ?? medic.prixMed,
        });

        await _consommerFefo(
          txn,
          numMed: ligne.numMed,
          quantite: ligne.nbr,
          reference: 'ACHAT:$id',
          designation: medic.designMed,
        );

        premierId ??= id;
      }

      for (final numMed in quantitesParMedicament.keys) {
        await _recalculerStock(txn, numMed);
      }

      return premierId ?? 0;
    });
  }

  /// Modifie une ligne de vente : l'ancienne consommation est intégralement
  /// annulée (retour dans les lots) avant d'appliquer la nouvelle.
  Future<int> updateAchat(Achat achat) async {
    final id = achat.id;
    if (id == null) {
      throw ArgumentError("Identifiant de l'achat manquant.");
    }
    if (achat.nbr <= 0) {
      throw ArgumentError.value(
        achat.nbr,
        'nbr',
        'La quantité vendue doit être supérieure à zéro.',
      );
    }
    final db = await database;

    return db.transaction((txn) async {
      final lignes = await txn.query(
        'achats',
        where: 'id = ?',
        whereArgs: <Object?>[id],
        limit: 1,
      );
      if (lignes.isEmpty) {
        throw const EntiteIntrouvableException('Achat introuvable.');
      }
      final ancien = Achat.fromMap(lignes.first);
      final nouveauMedic = await _medicParNumeroObligatoire(txn, achat.numMed);

      final touches = await _restaurerReference(txn, 'ACHAT:$id');

      final nombreModifie = await txn.update(
        'achats',
        <String, Object?>{
          'numAchat': achat.numAchat,
          'numMed': achat.numMed,
          'nomClient': achat.nomClient,
          'dateAchat': achat.dateAchat,
          'nbr': achat.nbr,
          'prixUnitaire': achat.prixUnitaire ?? nouveauMedic.prixMed,
        },
        where: 'id = ?',
        whereArgs: <Object?>[id],
      );

      await _consommerFefo(
        txn,
        numMed: achat.numMed,
        quantite: achat.nbr,
        reference: 'ACHAT:$id',
        designation: nouveauMedic.designMed,
      );

      for (final numMed in <String>{...touches, ancien.numMed, achat.numMed}) {
        await _recalculerStock(txn, numMed);
      }

      return nombreModifie;
    });
  }

  Future<int> deleteAchat(int id) async {
    final db = await database;

    return db.transaction((txn) async {
      final lignes = await txn.query(
        'achats',
        where: 'id = ?',
        whereArgs: <Object?>[id],
        limit: 1,
      );
      if (lignes.isEmpty) return 0;

      final achat = Achat.fromMap(lignes.first);
      final touches = await _restaurerReference(txn, 'ACHAT:$id');
      final nombreSupprime = await txn.delete(
        'achats',
        where: 'id = ?',
        whereArgs: <Object?>[id],
      );

      for (final numMed in <String>{...touches, achat.numMed}) {
        await _recalculerStock(txn, numMed);
      }

      return nombreSupprime;
    });
  }

  // ---------------------------------------------------------------------------
  // Indicateurs
  // ---------------------------------------------------------------------------

  /// Quantités vendues par médicament (clé = numMed).
  Future<Map<String, int>> ventesParMedicament() async {
    final db = await database;
    final lignes = await db.rawQuery(
      'SELECT numMed, SUM(nbr) AS quantite FROM achats GROUP BY numMed',
    );
    final resultat = <String, int>{};
    for (final ligne in lignes) {
      final numero = (ligne['numMed'] ?? '').toString();
      resultat[numero] = (ligne['quantite'] as num?)?.toInt() ?? 0;
    }
    return resultat;
  }

  /// Recette totale, en tenant compte du prix figé sur chaque vente.
  Future<int> chiffreAffairesTotal() async {
    final db = await database;
    final lignes = await db.rawQuery(
      'SELECT SUM(a.nbr * COALESCE(a.prixUnitaire, m.prixMed, 0)) AS total '
      'FROM achats a LEFT JOIN medics m ON m.numMed = a.numMed',
    );
    if (lignes.isEmpty) return 0;
    return (lignes.first['total'] as num?)?.toInt() ?? 0;
  }
}
