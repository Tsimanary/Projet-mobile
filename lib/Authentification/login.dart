import 'package:flutter/material.dart';

import '../Models/users.dart';
import '../SQLite/sqlite.dart';
import '../core/theme.dart';
import '../core/validators.dart';
import '../core/widgets/app_text_field.dart';
import '../pages/home.dart';
import 'signup.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _nomControleur = TextEditingController();
  final _motDePasseControleur = TextEditingController();
  final _baseDeDonnees = DatabaseHelper();

  bool _motDePasseVisible = false;
  bool _connexionEnCours = false;
  String? _messageErreur;

  @override
  void dispose() {
    _nomControleur.dispose();
    _motDePasseControleur.dispose();
    super.dispose();
  }

  Future<void> _connexion() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    setState(() {
      _connexionEnCours = true;
      _messageErreur = null;
    });

    try {
      final valide = await _baseDeDonnees.login(
        Users(
          usrName: _nomControleur.text.trim(),
          usrPassword: _motDePasseControleur.text,
        ),
      );

      if (!mounted) return;

      if (!valide) {
        setState(() {
          _connexionEnCours = false;
          _messageErreur = "Nom d'utilisateur ou mot de passe incorrect.";
        });
        return;
      }

      setState(() => _connexionEnCours = false);
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => const HomePage()),
      );
    } catch (erreur) {
      if (!mounted) return;
      setState(() {
        _connexionEnCours = false;
        _messageErreur = 'Erreur de connexion : $erreur';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: 280,
                        maxHeight: 160,
                      ),
                      child: Image.asset(
                        'lib/assets/images/Drugst.png',
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.local_pharmacy,
                          size: 96,
                          color: AppColors.vert,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Gestion de pharmacie',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppColors.vertFonce,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ChampTexte(
                      controleur: _nomControleur,
                      label: "Nom d'utilisateur",
                      icone: Icons.person_outline,
                      textCapitalization: TextCapitalization.none,
                      validateur: Validators.obligatoire,
                    ),
                    const SizedBox(height: 16),
                    ChampTexte(
                      controleur: _motDePasseControleur,
                      label: 'Mot de passe',
                      icone: Icons.lock_outline,
                      obscur: !_motDePasseVisible,
                      validateur: (valeur) =>
                          (valeur == null || valeur.isEmpty)
                              ? 'Le mot de passe est obligatoire.'
                              : null,
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
                    if (_messageErreur != null) ...<Widget>[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.rougeSurface,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: <Widget>[
                            const Icon(
                              Icons.error_outline,
                              color: AppColors.rouge,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _messageErreur!,
                                style: const TextStyle(
                                  color: AppColors.rouge,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _connexionEnCours ? null : _connexion,
                      child: _connexionEnCours
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
                          : const Text('SE CONNECTER'),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        const Text("Pas encore de compte ?"),
                        TextButton(
                          onPressed: _connexionEnCours
                              ? null
                              : () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) => const SignUp(),
                                    ),
                                  );
                                },
                          child: const Text('CRÉER UN COMPTE'),
                        ),
                      ],
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
