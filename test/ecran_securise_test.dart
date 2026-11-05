import 'package:appharmacie/core/ecran_securise.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  setUp(EcranSecurise.reinitialiser);

  tearDown(() {
    messenger.setMockMethodCallHandler(EcranSecurise.canal, null);
    EcranSecurise.reinitialiser();
  });

  void repondre(Future<Object?> Function(MethodCall appel) gestionnaire) {
    messenger.setMockMethodCallHandler(
      EcranSecurise.canal,
      (appel) async => gestionnaire(appel),
    );
  }

  test('activer pose le drapeau et retient l\'état', () async {
    final appels = <String>[];
    repondre((appel) async {
      appels.add(appel.method);
      return true;
    });

    expect(await EcranSecurise.activer(), isTrue);
    expect(appels, <String>['activer']);
    expect(EcranSecurise.actif, isTrue);
  });

  test('désactiver retire le drapeau', () async {
    final appels = <String>[];
    repondre((appel) async {
      appels.add(appel.method);
      return true;
    });

    await EcranSecurise.activer();
    expect(await EcranSecurise.desactiver(), isTrue);
    expect(appels, <String>['activer', 'desactiver']);
    expect(EcranSecurise.actif, isFalse);
  });

  test('une erreur de plateforme ne fait pas planter l\'application',
      () async {
    repondre((appel) async {
      throw PlatformException(code: 'refus', message: 'fenêtre indisponible');
    });

    expect(await EcranSecurise.activer(), isFalse);
    expect(EcranSecurise.actif, isFalse);
  });

  test('sans implémentation (bureau, test) le blocage reste inactif',
      () async {
    // Aucun gestionnaire simulé : le canal lève MissingPluginException.
    expect(await EcranSecurise.activer(), isFalse);
    expect(EcranSecurise.actif, isFalse);
  });
}
