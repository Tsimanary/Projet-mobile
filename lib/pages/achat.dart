import 'package:flutter/material.dart';
import 'package:appharmacie/Models/acht.dart'; // Assurez-vous d'importer correctement votre modèle d'Achat
import 'package:appharmacie/SQLite/sqlite.dart'; // Assurez-vous d'importer correctement votre classe DatabaseHelper
import 'package:appharmacie/dialog/addAchat.dart';

class AchatPage extends StatefulWidget {
  const AchatPage({super.key});

  @override
  _AchatPageState createState() => _AchatPageState();
}

class _AchatPageState extends State<AchatPage> {
  late List<Achat> _achats;
  late DatabaseHelper _dbHelper;
  late List<Achat> _filteredAchats;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _achats = [];
    _dbHelper = DatabaseHelper();
    _filteredAchats = [];
    _refreshAchats();
    _searchController.addListener(_filterAchats);
  }

  void _filterAchats() {
    setState(() {
      _filteredAchats = _achats
          .where((achat) =>
      achat.numAchat.toLowerCase().contains(_searchController.text.toLowerCase()) ||
          achat.numMed.toLowerCase().contains(_searchController.text.toLowerCase()) ||
          achat.nomClient.toLowerCase().contains(_searchController.text.toLowerCase()))
          .toList();
    });
  }

  void _refreshAchats() async {
    List<Achat> list = await _dbHelper.getAllAchats();
    setState(() {
      _achats = list;
      _filteredAchats = list;
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
            child: _filteredAchats.isEmpty
                ? const Center(
              child: Text('Pas d\'achats ajoutés'),
            )
                : ListView.builder(
              itemCount: _filteredAchats.length,
              itemBuilder: (context, index) {
                var achat = _filteredAchats[index];
                return Container(
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                  child: ListTile(
                    title: Text(
                      'Achat #${achat.numAchat}',
                      style: const TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      'Médicament: ${achat.numMed}, Client: ${achat.nomClient}, Quantité: ${achat.nbr}, Date: ${achat.dateAchat}',
                      style: const TextStyle(color: Colors.white),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          onPressed: () {
                            _editAchat(achat);
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.pink),
                          onPressed: () {
                            _confirmDeleteAchat(achat);
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
            MaterialPageRoute(builder: (context) => const AddAchat()),
          ).then((_) {
            _refreshAchats();
          });
        },
        backgroundColor: Colors.green,
        child: const Icon(Icons.add),
      ),
    );
  }

  void _editAchat(Achat achat) {
    var _achatNumAchatController = TextEditingController(text: achat.numAchat);
    var _achatMedController = TextEditingController(text: achat.numMed);
    var _achatClientController = TextEditingController(text: achat.nomClient);
    var _achatQuantiteController = TextEditingController(text: achat.nbr.toString());
    var _achatDateController = TextEditingController(text: achat.dateAchat);

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
                    'Modifier Achat',
                    style: TextStyle(
                      fontSize: 20.0,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16.0),
                  TextField(
                    controller: _achatNumAchatController,
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      labelText: 'Numéro Achat',
                      filled: true,
                      fillColor: Colors.green.withOpacity(0.2),
                    ),
                  ),
                  const SizedBox(height: 16.0),
                  TextField(
                    controller: _achatMedController,
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      labelText: 'Numéro Médicament',
                      filled: true,
                      fillColor: Colors.green.withOpacity(0.2),
                    ),
                  ),
                  const SizedBox(height: 20.0),
                  TextField(
                    controller: _achatClientController,
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      labelText: 'Nom Client',
                      filled: true,
                      fillColor: Colors.green.withOpacity(0.2),
                    ),
                  ),
                  const SizedBox(height: 20.0),
                  TextField(
                    controller: _achatQuantiteController,
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      labelText: 'Quantité',
                      filled: true,
                      fillColor: Colors.green.withOpacity(0.2),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 20.0),
                  TextField(
                    controller: _achatDateController,
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
                          int quantite = int.parse(_achatQuantiteController.text);
                          _updateAchat(
                            achat.id!,
                            _achatNumAchatController.text,
                            _achatMedController.text,
                            _achatClientController.text,
                            quantite,
                            _achatDateController.text,
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

  Future<void> _confirmDeleteAchat(Achat achat) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // utilisateur doit cliquer sur un des boutons pour fermer la boîte de dialogue
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirmer la suppression'),
          content: const SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text('Êtes-vous sûr de vouloir supprimer cet achat ?'),
              ],
            ),
          ),
          backgroundColor: Colors.white, // couleur de fond de la boîte de dialogue
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.0),
            side: BorderSide(color: Colors.green.withOpacity(0.5)), // bordure verte
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
                await _deleteAchat(achat.id!);
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _updateAchat(int id, String numAchat, String numMed, String nomClient, int nbr, String dateAchat) async {
    Achat achat = Achat(
      id: id,
      numAchat: numAchat,
      numMed: numMed,
      nomClient: nomClient,
      nbr: nbr,
      dateAchat: dateAchat,
    );
    await _dbHelper.updateAchat(achat);
    _refreshAchats();
  }

  Future<void> _deleteAchat(int id) async {
    await _dbHelper.deleteAchat(id);
    _refreshAchats();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
