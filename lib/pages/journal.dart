import 'package:flutter/material.dart';

import '../Models/mouvement.dart';
import '../SQLite/sqlite.dart';
import '../core/exceptions.dart';
import '../core/format.dart';
import '../core/session.dart';
import '../core/theme.dart';

/// Journal des mouvements de stock : qui a fait quoi, et quand.
///
/// C'est la contrepartie des rôles : un gestionnaire peut corriger une vente ou
/// un prix, mais chaque entrée et chaque sortie laisse une trace avec le compte
/// à l'origine du mouvement. Sans cet écran, les colonnes `auteur` ne
/// serviraient à rien.
class JournalPage extends StatefulWidget {
  const JournalPage({super.key});

  @override
  State<JournalPage> createState() => _JournalPageState();
}

class _JournalPageState extends State<JournalPage> {
  static const int _limite = 300;

  static const List<String> _filtres = <String>['Tous', 'Entrées', 'Sorties'];

  final DatabaseHelper _base = DatabaseHelper();

  List<Mouvement> _mouvements = <Mouvement>[];
  bool _chargement = true;
  String? _erreur;
  int _filtre = 0;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    if (!Session.permissions.peutConsulterJournal) {
      _chargement = false;
      _erreur = 'Le journal est réservé au gestionnaire.';
      return;
    }

    try {
      final mouvements = await _base.listerMouvements(limite: _limite);
      if (!mounted) return;
      setState(() {
        _mouvements = mouvements;
        _chargement = false;
        _erreur = null;
      });
    } on OperationRefuseeException catch (erreur) {
      if (!mounted) return;
      setState(() {
        _chargement = false;
        _erreur = erreur.toString();
      });
    } on Exception catch (erreur) {
      if (!mounted) return;
      setState(() {
        _chargement = false;
        _erreur = 'Lecture impossible : $erreur';
      });
    }
  }

  List<Mouvement> get _visibles {
    if (_filtre == 1) {
      return _mouvements.where((m) => m.estEntree).toList();
    }
    if (_filtre == 2) {
      return _mouvements.where((m) => !m.estEntree).toList();
    }
    return _mouvements;
  }

  /// `AAAA-MM-JJ HH:MM:SS` → `JJ/MM/AAAA HH:MM`.
  String _horodatage(String? valeur) {
    final brut = (valeur ?? '').trim();
    if (brut.isEmpty) return 'date inconnue';
    final morceaux = brut.split(' ');
    final date = afficherDate(morceaux.first);
    if (morceaux.length < 2) return date;
    final heure = morceaux[1].split(':');
    if (heure.length < 2) return '$date ${morceaux[1]}';
    return '$date ${heure[0]}:${heure[1]}';
  }

  Widget _carte(Mouvement mouvement) {
    final entree = mouvement.estEntree;
    final couleur = entree ? AppColors.vert : AppColors.orange;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: entree ? AppColors.vertSurface : AppColors.rougeSurface,
          child: Icon(
            entree ? Icons.arrow_downward : Icons.arrow_upward,
            color: couleur,
            size: 20,
          ),
        ),
        title: Text(
          '${mouvement.designMed ?? mouvement.numMed} · '
          '${entree ? '+' : '−'}${mouvement.quantiteAffichee}',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                '${mouvement.libelleType} · ${mouvement.referenceAffichee} · '
                '${_horodatage(mouvement.dateMouvement)}',
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 2),
              Row(
                children: <Widget>[
                  const Icon(
                    Icons.person_outline,
                    size: 13,
                    color: AppColors.gris,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      mouvement.auteurAffiche,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.gris,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        isThreeLine: true,
      ),
    );
  }

  Widget _vide() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.history, size: 40, color: AppColors.gris),
            const SizedBox(height: 12),
            Text(
              _filtre == 0
                  ? 'Aucun mouvement enregistré pour le moment.'
                  : 'Aucun mouvement de ce type.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.gris),
            ),
          ],
        ),
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
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () {
                  setState(() {
                    _chargement = true;
                    _erreur = null;
                  });
                  _charger();
                },
                child: const Text('Réessayer'),
              ),
            ],
          ),
        ),
      );
    }

    final visibles = _visibles;
    if (visibles.isEmpty) return _vide();

    return RefreshIndicator(
      onRefresh: _charger,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 16),
        children: <Widget>[
          ...visibles.map(_carte),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Text(
              _mouvements.length >= _limite
                  ? 'Les $_limite mouvements les plus récents. '
                      'Le détail complet reste dans la base et les sauvegardes.'
                  : '${_mouvements.length} mouvement(s) enregistré(s). '
                      'Chaque ligne indique le compte qui l\'a provoquée.',
              style: const TextStyle(fontSize: 12, color: AppColors.gris),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Journal'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                for (var i = 0; i < _filtres.length; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ChoiceChip(
                      label: Text(_filtres[i]),
                      selected: _filtre == i,
                      onSelected: (_) => setState(() => _filtre = i),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      body: _contenu(),
    );
  }
}
