# Sécurité — modèle de menace et choix techniques

Ce document explique **ce que protège** l'application, **comment**, et **ce
qu'elle ne protège pas**. Il est destiné à être relu avant toute mise en
production et à chaque évolution sensible.

---

## 1. Trois verrous, trois rôles

| Verrou | Ce qu'il protège | Où vit le secret |
|---|---|---|
| **Chiffrement de la base** (SQLCipher) | le fichier `.db` au repos : vol du téléphone, copie du fichier, extraction par sauvegarde, ADB, outil de récupération | clé de 32 octets aléatoires, dans le **Keystore** Android via `flutter_secure_storage` |
| **Code d'accès** (4 à 6 chiffres) | l'accès à l'application sur un téléphone **déjà déverrouillé** | empreinte **Argon2id** dans la table `parametres` de la base chiffrée |
| **Phrase secrète de sauvegarde** | le fichier exporté, qui circule hors du téléphone (courriel, clé USB, Drive) | nulle part : la clé AES-256 est redérivée en Argon2id à chaque ouverture |

Ils sont indépendants : le code d'accès n'est pas la clé de chiffrement de la
base, et la phrase de sauvegarde n'est pas le code d'accès. C'est volontaire —
un code à 4 chiffres (10 000 combinaisons) est un verrou d'usage, pas un secret
cryptographique ; une phrase longue, elle, peut l'être.

---

## 2. Chaîne de protection

```
Code d'accès (empreinte salée, jamais stockée en clair)
        │
        ▼
Application  ──►  SQLCipher  ◄──  Clé 32 octets (Keystore Android)
                     │
                     ▼
            pharmacie.db  (illisible sans la clé)
```

- La clé n'est **jamais** écrite dans un fichier de l'application, ni dans une
  préférence, ni dans le code. Hors du Keystore, elle n'existe qu'en mémoire
  pendant l'exécution.
- `android:allowBackup="false"` : la sauvegarde système ne peut pas emporter
  une base dont la clé resterait sur l'appareil (ce qui produirait un fichier
  inutilisable, voire une fuite).
- Toutes les requêtes sont paramétrées (aucune injection SQL possible).

---

## 3. Ce qui est réellement couvert

| Menace | Protégé ? | Comment |
|---|---|---|
| Téléphone volé, éteint ou verrouillé | **Oui** | base chiffrée + code d'accès |
| Fichier `pharmacie.db` copié (ADB, sauvegarde, carte SD, root) | **Oui** | chiffrement SQLCipher |
| Quelqu'un prend le téléphone déverrouillé et ouvre l'app | **Oui (usage courant)** | code d'accès + reverrouillage 30 s après passage en arrière-plan |
| Sauvegarde Android / Google Drive automatique | **Oui** | sauvegarde système désactivée |
| Analyse du trafic réseau | Sans objet | aucune permission internet, aucun serveur |
| Téléphone rooté, application ouverte | **Non** | la mémoire du processus est lisible |
| Code d'accès deviné par force brute | **Partiellement** | 5 essais puis blocage 5 min, compteur persistant ; un code à 6 chiffres est recommandé |
| Fichier de **sauvegarde** exporté (courriel, Drive, clé USB) | **Oui, si la phrase secrète est utilisée** | AES-256-GCM, clé dérivée en Argon2id — voir § 5 |
| Sauvegarde exportée **sans protection** (choix explicite) | **Non** | JSON en clair, précédé d'un avertissement |
| Phrase secrète oubliée | — | sauvegarde perdue : aucune récupération possible (par conception) |

---

## 4. Conversion des bases existantes

Une base créée avant cette version est en clair. Au premier lancement, la
conversion suit la procédure officielle SQLCipher, **sans perte** :

```sql
ATTACH DATABASE '<fichier>.chiffrement' AS chiffre KEY '<clé>';
SELECT sqlcipher_export('chiffre');
DETACH DATABASE chiffre;
```

Le fichier d'origine n'est supprimé qu'après succès complet de l'export ; en
cas d'erreur, rien n'a bougé. Un marqueur dans le coffre empêche toute
conversion répétée.

**Sauvegarde recommandée avant la première ouverture de cette version** :
`flutter build apk`, installation, export JSON — puis mise à jour.

---

## 5. Le fichier de sauvegarde : chiffré par phrase secrète

L'export produit un fichier **chiffré** (sauf si l'utilisateur demande
explicitement le contraire, avec un avertissement).

### 5.1 Chaîne de protection

```
Phrase secrète (jamais stockée)
        │
        ▼
   Argon2id (19 Mio, 2 passes, sel aléatoire de 16 octets)
        │
        ▼
   Clé AES-256  ──►  AES-256-GCM (nonce aléatoire de 12 octets)
                          │
                          ▼
        Enveloppe JSON : kdf + nonce + données + tag
```

- **Aucune clé n'est enregistrée** : elle est redérivée à chaque ouverture. Il
  n'existe donc pas de « clé de secours » à voler.
- **GCM authentifie** le contenu : une seule modification, même d'un octet, fait
  échouer le déchiffrement (pas de corruption silencieuse).
- **Sel et nonce sont neufs à chaque export** : deux sauvegardes du même
  contenu n'ont rien en commun, et un fichier ne peut pas révéler qu'un autre
  contient les mêmes données.

### 5.2 Enveloppe (auto-descriptive)

```json
{
  "application": "appharmacie",
  "type": "sauvegarde-chiffree",
  "format": 1,
  "kdf": { "algorithme": "argon2id", "memoire": 19456,
           "iterations": 2, "parallelisme": 1, "sel": "…" },
  "chiffrement": { "algorithme": "AES-256-GCM",
                   "nonce": "…", "donnees": "…", "tag": "…" }
}
```

Les paramètres voyagent avec le fichier : une sauvegarde faite avec des
paramètres plus faibles (ou plus forts) reste lisible, et la vérification
n'impose jamais de faire confiance à des réglages non lus.

### 5.3 Ce qui est refusé

- Phrase absente → « Cette sauvegarde est chiffrée : saisissez sa phrase
  secrète. »
- Phrase fausse **ou** fichier altéré → même message (« Phrase secrète
  incorrecte, ou fichier altéré ») : ne rien apprendre à un attaquant.
- Enveloppe d'une version de format plus récente → refus explicite (mettre à
  jour l'application).
- Sauvegarde en clair passée à la fonction de déchiffrement → refus explicite.

### 5.4 Le risque résiduel, énoncé sans détour

**Perdre la phrase = perdre la sauvegarde.** Il n'existe aucune récupération,
et c'est la contrepartie du chiffrement. L'interface l'affiche avant l'export et
rappelle que la phrase doit être conservée *séparément* du fichier.

Un export **sans protection** reste possible pour un transfert immédiat vers un
emplacement sûr, mais il est précédé d'un avertissement explicite : le fichier
est alors lisible par quiconque l'obtient.

---

## 6. Politique du code d'accès

| Paramètre | Valeur | Où |
|---|---|---|
| Longueur | 4 à 6 chiffres | `ReglesPin.longueurMin/Max` |
| Essais avant blocage | 5 | `ReglesPin.tentativesMax` |
| Durée du blocage | 5 minutes | `ReglesPin.dureeBlocage` |
| Compteur | persisté en base (redémarrer l'app ne remet pas à zéro) | table `parametres` |
| Reverrouillage | après 30 s en arrière-plan | `GardienSession.delaiReactivation` |
| Empreinte | **Argon2id** (19 Mio, 2 passes, 1 fil, sel de 16 octets) | `Securite.hacherFort` |
| Format | PHC autoportant `$argon2id$v=19$m=…,t=…,p=…$sel$empreinte` | `EmpreinteArgon2id` |
| Migration | empreintes SHA-256 héritées vérifiées puis réécrites à la volée | `Verrouillage._mettreANiveau` |

**Oubli du code** : il n'existe aucune récupération (par conception — un
« bouton magique » serait une porte dérobée). La sortie de secours est la
**sauvegarde JSON** : désinstaller, réinstaller, restaurer. C'est une raison
supplémentaire d'exporter régulièrement.

---

## 7. Dérivation des secrets : Argon2id

### 7.1 Pourquoi

SHA-256 salé est **rapide** : c'est exactement ce qu'il ne faut pas pour un mot
de passe. Un attaquant qui obtient une empreinte (sauvegarde JSON, téléphone
rooté) peut tester des milliards de candidats par seconde sur GPU. Argon2id
impose au contraire **du temps et de la mémoire** à chaque tentative, ce qui
rend l'attaque par dictionnaire hors ligne coûteuse.

### 7.2 Paramètres retenus

| Paramètre | Valeur | Justification |
|---|---|---|
| Mémoire | 19 456 kio (19 Mio) | minimum OWASP pour Argon2id |
| Passes | 2 | idem |
| Fils | 1 | téléphones d'entrée de gamme |
| Sel | 16 octets aléatoires, par secret | empêche les tables précalculées |
| Empreinte | 32 octets | marge suffisante |

Ces paramètres sont **écrits dans l'empreinte** (format PHC). Les durcir plus
tard — sur du matériel plus récent — n'invalide donc aucune empreinte
existante : chacune est vérifiée avec ses propres paramètres, et les secrets
migrent au format courant à la prochaine saisie correcte.

### 7.3 Coût perçu

Une vérification demande typiquement quelques centaines de millisecondes. Ce
délai est **visible** : l'écran de verrouillage affiche « Vérification… » avec
un indicateur de progression, et l'écran de connexion désactive son bouton. Ce
n'est pas une lenteur accidentelle, c'est le prix de la résistance hors ligne.

### 7.4 Migration (transparente, sans mot de passe perdu)

| Situation | Comportement |
|---|---|
| Mot de passe / code déjà en Argon2id | vérifié directement |
| Ancien SHA-256 salé | vérifié avec l'ancien algorithme, puis **réécrit en Argon2id** si correct |
| Mot de passe encore en clair (comptes d'origine) | comparé, puis réécrit en Argon2id |

Aucune action n'est demandée à l'utilisateur, et aucune empreinte faible ne
survit à une connexion réussie.

---

## 8. Limites connues et travaux restants

1. **Pas de verrouillage biométrique** (`local_auth`) : confort, pas sécurité.
2. **Rôles** : aujourd'hui tout compte peut tout faire, y compris supprimer
   une vente. Un rôle « vendeur » limité reste à définir.
3. **Écran de code sans anti-capture** : une capture d'écran reste possible
   sur les écrans de données (`FLAG_SECURE` non activé).
4. **Paramètres Argon2id non mesurés sur matériel réel** : à chronométrer sur
   le téléphone cible ; si la vérification dépasse ~1,5 s, descendre à
   `m=12 Mio, t=2` (toujours dans les recommandations OWASP). Le chiffrement
   d'une sauvegarde bénéficie du même réglage (il est fait une fois par
   export, quelques secondes sont acceptables).
