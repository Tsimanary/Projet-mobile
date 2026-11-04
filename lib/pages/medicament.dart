import 'package:flutter/material.dart';

import '../Models/medic.dart';
import '../SQLite/sqlite.dart';
import '../core/exceptions.dart';
import '../core/feedback.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../core/validators.dart';
import '../core/widgets/app_text_field.dart';
import '../core/widgets/confirm_dialog.dart';
import '../dialog/addMed.dart';

/// Liste des médicaments : recherche, modification, suppression.
class MedicamentPage extends StatefulWidget {
  const MedicamentPage({super.key});

  @override
  State<MedicamentPage> createState() => _MedicamentPageState();
}

class _MedicamentPageState extends State<MedicamentPage> {
  final DatabaseHelper _base = DatabaseHelper();
  final TextEditingController _rechercheControleur = TextEditingController();

  List<Medic> _medicaments = <Medic>[];
  List<Medic> _medicamentsFiltres = <Medic>[];
  bool _chargement = true;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    _rechercheControleur.addListener(_filtrer);
    _chargerMedicaments();
  }

  @override
  void dispose() {
    _rechercheControleur.dispose();
    super.dispose();
  }

  Future<void> _chargerMedicaments() async {
    try {
      final medicaments = await _base.getAllMedics();
      if (!mounted) return;
      setState(() {
        _medicaments = medicaments;
        _medicamentsFiltres = _filtrerListe(medicaments);
        _chargement = false;
        _erreur = null;
      });
    } catch (erreur) {
      if (!mounted) return;
      setState(() {
        _erreur = 'Chargement impossible : $erreur';
        _chargement = false;
      });
    }
  }

  List<Medic> _filtrerListe(List<Medic> medicaments) {
    final recherche = _rechercheControleur.text.trim().toLowerCase();
    if (recherche.isEmpty) return medicaments;
    return medicaments
        .where(
          (medicament) =>
              medicament.designMed.toLowerCase().contains(recherche) ||
              medicament.numMed.toLowerCase().contains(recherche),
        )
        .toList();
  }

  void _filtrer() {
    setState(() {
      _medicamentsFiltres = _filtrerListe(_medicaments);
    });
  }

  Future<void> _ajouter() async {
    await Navigator.of(context).push(
      MaterialPageRoute<bool>(builder: (_) => const AddMed()),
    );
    if (!mounted) return;
    await _chargerMedicaments();
  }

  Future<void> _modifier(Medic medicament) async {
    final modifie = await showDialog<Medic>(
      context: context,
      builder: (_) => _DialogueModificationMedicament(medicament: medicament),
    );
    if (modifie == null || !mounted) return;

    try {
      await _base.updateMedic(modifie);
      if (!mounted) return;
      afficherMessage(context, 'Médicament mis à jour.');
      await _chargerMedicaments();
    } on MedicamentDejaExisteException catch (erreur) {
      if (!mounted) return;
      afficherMessage(context, erreur.toString(), erreur: true);
    } on OperationRefuseeException catch (erreur) {
      if (!mounted) return;
      afficherMessage(context, erreur.toString(), erreur: true);
    } catch (erreur) {
      if (!mounted) return;
      afficherMessage(context, 'Mise à jour impossible : $erreur', erreur: true);
    }
  }

  Future<void> _supprimer(Medic medicament) async {
    final confirme = await confirmerAction(
      context,
      titre: 'Supprimer le médicament',
      message:
          'Voulez-vous vraiment supprimer « ${medicament.designMed} » ?\n\n'
          'Cette action est définitive.',
      libelleConfirmer: 'Supprimer',
    );
    if (!confirme || !mounted) return;

    try {
      await _base.deleteMedic(medicament.id!);
      if (!mounted) return;
      afficherMessage(context, 'Médicament supprimé.');
      await _chargerMedicaments();
    } on MedicamentUtiliseException catch (erreur) {
      if (!mounted) return;
      afficherMessage(context, erreur.toString(), erreur: true);
    } catch (erreur) {
      if (!mounted) return;
      afficherMessage(context, 'Suppression impossible : $erreur', erreur: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _rechercheControleur,
              decoration: const InputDecoration(
                labelText: 'Rechercher (désignation ou numéro)',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          Expanded(child: _contenu()),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Ajouter un médicament',
        onPressed: _ajouter,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _contenu() {
    if (_chargement) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_erreur != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(_erreur!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () {
                  setState(() => _chargement = true);
                  _chargerMedicaments();
                },
                child: const Text('Réessayer'),
              ),
            ],
          ),
        ),
      );
    }

    if (_medicamentsFiltres.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _medicaments.isEmpty
                ? 'Aucun médicament enregistré.\nAppuyez sur + pour commencer.'
                : 'Aucun résultat pour cette recherche.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.gris),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _chargerMedicaments,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _medicamentsFiltres.length,
        itemBuilder: (context, index) {
          final medicament = _medicamentsFiltres[index];
          return Card(
            elevation: 0,
            margin: const EdgeInsets.only(bottom: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Color(0xFFE0E6E0)),
            ),
            child: ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              title: Text(
                medicament.designMed,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '${medicament.numMed} · ${formaterMontant(medicament.prixMed)} · '
                  'stock ${medicament.stockMed}',
                ),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  IconButton(
                    tooltip: 'Modifier',
                    icon: const Icon(Icons.edit_outlined, color: AppColors.bleu),
                    onPressed: () => _modifier(medicament),
                  ),
                  IconButton(
                    tooltip: 'Supprimer',
                    icon: const Icon(Icons.delete_outline, color: AppColors.rouge),
                    onPressed: () => _supprimer(medicament),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Dialogue de modification d'un médicament.
///
/// Retourne le médicament modifié (non enregistré) au parent, qui se charge
/// de la persistance et de l'affichage des erreurs.
class _DialogueModificationMedicament extends StatefulWidget {
  const _DialogueModificationMedicament({required this.medicament});

  final Medic medicament;

  @override
  State<_DialogueModificationMedicament> createState() =>
      _DialogueModificationMedicamentState();
}

class _DialogueModificationMedicamentState
    extends State<_DialogueModificationMedicament> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _numeroControleur;
  late final TextEditingController _designationControleur;
  late final TextEditingController _prixControleur;

  @override
  void initState() {
    super.initState();
    _numeroControleur =
        TextEditingController(text: widget.medicament.numMed);
    _designationControleur =
        TextEditingController(text: widget.medicament.designMed);
    _prixControleur =
        TextEditingController(text: widget.medicament.prixMed.toString());
  }

  @override
  void dispose() {
    _numeroControleur.dispose();
    _designationControleur.dispose();
    _prixControleur.dispose();
    super.dispose();
  }

  void _valider() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(
      Medic(
        id: widget.medicament.id,
        numMed: _numeroControleur.text.trim(),
        designMed: _designationControleur.text.trim(),
        prixMed: Validators.versEntier(_prixControleur.text) ?? 0,
        stockMed: widget.medicament.stockMed,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Modifier le médicament'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ChampTexte(
                controleur: _numeroControleur,
                label: 'Numéro',
                icone: Icons.tag,
                validateur: (valeur) =>
                    Validators.obligatoire(valeur, champ: 'Le numéro'),
              ),
              const SizedBox(height: 12),
              ChampTexte(
                controleur: _designationControleur,
                label: 'Désignation',
                icone: Icons.medication_outlined,
                textCapitalization: TextCapitalization.sentences,
                validateur: (valeur) =>
                    Validators.obligatoire(valeur, champ: 'La désignation'),
              ),
              const SizedBox(height: 12),
              ChampTexte(
                controleur: _prixControleur,
                label: 'Prix unitaire (Ar)',
                icone: Icons.payments_outlined,
                clavier: TextInputType.number,
                formateurs: Saisies.chiffres,
                validateur: Validators.prix,
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Stock actuel : ${widget.medicament.stockMed} '
                  '(modifiable uniquement par les entrées et les ventes).',
                  style: const TextStyle(fontSize: 12, color: AppColors.gris),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: _valider,
          child: const Text('Enregistrer'),
        ),
      ],
    );
  }
}
