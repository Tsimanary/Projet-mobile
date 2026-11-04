import 'package:flutter/material.dart';

import 'Authentification/login.dart';
import 'core/gardien_session.dart';
import 'core/theme.dart';

void main() {
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
