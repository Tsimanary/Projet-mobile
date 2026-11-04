import 'package:flutter/material.dart';

import '../Models/lot.dart';
import '../Models/medic.dart';
import '../SQLite/sqlite.dart';
import '../core/format.dart';
import '../core/theme.dart';

/// Tableau de bord : alertes de stock, meilleures ventes, recette cumulée.
class AccueilPage extends StatefulWidget {
  const AccueilPage({super.key});

  @override
  State<AccueilPage> createState() => _AccueilPageState();
}

class _VenteAgregee {
  const _VenteAgregee({required this.designation, required this.quantite});

  final String designation;
  final int quantite;
}

class _AccueilPageState extends State<AccueilPage> {
  static const int seuilStockFaible = 5;

  final DatabaseHelper _base = DatabaseHelper();

  bool _chargement = true;
  String? _erreur;
  int _recetteTotale = 0;
  int _nombreVentes = 0;
  List<Medic> _ruptures = <Medic>[];
  List<Medic> _stockFaible = <Medic>[];
  List<_VenteAgregee> _meilleuresVentes = <_VenteAgregee>[];
  List<Lot> _lotsEnAlerte = <Lot>[];

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    if (mounted) {
      setState(() {
        _chargement = true;
        _erreur = null;
      });
    }

    try {
      final medics = await _base.getAllMedics();
      final ventesParMedicament = await _base.ventesParMedicament();
      final recette = await _base.chiffreAffairesTotal();
      final lotsEnAlerte = await _base.getLotsEnAlerte(jours: 90);

      final medicsParNumero = <String, Medic>{
        for (final medic in medics) medic.numMed: medic,
      };

      final ruptures = medics
          .where((medic) => medic.stockMed <= 0)
          .toList(growable: false);
      final stockFaible = medics
          .where((medic) =>
              medic.stockMed > 0 && medic.stockMed <= seuilStockFaible)
          .toList(growable: false);

      // Les ventes orphelines (médicament supprimé) sont simplement ignorées :
      // plus aucun `firstWhere` ne peut faire planter l'écran.
      final ventes = ventesParMedicament.entries
          .where((entree) => medicsParNumero.containsKey(entree.key))
          .map((entree) => _VenteAgregee(
                designation: medicsParNumero[entree.key]!.designMed,
                quantite: entree.value,
              ))
          .toList()
        ..sort((a, b) => b.quantite.compareTo(a.quantite));

      if (!mounted) return;
      setState(() {
        _recetteTotale = recette;
        _nombreVentes = ventesParMedicament.values
            .fold<int>(0, (total, quantite) => total + quantite);
        _ruptures = ruptures;
        _stockFaible = stockFaible;
        _meilleuresVentes = ventes.take(5).toList(growable: false);
        _lotsEnAlerte = lotsEnAlerte;
        _chargement = false;
      });
    } catch (erreur) {
      if (!mounted) return;
      setState(() {
        _erreur = 'Impossible de charger le tableau de bord : $erreur';
        _chargement = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
              const Icon(Icons.error_outline, color: AppColors.rouge, size: 48),
              const SizedBox(height: 12),
              Text(_erreur!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _charger,
                child: const Text('Réessayer'),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _charger,
      child: ListView(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        children: <Widget>[
          _carte(
            titre: 'Recette totale',
            icone: Icons.account_balance_wallet_outlined,
            contenu: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  formaterMontant(_recetteTotale),
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: AppColors.vertFonce,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$_nombreVentes unité(s) vendue(s) au total',
                  style: const TextStyle(color: AppColors.gris),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _carte(
            titre: 'Rupture de stock',
            icone: Icons.remove_shopping_cart_outlined,
            couleurIcone: AppColors.rouge,
            contenu: _listeStock(
              _ruptures,
              messageVide: 'Aucun médicament en rupture.',
              couleur: AppColors.rouge,
              etiquette: 'Rupture',
            ),
          ),
          const SizedBox(height: 12),
          _carte(
            titre: 'Stock faible (≤ $seuilStockFaible)',
            icone: Icons.warning_amber_outlined,
            couleurIcone: AppColors.orange,
            contenu: _listeStock(
              _stockFaible,
              messageVide: 'Aucune alerte de stock.',
              couleur: AppColors.orange,
              etiquette: 'À réapprovisionner',
            ),
          ),
          const SizedBox(height: 12),
          _carte(
            titre: 'Péremptions (≤ 90 jours)',
            icone: Icons.event_busy_outlined,
            couleurIcone: AppColors.orange,
            contenu: _listeLots(),
          ),
          const SizedBox(height: 12),
          _carte(
            titre: 'Top 5 des médicaments vendus',
            icone: Icons.emoji_events_outlined,
            couleurIcone: AppColors.bleu,
            contenu: _listeMeilleuresVentes(),
          ),
        ],
      ),
    );
  }

  Widget _carte({
    required String titre,
    required IconData icone,
    required Widget contenu,
    Color couleurIcone = AppColors.vert,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE0E6E0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(icone, color: couleurIcone, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    titre,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            contenu,
          ],
        ),
      ),
    );
  }

  Widget _listeStock(
    List<Medic> medics, {
    required String messageVide,
    required Color couleur,
    required String etiquette,
  }) {
    if (medics.isEmpty) {
      return Text(
        messageVide,
        style: const TextStyle(color: AppColors.gris),
      );
    }

    return Column(
      children: medics
          .map(
            (medic) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: <Widget>[
                  Expanded(child: Text(medic.designMed)),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: couleur.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${medic.stockMed} · $etiquette',
                      style: TextStyle(
                        color: couleur,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _listeLots() {
    if (_lotsEnAlerte.isEmpty) {
      return const Text(
        'Aucun lot périmé ou proche de la péremption.',
        style: TextStyle(color: AppColors.gris),
      );
    }

    return Column(
      children: <Widget>[
        for (final lot in _lotsEnAlerte.take(4))
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    '${lot.designMed ?? lot.numMed} · ${lot.libelle}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _etiquettePeremption(lot),
                  style: TextStyle(
                    color: lot.estPerime() ? AppColors.rouge : AppColors.orange,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        if (_lotsEnAlerte.length > 4)
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
                    "+ ${_lotsEnAlerte.length - 4} autre(s) — voir l'onglet Lots",
              style: const TextStyle(fontSize: 12, color: AppColors.gris),
            ),
          ),
      ],
    );
  }

  String _etiquettePeremption(Lot lot) {
    final jours = lot.joursRestants();
    if (jours == null) return 'pér. inconnue';
    if (jours < 0) return 'Périmé (${-jours} j)';
    return 'J-$jours';
  }

  Widget _listeMeilleuresVentes() {
    if (_meilleuresVentes.isEmpty) {
      return const Text(
        'Aucune vente enregistrée.',
        style: TextStyle(color: AppColors.gris),
      );
    }

    return Column(
      children: <Widget>[
        for (var i = 0; i < _meilleuresVentes.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: <Widget>[
                CircleAvatar(
                  radius: 12,
                  backgroundColor: AppColors.vertSurface,
                  child: Text(
                    '${i + 1}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.vertFonce,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(_meilleuresVentes[i].designation)),
                Text(
                  '${formaterNombre(_meilleuresVentes[i].quantite)} vendu(s)',
                  style: const TextStyle(
                    color: AppColors.bleu,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
