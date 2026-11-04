import 'package:appharmacie/core/exceptions.dart';
import 'package:appharmacie/core/stock_rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Disponibilité', () {
    test('stockSuffisant est cohérent', () {
      expect(StockRules.stockSuffisant(stock: 5, quantite: 5), isTrue);
      expect(StockRules.stockSuffisant(stock: 4, quantite: 5), isFalse);
      expect(StockRules.stockSuffisant(stock: 10, quantite: 0), isFalse);
      expect(StockRules.stockSuffisant(stock: 0, quantite: 1), isFalse);
    });

    test('une vente couverte par le stock ne lève rien', () {
      expect(
        () => StockRules.verifierDisponibilite(
          disponible: 10,
          demande: 10,
          designation: 'Paracétamol',
        ),
        returnsNormally,
      );
    });

    test('une vente supérieure au stock est refusée', () {
      expect(
        () => StockRules.verifierDisponibilite(
          disponible: 2,
          demande: 3,
          designation: 'Paracétamol',
        ),
        throwsA(isA<StockInsuffisantException>()),
      );
    });

    test('le message d\'erreur indique le stock disponible', () {
      try {
        StockRules.verifierDisponibilite(
          disponible: 2,
          demande: 5,
          designation: 'Amoxicilline',
        );
        fail('Une exception était attendue');
      } on StockInsuffisantException catch (erreur) {
        expect(erreur.disponible, 2);
        expect(erreur.demande, 5);
        expect(erreur.toString(), contains('Amoxicilline'));
      }
    });

    test('une demande nulle ou négative est refusée', () {
      expect(
        () => StockRules.verifierDisponibilite(
          disponible: 5,
          demande: 0,
          designation: 'Ibuprofène',
        ),
        throwsArgumentError,
      );
    });
  });

  group('FEFO (lots et péremptions)', () {
    test('sort d\'abord le lot dont la péremption est la plus proche', () {
      final allocations = allouerLots(
        lots: const <LotDisponible>[
          LotDisponible(
            id: 1,
            quantiteRestante: 10,
            datePeremption: '2027-12-31',
          ),
          LotDisponible(
            id: 2,
            quantiteRestante: 5,
            datePeremption: '2026-06-30',
          ),
        ],
        quantite: 7,
      );

      expect(allocations.map((a) => a.lotId).toList(), <int>[2, 1]);
      expect(allocations.first.quantite, 5);
      expect(allocations.last.quantite, 2);
      expect(quantiteAllouee(allocations), 7);
    });

    test('les lots sans péremption connue passent en dernier', () {
      final allocations = allouerLots(
        lots: const <LotDisponible>[
          LotDisponible(id: 1, quantiteRestante: 4),
          LotDisponible(
            id: 2,
            quantiteRestante: 4,
            datePeremption: '2030-01-01',
          ),
        ],
        quantite: 4,
      );

      expect(allocations.single.lotId, 2);
    });

    test('ignore les lots vides', () {
      final allocations = allouerLots(
        lots: const <LotDisponible>[
          LotDisponible(
            id: 1,
            quantiteRestante: 0,
            datePeremption: '2020-01-01',
          ),
          LotDisponible(
            id: 2,
            quantiteRestante: 6,
            datePeremption: '2030-01-01',
          ),
        ],
        quantite: 5,
      );

      expect(allocations.single.lotId, 2);
      expect(quantiteAllouee(allocations), 5);
    });

    test('alloue partiellement quand le stock ne suffit pas', () {
      final allocations = allouerLots(
        lots: const <LotDisponible>[
          LotDisponible(
            id: 1,
            quantiteRestante: 3,
            datePeremption: '2030-01-01',
          ),
        ],
        quantite: 5,
      );

      expect(quantiteAllouee(allocations), 3);
    });

    test('refuse une quantité nulle ou négative', () {
      expect(
        () => allouerLots(
          lots: const <LotDisponible>[
            LotDisponible(id: 1, quantiteRestante: 3),
          ],
          quantite: 0,
        ),
        throwsArgumentError,
      );
    });

    test('un lot périmé reste consommable (il est simplement signalé)', () {
      final allocations = allouerLots(
        lots: const <LotDisponible>[
          LotDisponible(
            id: 9,
            quantiteRestante: 2,
            datePeremption: '2020-01-01',
          ),
          LotDisponible(
            id: 10,
            quantiteRestante: 2,
            datePeremption: '2030-01-01',
          ),
        ],
        quantite: 3,
      );

      expect(allocations.first.lotId, 9);
      expect(quantiteAllouee(allocations), 3);
    });
  });

  test('le montant d\'une ligne est le produit prix × quantité', () {
    expect(StockRules.montantLigne(prixUnitaire: 1500, quantite: 3), 4500);
    expect(StockRules.montantLigne(prixUnitaire: 0, quantite: 3), 0);
    expect(
      () => StockRules.montantLigne(prixUnitaire: -1, quantite: 3),
      throwsArgumentError,
    );
  });
}
