import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';

import '../Models/acht.dart';
import '../Models/medic.dart';
import '../SQLite/sqlite.dart';
import '../core/exceptions.dart';
import '../core/feedback.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../core/validators.dart';
import '../core/widgets/app_text_field.dart';
import '../pages/pdf_utils.dart';

/// Saisie d'une vente multi-lignes.
///
/// La vente est enregistrée en **une seule transaction** : soit toutes les
/// lignes passent, soit aucune. La facture est construite à partir des
/// lignes réellement enregistrées.
class AddAchat extends StatefulWidget {
  const AddAchat({super.key});

  @override
  State<AddAchat> createState() => _AddAchatState();
}

class _AddAchatState extends State<AddAchat> {
  final _formKey = GlobalKey<FormState>();
  final _numeroControleur = TextEditingController();
  final _clientControleur = TextEditingController();
  final _dateControleur = TextEditingController();
  final _rechercheControleur = TextEditingController();
  final DatabaseHelper _base = DatabaseHelper();

  final Map<String, TextEditingController> _quantites =
      <String, TextEditingController>{};

  List<Medic> _medicaments = <Medic>[];
  List<Medic> _medicamentsFiltres = <Medic>[];
  bool _chargement = true;
  bool _enregistrementEnCours = false;
  String? _erreurChargement;
  int _total = 0;

  @override
  void initState() {
    super.initState();
    final maintenant = DateTime.now();
    _numeroControleur.text =
        'V-${DateFormat('yyyyMMdd').format(maintenant)}-${DateFormat('HHmmss').format(maintenant)}';
    _dateControleur.text = DateFormat('dd/MM/yyyy').format(maintenant);
    _rechercheControleur.addListener(_filtrer);
    _chargerMedicaments();
  }

  @override
  void dispose() {
    _numeroControleur.dispose();
    _clientControleur.dispose();
    _dateControleur.dispose();
    _rechercheControleur.dispose();
    for (final controleur in _quantites.values) {
      controleur.dispose();
    }
    super.dispose();
  }

  Future<void> _chargerMedicaments() async {
    try {
      final medicaments = await _base.getAllMedics();
      if (!mounted) return;
      setState(() {
        _medicaments = medicaments;
        _medicamentsFiltres = medicaments;
        for (final medicament in medicaments) {
          _quantites.putIfAbsent(
            medicament.numMed,
            () => TextEditingController(),
          );
        }
        _chargement = false;
      });
      _recalculerTotal();
    } catch (erreur) {
      if (!mounted) return;
      setState(() {
        _erreurChargement = 'Chargement impossible : $erreur';
        _chargement = false;
      });
    }
  }

  void _filtrer() {
    final recherche = _rechercheControleur.text.trim().toLowerCase();
    setState(() {
      _medicamentsFiltres = recherche.isEmpty
          ? _medicaments
          : _medicaments
              .where(
                (medicament) =>
                    medicament.designMed.toLowerCase().contains(recherche) ||
                    medicament.numMed.toLowerCase().contains(recherche),
              )
              .toList();
    });
  }

  int _quantiteDe(Medic medicament) =>
      Validators.versEntier(_quantites[medicament.numMed]?.text) ?? 0;

  void _recalculerTotal() {
    var total = 0;
    for (final medicament in _medicaments) {
      final quantite = _quantiteDe(medicament);
      if (quantite > 0) {
        total += medicament.prixMed * quantite;
      }
    }
    if (!mounted) return;
    setState(() => _total = total);
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
    FocusScope.of(context).unfocus();

    final lignes = <Achat>[];
    final erreursStock = <String>[];

    for (final medicament in _medicaments) {
      final quantite = _quantiteDe(medicament);
      if (quantite <= 0) continue;

      if (quantite > medicament.stockMed) {
        erreursStock.add(
          '${medicament.designMed} (stock : ${medicament.stockMed})',
        );
      }

      lignes.add(
        Achat(
          numAchat: _numeroControleur.text.trim(),
          numMed: medicament.numMed,
          nomClient: _clientControleur.text.trim(),
          dateAchat: _dateControleur.text.trim(),
          nbr: quantite,
          prixUnitaire: medicament.prixMed,
        ),
      );
    }

    if (lignes.isEmpty) {
      afficherMessage(
        context,
        'Saisissez au moins une quantité.',
        erreur: true,
      );
      return;
    }

    if (erreursStock.isNotEmpty) {
      afficherMessage(
        context,
        'Stock insuffisant : ${erreursStock.join(', ')}.',
        erreur: true,
      );
      return;
    }

    setState(() => _enregistrementEnCours = true);

    try {
      await _base.insertAchats(lignes);
      if (!mounted) return;

      setState(() => _enregistrementEnCours = false);
      afficherMessage(
        context,
        'Vente enregistrée : ${formaterMontant(_total)}.',
      );

      await _imprimerFacture(lignes);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on StockInsuffisantException catch (erreur) {
      if (!mounted) return;
      setState(() => _enregistrementEnCours = false);
      afficherMessage(context, erreur.toString(), erreur: true);
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

  Future<void> _imprimerFacture(List<Achat> lignes) async {
    final designations = <String, String>{
      for (final medicament in _medicaments)
        medicament.numMed: medicament.designMed,
    };

    final lignesFacture = lignes
        .map(
          (ligne) => LigneFacture(
            designation: designations[ligne.numMed] ?? ligne.numMed,
            numMed: ligne.numMed,
            quantite: ligne.nbr,
            prixUnitaire: ligne.prixUnitaire ?? 0,
          ),
        )
        .toList();

    final total = lignesFacture.fold<int>(
      0,
      (somme, ligne) => somme + ligne.montant,
    );

    try {
      final document = generateInvoicePdf(
        numAchat: _numeroControleur.text.trim(),
        nomClient: _clientControleur.text.trim(),
        dateAchat: _dateControleur.text.trim(),
        lignes: lignesFacture,
        total: total,
      );
      await Printing.layoutPdf(
        onLayout: (format) async => document.save(),
      );
    } catch (_) {
      // L'impression est optionnelle : un échec ne doit jamais annuler
      // une vente déjà enregistrée.
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_chargement) {
      return Scaffold(
        appBar: AppBar(title: const Text('Nouvelle vente')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_erreurChargement != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Nouvelle vente')),
        body: Center(child: Text(_erreurChargement!, textAlign: TextAlign.center)),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Nouvelle vente')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: Column(
            children: <Widget>[
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
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
                    const SizedBox(height: 16),
                    ChampTexte(
                      controleur: _rechercheControleur,
                      label: 'Rechercher un médicament',
                      icone: Icons.search,
                    ),
                    const SizedBox(height: 16),
                    if (_medicamentsFiltres.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Text(
                          'Aucun médicament ne correspond à la recherche.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.gris),
                        ),
                      )
                    else
                      for (final medicament in _medicamentsFiltres)
                        _ligneMedicament(medicament),
                  ],
                ),
              ),
              _piedDePage(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _ligneMedicament(Medic medicament) {
    final rupture = medicament.stockMed <= 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE0E6E0)),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  medicament.designMed,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  '${medicament.numMed} · ${formaterMontant(medicament.prixMed)}',
                  style: const TextStyle(fontSize: 12, color: AppColors.gris),
                ),
                Text(
                  rupture
                      ? 'Rupture de stock'
                      : 'Stock : ${medicament.stockMed}',
                  style: TextStyle(
                    fontSize: 12,
                    color: rupture ? AppColors.rouge : AppColors.vert,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 92,
            child: ChampTexte(
              controleur: _quantites[medicament.numMed]!,
              label: 'Qté',
              clavier: TextInputType.number,
              formateurs: Saisies.chiffres,
              onChanged: (_) => _recalculerTotal(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _piedDePage() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE0E6E0))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              const Text(
                'Total',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Text(
                formaterMontant(_total),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.vertFonce,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _enregistrementEnCours
                      ? null
                      : () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                  label: const Text('Annuler'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _enregistrementEnCours ? null : _enregistrer,
                  icon: const Icon(Icons.save_alt),
                  label: Text(
                    _enregistrementEnCours ? 'Enregistrement…' : 'Enregistrer',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
