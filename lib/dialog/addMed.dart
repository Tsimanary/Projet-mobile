import 'package:flutter/material.dart';
import 'package:appharmacie/Models/medic.dart';
import '../SQLite/sqlite.dart'; // Assurez-vous d'importer DatabaseHelper
import 'package:appharmacie/main.dart'; // Assurez-vous d'importer HomePage

class AddMed extends StatefulWidget {
  const AddMed({super.key});

  @override
  State<AddMed> createState() => _AddMedState();
}

class _AddMedState extends State<AddMed> {
  var _medNumController = TextEditingController();
  var _medDesignController = TextEditingController();
  var _medPrixController = TextEditingController();

  bool _validateNum = false;
  bool _validateDesign = false;
  bool _validatePrix = false;

  final DatabaseHelper _dbHelper = DatabaseHelper();

  void _validateFields() {
    setState(() {
      _medNumController.text.isEmpty ? _validateNum = true : _validateNum = false;
      _medDesignController.text.isEmpty ? _validateDesign = true : _validateDesign = false;
      _medPrixController.text.isEmpty ? _validatePrix = true : _validatePrix = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Ajouter de Médicament",
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.green,
      ),
      body: SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20.0),
              TextField(
                controller: _medNumController,
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  hintText: 'Entrer le Numéro du médicament',
                  labelText: 'Numéro:',
                  errorText: _validateNum ? 'Le champ Numéro ne peut pas être vide' : null,
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
                  hintText: 'Entrer la Désignation',
                  labelText: 'Désignation:',
                  errorText: _validateDesign ? 'Le champ Désignation ne peut pas être vide' : null,
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
                  hintText: 'Entrer le Prix',
                  labelText: 'Prix Unitaire:',
                  errorText: _validatePrix ? 'Le champ Prix Unitaire ne peut pas être vide' : null,
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
                children: [
                  TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: Colors.green,
                      textStyle: const TextStyle(fontSize: 15),
                    ),
                    onPressed: () async {
                      _validateFields();

                      if (!_validateNum && !_validateDesign && !_validatePrix) {
                        try {
                          // Convertir le prix saisi en int
                          int prixMed = int.parse(_medPrixController.text);

                          Medic newMedic = Medic(
                            numMed: _medNumController.text,
                            designMed: _medDesignController.text,
                            prixMed: prixMed,
                            stockMed: 0, // Initialiser le stock à 0
                          );

                          await _dbHelper.insertMedic(newMedic).then((id) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                backgroundColor: Colors.green,
                                content: Text(
                                  'Médicament ajouté avec succès',
                                  style: TextStyle(color: Colors.white),
                                ),
                              ),
                            );

                            _medNumController.clear();
                            _medDesignController.clear();
                            _medPrixController.clear();

                            Navigator.pushAndRemoveUntil(
                              context,
                              MaterialPageRoute(builder: (context) => const HomePage(initialIndex: 2)),
                                  (Route<dynamic> route) => false,
                            );
                          }).catchError((e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                backgroundColor: Colors.red,
                                content: Text(
                                  'Erreur lors de l\'ajout du médicament: $e',
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                            );
                          });
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              backgroundColor: Colors.red,
                              content: Text(
                                'Erreur: Une erreur est survenue',
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                          );
                        }
                      }
                    },
                    child: const Text('Enregistrer'),
                  ),
                  const SizedBox(width: 20.0),
                  TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: Colors.blue,
                      textStyle: const TextStyle(fontSize: 15),
                    ),
                    onPressed: () {
                      _medNumController.clear();
                      _medDesignController.clear();
                      _medPrixController.clear();
                    },
                    child: const Text('Effacer'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
