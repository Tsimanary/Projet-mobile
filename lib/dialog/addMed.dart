import 'package:flutter/material.dart';

import '../Models/medic.dart';
import '../SQLite/sqlite.dart';
import '../core/exceptions.dart';
import '../core/feedback.dart';
import '../core/validators.dart';
import '../core/widgets/app_text_field.dart';

/// Formulaire d'ajout d'un médicament.
class AddMed extends StatefulWidget {
  const AddMed({super.key});

  @override
  State<AddMed> createState() => _AddMedState();
}

class _AddMedState extends State<AddMed> {
  final _formKey = GlobalKey<FormState>();
  final _numeroControleur = TextEditingController();
  final _designationControleur = TextEditingController();
  final _prixControleur = TextEditingController();
  final DatabaseHelper _base = DatabaseHelper();

  bool _enregistrementEnCours = false;

  @override
  void dispose() {
    _numeroControleur.dispose();
    _designationControleur.dispose();
    _prixControleur.dispose();
    super.dispose();
  }

  Future<void> _enregistrer() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _enregistrementEnCours = true);

    try {
      await _base.insertMedic(
        Medic(
          numMed: _numeroControleur.text.trim(),
          designMed: _designationControleur.text.trim(),
          prixMed: Validators.versEntier(_prixControleur.text) ?? 0,
          stockMed: 0,
        ),
      );

      if (!mounted) return;
      afficherMessage(context, 'Médicament ajouté avec succès.');
      Navigator.of(context).pop(true);
    } on MedicamentDejaExisteException catch (erreur) {
      if (!mounted) return;
      setState(() => _enregistrementEnCours = false);
      afficherMessage(context, erreur.toString(), erreur: true);
    } catch (erreur) {
      if (!mounted) return;
      setState(() => _enregistrementEnCours = false);
      afficherMessage(context, "Échec de l'ajout : $erreur", erreur: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ajouter un médicament')),
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
                  label: 'Numéro du médicament',
                  hint: 'Ex. : MED-001',
                  icone: Icons.tag,
                  validateur: (valeur)
                      => Validators.obligatoire(valeur, champ: 'Le numéro'),
                ),
                const SizedBox(height: 16),
                ChampTexte(
                  controleur: _designationControleur,
                  label: 'Désignation',
                  hint: 'Ex. : Paracétamol 500 mg',
                  icone: Icons.medication_outlined,
                  textCapitalization: TextCapitalization.sentences,
                  validateur: (valeur) => Validators.obligatoire(
                    valeur,
                    champ: 'La désignation',
                  ),
                ),
                const SizedBox(height: 16),
                ChampTexte(
                  controleur: _prixControleur,
                  label: 'Prix unitaire (Ar)',
                  icone: Icons.payments_outlined,
                  clavier: TextInputType.number,
                  formateurs: Saisies.chiffres,
                  validateur: Validators.prix,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Le stock initial est à 0 : il augmente uniquement via les entrées.',
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
