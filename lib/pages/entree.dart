import 'package:flutter/material.dart';

import '../Models/entr.dart';
import '../SQLite/sqlite.dart';
import '../core/exceptions.dart';
import '../core/feedback.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../core/validators.dart';
import '../core/widgets/app_text_field.dart';
import '../core/widgets/confirm_dialog.dart';
import '../dialog/addEntree.dart';

/// Historique des entrées de stock.
///
/// Chaque entrée est une ligne distincte : modifier ou supprimer une entrée
/// ajuste le stock du médicament par différence (jamais par recalcul global).
class EntreePage extends StatefulWidget {
  const EntreePage({super.key});

  @override
  State<EntreePage> createState() => _EntreePageState();
}

class _EntreePageState extends State<EntreePage> {
  final DatabaseHelper _base = DatabaseHelper();
  final TextEditingController _rechercheControleur = TextEditingController();

  List<Entree> _entrees = <Entree>[];
  List<Entree> _entreesFiltrees = <Entree>[];
  List<String> _numerosMedicaments = <String>[];
  bool _chargement = true;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    _rechercheControleur.addListener(_filtrer);
    _charger();
  }

  @override
  void dispose() {
    _rechercheControleur.dispose();
    super.dispose();
  }

  Future<void> _charger() async {
    try {
      final entrees = await _base.getAllEntrees();
      final numeros = await _base.getAllMedNum();
      if (!mounted) return;
      setState(() {
        _entrees = entrees;
        _numerosMedicaments = numeros;
        _entreesFiltrees = _filtrerListe(entrees);
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

  List<Entree> _filtrerListe(List<Entree> entrees) {
    final recherche = _rechercheControleur.text.trim().toLowerCase();
    if (recherche.isEmpty) return entrees;
    return entrees
        .where(
          (entree) =>
              entree.numEntr.toLowerCase().contains(recherche) ||
              entree.numMed.toLowerCase().contains(recherche),
        )
        .toList();
  }

  void _filtrer() {
    setState(() {
      _entreesFiltrees = _filtrerListe(_entrees);
    });
  }

  Future<void> _ajouter() async {
    await Navigator.of(context).push(
      MaterialPageRoute<bool>(builder: (_) => const AddEntree()),
    );
    if (!mounted) return;
    await _charger();
  }

  Future<void> _modifier(Entree entree) async {
    final modifiee = await showDialog<Entree>(
      context: context,
      builder: (_) => _DialogueModificationEntree(
        entree: entree,
        numerosMedicaments: _numerosMedicaments,
      ),
    );
    if (modifiee == null || !mounted) return;

    try {
      await _base.updateEntree(modifiee);
      if (!mounted) return;
      afficherMessage(context, 'Entrée mise à jour.');
      await _charger();
    } on EntiteIntrouvableException catch (erreur) {
      if (!mounted) return;
      afficherMessage(context, erreur.toString(), erreur: true);
    } catch (erreur) {
      if (!mounted) return;
      afficherMessage(context, 'Mise à jour impossible : $erreur', erreur: true);
    }
  }

  Future<void> _supprimer(Entree entree) async {
    final confirme = await confirmerAction(
      context,
      titre: "Supprimer l'entrée",
      message:
          "Supprimer l'entrée ${entree.numEntr} ?\n"
          'Le stock du médicament sera diminué de ${entree.stockEntr} unité(s).',
      libelleConfirmer: 'Supprimer',
    );
    if (!confirme || !mounted) return;

    try {
      await _base.deleteEntree(entree.id!);
      if (!mounted) return;
      afficherMessage(context, 'Entrée supprimée.');
      await _charger();
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
                labelText: 'Rechercher (numéro ou médicament)',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          Expanded(child: _contenu()),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Nouvelle entrée',
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
                  _charger();
                },
                child: const Text('Réessayer'),
              ),
            ],
          ),
        ),
      );
    }

    if (_entreesFiltrees.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _entrees.isEmpty
                ? "Aucune entrée enregistrée.\nAppuyez sur + pour en créer une."
                : 'Aucun résultat pour cette recherche.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.gris),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _charger,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _entreesFiltrees.length,
        itemBuilder: (context, index) {
          final entree = _entreesFiltrees[index];
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
                'Entrée ${entree.numEntr}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '${entree.numMed} · +${entree.stockEntr} unité(s) · '
                  '${entree.dateEntr}',
                ),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  IconButton(
                    tooltip: 'Modifier',
                    icon: const Icon(Icons.edit_outlined, color: AppColors.bleu),
                    onPressed: () => _modifier(entree),
                  ),
                  IconButton(
                    tooltip: 'Supprimer',
                    icon: const Icon(Icons.delete_outline, color: AppColors.rouge),
                    onPressed: () => _supprimer(entree),
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

/// Dialogue de modification d'une entrée de stock.
class _DialogueModificationEntree extends StatefulWidget {
  const _DialogueModificationEntree({
    required this.entree,
    required this.numerosMedicaments,
  });

  final Entree entree;
  final List<String> numerosMedicaments;

  @override
  State<_DialogueModificationEntree> createState() =>
      _DialogueModificationEntreeState();
}

class _DialogueModificationEntreeState
    extends State<_DialogueModificationEntree> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _numeroControleur;
  late final TextEditingController _quantiteControleur;
  late final TextEditingController _dateControleur;
  late String? _medicamentSelectionne;
  late List<String> _numeros;

  @override
  void initState() {
    super.initState();
    _numeroControleur = TextEditingController(text: widget.entree.numEntr);
    _quantiteControleur =
        TextEditingController(text: widget.entree.stockEntr.toString());
    _dateControleur = TextEditingController(text: widget.entree.dateEntr);
    _numeros = List<String>.from(widget.numerosMedicaments);
    if (!_numeros.contains(widget.entree.numMed)) {
      _numeros.insert(0, widget.entree.numMed);
    }
    _medicamentSelectionne = widget.entree.numMed;
  }

  @override
  void dispose() {
    _numeroControleur.dispose();
    _quantiteControleur.dispose();
    _dateControleur.dispose();
    super.dispose();
  }

  Future<void> _choisirDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: analyserDate(_dateControleur.text) ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (date == null || !mounted) return;
    setState(() {
      _dateControleur.text = formaterDate(date);
    });
  }

  void _valider() {
    if (!_formKey.currentState!.validate()) return;
    if (_medicamentSelectionne == null) return;

    Navigator.of(context).pop(
      Entree(
        id: widget.entree.id,
        numEntr: _numeroControleur.text.trim(),
        numMed: _medicamentSelectionne!,
        stockEntr: Validators.versEntier(_quantiteControleur.text) ?? 0,
        dateEntr: _dateControleur.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Modifier l'entrée"),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ChampTexte(
                controleur: _numeroControleur,
                label: "Numéro d'entrée",
                icone: Icons.tag,
                validateur: (valeur) => Validators.obligatoire(
                  valeur,
                  champ: "Le numéro d'entrée",
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _medicamentSelectionne,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Médicament',
                  prefixIcon: Icon(Icons.medication_outlined),
                ),
                items: _numeros
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
              const SizedBox(height: 12),
              ChampTexte(
                controleur: _quantiteControleur,
                label: 'Quantité reçue',
                icone: Icons.inventory_2_outlined,
                clavier: TextInputType.number,
                formateurs: Saisies.chiffres,
                validateur: (valeur) =>
                    Validators.entier(valeur, champ: 'La quantité'),
              ),
              const SizedBox(height: 12),
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
