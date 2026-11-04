# Sécurité — modèle de menace et choix techniques

Ce document explique **ce que protège** l'application, **comment**, et **ce
qu'elle ne protège pas**. Il est destiné à être relu avant toute mise en
production et à chaque évolution sensible.

---

## 1. Deux verrous, deux rôles

| Verrou | Ce qu'il protège | Où vit le secret |
|---|---|---|
| **Chiffrement de la base** (SQLCipher) | le fichier `.db` au repos : vol du téléphone, copie du fichier, extraction par sauvegarde, ADB, outil de récupération | clé de 32 octets aléatoires, dans le **Keystore** Android via `flutter_secure_storage` |
| **Code d'accès** (4 à 6 chiffres) | l'accès à l'application sur un téléphone **déjà déverrouillé** | empreinte salée SHA-256 dans la table `parametres` de la base chiffrée |

Ils sont indépendants : le code d'accès n'est pas la clé de chiffrement. C'est
volontaire — un code à 4 chiffres (10 000 combinaisons) est un verrou
d'usage, pas un secret cryptographique.

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
| Fichier de **sauvegarde** exporté | **Non** | JSON en clair — voir § 5 |

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

## 5. Le point faible assumé : le fichier de sauvegarde

L'export produit un **JSON lisible** (c'est ce qui le rend restaurable sur un
autre appareil et inspectable en cas d'incident). Il contient les données de
gestion : catalogue, lots, mouvements, entrées, ventes, comptes (mots de passe
hachés).

Conséquences, affichées dans l'écran **Sécurité** et **Sauvegarde** :

- ne le stockez pas dans un dossier partagé ou une messagerie ouverte ;
- un export envoyé par courriel est un export potentiellement exposé ;
- il n'est **pas** chiffré par la clé de l'appareil (elle ne quitterait pas le
  téléphone, et le fichier doit rester restaurable ailleurs).

**Prochaine étape prévue** : chiffrement du fichier de sauvegarde par phrase
secrète (Argon2id + AES-GCM via le paquet `cryptography`). Non implémenté ici
volontairement : une cryptographie faite à la main est plus dangereuse que son
absence.

---

## 6. Politique du code d'accès

| Paramètre | Valeur | Où |
|---|---|---|
| Longueur | 4 à 6 chiffres | `ReglesPin.longueurMin/Max` |
| Essais avant blocage | 5 | `ReglesPin.tentativesMax` |
| Durée du blocage | 5 minutes | `ReglesPin.dureeBlocage` |
| Compteur | persisté en base (redémarrer l'app ne remet pas à zéro) | table `parametres` |
| Reverrouillage | après 30 s en arrière-plan | `GardienSession.delaiReactivation` |
| Empreinte | SHA-256 salé (sel aléatoire par code) | `Securite` |

**Oubli du code** : il n'existe aucune récupération (par conception — un
« bouton magique » serait une porte dérobée). La sortie de secours est la
**sauvegarde JSON** : désinstaller, réinstaller, restaurer. C'est une raison
supplémentaire d'exporter régulièrement.

---

## 7. Limites connues et travaux restants

1. **SHA-256 salé** pour le code et les mots de passe : rapide, donc vulnérable
   hors ligne. Cible : **Argon2id** (paquet `cryptography`), avec migration
   transparente des empreintes existantes.
2. **Sauvegarde non chiffrée** (§ 5).
3. **Pas de verrouillage biométrique** (`local_auth`) : confort, pas sécurité.
4. **Rôles** : aujourd'hui tout compte peut tout faire, y compris supprimer
   une vente. Un rôle « vendeur » limité reste à définir.
5. **Écran de code sans anti-capture** : une capture d'écran reste possible
   sur les écrans de données (`FLAG_SECURE` non activé).
