import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:appharmacie/Models/users.dart';
import 'package:appharmacie/Models/entr.dart'; // Correction de l'import
import 'package:appharmacie/Models/acht.dart';  // Correction de l'import
import 'package:appharmacie/Models/medic.dart';

class DatabaseHelper {
  final String databaseName = "pharmacie.db";
  String users = "CREATE TABLE users (usrId INTEGER PRIMARY KEY AUTOINCREMENT, usrName TEXT UNIQUE, usrPassword TEXT)";
  String medics = "CREATE TABLE medics (id INTEGER PRIMARY KEY AUTOINCREMENT, numMed TEXT, designMed TEXT, prixMed INTEGER, stockMed INTEGER)";
  String entrees = "CREATE TABLE entrees (id INTEGER PRIMARY KEY AUTOINCREMENT, numEntr TEXT, numMed TEXT, stockEntr INTEGER, dateEntr TEXT)";
  String achats = "CREATE TABLE achats (id INTEGER PRIMARY KEY AUTOINCREMENT, numAchat TEXT, numMed TEXT, nomClient TEXT, dateAchat TEXT, nbr INTEGER)";

  late Database _database;

  // Initialisation de la base de données
  Future<Database> initDB() async {
    final databasePath = await getDatabasesPath();
    final path = join(databasePath, databaseName);

    _database = await openDatabase(path, version: 1, onCreate: (db, version) async {
      await db.execute(users);
      await db.execute(medics);
      await db.execute(entrees);
      await db.execute(achats);
    });

    return _database;
  }

  // Méthode de connexion
  Future<bool> login(Users user) async {
    final Database db = await initDB();
    var result = await db.rawQuery(
        "select * from users where usrName = ? AND usrPassword = ?",
        [user.usrName, user.usrPassword]);
    return result.isNotEmpty;
  }

  // Inscription
  Future<int> signup(Users user) async {
    final Database db = await initDB();
    return await db.insert('users', user.toMap());
  }

  // Méthode pour insérer un médicament
  Future<int> insertMedic(Medic medic) async {
    final db = await initDB();
    int id = await db.insert('medics', medic.toMap());
    return id;
  }

  // Méthode pour récupérer tous les médicaments
  Future<List<Medic>> getAllMedics() async {
    final db = await initDB();
    var result = await db.query('medics');
    return result.map((map) => Medic.fromMap(map)).toList();
  }

  // Méthode pour supprimer le médicament par son ID
  Future<int> deleteMedic(int id) async {
    final Database db = await initDB();
    return await db.delete(
      'medics',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Méthode pour mettre à jour le médicament
  Future<int> updateMedic(Medic medic) async {
    final Database db = await initDB();
    return await db.update(
      'medics',
      medic.toMap(),
      where: 'id = ?',
      whereArgs: [medic.id],
    );
  }

  // Méthode pour insérer une entrée
  Future<int> insertEntree(Entree entre) async {
    final db = await initDB();
    List<Map<String, dynamic>> existingEntries = await db.query(
      'entrees',
      where: 'numMed = ?',
      whereArgs: [entre.numMed],
    );

    if (existingEntries.isNotEmpty) {
      int updated = await db.rawUpdate(
        'UPDATE entrees SET stockEntr = stockEntr + ? WHERE numMed = ?',
        [entre.stockEntr, entre.numMed],
      );
      return updated;
    } else {
      int id = await db.insert('entrees', entre.toMap());
      await db.rawUpdate(
        'UPDATE medics SET stockMed = stockMed + ? WHERE numMed = ?',
        [entre.stockEntr, entre.numMed],
      );
      return id;
    }
  }

  // Méthode pour récupérer toutes les entrées
  Future<List<Entree>> getAllEntrees() async {
    final Database db = await initDB();
    final List<Map<String, dynamic>> maps = await db.query('entrees');
    return List.generate(maps.length, (i) {
      return Entree.fromMap(maps[i]);
    });
  }

  // Méthode pour obtenir une entrée par son ID
  Future<Entree?> getEntreeById(int id) async {
    final db = await initDB();
    var result = await db.query('entrees', where: 'id = ?', whereArgs: [id]);
    return result.isNotEmpty ? Entree.fromMap(result.first) : null;
  }

  // Méthode pour supprimer une entrée
  Future<int> deleteEntree(int id) async {
    final Database db = await initDB();
    Entree? entryToDelete = await getEntreeById(id);
    if (entryToDelete != null) {
      await db.delete(
        'entrees',
        where: 'id = ?',
        whereArgs: [id],
      );
      await updateMedicStock(entryToDelete.numMed, -entryToDelete.stockEntr);
      return 1;
    }
    return -1;
  }

  // Méthode pour mettre à jour l'entrée
  Future<int> updateEntree(Entree entre) async {
    final db = await initDB();
    return await db.transaction((txn) async {
      int updatedEntree = await txn.update(
        'entrees',
        entre.toMap(),
        where: 'id = ?',
        whereArgs: [entre.id],
      );

      await txn.rawUpdate(
        'UPDATE medics SET stockMed = (SELECT SUM(stockEntr) FROM entrees WHERE numMed = ?) WHERE numMed = ?',
        [entre.numMed, entre.numMed],
      );

      return updatedEntree;
    });
  }

  // Méthode pour lister le numéro de médicament dans la base de données
  Future<List<String>> getAllMedNum() async {
    final db = await initDB();
    var res = await db.rawQuery('SELECT numMed FROM medics');
    List<String> list = res.isNotEmpty ? res.map((c) => c['numMed'].toString()).toList() : [];
    return list;
  }


  // Méthode pour mettre à jour le stock du médicament dans la table medics
  Future<void> updateMedicStock(String numMed, int stockToAdd) async {
    final db = await initDB();
    await db.rawUpdate(
      'UPDATE medics SET stockMed = stockMed + ? WHERE numMed = ?',
      [stockToAdd, numMed],
    );
  }

  // Méthode pour obtenir un médicament par son ID
  Future<Medic> getMedicById(int id) async {
    final db = await initDB();
    var result = await db.query('medics', where: 'id = ?', whereArgs: [id]);
    return result.isNotEmpty ? Medic.fromMap(result.first) : throw Exception("Médicament non trouvé");
  }

  // Méthode pour insérer un achat
  Future<int> insertAchat(Achat achat) async {
    final db = await initDB();

    var result = await db.query('medics', where: 'numMed = ?', whereArgs: [achat.numMed]);
    if (result.isEmpty) {
      return -2; // Médicament non trouvé
    }

    var medic = Medic.fromMap(result.first);
    if (medic.stockMed < achat.nbr) {
      return -1; // Stock insuffisant
    }

    int id = await db.insert('achats', achat.toMap());
    await db.rawUpdate(
      'UPDATE medics SET stockMed = stockMed - ? WHERE numMed = ?',
      [achat.nbr, achat.numMed],
    );

    return id;
  }

  // Méthode pour récupérer tous les achats
  Future<List<Achat>> getAllAchats() async {
    final db = await initDB();
    final List<Map<String, dynamic>> maps = await db.query('achats');
    return List.generate(maps.length, (i) {
      return Achat.fromMap(maps[i]);
    });
  }

  // Méthode pour supprimer un achat par son ID
  Future<int> deleteAchat(int id) async {
    final db = await initDB();
    Achat? achatToDelete = await getAchatById(id);
    if (achatToDelete != null) {
      await db.delete(
        'achats',
        where: 'id = ?',
        whereArgs: [id],
      );
      await updateMedicStock(achatToDelete.numMed, achatToDelete.nbr);
      return 1;
    }
    return -1;
  }

  // Méthode pour obtenir un achat par son ID
  Future<Achat?> getAchatById(int id) async {
    final db = await initDB();
    var result = await db.query('achats', where: 'id = ?', whereArgs: [id]);
    return result.isNotEmpty ? Achat.fromMap(result.first) : null;
  }

  // Méthode pour mettre à jour un achat
  Future<int> updateAchat(Achat achat) async {
    final db = await initDB();
    return await db.update(
      'achats',
      achat.toMap(),
      where: 'id = ?',
      whereArgs: [achat.id],
    );
  }
}
