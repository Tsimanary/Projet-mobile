import 'package:flutter/material.dart';

import '../Models/acht.dart';
import '../SQLite/sqlite.dart';
import '../core/exceptions.dart';
import '../core/feedback.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../core/session.dart';
import '../core/validators.dart';
import '../core/widgets/app_text_field.dart';
import '../core/widgets/confirm_dialog.dart';
import '../dialog/addAchat.dart';

/// Historique des ventes.
class AchatPage extends StatefulWidget {
  const AchatPage({super.key});

  @override
  State<AchatPage> createState() => _AchatPageState();
}

class _AchatPageState extends State<AchatPage> {
  final DatabaseHelper _base = DatabaseHelper();
  final TextEditingController _rechercheControleur = TextEditingController();

  List<Achat> _achats = <Achat>[];
  List<Achat> _achatsFiltres = <Achat>[];
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
      final achats = await _base.getAllAchats();
      final numeros = await _base.getAllMedNum();
      if (!mounted) return;
      setState(() {
        _achats = achats;
        _numerosMedicaments = numeros;
        _achatsFiltres = _filtrerListe(achats);
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

  List<Achat> _filtrerListe(List<Achat> achats) {
    final recherche = _rechercheControleur.text.trim().toLowerCase();
    if (recherche.isEmpty) return achats;
    return achats
        .where(
          (achat) =>
              achat.numAchat.toLowerCase().contains(recherche) ||
              achat.numMed.toLowerCase().contains(recherche) ||
              achat.nomClient.toLowerCase().contains(recherche),
        )
        .toList();
  }

  void _filtrer() {
    setState(() {
      _achatsFiltres = _filtrerListe(_achats);
    });
  }

  Future<void> _ajouter() async {
    await Navigator.of(context).push(
      MaterialPageRoute<bool>(builder: (_) => const AddAchat()),
    );
    if (!mounted) return;
    await _charger();
  }

  Future<void> _modifier(Achat achat) async {
    final modifie = await showDialog<Achat>(
      context: context,
      builder: (_) => _DialogueModificationAchat(
        achat: achat,
        numerosMedicaments: _numerosMedicaments,
      ),
    );
    if (modifie == null || !mounted) return;

    try {
      await _base.updateAchat(modifie);
      if (!mounted) return;
      afficherMessage(context, 'Vente mise à jour.');
      await _charger();
    } on StockInsuffisantException catch (erreur) {
      if (!mounted) return;
      afficherMessage(context, erreur.toString(), erreur: true);
    } on EntiteIntrouvableException catch (erreur) {
      if (!mounted) return;
      afficherMessage(context, erreur.toString(), erreur: true);
    } catch (erreur) {
      if (!mounted) return;
      afficherMessage(context, 'Mise à jour impossible : $erreur', erreur: true);
    }
  }

  Future<void> _supprimer(Achat achat) async {
    final confirme = await confirmerAction(
      context,
      titre: 'Supprimer la vente',
      message:
          'Supprimer la ligne de la vente ${achat.numAchat} '
          '(${achat.numMed} × ${achat.nbr}) ?\n'
          'Le stock sera recrédité de ${achat.nbr} unité(s).',
      libelleConfirmer: 'Supprimer',
    );
    if (!confirme || !mounted) return;

    try {
      await _base.deleteAchat(achat.id!);
      if (!mounted) return;
      afficherMessage(context, 'Vente supprimée, stock recrédité.');
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
                labelText: 'Rechercher (n° vente, médicament, client)',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          Expanded(child: _contenu()),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Nouvelle vente',
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

    if (_achatsFiltres.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _achats.isEmpty
                ? "Aucune vente enregistrée.\nAppuyez sur + pour en créer une."
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
        itemCount: _achatsFiltres.length,
        itemBuilder: (context, index) {
          final achat = _achatsFiltres[index];
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
                'Vente ${achat.numAchat}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '${achat.numMed} × ${achat.nbr} · ${achat.nomClient} · '
                  '${afficherDate(achat.dateAchat)}',
                ),
              ),
              // Le vendeur encaisse ; corriger ou supprimer reste un acte de
              // gestion, tracé et réservé au gestionnaire.
              trailing: Session.permissions.peutSupprimerVente
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        IconButton(
                          tooltip: 'Modifier',
                          icon: const Icon(
                            Icons.edit_outlined,
                            color: AppColors.bleu,
                          ),
                          onPressed: () => _modifier(achat),
                        ),
                        IconButton(
                          tooltip: 'Supprimer',
                          icon: const Icon(
                            Icons.delete_outline,
                            color: AppColors.rouge,
                          ),
                          onPressed: () => _supprimer(achat),
                        ),
                      ],
                    )
                  : null,
            ),
          );
        },
      ),
    );
  }
}

/// Dialogue de modification d'une ligne de vente.
class _DialogueModificationAchat extends StatefulWidget {
  const _DialogueModificationAchat({
    required this.achat,
    required this.numerosMedicaments,
  });

  final Achat achat;
  final List<String> numerosMedicaments;

  @override
  State<_DialogueModificationAchat> createState() =>
      _DialogueModificationAchatState();
}

class _DialogueModificationAchatState extends State<_DialogueModificationAchat> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _numeroControleur;
  late final TextEditingController _clientControleur;
  late final TextEditingController _quantiteControleur;
  late final TextEditingController _dateControleur;
  late String? _medicamentSelectionne;
  late List<String> _numeros;

  @override
  void initState() {
    super.initState();
    _numeroControleur = TextEditingController(text: widget.achat.numAchat);
    _clientControleur = TextEditingController(text: widget.achat.nomClient);
    _quantiteControleur =
        TextEditingController(text: widget.achat.nbr.toString());
    _dateControleur =
        TextEditingController(text: afficherDate(widget.achat.dateAchat));
    _numeros = List<String>.from(widget.numerosMedicaments);
    if (!_numeros.contains(widget.achat.numMed)) {
      _numeros.insert(0, widget.achat.numMed);
    }
    _medicamentSelectionne = widget.achat.numMed;
  }

  @override
  void dispose() {
    _numeroControleur.dispose();
    _clientControleur.dispose();
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

    final medicamentChange = _medicamentSelectionne != widget.achat.numMed;

    Navigator.of(context).pop(
      Achat(
        id: widget.achat.id,
        numAchat: _numeroControleur.text.trim(),
        numMed: _medicamentSelectionne!,
        nomClient: _clientControleur.text.trim(),
        dateAchat: versIso(_dateControleur.text) ?? _dateControleur.text.trim(),
        nbr: Validators.versEntier(_quantiteControleur.text) ?? 0,
        // Le prix figé n'est conservé que si le médicament ne change pas.
        prixUnitaire:
            medicamentChange ? null : widget.achat.prixUnitaire,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Modifier la vente'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ChampTexte(
                controleur: _numeroControleur,
                label: 'Numéro de vente',
                icone: Icons.receipt_long_outlined,
                validateur: (valeur) => Validators.obligatoire(
                  valeur,
                  champ: 'Le numéro de vente',
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
                controleur: _clientControleur,
                label: 'Nom du client',
                icone: Icons.person_outline,
                textCapitalization: TextCapitalization.words,
                validateur: (valeur) => Validators.obligatoire(
                  valeur,
                  champ: 'Le nom du client',
                ),
              ),
              const SizedBox(height: 12),
              ChampTexte(
                controleur: _quantiteControleur,
                label: 'Quantité vendue',
                icone: Icons.numbers,
                clavier: TextInputType.number,
                formateurs: Saisies.chiffres,
                validateur: (valeur) =>
                    Validators.entier(valeur, champ: 'La quantité'),
              ),
              const SizedBox(height: 12),
              ChampTexte(
                controleur: _dateControleur,
                label: 'Date de vente',
                icone: Icons.calendar_today_outlined,
                lectureSeule: true,
                onTap: _choisirDate,
                validateur: (valeur) => Validators.obligatoire(
                  valeur,
                  champ: 'La date de vente',
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
