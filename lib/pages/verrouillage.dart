import 'dart:async';

import 'package:flutter/material.dart';

import '../core/biometrie.dart';
import '../core/theme.dart';
import '../core/verrouillage.dart';
import '../core/verrouillage_regles.dart';

/// Écran de déverrouillage : pavé numérique et points de saisie.
///
/// Affiché au démarrage (et au retour d'arrière-plan) dès qu'un code d'accès
/// est configuré. Appelle [onDeverrouille] après un code correct.
class EcranVerrouillage extends StatefulWidget {
  const EcranVerrouillage({super.key, required this.onDeverrouille});

  final VoidCallback onDeverrouille;

  @override
  State<EcranVerrouillage> createState() => _EcranVerrouillageState();
}

class _EcranVerrouillageState extends State<EcranVerrouillage> {
  String _saisie = '';
  String? _erreur;
  bool _verification = false;
  EtatVerrouillage? _etat;
  Timer? _minuteur;

  /// Le bouton du capteur est-il affiché ?
  bool _biometriePossible = false;
  bool _biometrieEnCours = false;
  String? _infoBiometrie;

  @override
  void initState() {
    super.initState();
    _chargerEtat();
    _preparerBiometrie();
    // Rafraîchit le compte à rebours pendant un blocage.
    _minuteur = Timer.periodic(const Duration(seconds: 1), (_) {
      final etat = _etat;
      if (etat != null && etat.bloque && mounted) {
        setState(() => _etat = etat);
      }
    });
  }

  @override
  void dispose() {
    _minuteur?.cancel();
    super.dispose();
  }

  Future<void> _chargerEtat() async {
    try {
      final etat = await Verrouillage.etat();
      if (!mounted) return;
      setState(() => _etat = etat);
    } catch (_) {
      // Base momentanément indisponible : on laisse la saisie possible.
    }
  }

  bool get _bloque => _etat?.bloque ?? false;

  /// Relit le réglage puis propose le capteur, une fois, à l'ouverture.
  Future<void> _preparerBiometrie() async {
    await Biometrie.charger();
    if (!Biometrie.estActive) return;

    final disponible = await Biometrie.disponible();
    if (!mounted) return;

    if (!disponible) {
      setState(() {
        _biometriePossible = false;
        _infoBiometrie = ReglesBiometrie.messageIndisponible;
      });
      return;
    }

    setState(() {
      _biometriePossible = Biometrie.peutProposer;
      _infoBiometrie = null;
    });

    if (_biometriePossible) await _tenterBiometrie();
  }

  /// Tente le déverrouillage biométrique. Tout échec laisse le pavé numérique
  /// utilisable : la biométrie est un raccourci, jamais une obligation.
  Future<void> _tenterBiometrie() async {
    if (_biometrieEnCours || _verification) return;
    if (!Biometrie.peutProposer) {
      if (mounted) setState(() => _biometriePossible = false);
      return;
    }

    setState(() {
      _biometrieEnCours = true;
      _erreur = null;
      _infoBiometrie = null;
    });

    final resultat = await Biometrie.verifier();
    if (!mounted) return;

    var possible = false;
    var erreur = _erreur;
    var info = _infoBiometrie;

    if (resultat == ResultatBiometrie.reussi) {
      erreur = null;
      info = null;
    } else if (resultat == ResultatBiometrie.echec) {
      erreur = ReglesBiometrie.messageEchec(Biometrie.echecsConsecutifs);
      info = null;
      possible = Biometrie.peutProposer;
    } else if (resultat == ResultatBiometrie.verrouillee) {
      erreur = ReglesBiometrie.messageVerrouille;
      info = null;
    } else if (resultat == ResultatBiometrie.indisponible) {
      info = ReglesBiometrie.messageIndisponible;
    }

    setState(() {
      _biometrieEnCours = false;
      _biometriePossible = possible;
      _erreur = erreur;
      _infoBiometrie = info;
      if (resultat == ResultatBiometrie.verrouillee) _saisie = '';
    });

    if (resultat == ResultatBiometrie.reussi) widget.onDeverrouille();
  }

  void _ajouter(String chiffre) {
    if (_verification || _bloque) return;
    if (_saisie.length >= ReglesPin.longueurMax) return;

    setState(() {
      _saisie += chiffre;
      _erreur = null;
    });

    if (_saisie.length == ReglesPin.longueurMax) {
      _valider();
    }
  }

  void _effacer() {
    if (_verification || _saisie.isEmpty) return;
    setState(() {
      _saisie = _saisie.substring(0, _saisie.length - 1);
      _erreur = null;
    });
  }

  Future<void> _valider() async {
    if (_verification || _saisie.isEmpty) return;

    if (_saisie.length < ReglesPin.longueurMin) {
      setState(() {
        _erreur =
            'Le code comporte au moins ${ReglesPin.longueurMin} chiffres.';
      });
      return;
    }

    setState(() => _verification = true);

    var accepte = false;
    EtatVerrouillage? etat;
    try {
      accepte = await Verrouillage.verifier(_saisie);
      etat = await Verrouillage.etat();
    } catch (_) {
      accepte = false;
    }

    if (!mounted) return;

    final etatFinal = etat;
    setState(() {
      _verification = false;
      _etat = etatFinal;
      _saisie = '';
      if (accepte) {
        _erreur = null;
      } else if (etatFinal != null && etatFinal.bloque) {
        _erreur = 'Trop de tentatives. Réessayez dans '
            '${ReglesPin.formaterDuree(etatFinal.tempsRestant)}.';
      } else {
        final restantes = etatFinal?.tentativesRestantes ?? 0;
        _erreur = 'Code incorrect. Encore $restantes essai(s).';
      }
    });

    if (accepte) {
      // Le code a fait ses preuves : le compteur biométrique repart à zéro
      // pour le prochain verrouillage.
      Biometrie.reinitialiserEssais();
      widget.onDeverrouille();
    }
  }

  @override
  Widget build(BuildContext context) {
    final etat = _etat;

    return Material(
      color: Colors.white,
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: 72,
                  height: 72,
                  decoration: const BoxDecoration(
                    color: AppColors.vertSurface,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.lock_outline,
                    size: 34,
                    color: AppColors.vert,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Code d\'accès',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  _verification
                      ? 'Vérification…'
                      : _bloque
                          ? 'Application bloquée temporairement'
                          : 'Saisissez votre code pour continuer',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.gris),
                ),
                if (_bloque && etat != null) ...<Widget>[
                  const SizedBox(height: 6),
                  Text(
                    'Réessayez dans ${ReglesPin.formaterDuree(etat.tempsRestant)}',
                    style: const TextStyle(
                      color: AppColors.rouge,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                _points(),
                SizedBox(
                  height: 46,
                  child: Center(
                    child: _verification
                        // Argon2id prend quelques centaines de millisecondes :
                        // on l'annonce plutôt que de laisser un écran figé.
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            _erreur ?? '',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: AppColors.rouge),
                          ),
                  ),
                ),
                if (_biometrieEnCours)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                if (_biometriePossible && !_biometrieEnCours)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: TextButton.icon(
                      onPressed: _verification ? null : _tenterBiometrie,
                      icon: const Icon(Icons.fingerprint),
                      label: const Text('Déverrouiller par empreinte'),
                    ),
                  ),
                if (!_biometriePossible &&
                    !_biometrieEnCours &&
                    _infoBiometrie != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      _infoBiometrie!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.gris,
                      ),
                    ),
                  ),
                _pave(),
                const SizedBox(height: 8),
                SizedBox(
                  height: 44,
                  child: TextButton(
                    onPressed: _saisie.length >= ReglesPin.longueurMin &&
                            !_bloque &&
                            !_verification
                        ? _valider
                        : null,
                    child: const Text('Valider'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _points() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        for (var i = 0; i < ReglesPin.longueurMax; i++)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 6),
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i < _saisie.length ? AppColors.vert : Colors.transparent,
              border: Border.all(color: AppColors.vert, width: 1.5),
            ),
          ),
      ],
    );
  }

  Widget _pave() {
    const lignes = <List<String>>[
      <String>['1', '2', '3'],
      <String>['4', '5', '6'],
      <String>['7', '8', '9'],
    ];

    return Column(
      children: <Widget>[
        for (final ligne in lignes)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              for (final chiffre in ligne) _touche(chiffre),
            ],
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const SizedBox(width: 80, height: 64),
            _touche('0'),
            _toucheEffacer(),
          ],
        ),
      ],
    );
  }

  Widget _touche(String chiffre) {
    return SizedBox(
      width: 80,
      height: 64,
      child: TextButton(
        onPressed: _bloque || _verification ? null : () => _ajouter(chiffre),
        style: TextButton.styleFrom(
          foregroundColor: Colors.black87,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
        ),
        child: Text(
          chiffre,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }

  Widget _toucheEffacer() {
    return SizedBox(
      width: 80,
      height: 64,
      child: TextButton(
        onPressed: _bloque || _verification ? null : _effacer,
        child: const Icon(Icons.backspace_outlined),
      ),
    );
  }
}
