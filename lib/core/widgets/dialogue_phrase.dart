import 'package:flutter/material.dart';

import '../theme.dart';

/// Résultat d'un dialogue de phrase secrète.
class ResultatPhrase {
  const ResultatPhrase.chiffrer(this.phrase) : sansProtection = false;

  const ResultatPhrase.sansProtection()
      : phrase = null,
        sansProtection = true;

  /// Phrase choisie (null si l'utilisateur refuse la protection).
  final String? phrase;

  /// L'utilisateur a explicitement demandé un export sans protection.
  final bool sansProtection;
}

/// Demande une phrase secrète, avec confirmation optionnelle.
///
/// Retourne `null` si l'utilisateur annule.
class DialoguePhrase extends StatefulWidget {
  const DialoguePhrase({
    super.key,
    required this.titre,
    required this.message,
    this.confirmation = false,
    this.longueurMin = 8,
    this.libelleValider = 'Valider',
    this.boutonSansProtection,
  });

  final String titre;
  final String message;

  /// Affiche un second champ identique (saisie initiale).
  final bool confirmation;
  final int longueurMin;
  final String libelleValider;

  /// Libellé d'une action secondaire « sans protection » (null = absente).
  final String? boutonSansProtection;

  @override
  State<DialoguePhrase> createState() => _DialoguePhraseState();
}

class _DialoguePhraseState extends State<DialoguePhrase> {
  final TextEditingController _phrase = TextEditingController();
  final TextEditingController _confirmation = TextEditingController();
  bool _visible = false;

  @override
  void dispose() {
    _phrase.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  bool get _valide {
    if (_phrase.text.length < widget.longueurMin) return false;
    if (!widget.confirmation) return true;
    return _phrase.text == _confirmation.text;
  }

  void _valider() {
    if (!_valide) return;
    Navigator.of(context).pop(ResultatPhrase.chiffrer(_phrase.text));
  }

  @override
  Widget build(BuildContext context) {
    final accords = widget.confirmation &&
        _confirmation.text.isNotEmpty &&
        _phrase.text != _confirmation.text;

    return AlertDialog(
      title: Text(widget.titre),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(widget.message),
            const SizedBox(height: 16),
            TextField(
              controller: _phrase,
              autofocus: true,
              obscureText: !_visible,
              decoration: InputDecoration(
                labelText: 'Phrase secrète',
                helperText: '${widget.longueurMin} caractères minimum',
                suffixIcon: IconButton(
                  tooltip: _visible ? 'Masquer' : 'Afficher',
                  onPressed: () => setState(() => _visible = !_visible),
                  icon: Icon(
                    _visible ? Icons.visibility_off : Icons.visibility,
                  ),
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
            if (widget.confirmation) ...<Widget>[
              const SizedBox(height: 12),
              TextField(
                controller: _confirmation,
                obscureText: !_visible,
                decoration: InputDecoration(
                  labelText: 'Confirmation',
                  errorText: accords ? 'Les phrases ne correspondent pas.' : null,
                ),
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _valider(),
              ),
            ],
          ],
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      actions: <Widget>[
        if (widget.boutonSansProtection != null)
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.orange),
            onPressed: () => Navigator.of(context).pop(
              const ResultatPhrase.sansProtection(),
            ),
            child: Text(widget.boutonSansProtection!),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: _valide ? _valider : null,
          child: Text(widget.libelleValider),
        ),
      ],
    );
  }
}
