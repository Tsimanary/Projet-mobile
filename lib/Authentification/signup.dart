import 'package:flutter/material.dart';

import '../Models/users.dart';
import '../SQLite/sqlite.dart';
import '../core/exceptions.dart';
import '../core/theme.dart';
import '../core/validators.dart';
import '../core/widgets/app_text_field.dart';

class SignUp extends StatefulWidget {
  const SignUp({super.key});

  @override
  State<SignUp> createState() => _SignUpState();
}

class _SignUpState extends State<SignUp> {
  final _formKey = GlobalKey<FormState>();
  final _nomControleur = TextEditingController();
  final _motDePasseControleur = TextEditingController();
  final _confirmationControleur = TextEditingController();
  final _baseDeDonnees = DatabaseHelper();

  bool _motDePasseVisible = false;
  bool _enregistrementEnCours = false;
  String? _messageErreur;

  @override
  void dispose() {
    _nomControleur.dispose();
    _motDePasseControleur.dispose();
    _confirmationControleur.dispose();
    super.dispose();
  }

  Future<void> _creerCompte() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    setState(() {
      _enregistrementEnCours = true;
      _messageErreur = null;
    });

    try {
      await _baseDeDonnees.signup(
        Users(
          usrName: _nomControleur.text.trim(),
          usrPassword: _motDePasseControleur.text,
        ),
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on UtilisateurDejaExisteException catch (erreur) {
      if (!mounted) return;
      setState(() {
        _enregistrementEnCours = false;
        _messageErreur = erreur.toString();
      });
    } catch (erreur) {
      if (!mounted) return;
      setState(() {
        _enregistrementEnCours = false;
        _messageErreur = "Impossible de créer le compte : $erreur";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Créer un compte')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    const Text(
                      'Créez le compte qui administrera cette officine.',
                      style: TextStyle(color: AppColors.gris),
                    ),
                    const SizedBox(height: 20),
                    ChampTexte(
                      controleur: _nomControleur,
                      label: "Nom d'utilisateur",
                      icone: Icons.person_outline,
                      validateur: Validators.nomUtilisateur,
                    ),
                    const SizedBox(height: 16),
                    ChampTexte(
                      controleur: _motDePasseControleur,
                      label: 'Mot de passe',
                      icone: Icons.lock_outline,
                      obscur: !_motDePasseVisible,
                      validateur: Validators.motDePasse,
                      suffixe: IconButton(
                        tooltip: _motDePasseVisible
                            ? 'Masquer le mot de passe'
                            : 'Afficher le mot de passe',
                        onPressed: () {
                          setState(() {
                            _motDePasseVisible = !_motDePasseVisible;
                          });
                        },
                        icon: Icon(
                          _motDePasseVisible
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ChampTexte(
                      controleur: _confirmationControleur,
                      label: 'Confirmer le mot de passe',
                      icone: Icons.lock_outline,
                      obscur: !_motDePasseVisible,
                      validateur: (valeur) {
                        if (valeur == null || valeur.isEmpty) {
                          return 'Veuillez confirmer le mot de passe.';
                        }
                        if (valeur != _motDePasseControleur.text) {
                          return 'Les mots de passe ne correspondent pas.';
                        }
                        return null;
                      },
                    ),
                    if (_messageErreur != null) ...<Widget>[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.rougeSurface,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _messageErreur!,
                          style: const TextStyle(color: AppColors.rouge),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _enregistrementEnCours ? null : _creerCompte,
                      child: _enregistrementEnCours
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Text('CRÉER LE COMPTE'),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _enregistrementEnCours
                          ? null
                          : () => Navigator.of(context).pop(),
                      child: const Text('J\'ai déjà un compte'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
