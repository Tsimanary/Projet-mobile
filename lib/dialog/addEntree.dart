import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../Models/entr.dart';
import '../SQLite/sqlite.dart';
import '../core/exceptions.dart';
import '../core/feedback.dart';
import '../core/validators.dart';
import '../core/widgets/app_text_field.dart';

/// Formulaire d'enregistrement d'une entrée de stock.
///
/// Une entrée crée **toujours** une nouvelle ligne : l'historique des
/// réceptions reste intact, et le stock n'est augmenté qu'une seule fois
/// (côté base de données, dans une transaction).
class AddEntree extends StatefulWidget {
  const AddEntree({super.key});

  @override
  State<AddEntree> createState() => _AddEntreeState();
}

class _AddEntreeState extends State<AddEntree> {
  final _formKey = GlobalKey<FormState>();
  final _numeroControleur = TextEditingController();
  final _quantiteControleur = TextEditingController();
  final _dateControleur = TextEditingController();
  final DatabaseHelper _base = DatabaseHelper();

  List<String> _numerosMedicaments = <String>[];
  String? _medicamentSelectionne;
  bool _chargement = true;
  bool _enregistrementEnCours = false;
  String? _erreurChargement;

  @override
  void initState() {
    super.initState();
    _dateControleur.text = DateFormat('dd/MM/yyyy').format(DateTime.now());
    _chargerMedicaments();
  }

  @override
  void dispose() {
    _numeroControleur.dispose();
    _quantiteControleur.dispose();
    _dateControleur.dispose();
    super.dispose();
  }

  Future<void> _chargerMedicaments() async {
    try {
      final numeros = await _base.getAllMedNum();
      if (!mounted) return;
      setState(() {
        _numerosMedicaments = numeros;
        _chargement = false;
      });
    } catch (erreur) {
      if (!mounted) return;
      setState(() {
        _erreurChargement = 'Chargement impossible : $erreur';
        _chargement = false;
      });
    }
  }

  Future<void> _choisirDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (date == null || !mounted) return;
    setState(() {
      _dateControleur.text = DateFormat('dd/MM/yyyy').format(date);
    });
  }

  Future<void> _enregistrer() async {
    if (!_formKey.currentState!.validate()) return;
    if (_medicamentSelectionne == null) {
      afficherMessage(context, 'Sélectionnez un médicament.', erreur: true);
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _enregistrementEnCours = true);

    try {
      await _base.insertEntree(
        Entree(
          numEntr: _numeroControleur.text.trim(),
          numMed: _medicamentSelectionne!,
          stockEntr: Validators.versEntier(_quantiteControleur.text) ?? 0,
          dateEntr: _dateControleur.text.trim(),
        ),
      );

      if (!mounted) return;
      afficherMessage(context, 'Entrée de stock enregistrée.');
      Navigator.of(context).pop(true);
    } on EntiteIntrouvableException catch (erreur) {
      if (!mounted) return;
      setState(() => _enregistrementEnCours = false);
      afficherMessage(context, erreur.toString(), erreur: true);
    } catch (erreur) {
      if (!mounted) return;
      setState(() => _enregistrementEnCours = false);
      afficherMessage(context, "Échec de l'enregistrement : $erreur", erreur: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_chargement) {
      return Scaffold(
        appBar: AppBar(title: const Text('Nouvelle entrée')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_erreurChargement != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Nouvelle entrée')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(_erreurChargement!, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () {
                    setState(() {
                      _chargement = true;
                      _erreurChargement = null;
                    });
                    _chargerMedicaments();
                  },
                  child: const Text('Réessayer'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_numerosMedicaments.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Nouvelle entrée')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              "Aucun médicament enregistré. Ajoutez d'abord un médicament "
              "dans l'onglet « Médicaments ».",
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Nouvelle entrée')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                ChampTexte(
                  controleur: _numeroControleur,
                  label: "Numéro d'entrée",
                  hint: 'Ex. : ENT-001',
                  icone: Icons.tag,
                  validateur: (valeur) => Validators.obligatoire(
                    valeur,
                    champ: "Le numéro d'entrée",
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _medicamentSelectionne,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Médicament',
                    prefixIcon: Icon(Icons.medication_outlined),
                  ),
                  items: _numerosMedicaments
                      .map(
                        (numero) => DropdownMenuItem<String>(
                          value: numero,
                          child: Text(numero),
                        ),
                      )
                      .toList(),
                  onChanged: (valeur) {
                    setState(() => _medicamentSelectionne = valeur);
                  },
                  validator: (valeur) =>
                      valeur == null ? 'Sélectionnez un médicament.' : null,
                ),
                const SizedBox(height: 16),
                ChampTexte(
                  controleur: _quantiteControleur,
                  label: 'Quantité reçue',
                  icone: Icons.inventory_2_outlined,
                  clavier: TextInputType.number,
                  formateurs: Saisies.chiffres,
                  validateur: (valeur) => Validators.entier(
                    valeur,
                    champ: 'La quantité',
                  ),
                ),
                const SizedBox(height: 16),
                ChampTexte(
                  controleur: _dateControleur,
                  label: "Date d'entrée",
                  icone: Icons.calendar_today_outlined,
                  lectureSeule: true,
                  onTap: _choisirDate,
                  validateur: (valeur) => Validators.obligatoire(
                    valeur,
                    champ: "La date d'entrée",
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _enregistrementEnCours ? null : _enregistrer,
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Enregistrer'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _enregistrementEnCours
                      ? null
                      : () => Navigator.of(context).pop(),
                  child: const Text('Annuler'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
