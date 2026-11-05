import 'package:flutter/material.dart';

import '../Authentification/login.dart';
import '../core/backup.dart';
import '../core/backup_format.dart';
import '../core/chiffrement.dart';
import '../core/exceptions.dart';
import '../core/feedback.dart';
import '../core/session.dart';
import '../core/theme.dart';
import '../core/widgets/confirm_dialog.dart';
import '../core/widgets/dialogue_phrase.dart';

/// Écran de sauvegarde et de restauration.
///
/// Un seul fichier contient **toutes** les données (comptes, catalogue, lots,
/// mouvements, entrées, ventes). Il est chiffré par une phrase secrète, ce qui
/// permet de le transporter ou de l'archiver sans exposer l'officine.
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
      // Les compteurs sont un confort d'affichage : on n'interrompt rien.
    }
  }

  Future<void> _exporter() async {
    final resultat = await showDialog<ResultatPhrase>(
      context: context,
      barrierDismissible: false,
      builder: (_) => DialoguePhrase(
        titre: 'Protéger la sauvegarde',
        message:
            'Ce fichier contient toutes vos données. Choisissez une phrase '
            'secrète : elle sera demandée pour restaurer, et elle est le seul '
            'moyen d\'ouvrir le fichier.\n\n'
            'Si vous l\'oubliez, la sauvegarde est définitivement perdue.',
        confirmation: true,
        longueurMin: ChiffrementSauvegarde.longueurMinPhrase,
        libelleValider: 'Chiffrer et partager',
        boutonSansProtection: 'Exporter sans protection',
      ),
    );

    if (resultat == null || !mounted) return;

    if (resultat.sansProtection) {
      final confirme = await confirmerAction(
        context,
        titre: 'Exporter sans protection',
        message:
            'Le fichier ne sera pas chiffré : quiconque l\'obtient pourra lire '
            'l\'intégralité des données (catalogue, lots, ventes, comptes).\n\n'
            'À réserver à un transfert immédiat vers un emplacement sûr.',
        libelleConfirmer: 'Exporter en clair',
      );
      if (!confirme || !mounted) return;
    }

    setState(() => _occupe = true);
    try {
      final fichier = await Sauvegarde.ecrireFichier(
        phraseSecrete: resultat.phrase,
      );
      await Sauvegarde.partager(fichier, chiffree: resultat.phrase != null);

      if (!mounted) return;
      afficherMessage(
        context,
        resultat.phrase != null
            ? 'Sauvegarde chiffrée créée.'
            : 'Sauvegarde créée, non chiffrée.',
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
      final fichier = await Sauvegarde.choisir();
      if (fichier == null || !mounted) return;

      final tables = fichier.estChiffre
          ? await _demanderPhraseEtAnalyser(fichier)
          : await Sauvegarde.analyser(fichier);
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
      // Les comptes viennent peut-être de changer : on repart d'une session
      // vide, avec les droits du compte qui se reconnectera.
      Session.fermer();
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

  /// Demande la phrase secrète (3 essais) et renvoie les tables déchiffrées.
  Future<Map<String, Object?>?> _demanderPhraseEtAnalyser(
    FichierSauvegarde fichier,
  ) async {
    for (var essai = 1; essai <= 3; essai++) {
      final resultat = await showDialog<ResultatPhrase>(
        context: context,
        barrierDismissible: false,
        builder: (_) => DialoguePhrase(
          titre: 'Sauvegarde chiffrée',
          message:
              'Saisissez la phrase secrète utilisée lors de l\'export '
              '(essai $essai sur 3).',
          longueurMin: ChiffrementSauvegarde.longueurMinPhrase,
          libelleValider: 'Déchiffrer',
        ),
      );

      final phrase = resultat?.phrase;
      if (phrase == null || !mounted) return null;

      try {
        return await Sauvegarde.analyser(fichier, phrase: phrase);
      } on OperationRefuseeException catch (erreur) {
        if (!mounted) return null;
        afficherMessage(context, erreur.toString(), erreur: true);
      }
    }
    return null;
  }

  String _resumeCompteurs() {
    final medicaments = _compteurs['medics'] ?? 0;
    final lots = _compteurs['lots'] ?? 0;
    final ventes = _compteurs['achats'] ?? 0;
    return '$medicaments médicament(s), $lots lot(s), $ventes vente(s)';
  }

  @override
  Widget build(BuildContext context) {
    if (!Session.permissions.peutRestaurer) {
      return Scaffold(
        appBar: AppBar(title: const Text('Sauvegarde')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Écran réservé au gestionnaire.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

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
                  'mouvements de stock, entrées, ventes. Le stock est recalculé '
                  'à partir des lots lors de la restauration : il ne peut pas '
                  'devenir incohérent.',
            ),
            const SizedBox(height: 12),
            _compteurs(),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _exporter,
              icon: const Icon(Icons.lock_outline),
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
              titre: 'Chiffrement par phrase secrète',
              icone: Icons.enhanced_encryption_outlined,
              couleur: AppColors.vert,
              texte:
                  'Le fichier est chiffré en AES-256-GCM ; la clé est dérivée '
                  'de votre phrase par Argon2id et n\'est jamais enregistrée. '
                  'Sans la phrase, le fichier est inutilisable — même pour '
                  'nous : il n\'existe aucune récupération.',
            ),
            const SizedBox(height: 12),
            _carte(
              titre: 'Bonnes pratiques',
              icone: Icons.info_outline,
              couleur: AppColors.orange,
              texte:
                  'Faites une sauvegarde après chaque journée de travail et '
                  'avant toute mise à jour. Conservez le fichier hors du '
                  'téléphone (courriel, Drive) et notez la phrase secrète '
                  '*séparément* : les deux ensemble doivent être protégés.',
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
