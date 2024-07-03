import 'package:flutter/material.dart';
import 'package:appharmacie/Models/medic.dart'; // Assurez-vous que le chemin d'import est correct
import '../SQLite/sqlite.dart';
import '../dialog/addMed.dart';

class Medicament extends StatefulWidget {
  const Medicament({super.key});

  @override
  State<Medicament> createState() => _MedicamentState();
}

class _MedicamentState extends State<Medicament> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  late List<Medic> _medics;
  List<Medic> _filteredMedics = [];
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _medics = [];
    _refreshMedics();
    _searchController.addListener(_filterMedics);
  }

  void _filterMedics() {
    setState(() {
      _filteredMedics = _medics
          .where((medic) =>
          medic.designMed.toLowerCase().contains(_searchController.text.toLowerCase()))
          .toList();
    });
  }

  void _updateMedic(int id, String numMed, String designMed, int prixMed, int stockMed) async {
    Medic updatedMedic = Medic(
      id: id,
      numMed: numMed,
      designMed: designMed,
      prixMed: prixMed,
      stockMed: stockMed,
    );
    await _dbHelper.updateMedic(updatedMedic);
    _refreshMedics();
  }

  void _refreshMedics() async {
    List<Medic> medics = await _dbHelper.getAllMedics();
    setState(() {
      _medics = medics;
      _filterMedics();
    });
  }

  void _deleteMedic(int id) async {
    await _dbHelper.deleteMedic(id);
    _refreshMedics();
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
            child: _filteredMedics.isEmpty
                ? const Center(
              child: Text('Pas de médicaments ajoutés'),
            )
                : ListView.builder(
              itemCount: _filteredMedics.length,
              itemBuilder: (context, index) {
                var medic = _filteredMedics[index];
                return Container(
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                  child: ListTile(
                    title: Text(
                      medic.designMed,
                      style: const TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      'Num: ${medic.numMed}, Prix: ${medic.prixMed.toString()} Ar, Stock: ${medic.stockMed} ',
                      style: const TextStyle(color: Colors.white),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          onPressed: () {
                            _showEditDialog(context, medic);
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.pink),
                          onPressed: () {
                            _showDeleteDialog(context, medic);
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
            MaterialPageRoute(builder: (context) => const AddMed()),
          ).then((_) {
            _refreshMedics();
          });
        },
        backgroundColor: Colors.green,
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showEditDialog(BuildContext context, Medic medic) {
    var _medNumController = TextEditingController(text: medic.numMed);
    var _medDesignController = TextEditingController(text: medic.designMed);
    var _medPrixController = TextEditingController(text: medic.prixMed.toString());
    var _medStockController = TextEditingController(text: medic.stockMed.toString());

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
                    'Modifier Médicament',
                    style: TextStyle(
                      fontSize: 20.0,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16.0),
                  TextField(
                    controller: _medNumController,
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      hintText: 'Entrer le Numero du medicament',
                      labelText: 'Numero:',
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
                  const SizedBox(height: 20.0),
                  TextField(
                    controller: _medDesignController,
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      hintText: 'Entrer la désignation',
                      labelText: 'Désignation:',
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
                  const SizedBox(height: 20.0),
                  TextField(
                    controller: _medPrixController,
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      hintText: 'Entrer le prix ',
                      labelText: 'Prix Unitaire:',
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
                  const SizedBox(height: 20.0),
                  TextField(
                    controller: _medStockController,
                    readOnly: true, // Rend le champ en lecture seule
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      hintText: 'Entrer le nombre de Stock',
                      labelText: 'Stock:',
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
                          int stockMed = int.parse(_medStockController.text);
                          int prixMed = int.parse(_medPrixController.text);
                          _updateMedic(
                            medic.id!,
                            _medNumController.text,
                            _medDesignController.text,
                            prixMed,
                            stockMed,
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

  void _showDeleteDialog(BuildContext context, Medic medic) {
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
                    'Confirmation',
                    style: TextStyle(
                      fontSize: 20.0,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16.0),
                  const Text('Voulez-vous vraiment supprimer ce médicament ?'),
                  const SizedBox(height: 24.0),
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
                          backgroundColor: Colors.red,
                        ),
                        child: const Text('Supprimer'),
                        onPressed: () {
                          _deleteMedic(medic.id!);
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
}
