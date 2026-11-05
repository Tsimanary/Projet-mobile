# Publication sur le Play Store — procédure complète

État du dépôt : **prêt à signer et à téléverser**. Ce document décrit ce qui est
déjà configuré, puis les étapes qui exigent votre compte Google Play et votre
clé de signature (que personne d'autre que vous ne doit détenir).

---

## 1. Ce qui est déjà configuré

| Élément | Valeur |
|---|---|
| `applicationId` | `com.tsimanary.appharmacie` |
| `namespace` Android | `com.tsimanary.appharmacie` |
| Nom affiché | **AppHarmacie** |
| Icône | `android/app/src/main/res/mipmap-*/ic_launcher.png` (48 → 192 px) |
| Version | `pubspec.yaml` → `version: 1.4.0+4` (`1.4.0` = nom, `4` = versionCode) |
| AGP / Gradle / Kotlin / JDK | 8.3.2 / 8.4 / 1.9.22 / 17 |
| Signature release | lue dans `android/key.properties` s'il existe, sinon clés de debug |
| Permissions demandées | **aucune** (pas d'internet, pas de stockage, pas de localisation) |
| Sauvegarde Android | désactivée (`allowBackup="false"`) |
| Éléments Play Store prêts | `store/jeu-icone-512.png` (icône 512 × 512) |

> L'`applicationId` est **définitif** : le changer après publication crée une
> nouvelle application et perd les utilisateurs existants.

---

## 2. Prérequis machine

- Flutter ≥ 3.22 (`flutter --version`)
- JDK **17** (`java -version`) — obligatoire avec AGP 8
- Android SDK avec la plateforme **34**
- `keytool` (fourni avec le JDK)

---

## 3. Créer la clé de signature (une seule fois)

```bash
keytool -genkey -v -keystore ~/appharmacie-upload.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Conservez `appharmacie-upload.jks` **hors du dépôt** et sauvegardé en lieu sûr
(coffre, disque chiffré). En cas de perte, il devient impossible de publier une
mise à jour — seul un changement de clé via Google Play App Signing le permet,
et il faut alors ouvrir un ticket au support.

Créez ensuite `android/key.properties` à partir du modèle :

```bash
cp android/key.properties.example android/key.properties
# puis renseigner storePassword, keyPassword, keyAlias, storeFile
```

`android/key.properties`, `*.jks` et `*.keystore` sont déjà dans
`android/.gitignore` : ils ne partiront jamais sur GitHub.

---

## 4. Construire le paquet de publication

```bash
flutter clean
flutter pub get
flutter build appbundle --release
```

Résultat : `build/app/outputs/bundle/release/app-release.aab`

Pour tester la version signée sur un téléphone avant l'envoi :

```bash
flutter build apk --release
flutter install --release
```

Vérifications utiles :

```bash
# Taille des composants
flutter build appbundle --release --analyze-size

# Contrôle de la signature du bundle
jarsigner -verify -verbose -certs build/app/outputs/bundle/release/app-release.aab
```

---

## 5. Créer l'application dans la Play Console

1. [play.google.com/console](https://play.google.com/console) → **Créer une
   application**.
2. Nom : `AppHarmacie` — Langue : Français — Type : Application — Gratuite.
3. **Configuration de la fiche** :
   - Description courte (80 car.) :
     `Gestion d'officine : stock, lots, péremptions, ventes et factures PDF.`
   - Description longue : reprendre le README (fonctionnalités, mode hors ligne,
     sauvegarde).
   - Icône : `store/jeu-icone-512.png`.
   - Graphisme de mise en avant : 1024 × 500 (facultatif mais recommandé).
   - Captures d'écran téléphone : **au moins 2** (tableau de bord, lots).
4. **Classification du contenu** : application utilitaire/professionnelle, pas
   de contenu sensible, pas de publicité.
5. **Sécurité des données** (Data safety) :
   - « L'application collecte-t-elle ou partage-t-elle des données ? » →
     **Non**. Toutes les données restent sur l'appareil.
   - « Les données sont-elles chiffrées en transit ? » → sans objet (aucun
     transfert).
   - Suppression des données : l'utilisateur supprime l'application, ou utilise
     l'écran **Sauvegarde** pour exporter puis effacer.
6. **Politique de confidentialité** : URL publique obligatoire — voir § 6.
7. **Pays** : Madagascar en priorité, puis les marchés francophones.
8. **Tests** : créer une piste *Test interne* (jusqu'à 100 testeurs), installer
   via le lien, valider le parcours complet (entrée → vente → sauvegarde), puis
   promouvoir en production.

---

## 6. Politique de confidentialité

Le texte est fourni dans [`docs/CONFIDENTIALITE.md`](CONFIDENTIALITE.md) et en
version publiable dans [`docs/confidentialite.html`](confidentialite.html).

Pour obtenir une URL publique sans serveur, activez **GitHub Pages** sur ce
dépôt (Settings → Pages → branche `main`, dossier `/docs`) : la page sera
disponible à l'adresse

```
https://tsimanary.github.io/Projet-mobile/confidentialite.html
```

C'est cette URL qu'il faut saisir dans la Play Console.

---

## 7. Mises à jour

1. Incrémenter la version dans `pubspec.yaml` : `version: 1.5.0+5`
   (le nombre après `+` **doit** augmenter à chaque envoi).
2. `flutter build appbundle --release`
3. Play Console → Piste de production → **Créer une release** → téléverser
   l'`.aab` → notes de version → déployer.

---

## 8. Points de vigilance spécifiques à une application de santé

- **Aucune donnée ne doit quitter l'appareil sans action de l'utilisateur.**
  C'est le cas aujourd'hui : le seul partage est l'export de sauvegarde, lancé
  manuellement, qui contient des données de stock (pas de données patients).
- Les noms de clients saisis dans les ventes sont des données personnelles :
  évitez d'y consigner des informations médicales.
- Si vous ajoutez plus tard un backend, la déclaration *Data safety* devra être
  mise à jour **avant** la publication.
- Recommandé avant une utilisation réelle : chiffrement de la base
  (`sqflite_sqlcipher`) et code d'accès obligatoire.

---

## 9. Check-list d'envoi

- [ ] JDK 17 installé et `flutter doctor -v` sans erreur
- [ ] `android/key.properties` créé, keystore sauvegardé hors du dépôt
- [ ] `flutter analyze` et `flutter test` au vert
- [ ] `flutter build appbundle --release` réussi
- [ ] Installation de test validée sur un téléphone réel
- [ ] Icône 512 × 512 + 2 captures d'écran
- [ ] Texte de la politique de confidentialité en ligne
- [ ] Déclaration *Data safety* remplie (aucune collecte)
- [ ] Piste de test interne validée avant la production
