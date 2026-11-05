import 'package:appharmacie/Models/users.dart';
import 'package:appharmacie/core/exceptions.dart';
import 'package:appharmacie/core/roles.dart';
import 'package:appharmacie/core/session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Matrice des droits', () {
    test('le vendeur encaisse et consulte, mais ne supprime rien', () {
      const droits = Permissions(RoleUtilisateur.vendeur);

      expect(droits.estGestionnaire, isFalse);
      expect(droits.peutConsulter, isTrue);
      expect(droits.peutVendre, isTrue);
      expect(droits.peutCreerEntree, isTrue);

      expect(droits.peutModifierEntree, isFalse);
      expect(droits.peutModifierVente, isFalse);
      expect(droits.peutSupprimerVente, isFalse);
      expect(droits.peutGererCatalogue, isFalse);
      expect(droits.peutGererUtilisateurs, isFalse);
      expect(droits.peutSauvegarder, isFalse);
      expect(droits.peutRestaurer, isFalse);
      expect(droits.peutGererSecurite, isFalse);
    });

    test('le gestionnaire a tous les droits', () {
      const droits = Permissions(RoleUtilisateur.gestionnaire);

      expect(droits.estGestionnaire, isTrue);
      expect(droits.peutConsulter, isTrue);
      expect(droits.peutVendre, isTrue);
      expect(droits.peutCreerEntree, isTrue);
      expect(droits.peutModifierEntree, isTrue);
      expect(droits.peutModifierVente, isTrue);
      expect(droits.peutSupprimerVente, isTrue);
      expect(droits.peutGererCatalogue, isTrue);
      expect(droits.peutGererUtilisateurs, isTrue);
      expect(droits.peutSauvegarder, isTrue);
      expect(droits.peutRestaurer, isTrue);
      expect(droits.peutGererSecurite, isTrue);
    });
  });

  group('Lecture du rôle stocké', () {
    test('un rôle absent vient d\'un compte historique : gestionnaire', () {
      expect(RoleUtilisateur.depuis(null), RoleUtilisateur.gestionnaire);
      expect(RoleUtilisateur.depuis(''), RoleUtilisateur.gestionnaire);
      expect(RoleUtilisateur.depuis('   '), RoleUtilisateur.gestionnaire);
    });

    test('un rôle connu est relu, quelle que soit la casse', () {
      expect(
        RoleUtilisateur.depuis('gestionnaire'),
        RoleUtilisateur.gestionnaire,
      );
      expect(RoleUtilisateur.depuis('Vendeur'), RoleUtilisateur.vendeur);
      expect(RoleUtilisateur.depuis(' VENDEUR '), RoleUtilisateur.vendeur);
    });

    test('un rôle inconnu retombe sur le moindre privilège', () {
      expect(RoleUtilisateur.depuis('administrateur'), RoleUtilisateur.vendeur);
      expect(RoleUtilisateur.depuis('proprietaire'), RoleUtilisateur.vendeur);
    });

    test('libellés et valeurs stockées sont stables', () {
      for (final role in RoleUtilisateur.values) {
        expect(role.libelle, isNotEmpty);
        expect(role.description, isNotEmpty);
        expect(role.valeurBase, role.name);
        expect(RoleUtilisateur.depuis(role.valeurBase), role);
      }
    });
  });

  group('Session', () {
    tearDown(Session.fermer);

    test('sans session, l\'application se comporte comme un vendeur', () {
      expect(Session.estOuverte, isFalse);
      expect(Session.nom, isEmpty);
      expect(Session.role, RoleUtilisateur.vendeur);
      expect(Session.permissions.estGestionnaire, isFalse);
    });

    test('une session vendeur refuse les actions de gestion', () {
      Session.ouvrir(nom: 'Rina', role: RoleUtilisateur.vendeur);

      expect(Session.estOuverte, isTrue);
      expect(Session.nom, 'Rina');
      expect(
        () => Session.exigerGestionnaire('supprimer une vente'),
        throwsA(isA<OperationRefuseeException>()),
      );
    });

    test('une session gestionnaire ouvre les actions de gestion', () {
      Session.ouvrir(nom: 'Tahiry', role: RoleUtilisateur.gestionnaire);

      expect(Session.permissions.estGestionnaire, isTrue);
      expect(() => Session.exigerGestionnaire('supprimer une vente'), returnsNormally);
      expect(() => Session.exiger(true, 'modifier un prix'), returnsNormally);
      expect(
        () => Session.exiger(false, 'modifier un prix'),
        throwsA(isA<OperationRefuseeException>()),
      );
    });

    test('fermer la session redescend au niveau vendeur', () {
      Session.ouvrir(nom: 'Tahiry', role: RoleUtilisateur.gestionnaire);
      Session.fermer();

      expect(Session.estOuverte, isFalse);
      expect(Session.permissions.estGestionnaire, isFalse);
      expect(Session.nom, isEmpty);
    });
  });

  group('Règles de gestion des comptes', () {
    test('compter les gestionnaires', () {
      expect(ReglesComptes.compterGestionnaires(<RoleUtilisateur>[]), 0);
      expect(
        ReglesComptes.compterGestionnaires(<RoleUtilisateur>[
          RoleUtilisateur.gestionnaire,
          RoleUtilisateur.vendeur,
          RoleUtilisateur.gestionnaire,
        ]),
        2,
      );
    });

    test('le dernier gestionnaire ne peut pas perdre son rôle', () {
      expect(
        ReglesComptes.peutRetirerGestionnaire(
          gestionnaires: 1,
          roleActuel: RoleUtilisateur.gestionnaire,
        ),
        isFalse,
      );
      expect(
        ReglesComptes.peutRetirerGestionnaire(
          gestionnaires: 2,
          roleActuel: RoleUtilisateur.gestionnaire,
        ),
        isTrue,
      );
      // Rétrograder un vendeur est toujours possible (aucun effet).
      expect(
        ReglesComptes.peutRetirerGestionnaire(
          gestionnaires: 1,
          roleActuel: RoleUtilisateur.vendeur,
        ),
        isTrue,
      );
    });

    test('la suppression d\'un compte est encadrée', () {
      // Jamais le compte avec lequel on travaille.
      expect(
        ReglesComptes.peutSupprimer(
          gestionnaires: 3,
          roleCible: RoleUtilisateur.vendeur,
          compteConnecte: true,
        ),
        isFalse,
      );
      // Un vendeur part sans conséquence.
      expect(
        ReglesComptes.peutSupprimer(
          gestionnaires: 1,
          roleCible: RoleUtilisateur.vendeur,
          compteConnecte: false,
        ),
        isTrue,
      );
      // Le dernier gestionnaire reste.
      expect(
        ReglesComptes.peutSupprimer(
          gestionnaires: 1,
          roleCible: RoleUtilisateur.gestionnaire,
          compteConnecte: false,
        ),
        isFalse,
      );
      expect(
        ReglesComptes.peutSupprimer(
          gestionnaires: 2,
          roleCible: RoleUtilisateur.gestionnaire,
          compteConnecte: false,
        ),
        isTrue,
      );
    });

    test('les refus portent un message affichable', () {
      expect(
        () => ReglesComptes.verifierSuppression(
          gestionnaires: 1,
          roleCible: RoleUtilisateur.gestionnaire,
          compteConnecte: false,
        ),
        throwsA(
          isA<OperationRefuseeException>().having(
            (erreur) => erreur.toString(),
            'message',
            contains('au moins un gestionnaire'),
          ),
        ),
      );
      expect(
        () => ReglesComptes.verifierSuppression(
          gestionnaires: 2,
          roleCible: RoleUtilisateur.vendeur,
          compteConnecte: true,
        ),
        throwsA(
          isA<OperationRefuseeException>().having(
            (erreur) => erreur.toString(),
            'message',
            contains('connecté'),
          ),
        ),
      );
      expect(
        () => ReglesComptes.verifierSuppression(
          gestionnaires: 2,
          roleCible: RoleUtilisateur.vendeur,
          compteConnecte: false,
        ),
        returnsNormally,
      );
    });
  });

  group('Comptes', () {
    test('une ligne sans rôle est lue comme gestionnaire', () {
      final compte = Users.fromMap(<String, dynamic>{
        'usrId': 1,
        'usrName': 'Tahiry',
        'usrPassword': 'empreinte',
      });

      expect(compte.usrId, 1);
      expect(compte.usrName, 'Tahiry');
      expect(compte.usrRole, RoleUtilisateur.gestionnaire);
    });

    test('le rôle est écrit sous forme stable', () {
      const compte = Users(
        usrId: 4,
        usrName: 'Rina',
        usrPassword: 'secret',
        usrRole: RoleUtilisateur.vendeur,
      );
      final carte = compte.toMap();

      expect(carte['usrRole'], 'vendeur');
      expect(carte['usrId'], 4);
      expect(carte.containsKey('usrSalt'), isFalse);
      expect(
        Users.fromMap(carte).usrRole,
        RoleUtilisateur.vendeur,
      );
    });

    test('un nouveau compte est vendeur par défaut', () {
      const compte = Users(usrName: 'Rina', usrPassword: 'secret');
      expect(compte.usrRole, RoleUtilisateur.vendeur);
    });
  });
}
