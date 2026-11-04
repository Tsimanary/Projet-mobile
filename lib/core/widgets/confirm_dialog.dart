import 'package:flutter/material.dart';

import '../theme.dart';

/// Boîte de dialogue de confirmation réutilisable.
///
/// Retourne `true` si l'utilisateur confirme, `false` sinon (ou s'il ferme).
Future<bool> confirmerAction(
  BuildContext context, {
  required String titre,
  required String message,
  String libelleConfirmer = 'Confirmer',
  String libelleAnnuler = 'Annuler',
  Color couleurConfirmer = AppColors.rouge,
}) async {
  final reponse = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (contexteDialogue) {
      return AlertDialog(
        title: Text(titre),
        content: SingleChildScrollView(child: Text(message)),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(contexteDialogue).pop(false),
            child: Text(libelleAnnuler),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: couleurConfirmer,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(contexteDialogue).pop(true),
            child: Text(libelleConfirmer),
          ),
        ],
      );
    },
  );
  return reponse ?? false;
}
