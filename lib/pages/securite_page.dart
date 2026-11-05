import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/feedback.dart';
import '../core/theme.dart';
import '../core/verrouillage.dart';
import '../core/verrouillage_regles.dart';

/// Réglages de sécurité : chiffrement de la base et code d'accès.
class SecuritePage extends StatefulWidget {
  const SecuritePage({super.key});

  @override
  State<SecuritePage> createState() => _SecuritePageState();
}

class _SecuritePageState extends State<SecuritePage> {
  EtatVerrouillage? _etat;
  bool _occupe = false;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    try {
      final etat = await Verrouillage.etat();
      if (!mounted) return;
      setState(() => _etat = etat);
    } on Exception catch (erreur) {
      if (!mounted) return;
      afficherMessage(context, 'Lecture impossible : $erreur', erreur: true);
    }
  }

  Future<void> _executer(
    Future<void> Function() action,
    String succes,
  ) async {
    setState(() => _occupe = true);
    try {
      await action();
      await _charger();
      if (!mounted) return;
      afficherMessage(context, succes);
    } on Exception catch (erreur) {
      if (!mounted) return;
      afficherMessage(context, 'Opération impossible : $erreur', erreur: true);
    } finally {
      if (mounted) setState(() => _occupe = false);
    }
  }

  Future<String?> _demanderCode({
    required String titre,
    required String message,
  }) {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _DialogueCode(titre: titre, message: message),
    );
  }

  Future<void> _activer() async {
    final code = await _demanderCode(
      titre: 'Choisir un code',
      message: 'De ${ReglesPin.longueurMin} à ${ReglesPin.longueurMax} chiffres. '
          'Il sera demandé à chaque ouverture de l\'application.',
    );
    if (code == null || !mounted) return;

    final confirmation = await _demanderCode(
      titre: 'Confirmer le code',
      message: 'Saisissez à nouveau le même code.',
    );
    if (confirmation == null || !mounted) return;

    if (code != confirmation) {
      afficherMessage(
        context,
        'Les deux codes ne correspondent pas.',
        erreur: true,
      );
      return;
    }

    await _executer(
      () => Verrouillage.definir(code),
      'Code d\'accès activé.',
    );
  }

  Future<void> _desactiver() async {
    final code = await _demanderCode(
      titre: 'Code actuel',
      message: 'Saisissez votre code pour désactiver la protection.',
    );
    if (code == null || !mounted) return;

    var correct = false;
    try {
      correct = await Verrouillage.verifier(code);
    } catch (_) {
      correct = false;
    }
    if (!mounted) return;

    if (!correct) {
      afficherMessage(context, 'Code incorrect.', erreur: true);
      await _charger();
      return;
    }

    await _executer(
      () => Verrouillage.desactiver(),
      'Code d\'accès désactivé.',
    );
  }

  Future<void> _changer() async {
    final actuel = await _demanderCode(
      titre: 'Code actuel',
      message: 'Saisissez votre code actuel.',
    );
    if (actuel == null || !mounted) return;

    var correct = false;
    try {
      correct = await Verrouillage.verifier(actuel);
    } catch (_) {
      correct = false;
    }
    if (!mounted) return;
    if (!correct) {
      afficherMessage(context, 'Code incorrect.', erreur: true);
      await _charger();
      return;
    }

    final nouveau = await _demanderCode(
      titre: 'Nouveau code',
      message: 'De ${ReglesPin.longueurMin} à ${ReglesPin.longueurMax} chiffres.',
    );
    if (nouveau == null || !mounted) return;

    final confirmation = await _demanderCode(
      titre: 'Confirmer le code',
      message: 'Saisissez à nouveau le nouveau code.',
    );
    if (confirmation == null || !mounted) return;

    if (nouveau != confirmation) {
      afficherMessage(
        context,
        'Les deux codes ne correspondent pas.',
        erreur: true,
      );
      return;
    }

    await _executer(
      () => Verrouillage.definir(nouveau),
      'Code d\'accès modifié.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final etat = _etat;
    final actif = etat?.actif ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('Sécurité')),
      body: AbsorbPointer(
        absorbing: _occupe,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            if (_occupe) const LinearProgressIndicator(),
            if (_occupe) const SizedBox(height: 12),
            _carte(
              titre: 'Base de données chiffrée',
              icone: Icons.enhanced_encryption_outlined,
              couleur: AppColors.vert,
              texte:
                  'Le fichier SQLite est chiffré (SQLCipher). La clé de '
                  '32 octets est générée sur cet appareil et conservée par le '
                  'système (Keystore) : elle n\'est jamais écrite dans un '
                  'fichier de l\'application. Une copie du fichier, seule, '
                  'est donc illisible.',
            ),
            const SizedBox(height: 12),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: Color(0xFFE0E6E0)),
              ),
              child: Column(
                children: <Widget>[
                  SwitchListTile(
                    value: actif,
                    onChanged: (valeur) {
                      if (valeur) {
                        _activer();
                      } else {
                        _desactiver();
                      }
                    },
                    secondary: Icon(
                      actif ? Icons.lock_outline : Icons.lock_open,
                      color: actif ? AppColors.vert : AppColors.gris,
                    ),
                    title: const Text('Code d\'accès'),
                    subtitle: Text(
                      actif
                          ? 'Demandé à l\'ouverture et après 30 s '
                              'en arrière-plan'
                          : 'Aucune protection à l\'ouverture',
                    ),
                  ),
                  if (actif) const Divider(height: 1),
                  if (actif)
                    ListTile(
                      leading: const Icon(Icons.password),
                      title: const Text('Changer le code'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _changer,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _carte(
              titre: 'Blocage automatique',
              icone: Icons.timer_outlined,
              couleur: AppColors.bleu,
              texte:
                  '${ReglesPin.tentativesMax} essais erronés bloquent la '
                  'saisie pendant '
                  '${ReglesPin.formaterDuree(ReglesPin.dureeBlocage)}. '
                  'Le compteur est conservé dans la base : redémarrer '
                  'l\'application ne le remet pas à zéro.',
            ),
            const SizedBox(height: 12),
            _carte(
              titre: 'Sauvegarde chiffrée',
              icone: Icons.enhanced_encryption_outlined,
              couleur: AppColors.vert,
              texte:
                  'Les sauvegardes sont chiffrées par une phrase secrète '
                  '(AES-256-GCM, clé dérivée en Argon2id). Un export « sans '
                  'protection » reste possible, mais il est alors lisible en '
                  'clair : à éviter.',
            ),
            const SizedBox(height: 12),
            _carte(
              titre: 'Ce que cela ne protège pas',
              icone: Icons.info_outline,
              couleur: AppColors.gris,
              texte:
                  'Un téléphone déverrouillé, un appareil rooté ou une '
                  'application espionne peuvent toujours accéder aux données '
                  'pendant que l\'application est ouverte. Le chiffrement '
                  'protège le fichier au repos (vol, copie, sauvegarde '
                  'système).',
            ),
          ],
        ),
      ),
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

/// Saisie d'un code à 4–6 chiffres.
class _DialogueCode extends StatefulWidget {
  const _DialogueCode({required this.titre, required this.message});

  final String titre;
  final String message;

  @override
  State<_DialogueCode> createState() => _DialogueCodeState();
}

class _DialogueCodeState extends State<_DialogueCode> {
  final TextEditingController _controleur = TextEditingController();

  @override
  void dispose() {
    _controleur.dispose();
    super.dispose();
  }

  void _valider() {
    final code = _controleur.text;
    if (!ReglesPin.estValide(code)) return;
    Navigator.of(context).pop(code);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.titre),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(widget.message),
          const SizedBox(height: 16),
          TextField(
            controller: _controleur,
            autofocus: true,
            obscureText: true,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 22, letterSpacing: 8),
            inputFormatters: <TextInputFormatter>[
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(ReglesPin.longueurMax),
            ],
            decoration: const InputDecoration(hintText: '••••'),
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _valider(),
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: ReglesPin.estValide(_controleur.text) ? _valider : null,
          child: const Text('Valider'),
        ),
      ],
    );
  }
}
