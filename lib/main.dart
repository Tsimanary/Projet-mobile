import 'package:flutter/material.dart';

import 'Authentification/login.dart';
import 'core/biometrie_systeme.dart';
import 'core/ecran_securise.dart';
import 'core/gardien_session.dart';
import 'core/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Branche le capteur biométrique réel. Aucun accès disque ici : le réglage
  // est relu par le gardien de session, une fois la base ouverte.
  installerBiometrieSysteme();
  // Captures d'écran et miniatures bloquées sur toute l'application.
  await EcranSecurise.activer();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AppHarmacie',
      debugShowCheckedModeBanner: false,
      theme: construireTheme(),
      // Le gardien recouvre toute l'application de l'écran de déverrouillage
      // lorsqu'un code d'accès est configuré.
      builder: (context, child) =>
          GardienSession(child: child ?? const SizedBox.shrink()),
      home: const LoginPage(),
    );
  }
}
