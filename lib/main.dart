import 'package:appharmacie/pages/achat.dart';
import 'package:appharmacie/pages/entree.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:appharmacie/authentification/login.dart';
import 'package:appharmacie/pages/accueil.dart';
import 'package:appharmacie/pages/medicament.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(),
      home: const LoginPage(),
    );
  }
}

class HomePage extends StatefulWidget {
  final int initialIndex;

  const HomePage({super.key, this.initialIndex = 0});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  void setCurrentIndex(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  Widget _getBody(int index) {
    switch (index) {
      case 0:
        return const AccueilPage(); // Utilisez AccueilPage à la place de HomePage
      case 1:
        return const EntreePage();// Utilisez EntreePage a la place de entree
      case 2:
        return const Medicament(); // Utilisez MedicamentPage à la place de Medicament
      case 3:
        return const AchatPage();
      default:
        return const AccueilPage(); // Utilisez AccueilPage à la place de HomePage
    }
  }

  String _getTitle(int index) {
    switch (index) {
      case 0:
        return 'Accueil';
      case 1:
        return 'Entrees';
      case 2:
        return 'Médicaments';
      case 3:
        return 'achats';
      default:
        return 'Accueil';
    }
  }

  void _logout() {
    // Déconnexion et retour à l'écran de connexion
    Get.offAll(() => const LoginPage());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _getTitle(_currentIndex),
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.green,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      body: _getBody(_currentIndex),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setCurrentIndex(index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.green,
        unselectedItemColor: Colors.grey,
        iconSize: 40,
        elevation: 10,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Accueil',
          ),

          BottomNavigationBarItem(
            icon: Icon(Icons.transit_enterexit),
            label: 'Entrees',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.medication),
            label: 'Médicaments',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.monetization_on),
            label: 'Achats',
          ),
        ],
      ),
    );
  }
}


