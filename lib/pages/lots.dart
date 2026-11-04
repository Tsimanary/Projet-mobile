import 'package:flutter/material.dart';

import '../Models/lot.dart';
import '../SQLite/sqlite.dart';
import '../core/format.dart';
import '../core/theme.dart';

/// Suivi des lots et des péremptions.
///
/// Les lots sont triés en FEFO par la base : le premier de la liste est celui
/// qui doit sortir en premier.
class LotsPage extends StatefulWidget {
  const LotsPage({super.key});

  @override
  State<LotsPage> createState() => _LotsPageState();
}

class _FiltreLots {
  const _FiltreLots({required this.libelle, required this.jours});

  final String libelle;

  /// `null` = tous, `-1` = uniquement les périmés, sinon seuil en jours.
  final int? jours;
}

class _LotsPageState extends State<LotsPage> {
  static const List<_FiltreLots> _filtres = <_FiltreLots>[
    _FiltreLots(libelle: 'Tous', jours: null),
    _FiltreLots(libelle: '≤ 90 j', jours: 90),
    _FiltreLots(libelle: '≤ 30 j', jours: 30),
    _FiltreLots(libelle: 'Périmés', jours: -1),
  ];

  final DatabaseHelper _base = DatabaseHelper();

  List<Lot> _lots = <Lot>[];
  bool _chargement = true;
  String? _erreur;
  int _filtreSelectionne = 0;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    try {
      final lots = await _base.getAllLots();
      if (!mounted) return;
      setState(() {
        _lots = lots;
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

  List<Lot> get _lotsAffiches {
    final filtre = _filtres[_filtreSelectionne];
    if (filtre.jours == null) return _lots;
    if (filtre.jours == -1) {
      return _lots.where((lot) => lot.estPerime()).toList();
    }
    return _lots
        .where(
          (lot) {
            final restants = lot.joursRestants();
            return restants != null &&
                restants >= 0 &&
                restants <= filtre.jours!;
          },
        )
        .toList();
  }

  int get _nombrePerimes => _lots.where((lot) => lot.estPerime()).length;

  int get _nombreBientotPerimes =>
      _lots.where((lot) => lot.perimeBientot(jours: 90)).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: <Widget>[
          _entete(),
          Expanded(child: _contenu()),
        ],
      ),
    );
  }

  Widget _entete() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              _compteur(
                valeur: _nombrePerimes,
                libelle: 'périmé(s)',
                couleur: AppColors.rouge,
              ),
              const SizedBox(width: 12),
              _compteur(
                valeur: _nombreBientotPerimes,
                libelle: 'à surveiller (90 j)',
                couleur: AppColors.orange,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: <Widget>[
              for (var i = 0; i < _filtres.length; i++)
                ChoiceChip(
                  label: Text(_filtres[i].libelle),
                  selected: _filtreSelectionne == i,
                  onSelected: (_) => setState(() => _filtreSelectionne = i),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _compteur({
    required int valeur,
    required String libelle,
    required Color couleur,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: couleur.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$valeur $libelle',
        style: TextStyle(color: couleur, fontWeight: FontWeight.w600),
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

    final lots = _lotsAffiches;
    if (lots.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _lots.isEmpty
                ? "Aucun lot en stock. Enregistrez une entrée pour en créer un."
                : 'Aucun lot pour ce filtre.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.gris),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _charger,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: lots.length,
        itemBuilder: (context, index) {
          final lot = lots[index];
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
                lot.designMed ?? lot.numMed,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('${lot.numMed} · ${lot.libelle}'),
                    Text(
                      'Reste ${lot.quantiteRestante} · '
                      'pér. ${afficherDate(lot.datePeremption)}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
              trailing: _badge(lot),
            ),
          );
        },
      ),
    );
  }

  Widget _badge(Lot lot) {
    final restants = lot.joursRestants();
    Color couleur;
    String texte;

    if (restants == null) {
      couleur = AppColors.gris;
      texte = 'pér. n/c';
    } else if (restants < 0) {
      couleur = AppColors.rouge;
      texte = 'Périmé';
    } else if (restants <= 30) {
      couleur = AppColors.rouge;
      texte = 'J-$restants';
    } else if (restants <= 90) {
      couleur = AppColors.orange;
      texte = 'J-$restants';
    } else {
      couleur = AppColors.vert;
      texte = 'J-$restants';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: couleur.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        texte,
        style: TextStyle(
          color: couleur,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
