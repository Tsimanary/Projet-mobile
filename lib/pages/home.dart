import 'package:flutter/material.dart';

import '../Authentification/login.dart';
import '../core/roles.dart';
import '../core/session.dart';
import '../core/widgets/confirm_dialog.dart';
import 'accueil.dart';
import 'achat.dart';
import 'entree.dart';
import 'lots.dart';
import 'medicament.dart';
import 'sauvegarde.dart';
import 'securite_page.dart';
import 'utilisateurs.dart';

/// Conteneur principal : barre de navigation + déconnexion.
class HomePage extends StatefulWidget {
  const HomePage({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late int _index;

  static const List<String> _titres = <String>[
    'Tableau de bord',
    'Entrées de stock',
    'Médicaments',
    'Ventes',
    'Lots et péremptions',
  ];

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
  }

  Widget _corps(int index) {
    switch (index) {
      case 1:
        return const EntreePage();
      case 2:
        return const MedicamentPage();
      case 3:
        return const AchatPage();
      case 4:
        return const LotsPage();
      default:
        return const AccueilPage();
    }
  }

  Future<void> _deconnexion() async {
    final confirme = await confirmerAction(
      context,
      titre: 'Déconnexion',
      message: 'Voulez-vous vraiment vous déconnecter ?',
      libelleConfirmer: 'Se déconnecter',
      couleurConfirmer: Colors.red,
    );

    if (!confirme || !mounted) return;

    Session.fermer();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  void _ouvrir(Widget page) {
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => page))
        // Un rôle a pu changer : on redessine pour réappliquer les droits.
        .then((_) => mounted ? setState(() {}) : null);
  }

  /// Bandeau discret rappelant le compte et son rôle.
  Widget? _entete() {
    final compte = Session.courant;
    if (compte == null) return null;
    final gestionnaire = Session.permissions.estGestionnaire;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(_titres[_index]),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              gestionnaire ? Icons.verified_user : Icons.point_of_sale,
              size: 12,
              color: Colors.white70,
            ),
            const SizedBox(width: 4),
            Text(
              '${compte.nom} · ${compte.role.libelle}',
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final permissions = Session.permissions;

    return Scaffold(
      appBar: AppBar(
        title: _entete() ?? Text(_titres[_index]),
        actions: <Widget>[
          if (permissions.peutGererUtilisateurs)
            IconButton(
              tooltip: 'Utilisateurs',
              onPressed: () => _ouvrir(const UtilisateursPage()),
              icon: const Icon(Icons.group_outlined),
            ),
          if (permissions.peutGererSecurite)
            IconButton(
              tooltip: 'Sécurité',
              onPressed: () => _ouvrir(const SecuritePage()),
              icon: const Icon(Icons.lock_outline),
            ),
          if (permissions.peutSauvegarder)
            IconButton(
              tooltip: 'Sauvegarde et restauration',
              onPressed: () => _ouvrir(const SauvegardePage()),
              icon: const Icon(Icons.save_outlined),
            ),
          IconButton(
            tooltip: 'Se déconnecter',
            onPressed: _deconnexion,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: _corps(_index),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (index) => setState(() => _index = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Colors.grey.shade600,
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Icon(Icons.dashboard),
            label: 'Accueil',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.download_outlined),
            activeIcon: Icon(Icons.download),
            label: 'Entrées',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.medication_outlined),
            activeIcon: Icon(Icons.medication),
            label: 'Médicaments',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.point_of_sale_outlined),
            activeIcon: Icon(Icons.point_of_sale),
            label: 'Ventes',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.event_busy_outlined),
            activeIcon: Icon(Icons.event_busy),
            label: 'Lots',
          ),
        ],
      ),
    );
  }
}
