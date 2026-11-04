import 'package:flutter/material.dart';

import '../Authentification/login.dart';
import '../core/backup.dart';
import '../core/backup_format.dart';
import '../core/exceptions.dart';
import '../core/feedback.dart';
import '../core/theme.dart';
import '../core/widgets/confirm_dialog.dart';

/// Écran de sauvegarde et de restauration.
///
/// Un seul fichier JSON contient **toutes** les données (comptes, catalogue,
/// lots, mouvements, entrées, ventes) : c'est aussi la base d'une migration
/// vers un nouveau téléphone.
class SauvegardePage extends StatefulWidget {
  const SauvegardePage({super.key});

  @override
  State<SauvegardePage> createState() => _SauvegardePageState();
}

class _SauvegardePageState extends State<SauvegardePage> {
  bool _occupe = false;
  Map<String, int> _compteurs = <String, int>{};

  @override
  void initState() {
    super.initState();
    _chargerCompteurs();
  }

  Future<void> _chargerCompteurs() async {
    try {
      final compteurs = await Sauvegarde.compterDonnees();
      if (!mounted) return;
      setState(() => _compteurs = compteurs);
    } catch (_) {
      // L'affichage des compteurs est accessoire : on n'interrompt pas l'écran.
    }
  }

  Future<void> _exporter() async {
    setState(() => _occupe = true);
    try {
      final fichier = await Sauvegarde.ecrireFichier();
      await Sauvegarde.partager(fichier);
      if (!mounted) return;
      afficherMessage(
        context,
        'Sauvegarde créée :'
        ' ${(fichier.lengthSync() / 1024).toStringAsFixed(1)} Ko.',
      );
    } on Exception catch (erreur) {
      if (!mounted) return;
      afficherMessage(context, 'Sauvegarde impossible : $erreur', erreur: true);
    } finally {
      if (mounted) setState(() => _occupe = false);
    }
  }

  Future<void> _restaurer() async {
    setState(() => _occupe = true);
    try {
      final tables = await Sauvegarde.choisirEtAnalyser();
      if (tables == null || !mounted) return;

      final confirme = await confirmerAction(
        context,
        titre: 'Restaurer une sauvegarde',
        message:
            'Toutes les données actuelles (${_resumeCompteurs()}) seront '
            'remplacées par celles du fichier '
            '(${compterLignesSauvegarde(tables)} lignes).\n\n'
            'Cette opération est irréversible : exportez une sauvegarde de '
            'vos données actuelles avant de continuer.',
        libelleConfirmer: 'Restaurer',
        couleurConfirmer: AppColors.rouge,
      );
      if (!confirme || !mounted) return;

      await Sauvegarde.restaurer(tables);
      if (!mounted) return;

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (contexte) => AlertDialog(
          title: const Text('Restauration terminée'),
          content: const Text(
            'Les données ont été restaurées. '
            'Reconnectez-vous avec un compte présent dans la sauvegarde.',
          ),
          actions: <Widget>[
            FilledButton(
              onPressed: () => Navigator.of(contexte).pop(),
              child: const Text('Se reconnecter'),
            ),
          ],
        ),
      );

      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const LoginPage()),
        (route) => false,
      );
    } on OperationRefuseeException catch (erreur) {
      if (!mounted) return;
      afficherMessage(context, erreur.toString(), erreur: true);
    } on Exception catch (erreur) {
      if (!mounted) return;
      afficherMessage(context, 'Restauration impossible : $erreur', erreur: true);
    } finally {
      if (mounted) setState(() => _occupe = false);
    }
  }

  String _resumeCompteurs() {
    final medicaments = _compteurs['medics'] ?? 0;
    final lots = _compteurs['lots'] ?? 0;
    final ventes = _compteurs['achats'] ?? 0;
    return '$medicaments médicament(s), $lots lot(s), $ventes vente(s)';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sauvegarde')),
      body: AbsorbPointer(
        absorbing: _occupe,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            if (_occupe) const LinearProgressIndicator(),
            if (_occupe) const SizedBox(height: 12),
            _carte(
              titre: 'Ce qui est sauvegardé',
              icone: Icons.inventory_2_outlined,
              couleur: AppColors.bleu,
              texte:
                  'Comptes utilisateurs, catalogue, lots et péremptions, '
                  'mouvements de stock, entrées, ventes. '
                  'Le stock est recalculé à partir des lots lors de la '
                  'restauration : il ne peut pas devenir incohérent.',
            ),
            const SizedBox(height: 12),
            _compteurs(),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _exporter,
              icon: const Icon(Icons.save_alt),
              label: const Text('Créer et partager une sauvegarde'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _restaurer,
              icon: const Icon(Icons.restore),
              label: const Text('Restaurer depuis un fichier'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
            ),
            const SizedBox(height: 16),
            _carte(
              titre: 'Bonnes pratiques',
              icone: Icons.info_outline,
              couleur: AppColors.orange,
              texte:
                  'Faites une sauvegarde après chaque journée de travail et '
                  'avant toute mise à jour. Conservez-la hors du téléphone '
                  '(courriel, Drive) : elle contient des données de santé, '
                  'à protéger.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _compteurs() {
    final lignes = <({String libelle, int valeur})>[
      (libelle: 'Médicaments', valeur: _compteurs['medics'] ?? 0),
      (libelle: 'Lots', valeur: _compteurs['lots'] ?? 0),
      (libelle: 'Entrées', valeur: _compteurs['entrees'] ?? 0),
      (libelle: 'Ventes', valeur: _compteurs['achats'] ?? 0),
    ];

    return Row(
      children: <Widget>[
        for (final ligne in lignes) ...<Widget>[
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
              decoration: BoxDecoration(
                color: AppColors.vertSurface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: <Widget>[
                  Text(
                    '${ligne.valeur}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  Text(
                    ligne.libelle,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.gris,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _carte({
    required String titre,
    required IconData icone,
    required Color couleur,
    required String texte,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: couleur.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: couleur.withOpacity(0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icone, color: couleur),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  titre,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  texte,
                  style: const TextStyle(fontSize: 13, color: AppColors.gris),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
