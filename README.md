# AppHarmacie

Application mobile **Flutter** de gestion d'officine : médicaments, entrées de
stock, ventes, facturation PDF et tableau de bord.

Données stockées localement (SQLite) — l'application fonctionne hors ligne.

---

## Fonctionnalités

| Module | Contenu |
|---|---|
| **Authentification** | Compte unique local, mot de passe haché (sel + SHA-256) |
| **Tableau de bord** | Recette cumulée, ruptures, stocks faibles, top 5 des ventes |
| **Médicaments** | Ajout, recherche, modification, suppression protégée |
| **Entrées** | Réceptions de stock historisées, modification/suppression avec ajustement |
| **Ventes** | Vente multi-lignes, contrôle de stock, facture PDF A4 imprimable |

---

## Règles de gestion (garanties par le code)

1. **Une seule source de vérité pour le stock** : `medics.stockMed` n'est
   modifié que par les entrées et les ventes, dans des transactions SQLite.
2. **Une entrée = une ligne d'historique.** Aucune fusion : modifier une entrée
   applique uniquement la **différence** au stock.
3. **Une vente est atomique.** Toutes les lignes sont validées avant la première
   écriture : impossible d'enregistrer une vente partielle.
4. **Le prix est figé au moment de la vente** (`achats.prixUnitaire`) : changer
   un prix ne réécrit pas le chiffre d'affaires passé.
5. **Un médicament avec historique ne peut pas être supprimé** (protection de
   l'intégrité des ventes et des entrées).
6. **Les mots de passe ne sont jamais stockés en clair.** Les comptes créés par
   les versions précédentes sont migrés automatiquement à la première connexion.

Ces règles sont couvertes par des tests unitaires (`test/stock_rules_test.dart`).

---

## Installation

```bash
flutter pub get
flutter run
```

> ⚠️ Le fichier `pubspec.lock` n'a pas été régénéré après le nettoyage des
> dépendances : `flutter pub get` le met à jour automatiquement.

Prérequis : Flutter ≥ 3.22 (Dart ≥ 3.4).

---

## Tests

```bash
flutter test
```

- `test/stock_rules_test.dart` — calculs de stock (entrées, ventes, modifications)
- `test/validators_test.dart` — validation de formulaires et formatage
- `test/securite_test.dart` — hachage et vérification des mots de passe
- `test/widget_test.dart` — démarrage de l'application et validation du formulaire

---

## Structure

```
lib/
├── main.dart                 # Application (thème + écran de démarrage)
├── core/                     # Socle transverse
│   ├── exceptions.dart       # Exceptions métier (messages utilisateur)
│   ├── feedback.dart         # Snackbars (succès / erreur)
│   ├── format.dart           # Montants, dates, parsing tolérant
│   ├── securite.dart         # Hachage des mots de passe
│   ├── stock_rules.dart      # Règles de stock pures et testables
│   ├── theme.dart            # Palette et thème Material 3
│   ├── validators.dart       # Validateurs de formulaires
│   └── widgets/              # ChampTexte, dialogue de confirmation
├── Models/                   # Entités (Medic, Entree, Achat, Users)
├── SQLite/sqlite.dart        # Accès aux données + transactions + migrations
├── Authentification/         # Connexion, création de compte
├── dialog/                   # Formulaires (médicament, entrée, vente)
├── pages/                    # Écrans (accueil, médicaments, entrées, ventes)
└── assets/images/            # Images
```

### Base de données

Version de schéma : **2** (migration automatique depuis la version 1).

| Table | Rôle |
|---|---|
| `users` | Comptes (`usrPassword` = hachage, `usrSalt` = sel) |
| `medics` | Catalogue + stock courant |
| `entrees` | Historique des réceptions (une ligne par réception) |
| `achats` | Lignes de vente, avec `prixUnitaire` figé |

---

## Sécurité

- Mots de passe hachés avec sel aléatoire (migration transparente des anciens comptes).
- Sauvegarde Android désactivée (`android:allowBackup="false"`).
- Requêtes SQL entièrement paramétrées (aucune injection possible).

**À faire avant une mise en production** : Argon2id au lieu de SHA-256, chiffrement
de la base (`sqflite_sqlcipher`), rôles utilisateurs, verrouillage biométrique.

---

## Limites connues

- Pas de gestion des **lots** ni des **dates de péremption** (exigence pharmaceutique).
- Pas de **sauvegarde / restauration** : les données vivent sur un seul appareil.
- Pas de synchronisation multi-postes.
- Un seul compte par installation (pas d'écran d'administration des utilisateurs).
- Facture sans mentions légales ni TVA.
- Signature de release encore en mode debug ; `applicationId` à personnaliser
  avant publication.

Voir `docs/AUDIT_PROJET.md` (analyse initiale) et `docs/CORRECTIONS.md`
(détail des corrections apportées).
