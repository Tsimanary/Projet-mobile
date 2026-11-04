# AppHarmacie

Application mobile **Flutter** de gestion d'officine : médicaments, entrées de
stock **par lot**, ventes, péremptions, facturation PDF et tableau de bord.

Données stockées localement (SQLite) — l'application fonctionne hors ligne.

[![CI](https://github.com/Tsimanary/Projet-mobile/actions/workflows/flutter.yml/badge.svg)](https://github.com/Tsimanary/Projet-mobile/actions/workflows/flutter.yml)

---

## Fonctionnalités

| Module | Contenu |
|---|---|
| **Authentification** | Compte local, mot de passe haché (sel + SHA-256) |
| **Tableau de bord** | Recette cumulée, ruptures, stocks faibles, péremptions ≤ 90 j, top 5 des ventes |
| **Médicaments** | Ajout, recherche, modification, suppression protégée |
| **Entrées** | Réception par lot (numéro de lot + date de péremption), historique complet |
| **Ventes** | Vente multi-lignes, contrôle de stock, consommation **FEFO**, facture PDF A4 |
| **Lots** | Suivi des péremptions, filtres (≤ 90 j, ≤ 30 j, périmés), ordre FEFO |
| **Sauvegarde** | Export JSON complet partagé (courriel, Drive) et restauration transactionnelle |

---

## Règles de gestion (garanties par le code)

1. **`medics.stockMed` est une projection des lots.** Il est recalculé
   (`SUM(lots.quantiteRestante)`) après chaque mouvement, dans une transaction :
   aucune saisie manuelle, aucune dérive possible.
2. **Une entrée = une ligne d'historique + un lot.** Le lot porte la péremption ;
   modifier une entrée annule puis réapplique son mouvement.
3. **Les sorties sont en FEFO** : le lot dont la péremption est la plus proche
   part en premier ; les lots sans date connue partent en dernier.
4. **Chaque mouvement est tracé** (`mouvements_stock`) : annuler ou modifier une
   vente remet exactement les quantités dans les bons lots.
5. **Une entrée dont le lot a déjà été partiellement vendu ne peut pas être
   supprimée** (message explicite) : on corrige par une nouvelle entrée/sortie.
6. **Une vente est atomique** : toutes les lignes sont validées avant la
   première écriture.
7. **Le prix est figé au moment de la vente** (`achats.prixUnitaire`) : changer
   un prix ne réécrit pas le chiffre d'affaires passé.
8. **Dates stockées en `AAAA-MM-JJ`**, affichées en `JJ/MM/AAAA`.
9. **Mots de passe hachés**, migration transparente des comptes existants.
10. **Une sauvegarde = un fichier JSON versionné** contenant toutes les tables ;
    la restauration est transactionnelle (tout ou rien) et recalcule le stock
    depuis les lots.

Ces règles sont couvertes par des tests (`test/`).

---

## Installation

```bash
flutter pub get
flutter run
```

> ⚠️ `pubspec.lock` n'est pas régénéré automatiquement dans ce dépôt :
> `flutter pub get` le met à jour.

Prérequis : Flutter ≥ 3.22 (Dart ≥ 3.4).

---

## Tests et intégration continue

```bash
flutter analyze
flutter test
```

La CI GitHub Actions (`.github/workflows/flutter.yml`) exécute `analyze` et
`test` sur chaque pull request et sur `main`.

- `test/stock_rules_test.dart` — disponibilité, allocation **FEFO**, montants
- `test/validators_test.dart` — validation, formatage, dates ISO
- `test/backup_format_test.dart` — format de sauvegarde, refus des fichiers invalides
- `test/securite_test.dart` — hachage et vérification des mots de passe
- `test/widget_test.dart` — démarrage de l'application

---

## Structure

```
lib/
├── main.dart                 # Application (thème + écran de démarrage)
├── core/                     # Socle transverse
│   ├── backup.dart           # Export / partage / restauration du fichier
│   ├── backup_format.dart    # Format JSON versionné (pur, testable)
│   ├── exceptions.dart       # Exceptions métier (messages utilisateur)
│   ├── feedback.dart         # Snackbars
│   ├── format.dart           # Montants, dates ISO, parsing tolérant
│   ├── securite.dart         # Hachage des mots de passe
│   ├── stock_rules.dart      # Règles pures : disponibilité + FEFO
│   ├── theme.dart            # Palette et thème Material 3
│   ├── validators.dart       # Validateurs de formulaires
│   └── widgets/              # ChampTexte, dialogue de confirmation
├── Models/                   # Entités (Medic, Lot, Entree, Achat, Users)
├── SQLite/sqlite.dart        # Données, transactions, lots, migrations
├── Authentification/         # Connexion, création de compte
├── dialog/                   # Formulaires (médicament, entrée, vente)
├── pages/                    # Écrans (accueil, médicaments, entrées, ventes, lots, sauvegarde)
└── assets/images/
```

### Base de données (schéma v3)

| Table | Rôle |
|---|---|
| `users` | Comptes (`usrPassword` = hachage, `usrSalt` = sel) |
| `medics` | Catalogue + stock courant (projection des lots) |
| `lots` | Lots reçus : quantité, restant, péremption, date de réception |
| `mouvements_stock` | Journal des entrées/sorties (`reference` = `ENTREE:<id>` ou `ACHAT:<id>`) |
| `entrees` | Historique des réceptions (une ligne par réception, avec lot) |
| `achats` | Lignes de vente, avec `prixUnitaire` figé |

**Migrations** : `onUpgrade` gère v1 → v2 (hachage, prix figé) puis v2 → v3
(lots, mouvements, dates ISO). Le stock existant est repris dans un lot
technique `STOCK-REPRIS` sans péremption : aucune donnée n'est inventée et
l'invariant `stockMed == Σ quantiteRestante` est vrai dès la migration.

---

## Sécurité

- Mots de passe hachés avec sel aléatoire (migration transparente).
- Sauvegarde Android désactivée (`android:allowBackup="false"`).
- Requêtes SQL entièrement paramétrées.

**Avant une mise en production** : Argon2id, chiffrement de la base
(`sqflite_sqlcipher`), rôles utilisateurs, verrouillage biométrique.

---

## Limites connues

- Les données vivent sur **un seul appareil** : la sauvegarde JSON permet de
  migrer ou de restaurer, pas de synchroniser plusieurs postes en temps réel.
- Un seul compte par installation (pas d'écran d'administration).
- Facture sans mentions légales ni TVA.
- Signature de release à configurer (`android/key.properties`, voir
  `docs/PUBLICATION_PLAY_STORE.md`).

Voir `docs/AUDIT_PROJET.md` (analyse initiale) et `docs/CORRECTIONS.md`
(journal des corrections).
