import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Champ de saisie stylé et validé, réutilisé par tous les formulaires.
class ChampTexte extends StatelessWidget {
  const ChampTexte({
    super.key,
    required this.controleur,
    required this.label,
    this.hint,
    this.icone,
    this.suffixe,
    this.obscur = false,
    this.lectureSeule = false,
    this.clavier,
    this.formateurs,
    this.validateur,
    this.onTap,
    this.onChanged,
    this.maxLignes = 1,
    this.textCapitalization = TextCapitalization.none,
  });

  final TextEditingController controleur;
  final String label;
  final String? hint;
  final IconData? icone;
  final Widget? suffixe;
  final bool obscur;
  final bool lectureSeule;
  final TextInputType? clavier;
  final List<TextInputFormatter>? formateurs;
  final String? Function(String?)? validateur;
  final VoidCallback? onTap;
  final ValueChanged<String>? onChanged;
  final int maxLignes;
  final TextCapitalization textCapitalization;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controleur,
      obscureText: obscur,
      readOnly: lectureSeule,
      keyboardType: clavier,
      inputFormatters: formateurs,
      validator: validateur,
      onTap: onTap,
      onChanged: onChanged,
      maxLines: maxLignes,
      textCapitalization: textCapitalization,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: icone == null ? null : Icon(icone),
        suffixIcon: suffixe,
      ),
    );
  }
}

/// Contraintes de saisie courantes.
class Saisies {
  const Saisies._();

  /// Chiffres uniquement (quantités, prix, numéros).
  static final List<TextInputFormatter> chiffres = <TextInputFormatter>[
    FilteringTextInputFormatter.digitsOnly,
  ];
}
