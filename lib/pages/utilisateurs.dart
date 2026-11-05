import 'package:flutter/material.dart';

import '../Models/users.dart';
import '../SQLite/sqlite.dart';
import '../core/exceptions.dart';
import '../core/feedback.dart';
import '../core/roles.dart';
import '../core/session.dart';
import '../core/theme.dart';
import '../core/validators.dart';
import '../core/widgets/app_text_field.dart';
import '../core/widgets/confirm_dialog.dart';

/// Gestion des comptes : qui peut se connecter, et avec quels droits.
///
/// Écran réservé au gestionnaire — c'est le seul endroit où l'on crée un
/// compte, où l'on change un rôle et où l'on supprime un accès.
class UtilisateursPage extends StatefulWidget {
  const UtilisateursPage({super.key});

  @override
  State<UtilisateursPage> createState() => _UtilisateursPageState();
}

class _UtilisateursPageState extends State<UtilisateursPage> {
  final _baseDeDonnees = DatabaseHelper();

  List<Users> _comptes = <Users>[];
  bool _chargement = true;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  bool get _autorise => Session.permissions.peutGererUtilisateurs;

  Future<void> _charger() async {
    if (!_autorise) {
      // Pas de setState : on est encore dans initState.
      _chargement = false;
      _erreur = 'Cet écran est réservé au gestionnaire.';
      return;
    }

    try {
      final comptes = await _baseDeDonnees.getAllUsers();
      if (!mounted) return;
      setState(() {
        _comptes = comptes;
        _chargement = false;
        _erreur = null;
      });
    } on Exception catch (erreur) {
      if (!mounted) return;
      setState(() {
        _chargement = false;
        _erreur = erreur.toString();
      });
    }
  }

  Future<void> _creer() async {
    final resultat = await showDialog<Users>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _DialogueCompte(),
    );
    if (resultat == null || !mounted) return;

    try {
      await _baseDeDonnees.signup(resultat);
      await _charger();
      if (!mounted) return;
      afficherMessage(
        context,
        'Compte « ${resultat.usrName} » créé (${resultat.usrRole.libelle}).',
      );
    } on Exception catch (erreur) {
      if (!mounted) return;
      afficherMessage(context, 'Création impossible : $erreur', erreur: true);
    }
  }

  Future<void> _changerRole(Users compte) async {
    final nouveau = await showDialog<RoleUtilisateur>(
      context: context,
      builder: (_) => _DialogueRole(compte: compte),
    );
    if (nouveau == null || nouveau == compte.usrRole || !mounted) return;

    try {
      await _baseDeDonnees.updateUserRole(compte.usrId!, nouveau);
      await _charger();
      if (!mounted) return;
      afficherMessage(
        context,
        '${compte.usrName} est désormais ${nouveau.libelle}.',
      );
    } on Exception catch (erreur) {
      if (!mounted) return;
      afficherMessage(context, 'Changement impossible : $erreur', erreur: true);
    }
  }

  Future<void> _supprimer(Users compte) async {
    final confirme = await confirmerAction(
      context,
      titre: 'Supprimer le compte',
      message: 'Le compte « ${compte.usrName} » ne pourra plus se connecter. '
          'Les ventes déjà enregistrées sont conservées.',
      libelleConfirmer: 'Supprimer',
    );
    if (!confirme || !mounted) return;

    try {
      await _baseDeDonnees.deleteUser(compte.usrId!);
      await _charger();
      if (!mounted) return;
      afficherMessage(context, 'Compte « ${compte.usrName} » supprimé.');
    } on OperationRefuseeException catch (erreur) {
      if (!mounted) return;
      afficherMessage(context, erreur.toString(), erreur: true);
    } on Exception catch (erreur) {
      if (!mounted) return;
      afficherMessage(context, 'Suppression impossible : $erreur', erreur: true);
    }
  }

  Widget _carte(Users compte) {
    final gestionnaire = compte.usrRole == RoleUtilisateur.gestionnaire;
    final moiMeme = Session.nom.toLowerCase() == compte.usrName.toLowerCase();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor:
              gestionnaire ? AppColors.vertSurface : AppColors.bleu,
          child: Icon(
            gestionnaire ? Icons.verified_user : Icons.point_of_sale,
            color: gestionnaire ? AppColors.vert : Colors.white,
          ),
        ),
        title: Text(
          compte.usrName + (moiMeme ? ' (vous)' : ''),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(compte.usrRole.description),
        isThreeLine: true,
        trailing: PopupMenuButton<String>(
          tooltip: 'Actions',
          onSelected: (action) {
            if (action == 'role') _changerRole(compte);
            if (action == 'supprimer') _supprimer(compte);
          },
          itemBuilder: (_) => <PopupMenuEntry<String>>[
            const PopupMenuItem<String>(
              value: 'role',
              child: Text('Changer le rôle'),
            ),
            PopupMenuItem<String>(
              value: 'supprimer',
              enabled: !moiMeme,
              child: Text(
                moiMeme ? 'Compte connecté' : 'Supprimer',
                style: TextStyle(
                  color: moiMeme ? AppColors.gris : AppColors.rouge,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _contenu() {
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
              Text(_erreur!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              OutlinedButton(
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
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Row(
              children: <Widget>[
                const Icon(Icons.group_outlined, color: AppColors.vert),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${_comptes.length} '
                    '${_comptes.length > 1 ? 'comptes' : 'compte'}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          ..._comptes.map(_carte),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Le vendeur encaisse et reçoit les livraisons, sans pouvoir '
              'supprimer ni corriger quoi que ce soit. Le gestionnaire garde '
              'la main sur les prix, les comptes et les sauvegardes.',
              style: TextStyle(fontSize: 12, color: AppColors.gris),
            ),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Utilisateurs')),
      body: _contenu(),
      floatingActionButton: _autorise && _erreur == null
          ? FloatingActionButton.extended(
              onPressed: _creer,
              backgroundColor: AppColors.vert,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.person_add_alt),
              label: const Text('Nouveau compte'),
            )
          : null,
    );
  }
}

/// Création d'un compte : nom, mot de passe et rôle.
class _DialogueCompte extends StatefulWidget {
  const _DialogueCompte();

  @override
  State<_DialogueCompte> createState() => _DialogueCompteState();
}

class _DialogueCompteState extends State<_DialogueCompte> {
  final _formKey = GlobalKey<FormState>();
  final _nomControleur = TextEditingController();
  final _motDePasseControleur = TextEditingController();
  final _confirmationControleur = TextEditingController();

  RoleUtilisateur _role = RoleUtilisateur.vendeur;
  bool _visible = false;

  @override
  void dispose() {
    _nomControleur.dispose();
    _motDePasseControleur.dispose();
    _confirmationControleur.dispose();
    super.dispose();
  }

  void _valider() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(
      Users(
        usrName: _nomControleur.text.trim(),
        usrPassword: _motDePasseControleur.text,
        usrRole: _role,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nouveau compte'),
      content: SizedBox(
        width: 380,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                ChampTexte(
                  controleur: _nomControleur,
                  label: "Nom d'utilisateur",
                  icone: Icons.person_outline,
                  textCapitalization: TextCapitalization.none,
                  validateur: Validators.nomUtilisateur,
                ),
                const SizedBox(height: 12),
                ChampTexte(
                  controleur: _motDePasseControleur,
                  label: 'Mot de passe',
                  icone: Icons.lock_outline,
                  obscur: !_visible,
                  validateur: Validators.motDePasse,
                  suffixe: IconButton(
                    tooltip: _visible
                        ? 'Masquer le mot de passe'
                        : 'Afficher le mot de passe',
                    onPressed: () => setState(() => _visible = !_visible),
                    icon: Icon(
                      _visible ? Icons.visibility_off : Icons.visibility,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                ChampTexte(
                  controleur: _confirmationControleur,
                  label: 'Confirmer le mot de passe',
                  icone: Icons.lock_reset,
                  obscur: !_visible,
                  validateur: (valeur) => valeur == _motDePasseControleur.text
                      ? null
                      : 'Les deux mots de passe diffèrent.',
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Rôle',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
                RadioListTile<RoleUtilisateur>(
                  value: RoleUtilisateur.vendeur,
                  // ignore: deprecated_member_use
                  groupValue: _role,
                  // ignore: deprecated_member_use
                  onChanged: (valeur) => setState(() => _role = valeur!),
                  title: const Text('Vendeur'),
                  subtitle: Text(RoleUtilisateur.vendeur.description),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
                RadioListTile<RoleUtilisateur>(
                  value: RoleUtilisateur.gestionnaire,
                  // ignore: deprecated_member_use
                  groupValue: _role,
                  // ignore: deprecated_member_use
                  onChanged: (valeur) => setState(() => _role = valeur!),
                  title: const Text('Gestionnaire'),
                  subtitle: Text(RoleUtilisateur.gestionnaire.description),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        FilledButton(onPressed: _valider, child: const Text('Créer')),
      ],
    );
  }
}

/// Changement de rôle d'un compte existant.
class _DialogueRole extends StatelessWidget {
  const _DialogueRole({required this.compte});

  final Users compte;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Rôle de ${compte.usrName}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (final role in RoleUtilisateur.values)
            ListTile(
              leading: Icon(
                role == compte.usrRole
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: role == compte.usrRole ? AppColors.vert : AppColors.gris,
              ),
              title: Text(role.libelle),
              subtitle: Text(role.description),
              onTap: () => Navigator.of(context).pop(role),
            ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
      ],
    );
  }
}
