import 'package:flutter/material.dart';
import '../Models/entr.dart'; // Assurez-vous d'importer correctement votre modèle d'entrée
import '../SQLite/sqlite.dart'; // Assurez-vous d'importer correctement votre gestionnaire de base de données
import '../main.dart'; // Assurez-vous d'importer correctement votre fichier principal
import 'package:intl/intl.dart';

class AddEntree extends StatefulWidget {
  const AddEntree({super.key});

  @override
  State<AddEntree> createState() => _AddEntreeState();
}

class _AddEntreeState extends State<AddEntree> {
  var _numEntrController = TextEditingController();
  var _stockEntrController = TextEditingController();
  var _dateEntrController = TextEditingController();

  bool _validateNumEntr = false;
  bool _validateNumMed = false;
  bool _validateStockEntr = false;
  bool _validateDateEntr = false;

  final DatabaseHelper _dbHelper = DatabaseHelper();
  List<String> _medNum = [];
  String? _selectedMedNum;

  @override
  void initState() {
    super.initState();
    _loadMedNum();
  }

  void _loadMedNum() async {
    try {
      List<String> medNum = await _dbHelper.getAllMedNum();
      setState(() {
        _medNum = medNum;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text(
            'Erreur lors du chargement des numéros de médicaments: $e',
            style: const TextStyle(color: Colors.white),
          ),
        ),
      );
    }
  }

  void _validateFields() {
    setState(() {
      _numEntrController.text.isEmpty ? _validateNumEntr = true : _validateNumEntr = false;
      _selectedMedNum == null ? _validateNumMed = true : _validateNumMed = false;
      _stockEntrController.text.isEmpty ? _validateStockEntr = true : _validateStockEntr = false;
      _dateEntrController.text.isEmpty ? _validateDateEntr = true : _validateDateEntr = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Ajouter une Entrée",
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
                controller: _numEntrController,
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  hintText: 'Entrer le numéro d\'entrée',
                  labelText: 'Numéro d\'entrée:',
                  errorText: _validateNumEntr
                      ? 'Le champ Numéro d\'entrée ne peut pas être vide'
                      : null,
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
              DropdownButtonFormField<String>(
                value: _selectedMedNum,
                items: _medNum.map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                onChanged: (newValue) {
                  setState(() {
                    _selectedMedNum = newValue;
                  });
                },
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  hintText: 'Sélectionner le numéro de médicament',
                  labelText: 'Numéro de médicament:',
                  errorText: _validateNumMed
                      ? 'Le champ Numéro de médicament ne peut pas être vide'
                      : null,
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
              TextFormField(
                controller: _stockEntrController,
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  hintText: 'Entrer la quantité entrée',
                  labelText: 'Quantité entrée:',
                  errorText: _validateStockEntr
                      ? 'Le champ Quantité entrée ne peut pas être vide'
                      : null,
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
              TextFormField(
                controller: _dateEntrController,
                readOnly: true,
                onTap: () async {
                  DateTime? pickedDate = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2101),
                  );

                  if (pickedDate != null) {
                    setState(() {
                      _dateEntrController.text = DateFormat('dd/MM/yy').format(pickedDate);
                    });
                  }
                },
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  hintText: 'Entrer la date d\'entrée',
                  labelText: 'Date d\'entrée:',
                  errorText: _validateDateEntr
                      ? 'Le champ Date d\'entrée ne peut pas être vide'
                      : null,
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
                        textStyle: const TextStyle(fontSize: 15)),
                    onPressed: () async {
                      _validateFields();

                      if (!_validateNumEntr &&
                          !_validateNumMed &&
                          !_validateStockEntr &&
                          !_validateDateEntr) {
                        try {
                          int stockEntr = int.parse(_stockEntrController.text);

                          // Mise à jour du stock du médicament dans medics
                          await _dbHelper.updateMedicStock(_selectedMedNum!, stockEntr);

                          // Création de l'objet Entree
                          Entree newEntree = Entree(
                            numEntr: _numEntrController.text,
                            numMed: _selectedMedNum!,
                            stockEntr: stockEntr,
                            dateEntr: _dateEntrController.text,
                          );

                          // Insertion de l'entree dans la table entrees
                          await _dbHelper.insertEntree(newEntree).whenComplete(() {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                backgroundColor: Colors.green,
                                content: Text(
                                  'Médicament entré avec succès',
                                  style: TextStyle(color: Colors.white),
                                ),
                              ),
                            );

                            _numEntrController.clear();
                            _stockEntrController.clear();
                            _dateEntrController.clear();
                            setState(() {
                              _selectedMedNum = null;
                            });

                            Navigator.pushAndRemoveUntil(
                              context,
                              MaterialPageRoute(builder: (context) => const HomePage(initialIndex: 1)),
                                  (Route<dynamic> route) => false,
                            );
                          });

                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: Colors.red,
                              content: Text(
                                'Erreur lors de l\'ajout de l\'entrée: $e',
                                style: const TextStyle(color: Colors.white),
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
                        textStyle: const TextStyle(fontSize: 15)),
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: const Text('Annuler'),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}
