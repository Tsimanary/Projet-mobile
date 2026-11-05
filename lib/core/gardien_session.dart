import 'package:flutter/material.dart';

import '../pages/verrouillage.dart';
import 'biometrie.dart';
import 'verrouillage.dart';

/// Supervise la session : affiche l'écran de déverrouillage au démarrage
/// lorsqu'un code d'accès est configuré, et **reverrouille** l'application
/// après un passage en arrière-plan prolongé.
///
/// Placé dans `MaterialApp.builder`, l'écran de verrouillage recouvre toutes
/// les routes (y compris les dialogues) : rien ne peut être lu sans le code.
class GardienSession extends StatefulWidget {
  const GardienSession({
    super.key,
    required this.child,
    this.delaiReactivation = const Duration(seconds: 30),
  });

  final Widget child;

  /// Temps passé en arrière-plan au-delà duquel l'application se reverrouille.
  final Duration delaiReactivation;

  @override
  State<GardienSession> createState() => _GardienSessionState();
}

class _GardienSessionState extends State<GardienSession>
    with WidgetsBindingObserver {
  bool _codeActif = false;
  bool _verrouille = false;
  DateTime? _debutArrierePlan;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Verrouillage.actif.addListener(_surChangementDeCode);
    _initialiser();
  }

  @override
  void dispose() {
    Verrouillage.actif.removeListener(_surChangementDeCode);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _initialiser() async {
    var actif = false;
    try {
      actif = (await Verrouillage.etat()).actif;
    } catch (_) {
      // Coffre ou base indisponible : on n'enferme pas l'utilisateur dehors.
      actif = false;
    }

    // La base est ouverte à ce stade : on peut relire le réglage biométrique
    // avant d'afficher l'écran de verrouillage (sinon le bouton « empreinte »
    // n'apparaîtrait qu'au second affichage).
    await Biometrie.charger();

    if (!mounted) return;
    setState(() {
      _codeActif = actif;
      _verrouille = actif;
    });
  }

  void _surChangementDeCode() {
    final actif = Verrouillage.actif.value;
    if (!mounted || actif == _codeActif) return;
    setState(() {
      _codeActif = actif;
      if (actif) _verrouille = true;
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.inactive) {
      _debutArrierePlan ??= DateTime.now();
      return;
    }

    if (state == AppLifecycleState.resumed) {
      final debut = _debutArrierePlan;
      _debutArrierePlan = null;
      if (debut == null || !_codeActif) return;
      if (DateTime.now().difference(debut) >= widget.delaiReactivation) {
        setState(() => _verrouille = true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        widget.child,
        if (_verrouille)
          Positioned.fill(
            child: EcranVerrouillage(
              onDeverrouille: () {
                if (mounted) setState(() => _verrouille = false);
              },
            ),
          ),
      ],
    );
  }
}
