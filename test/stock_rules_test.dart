import 'package:appharmacie/core/exceptions.dart';
import 'package:appharmacie/core/stock_rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Entrées de stock', () {
    test('une entrée augmente le stock de la quantité reçue', () {
      expect(
        StockRules.apresEntree(stockActuel: 0, quantiteEntree: 10),
        10,
      );
      expect(
        StockRules.apresEntree(stockActuel: 10, quantiteEntree: 5),
        15,
      );
    });

    test('une quantité nulle ou négative est refusée', () {
      expect(
        () => StockRules.apresEntree(stockActuel: 0, quantiteEntree: 0),
        throwsArgumentError,
      );
      expect(
        () => StockRules.apresEntree(stockActuel: 0, quantiteEntree: -3),
        throwsArgumentError,
      );
    });
  });

  group('Ventes', () {
    test('une vente diminue le stock', () {
      expect(
        StockRules.apresVente(
          stockActuel: 20,
          quantiteVendue: 8,
          designation: 'Paracétamol',
        ),
        12,
      );
    });

    test('une vente supérieure au stock est refusée', () {
      expect(
        () => StockRules.apresVente(
          stockActuel: 2,
          quantiteVendue: 3,
          designation: 'Paracétamol',
        ),
        throwsA(isA<StockInsuffisantException>()),
      );
    });

    test('le message d\'erreur indique le stock disponible', () {
      try {
        StockRules.apresVente(
          stockActuel: 2,
          quantiteVendue: 5,
          designation: 'Amoxicilline',
        );
        fail('Une exception était attendue');
      } on StockInsuffisantException catch (erreur) {
        expect(erreur.disponible, 2);
        expect(erreur.demande, 5);
        expect(erreur.toString(), contains('Amoxicilline'));
      }
    });

    test('stockSuffisant est cohérent', () {
      expect(StockRules.stockSuffisant(stock: 5, quantite: 5), isTrue);
      expect(StockRules.stockSuffisant(stock: 4, quantite: 5), isFalse);
      expect(StockRules.stockSuffisant(stock: 10, quantite: 0), isFalse);
    });
  });

  group('Modification d\'une entrée (régression du bug « SUM »)', () {
    test('seule la différence est appliquée, les ventes restent déduites', () {
      // 10 entrés, 10 vendus -> stock 0 ; l'entrée passe de 10 à 12.
      expect(
        StockRules.apresModificationEntree(
          stockActuel: 0,
          ancienneQuantite: 10,
          nouvelleQuantite: 12,
        ),
        2,
      );
    });

    test('diminuer une entrée retire la différence', () {
      expect(
        StockRules.apresModificationEntree(
          stockActuel: 5,
          ancienneQuantite: 10,
          nouvelleQuantite: 7,
        ),
        2,
      );
    });
  });

  group('Modification d\'une vente', () {
    test('augmenter une vente consomme le stock', () {
      expect(
        StockRules.apresModificationVente(
          stockActuel: 10,
          ancienneQuantite: 2,
          nouvelleQuantite: 5,
          designation: 'Ibuprofène',
        ),
        7,
      );
    });

    test('diminuer une vente rend du stock', () {
      expect(
        StockRules.apresModificationVente(
          stockActuel: 10,
          ancienneQuantite: 5,
          nouvelleQuantite: 2,
          designation: 'Ibuprofène',
        ),
        13,
      );
    });

    test('augmenter au-delà du stock disponible est refusé', () {
      expect(
        () => StockRules.apresModificationVente(
          stockActuel: 1,
          ancienneQuantite: 2,
          nouvelleQuantite: 5,
          designation: 'Ibuprofène',
        ),
        throwsA(isA<StockInsuffisantException>()),
      );
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
