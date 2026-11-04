import 'package:appharmacie/core/backup_format.dart';
import 'package:appharmacie/core/exceptions.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Format de sauvegarde', () {
    test('un aller-retour conserve toutes les tables', () {
      final document = construireSauvegarde(
        <String, Object?>{
          'medics': <Object?>[
            <String, Object?>{'numMed': 'P001', 'designMed': 'Paracétamol'},
          ],
          'achats': <Object?>[
            <String, Object?>{'numMed': 'P001', 'nbr': 2},
          ],
        },
        maintenant: DateTime(2026, 11, 5, 9, 30),
      );

      final tables = analyserSauvegarde(document);

      expect((tables['medics'] as List).length, 1);
      expect((tables['achats'] as List).length, 1);
      expect(tables['lots'], isEmpty);
      expect(tables['entrees'], isEmpty);
      expect(tables['mouvements_stock'], isEmpty);
      expect(tables['users'], isEmpty);
      expect(compterLignesSauvegarde(tables), 2);
      expect(document, contains('"application": "appharmacie"'));
      expect(document, contains('2026-11-05T09:30:00.000'));
    });

    test('un contenu qui n\'est pas du JSON est refusé', () {
      expect(
        () => analyserSauvegarde('ceci n\'est pas une sauvegarde'),
        throwsA(isA<OperationRefuseeException>()),
      );
    });

    test('un JSON valide mais étranger à l\'application est refusé', () {
      expect(
        () => analyserSauvegarde('{"application":"autre","format":1,"tables":{}}'),
        throwsA(isA<OperationRefuseeException>()),
      );
    });

    test('une sauvegarde trop récente est refusée explicitement', () {
      final tropRecent = '{"application":"appharmacie","format":99,'
          '"tables":{"users":[],"medics":[],"lots":[],'
          '"mouvements_stock":[],"entrees":[],"achats":[]}}';

      expect(
        () => analyserSauvegarde(tropRecent),
        throwsA(
          isA<OperationRefuseeException>().having(
            (e) => e.toString(),
            'message',
            contains('plus récente'),
          ),
        ),
      );
    });

    test('une table manquante est signalée', () {
      final incomplet = '{"application":"appharmacie","format":1,'
          '"tables":{"users":[],"medics":[]}}';

      expect(
        () => analyserSauvegarde(incomplet),
        throwsA(
          isA<OperationRefuseeException>().having(
            (e) => e.toString(),
            'message',
            contains('absente'),
          ),
        ),
      );
    });

    test('toutes les tables attendues sont déclarées', () {
      expect(
        tablesSauvegardees,
        containsAll(<String>[
          'users',
          'medics',
          'lots',
          'mouvements_stock',
          'entrees',
          'achats',
        ]),
      );
    });
  });
}
