import 'package:flutter/material.dart';
import 'package:pdf/widgets.dart' as pdfLib;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import '../Models/medic.dart';
import '../Models/acht.dart';
import '../SQLite/sqlite.dart';
import '../pages/pdf_utils.dart';

class AddAchat extends StatefulWidget {
  const AddAchat({super.key});

  @override
  State<AddAchat> createState() => _AddAchatState();
}

class _AddAchatState extends State<AddAchat> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  late List<Medic> _medics;
  late List<Medic> _filteredMedics; // Liste filtrée des médicaments
  late Map<String, TextEditingController> _quantityControllers;

  final TextEditingController _numAchatController = TextEditingController();
  final TextEditingController _nomClientController = TextEditingController();
  final TextEditingController _dateAchatController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  double _totalPrice = 0.0;
  Medic? _selectedMedic; // Le médicament sélectionné depuis la recherche

  @override
  void initState() {
    super.initState();
    _medics = [];
    _filteredMedics = []; // Initialisation de la liste filtrée
    _quantityControllers = {};
    _fetchMedics();
  }

  void _fetchMedics() async {
    List<Medic> medics = await _dbHelper.getAllMedics();
    setState(() {
      _medics = medics;
      _filteredMedics = medics; // Initialisation des médicaments filtrés
      for (var medic in _medics) {
        _quantityControllers[medic.numMed] = TextEditingController();
      }
    });
  }

  void _updateTotalPrice() {
    double totalPrice = 0.0;
    for (var medic in _medics) {
      String quantityText = _quantityControllers[medic.numMed]?.text ?? '';
      if (quantityText.isNotEmpty) {
        int quantity = int.parse(quantityText);
        totalPrice += quantity * medic.prixMed;
      }
    }
    setState(() {
      _totalPrice = totalPrice;
    });
  }

  void _saveAchat() async {
    if (_numAchatController.text.isEmpty || _nomClientController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez remplir tous les champs obligatoires.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    bool stockInsufficient = false;

    for (var medic in _medics) {
      String quantityText = _quantityControllers[medic.numMed]?.text ?? '';
      if (quantityText.isNotEmpty) {
        int quantity = int.parse(quantityText);

        if (quantity > medic.stockMed) {
          stockInsufficient = true;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Stock insuffisant pour ${medic.designMed}. Disponible: ${medic.stockMed}'),
              backgroundColor: Colors.red,
            ),
          );
        } else {
          Achat achat = Achat(
            numAchat: _numAchatController.text,
            numMed: medic.numMed,
            nomClient: _nomClientController.text,
            dateAchat: _dateAchatController.text,
            nbr: quantity,
          );
          await _dbHelper.insertAchat(achat);
        }
      }
    }

    if (!stockInsufficient) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Achat enregistré avec succès.'),
          backgroundColor: Colors.green,
        ),
      );

      // Générer la facture après l'enregistrement de l'achat
      _showInvoice();

      // Attendre 1 seconde avant de revenir à l'écran précédent
      Future.delayed(const Duration(seconds: 1), () {
        Navigator.pop(context);
      });
    }
  }


  void _showInvoice() {
    pdfLib.Document pdf = generateInvoicePdf(
      _numAchatController.text,
      _nomClientController.text,
      _dateAchatController.text,
      _medics,
      _quantityControllers,
      _totalPrice,
    );

    Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }

  void _filterMedics(String query) {
    List<Medic> filteredList = _medics.where((medic) {
      return medic.designMed.toLowerCase().contains(query.toLowerCase());
    }).toList();

    setState(() {
      _filteredMedics = filteredList;
    });
  }

  @override
  Widget build(BuildContext context) {
    List<Medic> displayMedics = _selectedMedic != null ? [_selectedMedic!] : _filteredMedics;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Ajouter Achat',
          style: TextStyle(
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.green,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _numAchatController,
              decoration: InputDecoration(
                labelText: 'Numéro d\'Achat',
                filled: true,
                fillColor: Colors.green.withOpacity(0.2), // Fond vert opacité
                focusedBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.green, width: 2.0), // Bordure verte quand focus
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.green.withOpacity(0.5), width: 2.0), // Bordure verte quand inactif
                ),
              ),
            ),
            const SizedBox(height: 20.0),
            TextField(
              controller: _nomClientController,
              decoration: InputDecoration(
                labelText: 'Nom du Client',
                filled: true,
                fillColor: Colors.green.withOpacity(0.2), // Fond vert opacité
                focusedBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.green, width: 2.0), // Bordure verte quand focus
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.green.withOpacity(0.5), width: 2.0), // Bordure verte quand inactif
                ),
              ),
            ),
            const SizedBox(height: 20.0),
            TextField(
              controller: _dateAchatController,
              decoration: InputDecoration(
                labelText: 'Date d\'Achat',
                filled: true,
                fillColor: Colors.green.withOpacity(0.2), // Fond vert opacité
                focusedBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.green, width: 2.0), // Bordure verte quand focus
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.green.withOpacity(0.5), width: 2.0), // Bordure verte quand inactif
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Rechercher Médicament',
                prefixIcon: const Icon(Icons.search, color: Colors.pinkAccent), // Icône de recherche en rose
                filled: true,
                fillColor: Colors.pinkAccent.withOpacity(0.2), // Fond rose opacité
                focusedBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.pink, width: 2.0), // Bordure rose quand focus
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.pink.withOpacity(0.5), width: 2.0), // Bordure rose quand inactif
                ),
              ),
              onChanged: (value) {
                _filterMedics(value);
              },
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                itemCount: displayMedics.length,
                itemBuilder: (BuildContext context, int index) {
                  final medic = displayMedics[index];
                  final controller = _quantityControllers[medic.numMed];
                  return Column(
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text('${medic.designMed} (Num: ${medic.numMed})')),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: TextField(
                              controller: controller,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: 'Quantité',
                                filled: true,
                                fillColor: Colors.green.withOpacity(0.2),
                                focusedBorder: const OutlineInputBorder(
                                  borderSide: BorderSide(color: Colors.green, width: 2.0),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderSide: BorderSide(color: Colors.green.withOpacity(0.5), width: 2.0),
                                ),
                              ),
                              onChanged: (value) {
                                _updateTotalPrice();
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12), // Ajouter de l'espace entre les éléments
                    ],
                  );
                },
              ),

            ),
            const SizedBox(height: 16.0),
            Text('Prix Total: $_totalPrice Ar', style: const TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16.0),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ElevatedButton.icon(
                  onPressed: _showInvoice,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.pinkAccent, // Fond rose
                    foregroundColor: Colors.white, // Texte en blanc
                  ),
                  icon: const Icon(Icons.receipt, color: Colors.white), // Icône de facture
                  label: const Text('Facture', style: TextStyle(color: Colors.white)), // Texte en blanc
                ),
                ElevatedButton.icon(
                  onPressed: _saveAchat,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green, // Fond rose
                    foregroundColor: Colors.white, // Texte en blanc
                  ),
                  icon: const Icon(Icons.save_alt, color: Colors.white), // Icône de sauvegarde
                  label: const Text('Enregistrer', style: TextStyle(color: Colors.white)), // Texte en blanc
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class MedicSearchDelegate extends SearchDelegate<Medic> {
  final List<Medic> medics;
  final Function(String) onSearchChanged;

  MedicSearchDelegate(this.medics, this.onSearchChanged);

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () {
          query = '';
          onSearchChanged(query);
        },
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        close(context, _createEmptyMedic());
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    final List<Medic> filteredMedics = medics.where((medic) {
      return medic.designMed.toLowerCase().contains(query.toLowerCase());
    }).toList();

    return ListView.builder(
      itemCount: filteredMedics.length,
      itemBuilder: (context, index) {
        final Medic medic = filteredMedics[index];
        return ListTile(
          title: Text(medic.designMed),
          onTap: () {
            close(context, medic);
          },
        );
      },
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    final List<Medic> filteredMedics = medics.where((medic) {
      return medic.designMed.toLowerCase().contains(query.toLowerCase());
    }).toList();

    return ListView.builder(
      itemCount: filteredMedics.length,
      itemBuilder: (context, index) {
        final Medic medic = filteredMedics[index];
        return ListTile(
          title: Text(medic.designMed),
          onTap: () {
            query = medic.designMed;
            showResults(context);
          },
        );
      },
    );
  }

  Medic _createEmptyMedic() {
    return Medic(
      id: 0,
      numMed: '',
      designMed: '',
      prixMed: 0,
      stockMed: 0,
    );
  }
}
