# Politique de confidentialité — AppHarmacie

**Dernière mise à jour : 5 novembre 2026**

AppHarmacie est une application de gestion d'officine (catalogue de
médicaments, entrées de stock par lot, péremptions, ventes, factures PDF).

## 1. Principe : tout reste sur votre téléphone

L'application fonctionne **entièrement hors ligne**. Elle ne dispose d'aucune
autorisation système (ni internet, ni stockage, ni localisation, ni contacts) et
n'envoie aucune donnée vers un serveur : il n'existe aucun serveur.

## 2. Données enregistrées par l'application

| Donnée | Finalité | Où |
|---|---|---|
| Nom du compte et mot de passe (haché avec sel) | authentification locale | base SQLite de l'application |
| Médicaments (numéro, désignation, prix, stock) | gestion du stock | idem |
| Lots (numéro, péremption, quantités) et mouvements | traçabilité, FEFO | idem |
| Entrées et ventes (dates, quantités, nom du client si saisi) | historique, facturation | idem |
| Sauvegardes exportées | sauvegarde / migration | fichier choisi par l'utilisateur |

Aucune donnée n'est collectée par l'éditeur, aucun identifiant publicitaire
n'est utilisé, aucune analyse d'usage n'est effectuée.

## 3. Partage

L'application ne partage rien automatiquement. Le seul partage possible est
l'export de sauvegarde, **déclenché par vous** : le fichier est transmis à
l'application que vous choisissez (courriel, Drive, WhatsApp…), qui applique
alors sa propre politique de confidentialité.

Ce fichier contient l'intégralité de vos données (y compris les comptes
utilisateurs hachés). Conservez-le dans un emplacement protégé.

## 4. Conservation et suppression

Les données restent sur l'appareil jusqu'à ce que vous les supprimiez :

- suppression d'une fiche, d'une entrée ou d'une vente depuis l'application ;
- écran **Sauvegarde** → restauration d'une sauvegarde vierge ;
- désinstallation de l'application (supprime la base et les fichiers temporaires).

## 5. Sécurité

- Mots de passe stockés hachés (sel aléatoire + SHA-256), jamais en clair.
- Sauvegarde système Android désactivée : les données ne partent pas vers
  Google Drive via la sauvegarde automatique.
- Requêtes SQL paramétrées.
- Limite connue : la base n'est pas encore chiffrée au repos ; la protection
  repose sur le verrouillage de l'appareil. Le chiffrement et un code d'accès
  sont planifiés.

## 6. Données de santé et données personnelles

L'application gère des données de stock de médicaments. Si vous saisissez un nom
de client dans une vente, il s'agit d'une donnée personnelle : vous êtes
responsable de son usage et de sa conservation, conformément à la réglementation
applicable à Madagascar (loi n° 2014-038 sur la protection des données à
caractère personnel) et, le cas échéant, au RGPD pour les utilisateurs de
l'Union européenne.

## 7. Vos droits

Vous accédez à vos données, les exportez et les supprimez directement depuis
l'application, sans intervention de l'éditeur — celui-ci n'y ayant aucun accès.

## 8. Mineurs

L'application est un outil professionnel destiné aux personnels d'officine ;
elle ne s'adresse pas aux enfants.

## 9. Modifications

Toute évolution de cette politique sera publiée à cette adresse, avec la date de
mise à jour correspondante.
