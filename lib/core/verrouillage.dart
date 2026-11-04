import 'package:flutter/foundation.dart';

import '../SQLite/sqlite.dart';
import 'securite.dart';
import 'verrouillage_regles.dart';

/// État courant du code d'accès.
class EtatVerrouillage {
  const EtatVerrouillage({
    required this.actif,
    this.tentatives = 0,
    this.finBlocage,
  });

  /// Un code est-il configuré ?
  final bool actif;

  /// Essais ratés depuis le dernier succès.
  final int tentatives;

  /// Fin du blocage temporaire, ou `null`.
  final DateTime? finBlocage;

  bool get bloque =>
      finBlocage != null && finBlocage!.isAfter(DateTime.now());

  int get tentativesRestantes {
    final restantes = ReglesPin.tentativesMax - tentatives;
    return restantes < 0 ? 0 : restantes;
  }

  Duration get tempsRestant {
    final fin = finBlocage;
    if (fin == null) return Duration.zero;
    return ReglesPin.blocageRestant(fin: fin);
  }
}

/// Code d'accès à l'application (4 à 6 chiffres).
///
/// Le code n'est **jamais** stocké : seule une empreinte salée est conservée
/// dans la table `parametres` de la base chiffrée. Il protège l'accès à un
/// téléphone déverrouillé, pas le fichier lui-même (chiffré par la clé
/// conservée dans le coffre du système).
class Verrouillage {
  const Verrouillage._();

  static const String _cleSel = 'securite.pin.sel';
  static const String _cleHash = 'securite.pin.hash';
  static const String _cleEchecs = 'securite.pin.echecs';
  static const String _cleFinBlocage = 'securite.pin.fin_blocage';

  static final DatabaseHelper _base = DatabaseHelper();

  /// Notifié quand un code est activé ou désactivé (l'écran de garde écoute).
  static final ValueNotifier<bool> actif = ValueNotifier<bool>(false);

  /// Lit l'état courant et purge un blocage expiré.
  static Future<EtatVerrouillage> etat() async {
    final sel = await _base.lireParametre(_cleSel);
    final estActif = sel != null && sel.isNotEmpty;

    final echecs = int.tryParse(await _base.lireParametre(_cleEchecs) ?? '') ?? 0;
    final texteFin = await _base.lireParametre(_cleFinBlocage);
    final fin = texteFin == null ? null : DateTime.tryParse(texteFin);

    if (fin != null && !fin.isAfter(DateTime.now())) {
      await _reinitialiserEchecs();
      actif.value = estActif;
      return EtatVerrouillage(actif: estActif);
    }

    actif.value = estActif;
    return EtatVerrouillage(
      actif: estActif,
      tentatives: echecs,
      finBlocage: fin,
    );
  }

  /// Définit (ou remplace) le code d'accès.
  static Future<void> definir(String pin) async {
    if (!ReglesPin.estValide(pin)) {
      throw ArgumentError(
        'Le code doit comporter ${ReglesPin.longueurMin} à '
        '${ReglesPin.longueurMax} chiffres.',
      );
    }

    final sel = Securite.genererSel();
    await _base.ecrireParametre(_cleSel, sel);
    await _base.ecrireParametre(_cleHash, Securite.hasher(pin, sel));
    await _reinitialiserEchecs();
    actif.value = true;
  }

  /// Vérifie un code et gère les tentatives (blocage temporaire).
  static Future<bool> verifier(String pin) async {
    final sel = await _base.lireParametre(_cleSel);
    final hash = await _base.lireParametre(_cleHash);
    if (sel == null || hash == null) return false;

    final etatCourant = await etat();
    if (etatCourant.bloque) return false;

    if (Securite.verifier(motDePasse: pin, sel: sel, hashAttendu: hash)) {
      await _reinitialiserEchecs();
      return true;
    }

    final echecs = etatCourant.tentatives + 1;
    await _base.ecrireParametre(_cleEchecs, '$echecs');

    if (ReglesPin.doitBloquer(echecs)) {
      final fin = ReglesPin.finBlocage(
        echecs: echecs,
        dernierEchec: DateTime.now(),
      );
      if (fin != null) {
        await _base.ecrireParametre(_cleFinBlocage, fin.toIso8601String());
      }
    }

    return false;
  }

  /// Supprime le code d'accès (l'application ne demande plus rien au démarrage).
  static Future<void> desactiver() async {
    await _base.supprimerParametre(_cleSel);
    await _base.supprimerParametre(_cleHash);
    await _reinitialiserEchecs();
    actif.value = false;
  }

  static Future<void> _reinitialiserEchecs() async {
    await _base.supprimerParametre(_cleEchecs);
    await _base.supprimerParametre(_cleFinBlocage);
  }
}
