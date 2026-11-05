import 'package:appharmacie/Models/mouvement.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Lecture d\'un mouvement', () {
    test('une ligne complète est lue sans perte', () {
      final mouvement = Mouvement.fromMap(<String, dynamic>{
        'id': 42,
        'numMed': 'MED-001',
        'type': 'SORTIE',
        'quantite': -3,
        'reference': 'ACHAT:48',
        'dateMouvement': '2026-03-12 14:05:31',
        'auteur': 'Tahiry',
        'designMed': 'Paracétamol 500 mg',
      });

      expect(mouvement.id, 42);
      expect(mouvement.numMed, 'MED-001');
      expect(mouvement.estEntree, isFalse);
      expect(mouvement.quantite, -3);
      expect(mouvement.dateMouvement, '2026-03-12 14:05:31');
      expect(mouvement.designMed, 'Paracétamol 500 mg');
    });

    test('une ligne incomplète ne fait pas échouer la lecture', () {
      final mouvement = Mouvement.fromMap(<String, dynamic>{});

      expect(mouvement.id, isNull);
      expect(mouvement.numMed, isEmpty);
      expect(mouvement.quantite, 0);
      expect(mouvement.estEntree, isFalse);
      expect(mouvement.libelleType, 'Mouvement');
      expect(mouvement.referenceAffichee, 'sans référence');
    });
  });

  group('Affichage', () {
    test('la quantité affichée est toujours positive', () {
      final entree = Mouvement.fromMap(<String, dynamic>{
        'type': 'ENTREE',
        'quantite': 12,
      });
      final sortie = Mouvement.fromMap(<String, dynamic>{
        'type': 'SORTIE',
        'quantite': -12,
      });

      expect(entree.quantiteAffichee, 12);
      expect(sortie.quantiteAffichee, 12);
      expect(entree.estEntree, isTrue);
      expect(sortie.estEntree, isFalse);
    });

    test('les types sont traduits, l\'inconnu reste lisible', () {
      String libelle(String type) =>
          Mouvement.fromMap(<String, dynamic>{'type': type}).libelleType;

      expect(libelle('ENTREE'), 'Entrée');
      expect(libelle('SORTIE'), 'Sortie');
      // Casse différente : les données anciennes ne sont pas normalisées.
      expect(libelle('entree'), 'Entrée');
      // Valeur inattendue : on l'affiche telle quelle plutôt que de mentir.
      expect(libelle('AJUSTEMENT'), 'AJUSTEMENT');
    });

    test('l\'auteur est explicite quand il manque', () {
      final ancien = Mouvement.fromMap(<String, dynamic>{
        'type': 'ENTREE',
        'quantite': 5,
      });
      final recent = Mouvement.fromMap(<String, dynamic>{
        'type': 'ENTREE',
        'quantite': 5,
        'auteur': '  Rina  ',
      });

      expect(ancien.auteurAffiche, 'compte non enregistré');
      expect(recent.auteurAffiche, 'Rina');
    });

    test('la référence est traduite en langage d\'officine', () {
      String reference(String? valeur) =>
          Mouvement.fromMap(<String, dynamic>{'reference': valeur})
              .referenceAffichee;

      expect(reference('ACHAT:48'), 'Vente 48');
      expect(reference('ENTREE:12'), 'Réception 12');
      expect(reference('achat:7'), 'Vente 7');
      expect(reference('AUTRE:3'), 'AUTRE:3');
      expect(reference(null), 'sans référence');
      expect(reference('   '), 'sans référence');
    });
  });
}
