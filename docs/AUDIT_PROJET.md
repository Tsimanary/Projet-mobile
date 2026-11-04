# Audit technique — `appharmacie` (Projet-mobile)

**Date :** 4 novembre 2026
**Périmètre :** dépôt complet, branche `main` @ `49a2a84` (« first push »)
**Volume analysé :** 16 fichiers Dart dans `lib/` (17 avec le test) / 2 877 lignes de code applicatif, 87 fichiers versionnés, 1 commit
**Méthode :** revue de code statique exhaustive, lecture du schéma SQL, audit des dépendances, revue de la configuration Android/iOS, analyse fonctionnelle métier

---

## 1. Synthèse exécutive

`appharmacie` est une application mobile **Flutter** de gestion d'officine (médicaments, entrées de stock, ventes, facturation PDF, tableau de bord). C'est un **prototype fonctionnel et démontrable**, avec une vraie intention produit : le module « facture + top ventes + alertes de stock » montre que l'auteur a réfléchi au métier, pas seulement à l'écran.

En revanche, l'application **n'est pas exploitable en production en l'état**, pour trois raisons structurelles :

1. **Les stocks se désynchronisent dès la deuxième saisie** — ce n'est pas un cas limite, c'est le comportement normal du code actuel (double incrément + écrasement par `SUM` + ventes partielles non atomiques).
2. **Le modèle de données ne permet pas la traçabilité pharmacie** — pas de lot, pas de péremption, pas de fournisseur, pas d'historique de prix, pas d'utilisateur rattaché à une opération.
3. **La sécurité et la confidentialité sont absentes** — mots de passe en clair, aucune notion de rôle, noms de clients (données personnelles) stockés sans protection.

**Note globale : 3,1 / 10** en tant que produit livrable (≈ 6,5/10 en tant que projet pédagogique / prototype).

| Axe | Note | Commentaire court |
|---|---|---|
| Adéquation métier pharmacie | 4 / 10 | Bonnes idées, mais aucun invariant métier réellement garanti |
| Architecture logicielle | 3 / 10 | Pas de couches, logique dans les widgets, pas d'injection |
| Modèle de données | 2 / 10 | 4 tables plates, aucune contrainte, aucune intégrité référentielle |
| Cohérence / justesse du code | 3 / 10 | Bugs de calcul de stock bloquants, `int.parse` non protégés |
| Sécurité & conformité | 2 / 10 | Mots de passe en clair, pas de rôles, données de santé non protégées |
| UX / UI | 5 / 10 | Cohérent, lisible, mais contrastes insuffisants et non responsive |
| Tests & qualité logicielle | 1 / 10 | Le seul test fourni échoue ; aucun test métier |
| Build / distribution | 4 / 10 | `com.example`, signature debug, dépendances mal placées, import sensible à la casse |
| Documentation | 2 / 10 | README par défaut ; nomenclature opaque (`acht`, `entr`) |
| Maintenabilité | 3 / 10 | ~40 % de duplication UI, fichiers « fourre-tout » |

> **Verdict :** excellent socle de démonstration / soutenance ; à retravailler sur 4 à 6 semaines pour un MVP réellement utilisable en officine.

---

## 2. Fiche d'identité

| Élément | Valeur |
|---|---|
| Nom de package | `appharmacie` |
| Framework | Flutter (Dart SDK `>=3.4.3`, Flutter `>=3.22.0`) |
| Cible | Android + iOS |
| Persistance | SQLite locale via `sqflite` (`pharmacie.db`, version 1) |
| Navigation | `Navigator` **et** `Get.off/offAll` (GetX) — mélange |
| State management | `setState` uniquement (GetX présent mais non exploité) |
| Impression | `pdf` + `printing` (facture A4) |
| Graphiques | `flutter_charts`, `charts_flutter_new`, `charts_flutter` — **aucun utilisé** |
| Structure | `Authentification/`, `Models/`, `SQLite/`, `pages/`, `dialog/` |
| Contexte | Devise Ariary (`Ar`), interface 100 % française, projet d'école probable |

### Cartographie fonctionnelle réelle

```
Login / Signup (SQLite local, mot de passe en clair)
        │
        └── HomePage (BottomNavigationBar, 4 onglets)
              ├── Accueil      → KPI : stock < 5, top 5 ventes, CA cumulé
              ├── Entrées      → liste + création (addEntree) + édition/suppression
              ├── Médicaments  → recherche + CRUD (addMed, édition en dialog)
              └── Achats       → liste + création multi-lignes (addAchat) + facture PDF
```

### Ce qui existe vraiment (et qui est bien pensé)

- Vérification du stock **avant** une vente (`insertAchat` renvoie `-1`/`-2`).
- Restauration du stock à la suppression d'une vente (`deleteAchat`).
- Requêtes SQL **paramétrées** partout → pas d'injection SQL (point fort à souligner).
- Facture PDF multi-lignes avec total, imprimable/partageable.
- Dialogue de confirmation avant suppression, validation des champs vides.
- Tableau de bord : top ventes, alerte stock, chiffre d'affaires — la bonne intuition métier.

---

## 3. Architecture actuelle

```
lib/
├── main.dart              → App + HomePage (navigation + AppBar + logout)
├── Authentification/      → login.dart, signup.dart (UI + appels DB directs)
├── Models/                → 4 POJO avec fromMap/toMap manuels
├── SQLite/sqlite.dart     → DatabaseHelper : 20 méthodes, SQL brut + règles métier
├── pages/                 → 4 écrans + pdf_utils.dart
├── dialog/                → 3 formulaires pleine page nommés « dialog »
└── assets/images/         → 5 PNG dans lib/ (devrait être assets/)
```

**Couches réelles : 1,5.** Il y a bien une séparation *fichiers*, mais pas de séparation *responsabilités* :

- Les widgets appellent directement `DatabaseHelper` (pas de repository, pas de service).
- `DatabaseHelper` mélange 3 rôles : accès données, **règles métier de stock**, et formatage.
- `pdf_utils.dart` dépend de `TextEditingController` (Flutter/Material) : la génération de document est **coudée à l'UI**, donc intestable.
- Aucune injection de dépendances : `DatabaseHelper()` est instancié **9 fois** dans le projet ; le champ `late Database _database` n'est donc jamais un singleton utile.

**Conséquence directe :** aucune règle métier n'est testable sans monter une UI et une base réelle. C'est la cause racine de l'absence de tests.

---

## 4. Modèle de données

### 4.1 Schéma actuel (`lib/SQLite/sqlite.dart:11-14`)

```sql
users   (usrId PK, usrName TEXT UNIQUE, usrPassword TEXT)
medics  (id PK, numMed TEXT, designMed TEXT, prixMed INTEGER, stockMed INTEGER)
entrees (id PK, numEntr TEXT, numMed TEXT, stockEntr INTEGER, dateEntr TEXT)
achats  (id PK, numAchat TEXT, numMed TEXT, nomClient TEXT, dateAchat TEXT, nbr INTEGER)
```

### 4.2 Dix défauts de conception

| # | Problème | Conséquence |
|---|---|---|
| 1 | **Aucune clé étrangère**, aucun `REFERENCES`, aucun `ON DELETE` | Supprimer un médicament laisse des achats orphelins → crash du dashboard (§5.4) |
| 2 | `PRAGMA foreign_keys = ON` jamais activé (ni `onConfigure`) | Même avec des FK déclarées, SQLite les ignorerait |
| 3 | `medics.numMed` **non UNIQUE** | Doublons possibles ; `updateMedic` modifie alors plusieurs lignes ; `firstWhere` devient ambigu |
| 4 | `achats.numAchat` **non UNIQUE**, saisi à la main | Deux ventes peuvent porter le même numéro → factures non identifiables |
| 5 | Dates en `TEXT` format `dd/MM/yy` | Non triable, non filtrable, ambigu (« 01/02/26 »), perte du siècle, pas d'heure |
| 6 | `entrees` sert **à la fois** de journal de mouvements et de stock agrégé | Une « entrée » est écrasée au lieu d'être historisée → perte de traçabilité |
| 7 | `stockMed` **dupliqué** dans `medics` et dérivable de `entrees - achats` | Deux sources de vérité → dérive garantie (voir §5) |
| 8 | Aucun **index** (hors PK) | Jointures/`WHERE numMed` en scan complet |
| 9 | Aucun prix **figé** sur la ligne de vente | Changer un prix réécrit rétroactivement tout le CA historique |
| 10 | `version: 1` sans `onUpgrade` | Aucune migration possible → toute évolution cassera les bases installées (ou effacera les données) |

### 4.3 Ce qui manque pour faire de la pharmacie

Un logiciel d'officine, même minimal, ne peut pas se passer de :

**Traçabilité (obligation réglementaire en pratique)**
- **Lots** et **dates de péremption** (aujourd'hui impossibles à représenter)
- Fournisseur, numéro de bon de livraison, prix d'achat
- Historique immuable des mouvements (`ENTREE`, `SORTIE`, `RETOUR`, `AJUSTEMENT`, `PERTE`)
- Utilisateur + horodatage sur chaque opération (audit trail)

**Gestion commerciale**
- Marge réelle (`prix_vente - prix_achat`) — aujourd'hui seule la recette est calculée, pas le bénéfice
- TVA / mentions légales sur la facture, numérotation séquentielle
- Retours / avoirs, annulations motivées
- Inventaire physique et ajustements justifiés
- Seuil d'alerte **par produit** (aujourd'hui `stock < 5` codé en dur)
- Ordonnances (prescripteur, patient, posologie) si l'officine en délivre

**Exploitation**
- Rôles : `admin` / `pharmacien` / `vendeur` (aujourd'hui : n'importe qui s'inscrit et a tous les droits)
- Rapport de caisse journalier (« Z »), clôture
- Sauvegarde / restauration (voir §8.3)

---

## 5. Bugs — par ordre de gravité

> Les 5 premiers sont **bloquants** : ils corrompent les données sans message d'erreur.

### 5.1 🔴 Double incrément du stock à chaque entrée
`lib/dialog/addEntree.dart:203` **et** `lib/SQLite/sqlite.dart:84-106`

L'écran appelle `updateMedicStock(+q)` **puis** `insertEntree(...)`, qui incrémente **encore** le stock quand aucune entrée n'existe déjà pour ce médicament.

**Reproduction :**
1. Médicament `A`, stock 0.
2. Saisir une entrée de 10 → `stock = 0 + 10 = 10` puis `insertEntree` → `stock = 20`.
3. Saisir une entrée de 5 → `+5 = 25` ; `insertEntree` trouve une ligne existante → **aucun** ajout.
4. Stock affiché : **25** — attendu : **15**.

Le stock est donc faux dès la 2ᵉ saisie, et les deux tables divergent.

### 5.2 🔴 `updateEntree` écrase le stock avec la somme des entrées
`lib/SQLite/sqlite.dart:141-157`

```sql
UPDATE medics SET stockMed = (SELECT SUM(stockEntr) FROM entrees WHERE numMed = ?) ...
```

**Scénario :** 10 entrés, 10 vendus → stock 0. Modifier la quantité de l'entrée (10 → 12) → `stockMed = 12`. Les 10 ventes disparaissent du calcul : le stock remonte artificiellement et l'officine croit détenir 12 boîtes inexistantes.

### 5.3 🔴 Vente multi-lignes non atomique
`lib/dialog/addAchat.dart:72-120` + `sqlite.dart:186-207`

La boucle appelle `insertAchat()` **ligne par ligne**, sans transaction :

```dart
for (var medic in _medics) { ... await _dbHelper.insertAchat(achat); }
if (!stockInsufficient) { ...facture... }
```

**Scénario :** vente de 3 produits, le 2ᵉ est insuffisant → la ligne 1 est **enregistrée et décrémentée**, les lignes 2 et 3 non, et comme `stockInsufficient == true`, **aucune facture n'est générée**. L'utilisateur voit un message d'erreur ; la base contient une vente partielle invisible. Les codes de retour `-1`/`-2` de `insertAchat` ne sont **pas** vérifiés.

Ajout aggravant : la vérification se fait sur `medic.stockMed` chargé au `initState` (données potentiellement périmées).

### 5.4 🔴 Crash du tableau de bord après suppression d'un médicament vendu
`lib/pages/accueil.dart:30`

```dart
sum + (achat.nbr * medics.firstWhere((m) => m.numMed == achat.numMed).prixMed)
```

`deleteMedic` ne supprime pas les achats liés. Dès qu'un médicament vendu est supprimé, `firstWhere` lève `StateError: No element` → écran rouge d'erreur à l'ouverture de l'accueil. Il suffit d'une suppression pour rendre l'application inutilisable.

### 5.5 🔴 Modification / suppression de vente ne recale pas le stock
`lib/SQLite/sqlite.dart:241-249`

`updateAchat` met à jour la ligne **sans ajuster `stockMed`**. Modifier une quantité de 2 → 5 laisse le stock inchangé. `deleteAchat` restaure ensuite `achat.nbr` **courant** (5) au lieu de la quantité réellement déduite → dérive cumulée à chaque cycle modifier/supprimer.

### 5.6 🟠 `int.parse` non protégés — crash utilisateur
`addAchat.dart:56,81` · `medicament.dart:270-271` · `achat.dart:240` · `addEntree.dart:200`

Un champ vide, « 12a » ou « 1 200 » déclenche une `FormatException` non capturée. Dans `_updateTotalPrice` (`addAchat.dart:52-63`), **chaque frappe** est parsée : saisir « abc » casse l'écran. Utiliser `int.tryParse` + validation de formulaire (`Form`/`TextFormField`) avec `inputFormatters`.

### 5.7 🟠 Import sensible à la casse → build impossible sur Linux/CI
`lib/main.dart:5`

```dart
import 'package:appharmacie/authentification/login.dart'; // dossier réel : Authentification/
```

Fonctionne sur Windows/macOS (systèmes insensibles à la casse), **échoue** sur Linux et sur la plupart des CI (`Target of URI doesn't exist`). Bug de portabilité silencieux.

### 5.8 🟠 `pdf` et `printing` déclarés en `dev_dependencies`
`pubspec.yaml:29-31` alors qu'ils sont importés par `lib/pages/pdf_utils.dart` et `lib/dialog/addAchat.dart` (code de production).

Cela fonctionne aujourd'hui pour le package racine, mais c'est une bombe à retardement : toute extraction en package/monorepo, ou un build `--no-dev`-like, casse la compilation. À déplacer en `dependencies`.

### 5.9 🟠 Le seul test du projet échoue
`test/widget_test.dart` est le template « Counter » par défaut : il cherche `find.text('0')` alors que l'application démarre sur `LoginPage`. **`flutter test` est rouge depuis le premier commit** — donc aucune CI possible sans le supprimer, et surtout : 0 test métier sur le calcul de stock, la plus critique des fonctions.

### 5.10 🟠 Débordement d'UI sur petits écrans
`lib/Authentification/login.dart:69` : `Image.asset("lib/assets/images/Drugst.png", width: 370)`. Sur un écran 320–360 dp, la Colonne déborde (rayures jaunes/noir en debug). Utiliser `ConstrainedBox` + `Image.asset(..., fit: BoxFit.contain)` ou `maxWidth: MediaQuery.sizeOf(context).width * 0.8`.

### 5.11 🟡 Autres anomalies vérifiées

| Réf. | Description |
|---|---|
| `accueil.dart:140` | Affiche le **prix** sous le libellé « Vendu: » au lieu de la quantité vendue |
| `accueil.dart:32` | Seuil `stockMed < 5` alors que le titre annonce « rupture de stock » (rupture = 0) |
| `addAchat.dart:25` | Date de vente en `TextField` libre (l'écran Entrée utilise, lui, un `showDatePicker`) → formats hétérogènes |
| `addAchat.dart:29,150,305` | `_selectedMedic` jamais affecté + `MedicSearchDelegate` jamais instancié → **~80 lignes de code mort** |
| `signup.dart:150-160` | `.whenComplete()` navigue **même si** l'insertion a échoué (doublon `UNIQUE`) → échec silencieux |
| `login.dart:30-40` | Pas de `trim()` sur le nom d'utilisateur → « admin » et « admin » (espace) coexistent |
| `sqlite.dart:19-31` | `initDB()` rappelé par **chaque** méthode (20×) → réouverture répétée, pas de `onConfigure`, pas de `onUpgrade` |
| `sqlite.dart` | Requêtes sans `ORDER BY` → ordre d'affichage arbitraire ; aucune pagination |
| `medicament.dart` | Pas de `dispose()` du `_searchController` (fuite) ; tous les `TextEditingController` des dialogs/maps ne sont jamais libérés |
| Partout | `setState` après `await` sans `if (!mounted) return;` (seul `login.dart:32` le fait) |
| `main.dart` | Mélange `Navigator` et `Get.offAll` ; `Get.offAll` après ajout réinitialise la pile → comportement « retour » incohérent |
| `addMed` / `addEntree` | Pas de contrôle d'unicité du code médicament côté écran |

---

## 6. Sécurité & conformité

| Constat | Gravité | Recommandation |
|---|---|---|
| Mots de passe **en clair** dans SQLite (`usrPassword TEXT`) | 🔴 Critique | `argon2`/`bcrypt` (via `pointycastle` ou package dédié) + sel par utilisateur |
| Inscription **ouverte** : quiconque crée un compte a tous les droits d'administration | 🔴 Critique | Rôle + `actif` + création du premier admin au seed ; inscription réservée à l'admin |
| Base **non chiffrée** (`sqflite_sqlcipher` non utilisé) | 🔴 Critique | Chiffrement au repos + `flutter_secure_storage` pour la clé |
| `nomClient` = données personnelles, sans base légale, sans durée de conservation, sans export/suppression | 🟠 Majeur | Politique de conservation, anonymisation après N mois, page « données personnelles » |
| `android:allowBackup` non défini → **true par défaut** : la base est exfiltrable via `adb backup` | 🟠 Majeur | `android:allowBackup="false"` + `dataExtractionRules` |
| Aucun verrouillage applicatif (PIN/biométrie), aucun timeout de session | 🟠 Majeur | `local_auth` + re-auth après inactivité |
| Aucun journal d'audit (qui a supprimé quoi) | 🟠 Majeur | Table `audit_log` (user, action, entité, horodatage) |
| Pas de politique d'échec de connexion (brute-force trivial sur 4 chiffres) | 🟡 Moyen | Compteur + délai progressif |

**Cadre juridique :** l'application traite des **données de santé** et des données de clients. Même à Madagascar (loi n° 2014-006 sur la protection des données à caractère personnel), cela impose finalité, proportionnalité, sécurité et droits des personnes. À l'export (UE), le RGPD s'applique immédiatement. Le point 4 ci-dessus est le plus exposant.

**Point positif :** toutes les requêtes SQL sont paramétrées (`?` + `whereArgs`) — pas de concaténation, donc pas d'injection. À préserver lors du refactoring.

---

## 7. Qualité du code et dette technique

| Indicateur | Valeur mesurée | Norme attendue |
|---|---|---|
| Fichiers > 300 lignes | 4 sur 16 | < 200 |
| Duplication UI (`withOpacity` répétés) | 74 occurrences de styles verts en dur | thème centralisé |
| Occurrences de `int.parse` | 8, dont 6 sans `try/catch` | 0 |
| Widgets contenant de la logique métier | 3 écrans + 3 formulaires | 0 |
| Tests | 1 (qui échoue) | couverture du domaine > 70 % |
| Dépendances inutilisées | **6 sur 12** | 0 |
| `dispose()` implémentés | 2 sur 5 écrans à contrôleurs | 100 % |

### 7.1 Dépendances — audit

| Package | Statut | Action |
|---|---|---|
| `sqflite`, `path` | ✅ utilisés | garder |
| `intl` | ✅ `DateFormat` (1 usage) | garder, **monter** en `^0.19+` |
| `get` | ⚠️ 2 appels (`Get.off`, `Get.offAll`) | garder ou supprimer — inutile en l'état |
| `pdf`, `printing` | ✅ utilisés mais **en `dev_dependencies`** | **déplacer en `dependencies`** |
| `path_provider`, `cupertino_icons`, `json_path` | ❌ 0 usage | supprimer |
| `flutter_charts`, `charts_flutter_new`, `charts_flutter` | ❌ 0 usage, **abandonnés** (`charts_flutter` est *discontinued*) | supprimer |
| `flutter_lints` | ✅ | garder |

> `charts_flutter` fige `intl` en `^0.17.0` — c'est lui qui **bloque la montée de version** de `intl`. Le supprimer débloque la chaîne. Pour les graphiques futurs : `fl_chart` (maintenu).

### 7.2 Conventions

- Fichiers non `snake_case` (`acht.dart`, `entr.dart`), dossiers capitalisés (`Models`, `SQLite`) → contraire aux *Effective Dart* et source de bugs de casse (§5.7).
- Noms tronqués (`acht`, `entr`, `Medic`, `EntreePage` vs classe `Medicament`) : lisibilité et recherche dégradées.
- Modèles : champs publics mutables, pas de `copyWith`, pas d'égalité, sérialisation manuelle dupliquée ×4 → `freezed` ou `json_serializable` (le fichier `config.json` trahit d'ailleurs un reste de générateur de code `get_cli`/Flutter Architect, avec `"unfreezed": true`).
- Commentaires en français **et** anglais, dont plusieurs « Assurez-vous que… » laissés en production.
- README = template Flutter + 7 lignes `# Projet-mobile` collées. Aucune documentation du schéma, des règles de stock, ni des écrans.
- `lib/assets/images/` : les assets n'ont pas leur place sous `lib/` (convention : `assets/`).

### 7.3 UX / UI

- **Contraste insuffisant** : texte blanc sur `Colors.green.withOpacity(0.5)` ≈ 2,2:1 (WCAG AA exige 4,5:1). En plein soleil, dans une officine, c'est illisible.
- **Non responsive** : largeurs fixes (370 px), `Row` de boutons sans `Wrap` → débordements sur petits écrans et en orientation paysage.
- **Aucun retour de chargement** (`FutureBuilder`/skeleton) : les listes apparaissent vides puis se remplissent.
- **Pas de i18n** : chaînes françaises en dur, devise `Ar` codée en dur → verrouille le produit à un seul marché.
- **Pas de thème** : couleurs répétées à la main (`Colors.green` ~90×), pas de mode sombre.
- Points corrects : hiérarchie visuelle claire, icônes pertinentes, confirmations avant suppression, formulaires lisibles.

---

## 8. Build, plateformes, exploitation

### 8.1 Android

| Élément | État | Risque |
|---|---|---|
| `applicationId` / `namespace` | `com.example.appharmacie` | **Refus Play Store**, collision de package |
| Signature release | `signingConfigs.debug` (`app/build.gradle:52`) | **Impossible à publier** ; clé de debug publique |
| AGP / Kotlin / Gradle | 7.3.0 / 1.7.10 / 7.6.3 | Obsolètes pour Flutter 3.22+ ; cible : AGP 8.3, Kotlin 1.9, Gradle 8.4, JDK 17 |
| `minSdk` | hérité de Flutter (21) | OK |
| Permissions | aucune déclarée | OK pour SQLite ; `printing` fonctionne, mais ajouter `<queries>` (Android 11+) si partage PDF |
| `android:allowBackup` | non défini (= true) | Fuite de la base (§6) |
| Icône | icône Flutter par défaut | Image de marque absente |

### 8.2 iOS

- `IPHONEOS_DEPLOYMENT_TARGET = 12.0` : cohérent avec `printing`, mais Flutter 3.29+ exigera 13.0 → à planifier.
- `Podfile` absent du dépôt (généré au premier build) : acceptable, à documenter.
- Aucune config d'icône d'app (`flutter_launcher_icons` non utilisé).

### 8.3 Exploitation — le risque le plus sous-estimé

Tout est stocké **sur un seul téléphone**, sans sauvegarde :

- téléphone perdu, cassé, réinitialisé → **l'intégralité de l'historique de l'officine est perdue** ;
- pas d'export (seule la facture PDF par vente existe) ;
- pas de multi-poste : deux vendeurs sur deux téléphones = deux bases divergentes.

C'est, en pratique, le point qui empêcherait une officine réelle d'adopter l'outil. Minimum viable : **export/import JSON ou CSV** + copie automatique vers un dossier/cloud. Cible : synchronisation serveur (Supabase/Firebase) avec résolution de conflits.

---

## 9. Plan d'action priorisé

### P0 — Correctifs bloquants (2 à 3 jours)

1. Supprimer le double incrément (`addEntree.dart:203` **ou** la branche `else` de `insertEntree` — une seule source de vérité).
2. Remplacer le `SUM` de `updateEntree` par un **delta** (`stock += nouvelle - ancienne`).
3. Encapsuler la vente multi-lignes dans une **transaction** + vérifier les codes de retour, facture uniquement si `COMMIT` réussi.
4. Corriger `accueil.dart:30` (`firstWhereOrNull` + affichage « inconnu »), et bloquer la suppression d'un médicament référencé.
5. Ajuster le stock dans `updateAchat` (delta) et supprimer `deleteMedic` en cascade logique.
6. `int.tryParse` + `Form`/validators partout.
7. Corriger la casse de l'import `main.dart:5`.
8. Déplacer `pdf`/`printing` en `dependencies` ; supprimer les 6 dépendances mortes.
9. Remplacer le test template par des tests unitaires du calcul de stock.

### P1 — Refonte du modèle de données (5 à 8 jours)

Schéma cible (extrait) :

```sql
PRAGMA foreign_keys = ON;

CREATE TABLE users (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  username TEXT NOT NULL UNIQUE,
  password_hash TEXT NOT NULL,
  salt TEXT NOT NULL,
  role TEXT NOT NULL DEFAULT 'vendeur' CHECK (role IN ('admin','pharmacien','vendeur')),
  actif INTEGER NOT NULL DEFAULT 1,
  created_at TEXT NOT NULL            -- ISO-8601
);

CREATE TABLE medicaments (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  code TEXT NOT NULL UNIQUE,
  designation TEXT NOT NULL,
  forme TEXT, dosage TEXT,
  prix_vente INTEGER NOT NULL CHECK (prix_vente >= 0),
  prix_achat INTEGER NOT NULL DEFAULT 0,
  seuil_alerte INTEGER NOT NULL DEFAULT 5,
  actif INTEGER NOT NULL DEFAULT 1
);

CREATE TABLE lots (                   -- la clé de la traçabilité pharmacie
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  medicament_id INTEGER NOT NULL REFERENCES medicaments(id),
  numero_lot TEXT NOT NULL,
  quantite_recue INTEGER NOT NULL CHECK (quantite_recue > 0),
  quantite_restante INTEGER NOT NULL CHECK (quantite_restante >= 0),
  date_peremption TEXT NOT NULL,      -- YYYY-MM-DD
  date_reception TEXT NOT NULL,
  prix_achat_unitaire INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE ventes (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  numero TEXT NOT NULL UNIQUE,        -- V-20261104-0001 (séquence)
  client_nom TEXT,
  total INTEGER NOT NULL,
  date_vente TEXT NOT NULL,
  user_id INTEGER NOT NULL REFERENCES users(id)
);

CREATE TABLE vente_lignes (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  vente_id INTEGER NOT NULL REFERENCES ventes(id) ON DELETE CASCADE,
  medicament_id INTEGER NOT NULL REFERENCES medicaments(id),
  lot_id INTEGER REFERENCES lots(id),
  quantite INTEGER NOT NULL CHECK (quantite > 0),
  prix_unitaire INTEGER NOT NULL      -- figé : le CA historique devient juste
);

CREATE TABLE mouvements_stock (       -- source de vérité unique
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  medicament_id INTEGER NOT NULL REFERENCES medicaments(id),
  lot_id INTEGER REFERENCES lots(id),
  type TEXT NOT NULL CHECK (type IN ('ENTREE','SORTIE','RETOUR','AJUSTEMENT','PERTE')),
  quantite INTEGER NOT NULL,          -- signé
  reference TEXT,
  date_mouvement TEXT NOT NULL,
  user_id INTEGER NOT NULL REFERENCES users(id)
);

CREATE INDEX idx_mvt_med ON mouvements_stock(medicament_id, date_mouvement);
CREATE INDEX idx_lots_med ON lots(medicament_id, date_peremption);
```

Transaction type (à appliquer à la vente) :

```dart
Future<int> enregistrerVente(Vente vente, List<VenteLigne> lignes) async {
  final db = await database;
  return db.transaction((txn) async {
    // 1. tout vérifier AVANT d'écrire
    for (final l in lignes) {
      final rows = await txn.rawQuery(
        'SELECT COALESCE(SUM(quantite),0) AS s FROM mouvements_stock WHERE medicament_id = ?',
        [l.medicamentId],
      );
      final stock = rows.first['s'] as int? ?? 0;
      if (stock < l.quantite) {
        throw StockInsuffisant(l.medicamentId, demande: l.quantite, disponible: stock);
      }
    }
    // 2. écrire
    final venteId = await txn.insert('ventes', vente.toMap());
    for (final l in lignes) {
      await txn.insert('vente_lignes', l.copyWith(venteId: venteId).toMap());
      await txn.insert('mouvements_stock', {
        'medicament_id': l.medicamentId,
        'type': 'SORTIE',
        'quantite': -l.quantite,
        'reference': 'VENTE:$venteId',
        'date_mouvement': DateTime.now().toIso8601String(),
        'user_id': session.userId,
      });
    }
    return venteId;
  });
}
```

Puis : migration `onUpgrade` versionnée (1 → 2) avec script de reprise des données existantes, et **dates en ISO-8601**.

### P2 — Sécurité (2 à 3 jours)
Hachage Argon2/bcrypt · rôles + seed admin au premier lancement · `allowBackup=false` · audit log · verrouillage biométrique · chiffrement de la base.

### P3 — Architecture et UX (5 à 7 jours)
Feature-first + repository (`data/`, `domain/`, `presentation/`) · `Riverpod` ou `Bloc` à la place de `setState` + GetX · `drift` (SQL typé, migrations, requêtes réactives) à la place de `sqflite` brut · thème centralisé (`ColorScheme.fromSeed`) · composants réutilisables (`AppTextField`, `SearchBar`, `ConfirmDialog`) pour éliminer les 40 % de duplication · contrastes conformes · responsive · i18n (`flutter_localizations` + ARB) · widgets de chargement.

### P4 — Fonctionnalités métier (3 à 4 semaines)
Lots & péremption avec alertes · seuils par produit · marge et bénéfice · inventaire & ajustements · retours/avoirs · rapports de caisse · export/import & sauvegarde cloud · gestion des ordonnances · multi-utilisateurs synchronisés.

### P5 — Industrialisation (en continu)
`flutter analyze` + lints stricts en CI · tests unitaires du domaine + widget tests · `flutter_launcher_icons` · signature de release + Play Console interne · README réel (schéma, architecture, règles de stock) · versioning sémantique + `CHANGELOG`.

**Estimation globale pour un MVP production : 4 à 6 semaines** (1 développeur Flutter expérimenté), dont ~1 semaine de correctifs et de modèle de données.

---

## 10. Structure cible proposée

```
lib/
├── main.dart
├── app/                     # theme, routes, i18n, DI
├── core/                    # résultat, exceptions, formatage, horloge
├── data/
│   ├── database/            # app_database.dart (drift), migrations, seed
│   ├── repositories/        # MedicamentRepository, VenteRepository, ...
│   └── models/              # DTO + mappers
├── domain/
│   ├── entities/            # Medicament, Lot, Vente, MouvementStock
│   └── usecases/            # EnregistrerVente, EntrerStock, AjusterStock
└── presentation/
    ├── auth/                # login, signup, session
    ├── dashboard/
    ├── medicaments/
    ├── stock/
    ├── ventes/
    └── shared/widgets/      # AppTextField, SearchBar, ConfirmDialog, MoneyText
test/
├── domain/                  # règles de stock (le cœur du risque)
├── data/                    # repositories sur base en mémoire
└── widget/                  # parcours critiques
```

---

## 11. Checklist avant toute mise en production

- [ ] Aucun test rouge ; couverture du domaine ≥ 70 %
- [ ] `flutter analyze` sans erreur ni warning
- [ ] Stock vérifié par un test automatisé : entrée, vente, modification, suppression, retour
- [ ] `applicationId` propre, signature release, icône, écran de démarrage
- [ ] Mots de passe hachés, rôles appliqués, `allowBackup=false`
- [ ] Sauvegarde/restauration testée (restaurer sur un appareil vierge)
- [ ] Migration de schéma testée depuis une base v1
- [ ] Contrastes AA vérifiés, test sur appareil ≤ 5 pouces et en paysage
- [ ] Mentions légales de la facture conformes au contexte local
- [ ] README à jour : schéma, architecture, procédure de build

---

## 12. Conclusion

Le projet démontre une **bonne compréhension du problème métier** (stock, ventes, facture, indicateurs) et une maîtrise correcte des briques Flutter essentielles (SQLite, navigation, formulaires, PDF). La structure de dossiers montre une intention d'organisation louable.

Ce qui manque n'est pas du « polish » : c'est l'**invariant central**. Un logiciel de stock n'a de valeur que si `stock = Σ entrées − Σ sorties` est vrai à tout instant. Aujourd'hui, cette égalité est fausse après deux saisies normales. Tant que ce point n'est pas résolu — avec une source de vérité unique (mouvements), des transactions et des tests — aucune fonctionnalité supplémentaire n'apportera de valeur.

**Priorité absolue :** P0 (correctifs de stock) puis P1 (modèle de données). Le reste — architecture, design, fonctionnalités avancées — viendra d'autant plus vite que les fondations seront saines.
