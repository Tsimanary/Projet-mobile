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
   → **traité à l'itération 9 (section 14)** : deux rôles, écran Utilisateurs,
   inscription ouverte seulement à la première installation.
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

Passage de 12 à **32 tests** : disponibilité, FEFO, montants, validateurs,
dates ISO, hachage, démarrage de l'application.

### 8.7 Toujours ouvert

- Rôles et administration des comptes *(rôles : section 14)*, Argon2id,
  chiffrement de la base.
- Signature de release, `applicationId`, icônes, fiche Play Store.
- Codes-barres (scan de lot) et inventaire physique.

- Rôles et administration des comptes *(rôles : section 14)*, Argon2id,
  chiffrement de la base.
- Signature de release, `applicationId`, icônes, fiche Play Store.
- Codes-barres (scan de lot) et inventaire physique.

---

## 9. Itération 4 — sauvegarde, export et restauration

### 9.1 Le problème

Une base SQLite locale sans sauvegarde, c'est une officine qui perd tout sur un
téléphone volé, cassé ou réinitialisé — et aucune migration possible vers un
nouvel appareil. C'était la limite la plus grave après les lots.

### 9.2 Solution retenue

Un **fichier JSON unique, versionné**, contenant les six tables
(`users`, `medics`, `lots`, `mouvements_stock`, `entrees`, `achats`).

| Choix | Raison |
|---|---|
| JSON et non copie du `.db` | lisible, portable entre versions, diffable, indépendant du chiffrement à venir |
| Partage système (`share_plus`) | aucune permission de stockage, l'utilisateur choisit la destination (courriel, Drive) |
| Écriture dans le répertoire temporaire | toujours accessible en écriture, compatible FileProvider |
| Restauration en **une transaction** | en cas de fichier corrompu, la base reste intacte |
| Stock **recalculé** après restauration | l'invariant `stockMed == Σ lots.quantiteRestante` est rétabli même si le fichier vient d'une version antérieure |

### 9.3 Validation du fichier

`analyserSauvegarde` (pur, testé) refuse avec un message clair :
- un contenu qui n'est pas du JSON ;
- un JSON qui ne vient pas de l'application (`application != appharmacie`) ;
- une version de format inconnue ou **plus récente** que l'application ;
- une table manquante.

Aucune donnée n'est écrite avant validation complète **et** confirmation
explicite de l'utilisateur (dialogue rouge rappelant que l'opération est
irréversible).

### 9.4 Interface

Nouvel écran **Sauvegarde** (icône disquette dans la barre du haut) :
compteurs de données, bouton de création + partage, bouton de restauration,
et rappel des bonnes pratiques (données de santé : conserver hors du téléphone).
Après restauration, retour à l'écran de connexion — les comptes ont pu changer.

### 9.5 Tests

**6 tests supplémentaires** (`test/backup_format_test.dart`, total **38** au 5 novembre 2026) : aller-retour complet,
refus du non-JSON, refus d'un fichier étranger, refus d'une version future,
détection d'une table manquante, exhaustivité de la liste des tables.

---

## 10. Itération 5 — Android : identité, signature, publication

### 10.1 Identité de l'application

| Élément | Avant | Après |
|---|---|---|
| `applicationId` | `com.example.appharmacie` (placeholder) | `com.tsimanary.appharmacie` |
| `namespace` / package Kotlin | `com.example.appharmacie` | `com.tsimanary.appharmacie` (fichier déplacé) |
| Icône | icône Flutter par défaut | croix + mortier, déclinée 48 → 192 px |
| Écran de démarrage | fond blanc vide | fond blanc + logo centré |

L'`applicationId` est définitif : le changer après publication créerait une
nouvelle application.

### 10.2 Chaîne de compilation

| Outil | Avant | Après |
|---|---|---|
| AGP | 7.3.0 | **8.3.2** |
| Gradle | 7.6.3 | **8.4** |
| Kotlin | 1.7.10 | **1.9.22** |
| Java source/target | 1.8 | **17** (compilé et ciblé) |

Ces versions sont celles attendues par Flutter 3.22 et par les plugins ajoutés à
l'itération 4 (`share_plus`, `file_picker`).

### 10.3 Signature de release

`android/app/build.gradle` lit `android/key.properties` s'il existe :

```groovy
signingConfig = keystorePropertiesFile.exists()
        ? signingConfigs.release
        : signingConfigs.debug
```

- En développement, rien ne change (`flutter run --release` fonctionne).
- En production, il suffit de créer `key.properties` (modèle fourni :
  `android/key.properties.example`) pour que `flutter build appbundle` produise
  un paquet signé.
- Le keystore et `key.properties` sont déjà exclus par `android/.gitignore`.

### 10.4 Livrables de publication

- `store/jeu-icone-512.png` — icône exigée par la Play Console.
- `store/icone-1024.png` — source de l'icône (retouches futures).
- `docs/PUBLICATION_PLAY_STORE.md` — procédure complète : keystore, build,
  fiche, *Data safety*, test interne, mises à jour, check-list.
- `docs/CONFIDENTIALITE.md` + `docs/confidentialite.html` — politique de
  confidentialité (aucune collecte, données locales, fichier de sauvegarde).

### 10.5 Toujours ouvert (choix produit ou dépendance externe)

- **Argon2id** et **chiffrement de la base** (`sqflite_sqlcipher`) : impact sur
  les performances et migration à planifier.
- **Rôles** (vendeur / gestionnaire) : nécessite un écran d'administration.
  → **traité à l'itération 9 (section 14)**.
- **Verrouillage biométrique** (`local_auth`).
- **Synchronisation multi-postes** : présuppose un backend.

---

## 11. Itération 6 — chiffrement de la base et code d'accès

### 11.1 Le risque traité

Jusqu'ici, la base était un fichier SQLite **en clair** dans le répertoire
privé de l'application. Sur un téléphone rooté, via ADB ou un outil de
récupération, elle s'ouvre en dix secondes : l'intégralité du stock, des ventes
et des comptes est lisible. C'était la dernière faiblesse majeure avant une
mise entre les mains d'un pharmacien.

### 11.2 Chiffrement (SQLCipher)

| Élément | Choix |
|---|---|
| Moteur | `sqflite_sqlcipher` (API identique à `sqflite`, `sqflite` retiré pour éviter deux moteurs) |
| Clé | 32 octets tirés de `Random.secure()`, encodés en base64url |
| Conservation | `flutter_secure_storage` → **Keystore Android** ; jamais dans un fichier |
| Ouverture | `openDatabase(..., password: cle)` |
| Conversion des bases en clair | `ATTACH ... KEY` + `sqlcipher_export` + remplacement du fichier, **une seule fois** (marqueur dans le coffre) |
| En cas d'échec de conversion | le fichier d'origine n'est pas touché (suppression après succès seulement) |

Complément : `allowBackup="false"` était déjà en place — indispensable, sinon
Android restaurerait la base sur un autre appareil sans la clé du Keystore.

### 11.3 Code d'accès

Le chiffrement protège le fichier ; il ne protège rien sur un téléphone
déverrouillé. D'où un second verrou, indépendant :

- **4 à 6 chiffres**, empreinte **SHA-256 salée** stockée dans une nouvelle
  table `parametres` (schéma **v4**, clé/valeur) : le code n'existe nulle part.
- **5 essais** puis blocage de **5 minutes** ; le compteur est **persisté en
  base**, donc redémarrer l'application ne remet pas les compteurs à zéro.
- **Reverrouillage automatique** après 30 s en arrière-plan (`GardienSession`,
  placé dans `MaterialApp.builder` : l'écran de verrouillage recouvre routes et
  dialogues).
- Écran de réglages **Sécurité** : activation, changement, désactivation
  (changement et désactivation exigent le code actuel).
- Politique isolée dans `ReglesPin` (pure, testée) : longueur, seuil, durée.

### 11.4 Décision assumée : pas de récupération

Aucun « code de secours » n'est stocké. Un mécanisme de récupération serait une
porte dérobée : il rendrait le verrou décoratif. La sortie de secours est la
**sauvegarde JSON** — d'où l'importance de l'export régulier, rappelé dans
l'écran Sécurité.

### 11.5 Le point faible qui reste, écrit noir sur blanc

Le **fichier de sauvegarde est en clair** (JSON). C'est un choix : il doit
rester restaurable sur un autre appareil, et chiffrer correctement exige
Argon2id + AES-GCM. Une cryptographie improvisée serait pire que l'absence de
chiffrement. L'avertissement est affiché dans les écrans **Sécurité** et
**Sauvegarde**, et le chantier est documenté dans `docs/SECURITE.md`.

### 11.6 Tests

9 tests supplémentaires (`test/verrouillage_test.dart`) : longueur et caractères
du code, seuil de blocage, calcul de la fin de blocage, temps restant, formats
de durée, empreinte (bon code / mauvais code / sel unique / pas de code en
clair). Total du projet : **47 tests**.

---

## 12. Itération 7 — Argon2id pour les mots de passe et le code d'accès

### 12.1 Le problème

SHA-256 salé protège contre la lecture directe, mais c'est une fonction
**rapide** : sur une empreinte extraite (sauvegarde JSON, téléphone rooté), un
attaquant teste des milliards de candidats par seconde. Le sel empêche les
tables précalculées, il n'empêche pas la force brute. Pour un mot de passe
d'utilisateur, c'est le mauvais outil.

### 12.2 Ce qui a été fait

| Élément | Choix |
|---|---|
| Algorithme | **Argon2id** (`cryptography`), recommandation OWASP |
| Paramètres | mémoire **19 456 kio** (19 Mio), **2** passes, **1** fil, empreinte 32 octets, sel 16 octets |
| Format de stockage | **PHC autoportant** : `$argon2id$v=19$m=…,t=…,p=…$sel$empreinte` |
| Comparaison | en temps constant (pas de fuite par le temps de réponse) |
| Analyse défensive | toute empreinte illisible est refusée, jamais d'exception remontée à l'UI |
| Coût perçu | indicateur « Vérification… » sur l'écran de verrouillage, bouton désactivé à la connexion |

**Pourquoi le format PHC** : les paramètres voyagent avec l'empreinte. Durcir
les réglages plus tard ne casse rien — chaque empreinte est vérifiée avec les
paramètres qui ont servi à la produire. Et un attaquant ne peut pas les réduire :
la vérification recalculerait une empreinte différente.

### 12.3 Migration transparente

Trois formats peuvent coexister dans une base existante :

1. **Argon2id** (nouveau) → vérifié directement ;
2. **SHA-256 salé** (itération 3) → vérifié avec l'ancien algorithme, puis
   **réécrit en Argon2id** si le secret est correct (`login`,
   `Verrouillage._mettreANiveau`) ;
3. **mot de passe en clair** (comptes d'origine) → comparé, puis réécrit.

Aucune action utilisateur, aucune donnée perdue, et plus aucune empreinte faible
ne survit à une connexion réussie.

### 12.4 Tests

8 tests supplémentaires (`test/empreinte_test.dart`) : aller-retour du format
PHC, sept formes d'empreintes invalides, comparaison en temps constant, secret
correct/incorrect, unicité des sels, empreinte abîmée sans exception, et
compatibilité de l'ancien format. Total du projet : **55 tests**.

### 12.5 Réserve honnête

Les paramètres Argon2id n'ont pas pu être **chronométrés sur un téléphone
réel** dans cet environnement. Recommandation : mesurer la vérification sur
l'appareil cible ; au-delà de ~1,5 s, réduire à `m=12 Mio, t=2` (toujours dans
les recommandations OWASP) — le format PHC rend ce réglage indolore.

---

## 13. Itération 8 — sauvegarde chiffrée par phrase secrète

### 13.1 Le dernier trou

La base était chiffrée, mais le fichier exporté ne l'était pas : un JSON en
clair contenant tout l'historique, envoyé par courriel ou posé sur un Drive. Le
chiffrement de la base devenait alors décoratif dès le premier export.

### 13.2 Chaîne mise en place

| Étape | Choix | Raison |
|---|---|---|
| Dérivation | **Argon2id** (19 Mio, 2 passes, sel de 16 octets) | coût mémoire, donc attaque hors ligne coûteuse sur la phrase |
| Chiffrement | **AES-256-GCM** | authentifié : toute altération est détectée, pas de corruption silencieuse |
| Nonce | 12 octets aléatoires par export | un nonce réutilisé casserait la confidentialité |
| Clé | jamais stockée, redérivée à chaque ouverture | rien à voler sur l'appareil |
| Conteneur | enveloppe **JSON auto-descriptive** (kdf + nonce + données + tag) | lisible, versionnée, sans dépendance à un format binaire maison |

### 13.3 Interface

- L'export demande une **phrase secrète (8 caractères minimum) avec
  confirmation** : c'est le chemin par défaut.
- Un export **sans protection** reste possible, derrière un avertissement
  explicite et une confirmation.
- La restauration détecte l'enveloppe, demande la phrase (**3 essais**), puis
  applique la transaction habituelle.
- Le message d'erreur est **le même** pour une phrase fausse et un fichier
  altéré : ne rien apprendre à un attaquant.

### 13.4 Le refus assumé

Aucune récupération de phrase, aucune clé de secours stockée quelque part « au
cas où ». Une telle clé annulerait le chiffrement. L'interface le dit avant
l'export, et `docs/SECURITE.md` le répète : **phrase perdue = sauvegarde
perdue**.

### 13.5 Tests

9 tests supplémentaires (`test/chiffrement_test.dart`) : aller-retour,
enveloppe conforme, phrase incorrecte, deux exports tous deux valides mais
différents, enveloppe altérée rejetée, phrase trop courte refusée, détection des
enveloppes, refus d'un fichier en clair, et intégration complète
(chiffrement → déchiffrement → validation du format de sauvegarde).
Total du projet : **64 tests**.

### 13.6 Ce qu'il reste, sans se raconter d'histoires

- **Rôles** (vendeur / gestionnaire) : décision métier, pas technique.
- **Biométrie** : confort d'usage, à ajouter après les rôles.
- **Mesure du coût Argon2id sur appareil réel** : 1 mesure, 1 réglage.
- **`FLAG_SECURE`** sur les écrans sensibles (captures d'écran).

---

## 14. Itération 9 — rôles vendeur et gestionnaire

### 14.1 Le problème

Tous les comptes pouvaient tout faire : un vendeur pouvait supprimer une
vente, changer un prix ou effacer une réception. Une faute de frappe — ou une
mauvaise intention — devenait indétectable, et la comptabilité ne valait plus
rien. L'audit initial le classait déjà comme point bloquant (B7).

### 14.2 Deux rôles, fermés par défaut

`lib/core/roles.dart` :

```dart
enum RoleUtilisateur { gestionnaire, vendeur }
```

- **vendeur** : consulter, vendre, réceptionner une livraison ;
- **gestionnaire** : tout, plus la correction/suppression des ventes et des
  entrées, le catalogue (donc les prix), les comptes, la sauvegarde et la
  sécurité.

`Permissions` énumère chaque droit nommément et retourne `estGestionnaire`
pour tout ce qui n'a pas été ouvert explicitement : une fonctionnalité
ajoutée demain est réservée au gestionnaire par défaut.

Lecture des données stockées (`RoleUtilisateur.depuis`) :

| Valeur en base | Rôle lu | Pourquoi |
|---|---|---|
| `gestionnaire` | gestionnaire | — |
| `vendeur` | vendeur | — |
| absente / vide | **gestionnaire** | comptes créés avant les rôles = propriétaires |
| inconnue (`admin`, texte libre…) | **vendeur** | on ne donne jamais un droit sur une valeur inattendue |

### 14.3 La session, et pourquoi elle n'est pas persistée

`lib/core/session.dart` garde le compte connecté **en mémoire seulement** :

```dart
Session.ouvrir(nom: compte.usrName, role: compte.usrRole);  // après login
Session.exigerGestionnaire('supprimer une vente');          // lève si refusé
```

Pas d'écriture disque : fermer l'application (ou se déconnecter, ou
restaurer) ferme la session. Sans session, `Session.role` vaut **vendeur**.
Conséquence voulue : un plantage ou un redémarrage ne laisse jamais traîner
des droits de gestion, et il n'existe aucun fichier à falsifier pour
s'octroyer le rôle administrateur.

### 14.4 Les droits sont vérifiés dans la couche données

Masquer un bouton n'est pas une protection. Chaque opération sensible appelle
`Session.exigerGestionnaire(...)` dans `lib/SQLite/sqlite.dart` :

`insertMedic`, `updateMedic`, `deleteMedic`, `updateEntree`, `deleteEntree`,
`updateAchat`, `deleteAchat`, `exporterTout`, `restaurerTout`, `signup`
(hors premier compte), `getAllUsers`, `updateUserRole`, `deleteUser`.

Le refus est une `OperationRefuseeException` avec un message affichable
(« Action réservée au gestionnaire : supprimer une vente. »).

### 14.5 Garde-fous sur les comptes

`ReglesComptes` (pur, testable sans base) :

- impossible de retirer le rôle au **dernier gestionnaire** ;
- impossible de supprimer le dernier gestionnaire ;
- impossible de supprimer le compte avec lequel on est connecté.

Sans ces règles, une manipulation malheureuse laisserait une application sans
personne capable de créer un compte ni de restaurer une sauvegarde : les
données seraient définitivement inaccessibles.

### 14.6 Base de données (v4 → v5) et traçabilité

Migration additive, aucune donnée réécrite :

| Colonne | Contenu |
|---|---|
| `users.usrRole TEXT NOT NULL DEFAULT 'gestionnaire'` | rôle du compte |
| `entrees.auteur TEXT` | nom du compte qui a saisi la réception |
| `achats.auteur TEXT` | nom du compte qui a encaissé la vente |

`signup` : le **premier** compte d'une installation est toujours gestionnaire
(c'est celui qui installe) ; les suivants sont créés depuis l'écran
« Utilisateurs » par un gestionnaire connecté. La page de connexion ne propose
plus « Créer un compte » que lors de la première utilisation.

### 14.7 Interface

- Nouvel écran `pages/utilisateurs.dart` : liste des comptes, création
  (nom, mot de passe, rôle), changement de rôle, suppression — chaque action
  confirmée, chaque refus expliqué.
- `home.dart` : badge « nom · rôle », menu Utilisateurs / Sécurité /
  Sauvegarde réservé au gestionnaire, `Session.fermer()` à la déconnexion.
- `medicament.dart`, `entree.dart`, `achat.dart` : les boutons modifier /
  supprimer disparaissent pour un vendeur ; le bouton d'ajout de médicament
  aussi. Vendre et réceptionner restent disponibles.
- `sauvegarde.dart`, `securite_page.dart` : écran de refus explicite si un
  vendeur y accède autrement que par le menu.

### 14.8 Tests

17 tests supplémentaires (`test/roles_test.dart`) : matrice complète des deux
rôles, lecture des rôles stockés (absent, casse, inconnu), session par défaut
vendeur, refus vendeur, ouverture gestionnaire, fermeture, comptage des
gestionnaires, garde du dernier gestionnaire, garde du compte connecté,
messages affichables, sérialisation du rôle.
Total du projet : **81 tests**.

### 14.9 Ce qu'il reste

- **Biométrie** (`local_auth`) : confort, pas sécurité.
- **`FLAG_SECURE`** : empêcher captures d'écran et miniatures.
- **Écran de journal d'audit** : les colonnes `auteur` et
  `mouvements_stock` existent, il manque l'affichage.
- **Mesure du coût Argon2id** sur le téléphone cible.

---

## 15. Itération 10 — déverrouillage biométrique

### 15.1 Le problème réel

Le code d'accès protège l'ouverture, mais il se retape à chaque fois : à
chaque démarrage, et après 30 s en arrière-plan. Une officine où l'on
consulte l'application cinquante fois par jour finit par désactiver le
verrou — la sécurité perdue est bien plus grande que celle apportée par un
code à 4 chiffres.

### 15.2 Ce qui a été fait

`local_auth` (empreinte, visage, iris selon l'appareil) :

- **Une seconde façon d'ouvrir le verrou, pas un quatrième verrou.** Le code
  reste défini, modifiable, et redevient obligatoire après trois échecs du
  capteur.
- **Activation prouvée** : l'option ne s'active qu'après une empreinte
  reconnue. On n'active pas un verrou qu'on n'a pas essayé.
- **`biometricOnly: true`** : le code de déverrouillage du téléphone ne peut
  pas servir de code d'accès de l'application.
- **Réglage persistant** dans la table `parametres` de la base chiffrée
  (`securite.biometrie.active`). Cette table n'est **pas** dans l'export de
  sauvegarde : comme l'empreinte du code d'accès, le réglage reste lié à
  l'appareil et n'est jamais transporté avec les données.
- **Compteur d'échecs en mémoire** : il repart à zéro au redémarrage, sans
  conséquence — le code garde ses 5 essais et son blocage persistant.
- **Aucune panne ne bloque l'utilisateur** : plugin absent, capteur occupé,
  `PlatformException`, base illisible → on retombe sur le code, avec un
  message.

### 15.3 Architecture (testable sans téléphone)

| Fichier | Rôle |
|---|---|
| `lib/core/biometrie.dart` | politique pure : `ReglesBiometrie` (3 essais), `ResultatBiometrie`, façade `Biometrie` |
| `lib/core/biometrie_systeme.dart` | `local_auth` + lecture/écriture du réglage dans `parametres` |
| `test/biometrie_test.dart` | 14 tests avec un capteur simulé (aucun plugin requis) |

`VerificateurBiometrique` et `DepotBiometrie` sont des interfaces : le cœur de
décision ne connaît ni le plugin ni SQLite, donc les tests s'exécutent
partout, y compris en intégration continue sans appareil.

### 15.4 Android — ce qui devait changer

| Point | Avant | Après | Pourquoi |
|---|---|---|---|
| `MainActivity` | `FlutterActivity` | **`FlutterFragmentActivity`** | l'invite biométrique est un fragment AndroidX |
| `minSdk` | valeur Flutter (21) | **24** (Android 7.0) | plancher de `local_auth_android` |
| Permissions | aucune | **`USE_BIOMETRIC`** | permission « normale » : pas de dialogue, pas d'accès aux données |
| `pubspec.yaml` | — | **`local_auth: ^2.2.0`** | pub résout `local_auth_android` selon votre version de Flutter |

### 15.5 Interface

- **Écran de verrouillage** : bouton « Déverrouiller par empreinte » sous les
  points, invite lancée automatiquement à l'ouverture quand l'option est
  active ; messages d'échec avec essais restants ; après 3 échecs, le bouton
  disparaît et un texte explique que le code est désormais seul.
- **Écran Sécurité** : interrupteur « Déverrouillage par empreinte »,
  désactivé (avec explication) si aucun code n'est défini ou si l'appareil
  n'a aucune empreinte enregistrée ; désactivation confirmée.

### 15.6 Tests et documentation

14 tests supplémentaires (`test/biometrie_test.dart`) : 3 essais, messages,
désactivation par défaut, activation prouvée ou refusée, relecture du réglage,
base illisible, désactivation, succès, verrouillage après 3 échecs, remise à
zéro, reprise après saisie du code, capteur absent, panne du capteur.
Total du projet : **95 tests**.

Documents mis à jour : `docs/SECURITE.md` (§ 1, § 3, nouveau § 9),
`README.md`, `docs/PUBLICATION_PLAY_STORE.md` (permission, API 24, Data
safety), version `1.7.0+7`.

### 15.7 Ce qu'il reste

- **`FLAG_SECURE`** : empêcher captures d'écran et miniatures.
- **Écran de journal d'audit** (colonnes `auteur` déjà en base).
- **Mesure du coût Argon2id** sur le téléphone cible.
