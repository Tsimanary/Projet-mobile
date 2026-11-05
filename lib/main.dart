import 'package:flutter/material.dart';

import 'Authentification/login.dart';
import 'core/biometrie_systeme.dart';
import 'core/gardien_session.dart';
import 'core/theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Branche le capteur biométrique réel. Aucun accès disque ici : le réglage
  // est relu par le gardien de session, une fois la base ouverte.
  installerBiometrieSysteme();
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
