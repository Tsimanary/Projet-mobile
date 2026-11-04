# Corrections apportées — `appharmacie`

**Date :** 4 novembre 2026
**Référence :** `docs/AUDIT_PROJET.md` (audit initial, branche `main` @ `49a2a84`)

Ce document liste, bug par bug, ce qui a été corrigé et où. Les éléments
volontairement laissés de côté sont indiqués en fin de document.

---

## 1. Bugs bloquants (corrigés)

### B1 — Double incrément du stock à l'entrée
**Avant :** `addEntree.dart` appelait `updateMedicStock(+q)` **puis**
`insertEntree()`, qui incrémentait encore le stock → une entrée de 10 sur un
stock 0 donnait 20.

**Après :**
- l'écran ne touche plus au stock (`lib/dialog/addEntree.dart`) ;
- `insertEntree()` (`lib/SQLite/sqlite.dart`) insère **toujours** une nouvelle
  ligne et incrémente le stock **une seule fois**, dans une transaction.

**Test de non-régression :** `StockRules.apresEntree` (`test/stock_rules_test.dart`).

### B2 — `updateEntree` écrasait le stock avec `SUM(stockEntr)`
**Avant :** `UPDATE medics SET stockMed = (SELECT SUM(stockEntr) ...)` : les
ventes disparaissaient du calcul.

**Après :** application d'un **delta** (`StockRules.apresModificationEntree`),
écriture d'une valeur absolue calculée dans la transaction. Le changement de
médicament d'une entrée est géré (débit de l'ancien, crédit du nouveau).

**Test :** « 10 entrés, 10 vendus → stock 0 ; entrée modifiée 10 → 12 ⇒ stock 2 ».

### B3 — Vente multi-lignes non atomique
**Avant :** `insertAchat()` appelé ligne par ligne ; en cas de rupture en
milieu de panier, les lignes précédentes restaient enregistrées sans facture.

**Après :** `insertAchats(List<Achat>)` vérifie **toutes** les lignes (stock
cumulé par médicament) avant la moindre écriture, puis écrit dans une seule
transaction. `lib/dialog/addAchat.dart` utilise cette méthode et affiche les
erreurs `StockInsuffisantException` / `EntiteIntrouvableException`.

### B4 — Crash du tableau de bord (`firstWhere` sur médicament supprimé)
**Avant :** `medics.firstWhere(...)` levait `StateError`.

**Après :** `lib/pages/accueil.dart` agrège les ventes en SQL
(`ventesParMedicament()`), ignore les ventes orphelines et n'utilise plus
`firstWhere`. En complément, `deleteMedic()` **refuse** la suppression d'un
médicament possédant un historique (`MedicamentUtiliseException`).

### B5 — Modification / suppression de vente ne recalait pas le stock
**Après :** `updateAchat()` applique la différence de quantité
(`StockRules.apresModificationVente`) et gère le changement de médicament ;
`deleteAchat()` recrédite exactement la quantité enregistrée. Les deux
opérations sont transactionnelles.

---

## 2. Bugs majeurs (corrigés)

| Réf. | Correction | Fichiers |
|---|---|---|
| B6 — `int.parse` non protégés | `Validators.versEntier` / `int.tryParse` partout, `FilteringTextInputFormatter.digitsOnly`, `Form` + validateurs | tous les formulaires |
| B7 — Import sensible à la casse | `package:appharmacie/authentification/...` → `Authentification` ; `HomePage` déplacé dans `lib/pages/home.dart` | `lib/main.dart` |
| B8 — `pdf` / `printing` en `dev_dependencies` | déplacés en `dependencies` | `pubspec.yaml` |
| B9 — Test du projet en échec | test « compteur » supprimé, remplacé par 12 tests (dont 9 sur le stock) | `test/` |
| B10 — Débordement de l'image de connexion | `ConstrainedBox` + `BoxFit.contain` + `errorBuilder` | `lib/Authentification/login.dart` |
| B11 — « Vendu : prix » au lieu de la quantité | le top 5 affiche la quantité vendue réelle | `lib/pages/accueil.dart` |
| B12 — Titre « rupture » avec seuil `< 5` | deux sections distinctes : *Rupture* (0) et *Stock faible* (1 → 5) | `lib/pages/accueil.dart` |
| B13 — Date de vente en texte libre | sélecteur de date, date du jour par défaut, parsing tolérant des anciennes valeurs | `addAchat.dart`, `achat.dart`, `core/format.dart` |
| B14 — Code mort (`MedicSearchDelegate`, `_selectedMedic`) | supprimé (~80 lignes) | `lib/dialog/addAchat.dart` |
| B15 — Inscription échouant silencieusement | erreur affichée (`UtilisateurDejaExisteException`), retour à l'écran de connexion en cas de succès | `signup.dart` |

---

## 3. Intégrité du modèle de données

| Avant | Après |
|---|---|
| `DatabaseHelper` instancié 9 fois, `initDB()` rappelée à chaque appel | **singleton** + ouverture paresseuse unique (`Future<Database> get database`) |
| `version: 1`, aucun `onUpgrade` | **version 2** + `onUpgrade` + ajout de colonnes idempotent |
| Aucun index | index sur `medics.numMed`, `entrees.numMed`, `achats.numMed`, `achats.numAchat` |
| Numéro de médicament en doublon possible | contrôle d'unicité en amont (`MedicamentDejaExisteException`) ; renommage bloqué si historique |
| Prix de vente recalculé avec le prix courant | colonne `achats.prixUnitaire` figée + migration des lignes existantes |
| `stockMed` modifiable via l'écran d'édition | le stock n'est **jamais** édité directement (affiché en lecture seule) |
| Aucun `ORDER BY` | listes triées (désignation, date décroissante) |
| Modèles fragiles (`json["x"] as int`) | parsing tolérant (`as num?`, valeurs par défaut) |

---

## 4. Sécurité

- **Mots de passe hachés** : sel aléatoire par utilisateur (`Random.secure()`),
  SHA-256(`sel::motDePasse`), colonne `users.usrSalt` (migration v2).
  Les comptes hérités en clair sont convertis **à la première connexion réussie**
  (`lib/SQLite/sqlite.dart`, `login()`).
- **Sauvegarde Android désactivée** : `android:allowBackup="false"` +
  `android:fullBackupContent="false"` (la base n'est plus exfiltrable via `adb backup`).
- Aucune requête SQL concaténée (conservé).

---

## 5. Qualité et maintenabilité

- `lib/core/` introduit : exceptions métier, validateurs, règles de stock pures,
  formatage, sécurité, thème, widgets partagés.
- **Duplication UI supprimée** : `ChampTexte` (1 composant au lieu de dizaines de
  `TextField` stylés à la main), `confirmerAction` (1 dialogue au lieu de 3 copies),
  `afficherMessage` (Snackbar uniforme).
- **Thème centralisé** (Material 3) : fini les `Colors.green` codés en dur,
  contrastes corrigés (texte foncé sur fond clair).
- **Navigation unifiée** : `GetMaterialApp`/GetX remplacés par `MaterialApp` +
  `Navigator` ; dépendance `get` retirée.
- **Cycle de vie** : tous les `TextEditingController` sont libérés (`dispose`),
  `setState` protégés par `if (!mounted) return;`.
- **PDF découplé de l'UI** : `generateInvoicePdf` reçoit des `LigneFacture`
  (plus de `TextEditingController`) → testable, et n'imprime que des lignes
  réellement enregistrées.
- **Dépendances** : `charts_flutter` (abandonné), `charts_flutter_new`,
  `flutter_charts`, `json_path`, `path_provider`, `cupertino_icons` et `get`
  supprimés ; `intl` débloqué en `^0.19.0` ; `crypto` ajouté.
- **README** réécrit (installation, règles métier, structure, sécurité, limites).

---

## 6. Non corrigé — décisions à prendre

Ces points relèvent de choix produit ou nécessitent une refonte plus large
(voir `docs/AUDIT_PROJET.md`, plans P2 à P4). **Les lots et péremptions, listés
ici lors de la première itération, ont été traités à l'itération 3 (section 8).**

1. **Sauvegarde / restauration** : requiert un package de partage (`share_plus`)
   ou un backend.
3. **Rôles et gestion des utilisateurs** : aujourd'hui un compte, un appareil.
   L'inscription reste ouverte ; à restreindre dès qu'un écran d'administration existe.
4. **Argon2id / bcrypt** : SHA-256 salé est un progrès, pas l'état de l'art.
5. **Signature de release et `applicationId`** (`com.example.appharmacie`) :
   nécessite votre keystore et votre domaine.
6. **Migration de `medics.numMed` en `UNIQUE` SQL** : impossible sur une base
   existante sans reconstruire la table ; l'unicité est contrôlée côté code.
7. **Montants en `double`** : déjà remplacés par des entiers partout dans le
   nouveau code ; les anciennes valeurs stockées restent des entiers.

---

## 7. Vérifications à effectuer sur votre poste

Je n'ai pas pu exécuter Flutter dans cet environnement (SDK absent). À lancer :

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

Le code a été contrôlé statiquement (équilibrage syntaxique, résolution de tous
les imports, vérification des appels à la couche de données). Si `flutter analyze`
signale un point, ce sera très probablement une règle de style
(`prefer_const_constructors`, `use_build_context_synchronously`) et non une
erreur de compilation.

---

## 8. Itération 3 — lots, péremption, dates ISO, CI

### 8.1 Schéma v3 : lots et journal de mouvements

| Avant | Après |
|---|---|
| Stock porté uniquement par `medics.stockMed`, sans traçabilité | `lots` (quantité reçue/restante, péremption, réception) + `mouvements_stock` (journal) |
| Aucune péremption | chaque entrée crée/complète un lot daté |
| Dates `JJ/MM/AAAA` non triables | dates stockées en `AAAA-MM-JJ` (tri, filtres, alertes) |
| Sorties sans lien avec les lots | consommation **FEFO** tracée par lot |
| Suppression d'entrée dangereuse | refusée si le lot a déjà été partiellement vendu |

**Invariant central** : `medics.stockMed == SUM(lots.quantiteRestante)`. Il est
recalculé (`_recalculerStock`) à chaque transaction, ce qui rend la
synchronisation impossible à casser.

**Migration v2 → v3** (`_migrerVers3`) : ajout des colonnes de lot sur
`entrees`, création des tables, conversion des dates historiques, puis reprise
du stock existant dans un lot technique `STOCK-REPRIS` **sans péremption**
(aucune donnée inventée). Les stocks négatifs éventuels sont remis à zéro.

**Annulation par journal** : chaque vente écrit un mouvement par lot avec la
référence `ACHAT:<id>`. Modifier ou supprimer la vente rejoue ce journal à
l'envers, puis réapplique la nouvelle quantité — dans la même transaction, donc
sans état intermédiaire incohérent.

### 8.2 Règle FEFO testable

`lib/core/stock_rules.dart` expose désormais une allocation pure :

```dart
List<AllocationLot> allouerLots({required List<LotDisponible> lots, required int quantite});
int quantiteAllouee(List<AllocationLot> allocations);
```

Tri par péremption croissante, lots sans date en dernier, allocation partielle
si le stock ne suffit pas (l'appelant valide ensuite avec
`StockRules.verifierDisponibilite`). **6 tests dédiés** couvrent l'ordre, les
lots vides, l'allocation partielle et les quantités invalides.

### 8.3 Interface

- **Nouvelle entrée** : numéro de lot + date de péremption (obligatoire) +
  date de réception, avec sélecteurs de date.
- **Onglet « Lots »** : tous les lots disponibles triés FEFO, filtres
  *Tous / ≤ 90 j / ≤ 30 j / Périmés*, compteurs d'alerte.
- **Tableau de bord** : carte « Péremptions (≤ 90 jours) » avec les 4 lots les
  plus urgents.
- **Liste des entrées** : lot et péremption affichés, en rouge si périmé.

### 8.4 Dates ISO

`lib/core/format.dart` : `formaterDateIso`, `versIso`, `afficherDate`,
`joursAvant`. Toute saisie reste en `JJ/MM/AAAA`, tout stockage est en
`AAAA-MM-JJ`, et la lecture tolère les anciens formats.

### 8.5 Intégration continue

`.github/workflows/flutter.yml` : `flutter pub get`, `flutter analyze`,
`flutter test` sur chaque pull request et sur `main`.

### 8.6 Tests

Passage de 12 à **23 tests** : disponibilité, FEFO, montants, validateurs,
dates ISO, hachage, démarrage de l'application.

### 8.7 Toujours ouvert

- **Sauvegarde / restauration** : nécessite un choix de package (`share_plus`)
  ou un backend — décision produit.
- Rôles et administration des comptes, Argon2id, chiffrement de la base.
- Signature de release, `applicationId`, icônes, fiche Play Store.
- Codes-barres (scan de lot) et inventaire physique.
