import 'package:flutter/material.dart';
import '../SQLite/sqlite.dart';
import '../Models/medic.dart';
import '../Models/acht.dart';

class AccueilPage extends StatefulWidget {
  const AccueilPage({super.key});

  @override
  State<AccueilPage> createState() => _AccueilPageState();
}

class _AccueilPageState extends State<AccueilPage> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  late List<Medic> _lowStockMedics = [];
  late double _totalRevenue = 0.0;
  late List<Medic> _topSellingMedics = [];

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
  }

  void _fetchDashboardData() async {
    List<Medic> medics = await _dbHelper.getAllMedics();
    List<Achat> achats = await _dbHelper.getAllAchats();

    double totalRevenue = achats.fold(0.0, (sum, achat) =>
    sum + (achat.nbr * medics.firstWhere((m) => m.numMed == achat.numMed).prixMed));

    List<Medic> lowStockMedics = medics.where((m) => m.stockMed < 5).toList();

    Map<String, int> medicSalesCount = {};
    for (var achat in achats) {
      if (medicSalesCount.containsKey(achat.numMed)) {
        medicSalesCount[achat.numMed] = medicSalesCount[achat.numMed]! + achat.nbr;
      } else {
        medicSalesCount[achat.numMed] = achat.nbr;
      }
    }
    List<Medic> topSellingMedics = medics.where((m) => medicSalesCount.containsKey(m.numMed)).toList()
      ..sort((a, b) => medicSalesCount[b.numMed]!.compareTo(medicSalesCount[a.numMed]!));

    setState(() {
      _lowStockMedics = lowStockMedics;
      _totalRevenue = totalRevenue;
      _topSellingMedics = topSellingMedics.take(5).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCard(
              title: 'Médicaments en Rupture de Stock',
              content: _buildLowStockList(),
            ),
            const SizedBox(height: 20.0),
            _buildCard(
              title: 'Top 5 Médicaments les Plus Vendus',
              content: _buildTopSellingMedicsList(),
            ),
            const SizedBox(height: 20.0),
            _buildCard(
              title: 'Recette Totale Accumulée',
              content: Text(
                '$_totalRevenue Ar',
                style: const TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard({required String title, required Widget content}) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Container(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold, color: Colors.green),
            ),
            const SizedBox(height: 10.0),
            content,
          ],
        ),
      ),
    );
  }

  Widget _buildLowStockList() {
    if (_lowStockMedics.isEmpty) {
      return const Text('Aucun médicament en rupture de stock.', style: TextStyle(color: Colors.grey));
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _lowStockMedics.length,
      itemBuilder: (context, index) {
        Medic medic = _lowStockMedics[index];
        return ListTile(
          title: Text('${medic.designMed} (Stock: ${medic.stockMed})'),
          subtitle: const Text(
            'Réapprovisionner bientôt',
            style: TextStyle(color: Colors.red),
          ),
        );
      },
    );
  }

  Widget _buildTopSellingMedicsList() {
    if (_topSellingMedics.isEmpty) {
      return const Text('Aucun médicament vendu.', style: TextStyle(color: Colors.grey));
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _topSellingMedics.length,
      itemBuilder: (context, index) {
        Medic medic = _topSellingMedics[index];
        return ListTile(
          title: Text(medic.designMed),
          subtitle: Text(
            'Vendu: ${medic.prixMed}',
            style: const TextStyle(color: Colors.blue),
          ),
        );
      },
    );
  }
}
