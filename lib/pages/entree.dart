import 'package:flutter/material.dart';
import 'package:appharmacie/Models/entr.dart'; // Assurez-vous d'importer correctement votre modèle d'Entree
import 'package:appharmacie/SQLite/sqlite.dart'; // Assurez-vous d'importer correctement votre classe DatabaseHelper
import 'package:appharmacie/dialog/addEntree.dart';

class EntreePage extends StatefulWidget {
  const EntreePage({super.key});

  @override
  _EntreePageState createState() => _EntreePageState();
}

class _EntreePageState extends State<EntreePage> {
  late List<Entree> _entrees;
  late DatabaseHelper _dbHelper;
  late List<Entree> _filteredEntrees;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _entrees = [];
    _dbHelper = DatabaseHelper();
    _filteredEntrees = [];
    _refreshEntrees();
    _searchController.addListener(_filterEntrees);
  }

  void _filterEntrees() {
    setState(() {
      _filteredEntrees = _entrees
          .where((entree) =>
      entree.numEntr.toLowerCase().contains(_searchController.text.toLowerCase()) ||
          entree.numMed.toLowerCase().contains(_searchController.text.toLowerCase()))
          .toList();
    });
  }

  void _refreshEntrees() async {
    List<Entree> list = await _dbHelper.getAllEntrees();
    setState(() {
      _entrees = list;
      _filteredEntrees = list;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Recherche',
                prefixIcon: const Icon(Icons.search, color: Colors.green),
                filled: true,
                fillColor: Colors.green.withOpacity(0.2),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.green.withOpacity(0.5), width: 2.0),
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.green.withOpacity(0.5), width: 2.0),
                ),
              ),
            ),
          ),
          Expanded(
            child: _filteredEntrees.isEmpty
                ? const Center(
              child: Text('Pas d\'entrées ajoutées'),
            )
                : ListView.builder(
              itemCount: _filteredEntrees.length,
              itemBuilder: (context, index) {
                var entree = _filteredEntrees[index];
                return Container(
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                  child: ListTile(
                    title: Text(
                      'Entrée #${entree.numEntr}',
                      style: const TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      'Médicament: ${entree.numMed}, Stock Entrée: ${entree.stockEntr}, Date: ${entree.dateEntr}',
                      style: const TextStyle(color: Colors.white),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          onPressed: () {
                            _editEntree(entree);
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.pink),
                          onPressed: () {
                            _confirmDeleteEntree(entree);
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddEntree()),
          ).then((_) {
            _refreshEntrees();
          });
        },
        backgroundColor: Colors.green,
        child: const Icon(Icons.add),
      ),
    );
  }

  void _editEntree(Entree entree) {
    var _entreeNumEntrController = TextEditingController(text: entree.numEntr);
    var _entreeMedController = TextEditingController(text: entree.numMed);
    var _entreeStockController = TextEditingController(text: entree.stockEntr.toString());
    var _entreeDateController = TextEditingController(text: entree.dateEntr);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12.0),
              border: Border.all(
                color: Colors.green.withOpacity(0.5),
                width: 3.0,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Modifier Entrée',
                    style: TextStyle(
                      fontSize: 20.0,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16.0),
                  TextField(
                    controller: _entreeNumEntrController,
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      labelText: 'Numéro Entrée',
                      filled: true,
                      fillColor: Colors.green.withOpacity(0.2),
                    ),
                  ),
                  const SizedBox(height: 16.0),
                  TextField(
                    controller: _entreeMedController,
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      labelText: 'Numéro Médicament',
                      filled: true,
                      fillColor: Colors.green.withOpacity(0.2),
                    ),
                  ),
                  const SizedBox(height: 20.0),
                  TextField(
                    controller: _entreeStockController,
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      labelText: 'Stock Entrée',
                      filled: true,
                      fillColor: Colors.green.withOpacity(0.2),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 20.0),
                  TextField(
                    controller: _entreeDateController,
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      labelText: 'Date',
                      filled: true,
                      fillColor: Colors.green.withOpacity(0.2),
                    ),
                  ),
                  const SizedBox(height: 20.0),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: Colors.blue,
                        ),
                        child: const Text('Annuler'),
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                      ),
                      const SizedBox(width: 8.0),
                      TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: Colors.green,
                        ),
                        child: const Text('Enregistrer'),
                        onPressed: () {
                          int stock = int.parse(_entreeStockController.text);
                          _updateEntree(
                            entree.id!,
                            _entreeNumEntrController.text,
                            _entreeMedController.text,
                            stock,
                            _entreeDateController.text,
                          );
                          Navigator.of(context).pop();
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmDeleteEntree(Entree entree) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // utilisateur doit cliquer sur un des boutons pour fermer la boîte de dialogue
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirmer la suppression'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text('Voulez-vous vraiment supprimer l\'entrée ${entree.numEntr} ?'),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              style: TextButton.styleFrom(
                backgroundColor: Colors.blue, // bouton bleu pour "Annuler"
              ),
              child: const Text(
                'Annuler',
                style: TextStyle(color: Colors.white),
              ),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              style: TextButton.styleFrom(
                backgroundColor: Colors.pink, // bouton rose pour "Supprimer"
              ),
              child: const Text(
                'Supprimer',
                style: TextStyle(color: Colors.white),
              ),
              onPressed: () async {
                await _deleteEntree(entree.id!);
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _updateEntree(int id, String numEntr, String numMed, int stockEntr, String dateEntr) async {
    Entree entree = Entree(
      id: id,
      numEntr: numEntr,
      numMed: numMed,
      stockEntr: stockEntr,
      dateEntr: dateEntr,
    );
    await _dbHelper.updateEntree(entree);
    _refreshEntrees();
  }

  Future<void> _deleteEntree(int id) async {
    await _dbHelper.deleteEntree(id);
    _refreshEntrees();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
