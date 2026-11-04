import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../Models/acht.dart';
import '../Models/entr.dart';
import '../Models/medic.dart';
import '../Models/users.dart';
import '../core/exceptions.dart';
import '../core/securite.dart';
import '../core/stock_rules.dart';

/// Accès unique à la base SQLite locale.
///
/// Invariants garantis par cette classe :
///  * `medics.stockMed` n'est modifié qu'à l'intérieur d'une transaction ;
///  * une vente multi-lignes est entièrement validée **avant** la moindre
///    écriture (aucune vente partielle possible) ;
///  * une entrée de stock est toujours ajoutée (jamais fusionnée) ;
///  * les mots de passe sont hachés (avec migration des comptes existants) ;
///  * un médicament possédant un historique ne peut pas être supprimé.
class DatabaseHelper {
  DatabaseHelper._();

  static final DatabaseHelper _instance = DatabaseHelper._();

  /// `DatabaseHelper()` renvoie toujours la même instance.
  factory DatabaseHelper() => _instance;

  static const String _nomBase = 'pharmacie.db';
  static const int _versionBase = 2;

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
          'dateEntr TEXT)',
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
        await _creerIndex(db);
      },
      onUpgrade: (db, ancienneVersion, nouvelleVersion) async {
        if (ancienneVersion < 2) {
          // v1 -> v2 : hachage des mots de passe + prix figé sur les ventes.
          await _ajouterColonneSiAbsente(db, 'users', 'usrSalt', 'TEXT');
          await _ajouterColonneSiAbsente(db, 'achats', 'prixUnitaire', 'INTEGER');
          await _creerIndex(db);
        }
      },
    );
  }

  Future<void> _creerIndex(Database db) async {
    const instructions = <String>[
      'CREATE INDEX IF NOT EXISTS idx_medics_numMed ON medics(numMed)',
      'CREATE INDEX IF NOT EXISTS idx_entrees_numMed ON entrees(numMed)',
      'CREATE INDEX IF NOT EXISTS idx_achats_numMed ON achats(numMed)',
      'CREATE INDEX IF NOT EXISTS idx_achats_numAchat ON achats(numAchat)',
    ];
    for (final instruction in instructions) {
      await db.execute(instruction);
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
      throw EntiteIntrouvableException(
        'Médicament « $numMed » introuvable.',
      );
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

  /// Écrit le stock absolu (jamais un delta) : idempotent et testable.
  Future<void> _ecrireStock(
    DatabaseExecutor executeur,
    String numMed,
    int nouveauStock,
  ) async {
    await executeur.update(
      'medics',
      <String, Object?>{'stockMed': nouveauStock < 0 ? 0 : nouveauStock},
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
    final lignes = await db.query('medics', orderBy: 'designMed COLLATE NOCASE ASC');
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
      throw EntiteIntrouvableException('Médicament introuvable.');
    }
    return Medic.fromMap(lignes.first);
  }

  Future<bool> _numeroMedicamentExiste(String numMed, {int? saufId}) async {
    final db = await database;
    final lignes = await db.query(
      'medics',
      columns: <String>['id'],
      where: saufId == null ? 'numMed = ?' : 'numMed = ? AND id <> ?',
      whereArgs: saufId == null
          ? <Object?>[numMed]
          : <Object?>[numMed, saufId],
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
  /// exclusivement piloté par les entrées et les ventes.
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

    return db.delete('medics', where: 'id = ?', whereArgs: <Object?>[id]);
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
    final lignes = await db.query('entrees', orderBy: 'id DESC');
    return lignes.map((ligne) => Entree.fromMap(ligne)).toList();
  }

  Future<int> insertEntree(Entree entree) async {
    if (entree.stockEntr <= 0) {
      throw ArgumentError.value(
        entree.stockEntr,
        'stockEntr',
        'La quantité entrée doit être supérieure à zéro.',
      );
    }
    final db = await database;

    return db.transaction((txn) async {
      await _medicParNumeroObligatoire(txn, entree.numMed);

      final id = await txn.insert('entrees', <String, Object?>{
        'numEntr': entree.numEntr.trim(),
        'numMed': entree.numMed,
        'stockEntr': entree.stockEntr,
        'dateEntr': entree.dateEntr,
      });

      final stock = await _stockActuel(txn, entree.numMed);
      final nouveauStock = StockRules.apresEntree(
        stockActuel: stock,
        quantiteEntree: entree.stockEntr,
      );
      await _ecrireStock(txn, entree.numMed, nouveauStock);

      return id;
    });
  }

  Future<int> updateEntree(Entree entree) async {
    final id = entree.id;
    if (id == null) {
      throw ArgumentError("Identifiant de l'entrée manquant.");
    }
    if (entree.stockEntr <= 0) {
      throw ArgumentError.value(
        entree.stockEntr,
        'stockEntr',
        'La quantité entrée doit être supérieure à zéro.',
      );
    }
    final db = await database;

    return db.transaction((txn) async {
      final lignes = await txn.query(
        'entrees',
        where: 'id = ?',
        whereArgs: <Object?>[id],
        limit: 1,
      );
      if (lignes.isEmpty) {
        throw const EntiteIntrouvableException('Entrée introuvable.');
      }
      final ancienne = Entree.fromMap(lignes.first);

      final nombreModifie = await txn.update(
        'entrees',
        <String, Object?>{
          'numEntr': entree.numEntr.trim(),
          'numMed': entree.numMed,
          'stockEntr': entree.stockEntr,
          'dateEntr': entree.dateEntr,
        },
        where: 'id = ?',
        whereArgs: <Object?>[id],
      );

      if (ancienne.numMed == entree.numMed) {
        final stock = await _stockActuel(txn, entree.numMed);
        final nouveauStock = StockRules.apresModificationEntree(
          stockActuel: stock,
          ancienneQuantite: ancienne.stockEntr,
          nouvelleQuantite: entree.stockEntr,
        );
        await _ecrireStock(txn, entree.numMed, nouveauStock);
      } else {
        // Le médicament a changé : on retire l'ancienne quantité puis on
        // crédite la nouvelle, jamais un recalcul global.
        final ancienMedic = await _medicParNumero(txn, ancienne.numMed);
        if (ancienMedic != null) {
          final stockAncien = await _stockActuel(txn, ancienne.numMed);
          await _ecrireStock(txn, ancienne.numMed, stockAncien - ancienne.stockEntr);
        }
        final stockNouveau = await _stockActuel(txn, entree.numMed);
        final nouveauStock = StockRules.apresEntree(
          stockActuel: stockNouveau,
          quantiteEntree: entree.stockEntr,
        );
        await _ecrireStock(txn, entree.numMed, nouveauStock);
      }

      return nombreModifie;
    });
  }

  Future<int> deleteEntree(int id) async {
    final db = await database;

    return db.transaction((txn) async {
      final lignes = await txn.query(
        'entrees',
        where: 'id = ?',
        whereArgs: <Object?>[id],
        limit: 1,
      );
      if (lignes.isEmpty) return 0;

      final entree = Entree.fromMap(lignes.first);
      final nombreSupprime = await txn.delete(
        'entrees',
        where: 'id = ?',
        whereArgs: <Object?>[id],
      );

      final medic = await _medicParNumero(txn, entree.numMed);
      if (medic != null) {
        final stock = await _stockActuel(txn, entree.numMed);
        await _ecrireStock(txn, entree.numMed, stock - entree.stockEntr);
      }

      return nombreSupprime;
    });
  }

  // ---------------------------------------------------------------------------
  // Ventes
  // ---------------------------------------------------------------------------

  Future<List<Achat>> getAllAchats() async {
    final db = await database;
    final lignes = await db.query('achats', orderBy: 'id DESC');
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
        if (!StockRules.stockSuffisant(stock: stock, quantite: entree.value)) {
          throw StockInsuffisantException(
            designation: medicsParNumero[entree.key]!.designMed,
            demande: entree.value,
            disponible: stock,
          );
        }
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
        premierId ??= id;
      }

      for (final entree in quantitesParMedicament.entries) {
        final medic = medicsParNumero[entree.key]!;
        final stock = await _stockActuel(txn, entree.key);
        final nouveauStock = StockRules.apresVente(
          stockActuel: stock,
          quantiteVendue: entree.value,
          designation: medic.designMed,
        );
        await _ecrireStock(txn, entree.key, nouveauStock);
      }

      return premierId ?? 0;
    });
  }

  /// Raccourci pour une vente à une seule ligne.
  Future<int> insertAchat(Achat achat) => insertAchats(<Achat>[achat]);

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

      final nombreModifie = await txn.update(
        'achats',
        <String, Object?>{
          'numAchat': achat.numAchat,
          'numMed': achat.numMed,
          'nomClient': achat.nomClient,
          'dateAchat': achat.dateAchat,
          'nbr': achat.nbr,
          'prixUnitaire': achat.prixUnitaire ?? ancien.prixUnitaire ?? nouveauMedic.prixMed,
        },
        where: 'id = ?',
        whereArgs: <Object?>[id],
      );

      if (ancien.numMed == achat.numMed) {
        final stock = await _stockActuel(txn, achat.numMed);
        final nouveauStock = StockRules.apresModificationVente(
          stockActuel: stock,
          ancienneQuantite: ancien.nbr,
          nouvelleQuantite: achat.nbr,
          designation: nouveauMedic.designMed,
        );
        await _ecrireStock(txn, achat.numMed, nouveauStock);
      } else {
        final ancienMedic = await _medicParNumero(txn, ancien.numMed);
        if (ancienMedic != null) {
          final stockAncien = await _stockActuel(txn, ancien.numMed);
          await _ecrireStock(txn, ancien.numMed, stockAncien + ancien.nbr);
        }
        final stockNouveau = await _stockActuel(txn, achat.numMed);
        final nouveauStock = StockRules.apresVente(
          stockActuel: stockNouveau,
          quantiteVendue: achat.nbr,
          designation: nouveauMedic.designMed,
        );
        await _ecrireStock(txn, achat.numMed, nouveauStock);
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
      final nombreSupprime = await txn.delete(
        'achats',
        where: 'id = ?',
        whereArgs: <Object?>[id],
      );

      final medic = await _medicParNumero(txn, achat.numMed);
      if (medic != null) {
        final stock = await _stockActuel(txn, achat.numMed);
        await _ecrireStock(txn, achat.numMed, stock + achat.nbr);
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
