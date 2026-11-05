# AppHarmacie

Application mobile **Flutter** de gestion d'officine : médicaments, entrées de
stock **par lot**, ventes, péremptions, facturation PDF et tableau de bord.

Données stockées localement (SQLite) — l'application fonctionne hors ligne.

[![CI](https://github.com/Tsimanary/Projet-mobile/actions/workflows/flutter.yml/badge.svg)](https://github.com/Tsimanary/Projet-mobile/actions/workflows/flutter.yml)

---

## Fonctionnalités

| Module | Contenu |
|---|---|
| **Authentification** | Comptes locaux, mots de passe **Argon2id**, deux rôles |
| **Tableau de bord** | Recette cumulée, ruptures, stocks faibles, péremptions ≤ 90 j, top 5 des ventes |
| **Médicaments** | Ajout, recherche, modification, suppression protégée |
| **Entrées** | Réception par lot (numéro de lot + date de péremption), historique complet |
| **Ventes** | Vente multi-lignes, contrôle de stock, consommation **FEFO**, facture PDF A4 |
| **Lots** | Suivi des péremptions, filtres (≤ 90 j, ≤ 30 j, périmés), ordre FEFO |
| **Sauvegarde** | Export complet **chiffré par phrase secrète** (AES-256-GCM + Argon2id), partage système, restauration transactionnelle |
| **Utilisateurs** | Création de comptes, changement de rôle, suppression encadrée (gestionnaire) |
| **Sécurité** | Base SQLite **chiffrée** (SQLCipher), **code d'accès** 4–6 chiffres, **déverrouillage par empreinte**, reverrouillage automatique |

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
10. **Une sauvegarde = un fichier versionné** contenant toutes les tables,
    **chiffré en AES-256-GCM** avec une clé dérivée de la phrase secrète par
    Argon2id ; la restauration est transactionnelle (tout ou rien) et recalcule
    le stock depuis les lots.
11. **La base est chiffrée** (SQLCipher). La clé de 32 octets est générée sur
    l'appareil et conservée par le Keystore du système ; un fichier `.db`
    copié est inutilisable sans elle. Les bases existantes sont converties
    automatiquement, sans perte.
12. **Un code d'accès** protège l'application : empreinte **Argon2id** (jamais
    le code), 5 essais avant un blocage de 5 minutes, reverrouillage après 30 s
    en arrière-plan.
13. **Les secrets sont dérivés en Argon2id** (format PHC autoportant). Les
    empreintes SHA-256 héritées restent vérifiables et sont réécrites à la
    volée à la première saisie correcte.
14. **Deux rôles, appliqués par le code, pas par l'interface** : le vendeur
    consulte, vend et reçoit les livraisons ; le gestionnaire ajoute la
    correction/suppression des ventes et des entrées, le catalogue (donc les
    prix), les comptes, la sauvegarde/restauration et les réglages de sécurité.
    Chaque opération sensible appelle `Session.exigerGestionnaire` côté SQL :
    masquer un bouton ne suffit pas. La matrice est **fermée par défaut** et
    il reste toujours au moins un gestionnaire.

Ces règles sont couvertes par des tests (`test/`).

---

## Installation

```bash
flutter pub get
flutter run
```

Publication sur le Play Store : voir [`docs/PUBLICATION_PLAY_STORE.md`](docs/PUBLICATION_PLAY_STORE.md)
(clé de signature, `flutter build appbundle`, fiche Play Store, check-list).
Politique de confidentialité : [`docs/CONFIDENTIALITE.md`](docs/CONFIDENTIALITE.md)
et sa version publiable [`docs/confidentialite.html`](docs/confidentialite.html).

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
- `test/verrouillage_test.dart` — politique du code d'accès, empreintes
- `test/chiffrement_test.dart` — chiffrement de la sauvegarde (aller-retour,
  mauvaise phrase, fichier altéré)
- `test/securite_test.dart` — hachage et vérification des mots de passe
- `test/roles_test.dart` — matrice des droits, lecture des rôles, session,
  garde du dernier gestionnaire
- `test/biometrie_test.dart` — activation, essais, repli sur le code, pannes
  du capteur
- `test/widget_test.dart` — démarrage de l'application

**95 tests** au total (`flutter test`).

---

## Structure

```
lib/
├── main.dart                 # Application (thème + écran de démarrage)
├── core/                     # Socle transverse
│   ├── backup.dart           # Export / partage / restauration du fichier
│   ├── biometrie.dart        # Politique du déverrouillage par empreinte
│   ├── biometrie_systeme.dart # Branchement local_auth + réglage en base
│   ├── backup_format.dart    # Format JSON versionné (pur, testable)
│   ├── chiffrement.dart      # Enveloppe AES-256-GCM de la sauvegarde
│   ├── coffre.dart           # Clé de chiffrement (Keystore du système)
│   ├── gardien_session.dart  # Écran de verrouillage + reverrouillage auto
│   ├── verrouillage.dart     # Code d'accès (empreinte, tentatives, blocage)
│   ├── verrouillage_regles.dart # Politique du code (pure, testable)
│   ├── exceptions.dart       # Exceptions métier (messages utilisateur)
│   ├── feedback.dart         # Snackbars
│   ├── format.dart           # Montants, dates ISO, parsing tolérant
│   ├── roles.dart            # Rôles, matrice des droits, règles de comptes
│   ├── session.dart          # Compte connecté et vérification des droits
│   ├── securite.dart         # Hachage des mots de passe
│   ├── stock_rules.dart      # Règles pures : disponibilité + FEFO
│   ├── theme.dart            # Palette et thème Material 3
│   ├── validators.dart       # Validateurs de formulaires
│   └── widgets/              # ChampTexte, dialogue de confirmation
├── Models/                   # Entités (Medic, Lot, Entree, Achat, Users)
├── SQLite/sqlite.dart        # Données, transactions, lots, migrations
├── Authentification/         # Connexion, création de compte
├── dialog/                   # Formulaires (médicament, entrée, vente)
├── pages/                    # Écrans (accueil, médicaments, entrées, ventes, lots,
│                             #  sauvegarde, sécurité, utilisateurs, verrouillage)
└── assets/images/

android/                      # AGP 8.3.2, Gradle 8.4, Kotlin 1.9.22, JDK 17, minSdk 24
docs/                         # audit, corrections, sécurité, publication, confidentialité
store/                        # icônes du Play Store (1024 et 512 px)
```

### Base de données (schéma v5)

| Table | Rôle |
|---|---|
| `users` | Comptes (`usrPassword` = hachage Argon2id, `usrRole` = rôle) |
| `medics` | Catalogue + stock courant (projection des lots) |
| `lots` | Lots reçus : quantité, restant, péremption, date de réception |
| `mouvements_stock` | Journal des entrées/sorties (`reference` = `ENTREE:<id>` ou `ACHAT:<id>`) |
| `entrees` | Historique des réceptions (une ligne par réception, avec lot et `auteur`) |
| `achats` | Lignes de vente, avec `prixUnitaire` figé et `auteur` |

**Migrations** : `onUpgrade` gère v1 → v2 (hachage, prix figé), v2 → v3
(lots, mouvements, dates ISO), v3 → v4 (paramètres) puis v4 → v5 (rôles,
auteur des mouvements). Les comptes créés avant les rôles deviennent
**gestionnaires** : ce sont les propriétaires de l'installation. Le stock existant est repris dans un lot
technique `STOCK-REPRIS` sans péremption : aucune donnée n'est inventée et
l'invariant `stockMed == Σ quantiteRestante` est vrai dès la migration.

---

## Sécurité

- **Base chiffrée** (SQLCipher) : clé de 32 octets dans le Keystore Android,
  jamais écrite dans un fichier de l'application.
- **Code d'accès** 4–6 chiffres : empreinte salée, blocage temporaire après 5
  essais, reverrouillage après 30 s d'inactivité en arrière-plan.
- **Mots de passe et code d'accès hachés en Argon2id** (19 Mio, 2 passes, sel
  aléatoire) — coût mémoire et temps à chaque tentative, empreintes héritées
  migrées automatiquement.
- Sauvegarde Android désactivée (`android:allowBackup="false"`).
- Requêtes SQL entièrement paramétrées.
- **Sauvegardes chiffrées** par phrase secrète (AES-256-GCM), enveloppe JSON
  autoportante (sel et nonce aléatoires à chaque export, contenu authentifié).
- Modèle de menace complet et limites : [`docs/SECURITE.md`](docs/SECURITE.md).
- **Deux rôles** vérifiés dans la couche données : un vendeur ne peut ni
  supprimer, ni corriger, ni changer un prix, même en contournant l'interface.
- **Déverrouillage par empreinte** (`local_auth`) : le capteur du système,
  jamais le code du téléphone à la place du code de l'application ; l'option
  ne s'active qu'après une empreinte reconnue et rend la main au code après
  trois échecs. Le compteur anti-force-brute du code reste inchangé.
- **Une seule permission Android** : `USE_BIOMETRIC` (permission « normale »,
  sans dialogue à l'installation, sans accès aux données). Aucun accès à
  internet, au stockage ou à la localisation : les données ne sortent du
  téléphone que par l'export de sauvegarde, déclenché par l'utilisateur.

**Avant une mise en production** : blocage des captures d'écran
(`FLAG_SECURE`).

---

## Limites connues

- Les données vivent sur **un seul appareil** : la sauvegarde JSON permet de
  migrer ou de restaurer, pas de synchroniser plusieurs postes en temps réel.
- Les comptes sont locaux à l'appareil : pas de synchronisation des rôles
  entre plusieurs téléphones.
- Facture sans mentions légales ni TVA.
- La signature de release nécessite **votre** keystore
  (`android/key.properties`, voir `docs/PUBLICATION_PLAY_STORE.md`) ; sans lui,
  les builds sont signés avec les clés de debug.
- **Phrase secrète de sauvegarde oubliée** = sauvegarde perdue : il n'existe
  aucune récupération (contrepartie assumée du chiffrement).
- Pas de `FLAG_SECURE` : captures d'écran et miniatures dans le sélecteur
  d'applications restent possibles.
- Déverrouillage biométrique **en plus** du code, jamais à sa place : pas de
  « code de secours biométrique », et Android 7.0 minimum (`local_auth`).
- Pas de journal d'audit consultable : la trace existe en base
  (`mouvements_stock`, colonnes `auteur`) mais n'a pas d'écran dédié.

Voir `docs/AUDIT_PROJET.md` (analyse initiale) et `docs/CORRECTIONS.md`
(journal des corrections).
