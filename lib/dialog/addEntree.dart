import 'package:flutter/material.dart';

import '../Models/entr.dart';
import '../SQLite/sqlite.dart';
import '../core/exceptions.dart';
import '../core/feedback.dart';
import '../core/format.dart';
import '../core/validators.dart';
import '../core/widgets/app_text_field.dart';

/// Formulaire d'enregistrement d'une entrée de stock.
///
/// Une entrée crée **toujours** un mouvement et alimente un lot daté : c'est
/// ce lot qui portera la péremption et qui sera consommé en priorité lors des
/// ventes (FEFO).
class AddEntree extends StatefulWidget {
  const AddEntree({super.key});

  @override
  State<AddEntree> createState() => _AddEntreeState();
}

class _AddEntreeState extends State<AddEntree> {
  final _formKey = GlobalKey<FormState>();
  final _numeroControleur = TextEditingController();
  final _quantiteControleur = TextEditingController();
  final _lotControleur = TextEditingController();
  final _peremptionControleur = TextEditingController();
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
    final maintenant = DateTime.now();
    _dateControleur.text = formaterDate(maintenant);
    _chargerMedicaments();
  }

  @override
  void dispose() {
    _numeroControleur.dispose();
    _quantiteControleur.dispose();
    _lotControleur.dispose();
    _peremptionControleur.dispose();
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

  Future<void> _choisirDate({
    required TextEditingController controleur,
    DateTime? initiale,
  }) async {
    final date = await showDatePicker(
      context: context,
      initialDate: initiale ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (date == null || !mounted) return;
    setState(() {
      controleur.text = formaterDate(date);
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
      final numeroLot = _lotControleur.text.trim();
      await _base.insertEntree(
        Entree(
          numEntr: _numeroControleur.text.trim(),
          numMed: _medicamentSelectionne!,
          stockEntr: Validators.versEntier(_quantiteControleur.text) ?? 0,
          dateEntr: versIso(_dateControleur.text) ?? _dateControleur.text.trim(),
          numeroLot: numeroLot.isEmpty ? null : numeroLot,
          datePeremption: versIso(_peremptionControleur.text),
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
      afficherMessage(
        context,
        "Échec de l'enregistrement : $erreur",
        erreur: true,
      );
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
                  controleur: _lotControleur,
                  label: 'Numéro de lot (facultatif)',
                  hint: 'Ex. : L2026-04',
                  icone: Icons.qr_code_2,
                ),
                const SizedBox(height: 16),
                ChampTexte(
                  controleur: _peremptionControleur,
                  label: 'Date de péremption',
                  icone: Icons.event_busy_outlined,
                  lectureSeule: true,
                  onTap: () => _choisirDate(
                    controleur: _peremptionControleur,
                    initiale: DateTime.now().add(const Duration(days: 365)),
                  ),
                  validateur: (valeur) => Validators.obligatoire(
                    valeur,
                    champ: 'La date de péremption',
                  ),
                ),
                const SizedBox(height: 16),
                ChampTexte(
                  controleur: _dateControleur,
                  label: "Date de réception",
                  icone: Icons.calendar_today_outlined,
                  lectureSeule: true,
                  onTap: () => _choisirDate(controleur: _dateControleur),
                  validateur: (valeur) => Validators.obligatoire(
                    valeur,
                    champ: 'La date de réception',
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Les ventes consommeront en priorité le lot dont la '
                  'péremption est la plus proche.',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
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
