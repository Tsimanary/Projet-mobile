import 'package:flutter/material.dart';

import 'theme.dart';

/// Affiche un message temporaire en bas de l'écran.
///
/// [erreur] = true pour un échec (fond rouge), false pour un succès.
void afficherMessage(
  BuildContext context,
  String message, {
  bool erreur = false,
}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: erreur ? AppColors.rouge : AppColors.vert,
      ),
    );
}
