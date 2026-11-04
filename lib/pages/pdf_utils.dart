import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pdfLib;

import '../core/stock_rules.dart';

/// Ligne de facture : structure indépendante de l'interface.
///
/// C'est ce découplage qui rend la génération de PDF testable et qui évite
/// d'imprimer des lignes jamais enregistrées.
class LigneFacture {
  const LigneFacture({
    required this.designation,
    required this.numMed,
    required this.quantite,
    required this.prixUnitaire,
  });

  final String designation;
  final String numMed;
  final int quantite;
  final int prixUnitaire;

  int get montant =>
      StockRules.montantLigne(prixUnitaire: prixUnitaire, quantite: quantite);
}

/// Construit la facture PDF d'une vente.
pdfLib.Document generateInvoicePdf({
  required String numAchat,
  required String nomClient,
  required String dateAchat,
  required List<LigneFacture> lignes,
  required int total,
  String nomOfficine = 'Pharmacie',
}) {
  final document = pdfLib.Document();
  final date = DateTime.now();

  document.addPage(
    pdfLib.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pdfLib.EdgeInsets.all(32),
      build: (pdfLib.Context context) => <pdfLib.Widget>[
        pdfLib.Row(
          mainAxisAlignment: pdfLib.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pdfLib.CrossAxisAlignment.start,
          children: <pdfLib.Widget>[
            pdfLib.Column(
              crossAxisAlignment: pdfLib.CrossAxisAlignment.start,
              children: <pdfLib.Widget>[
                pdfLib.Text(
                  nomOfficine,
                  style: pdfLib.TextStyle(
                    fontSize: 20,
                    fontWeight: pdfLib.FontWeight.bold,
                  ),
                ),
                pdfLib.SizedBox(height: 4),
                pdfLib.Text('Facture n° $numAchat'),
              ],
            ),
            pdfLib.Column(
              crossAxisAlignment: pdfLib.CrossAxisAlignment.end,
              children: <pdfLib.Widget>[
                pdfLib.Text("Date de vente : $dateAchat"),
                pdfLib.Text(
                  'Éditée le ${date.day.toString().padLeft(2, '0')}/'
                  '${date.month.toString().padLeft(2, '0')}/${date.year}',
                ),
              ],
            ),
          ],
        ),
        pdfLib.SizedBox(height: 12),
        pdfLib.Divider(),
        pdfLib.SizedBox(height: 8),
        pdfLib.Text('Client : ${nomClient.trim().isEmpty ? "—" : nomClient}'),
        pdfLib.SizedBox(height: 16),
        pdfLib.Text(
          'Détail de la vente',
          style: pdfLib.TextStyle(
            fontSize: 14,
            fontWeight: pdfLib.FontWeight.bold,
          ),
        ),
        pdfLib.SizedBox(height: 8),
        pdfLib.Row(
          children: <pdfLib.Widget>[
            pdfLib.Expanded(flex: 4, child: pdfLib.Text('Désignation')),
            pdfLib.Expanded(
              flex: 2,
              child: pdfLib.Text('Qté', textAlign: pdfLib.TextAlign.right),
            ),
            pdfLib.Expanded(
              flex: 3,
              child: pdfLib.Text(
                'Prix unitaire',
                textAlign: pdfLib.TextAlign.right,
              ),
            ),
            pdfLib.Expanded(
              flex: 3,
              child: pdfLib.Text('Montant', textAlign: pdfLib.TextAlign.right),
            ),
          ],
        ),
        pdfLib.SizedBox(height: 4),
        pdfLib.Divider(),
        for (final ligne in lignes)
          pdfLib.Padding(
            padding: const pdfLib.EdgeInsets.symmetric(vertical: 3),
            child: pdfLib.Row(
              children: <pdfLib.Widget>[
                pdfLib.Expanded(
                  flex: 4,
                  child: pdfLib.Text(
                    '${ligne.designation} (n° ${ligne.numMed})',
                  ),
                ),
                pdfLib.Expanded(
                  flex: 2,
                  child: pdfLib.Text(
                    '${ligne.quantite}',
                    textAlign: pdfLib.TextAlign.right,
                  ),
                ),
                pdfLib.Expanded(
                  flex: 3,
                  child: pdfLib.Text(
                    '${ligne.prixUnitaire} Ar',
                    textAlign: pdfLib.TextAlign.right,
                  ),
                ),
                pdfLib.Expanded(
                  flex: 3,
                  child: pdfLib.Text(
                    '${ligne.montant} Ar',
                    textAlign: pdfLib.TextAlign.right,
                  ),
                ),
              ],
            ),
          ),
        pdfLib.SizedBox(height: 4),
        pdfLib.Divider(),
        pdfLib.SizedBox(height: 8),
        pdfLib.Row(
          mainAxisAlignment: pdfLib.MainAxisAlignment.end,
          children: <pdfLib.Widget>[
            pdfLib.Text(
              'TOTAL : $total Ar',
              style: pdfLib.TextStyle(
                fontSize: 14,
                fontWeight: pdfLib.FontWeight.bold,
              ),
            ),
          ],
        ),
        pdfLib.SizedBox(height: 24),
        pdfLib.Text(
          'Merci de votre confiance.',
          style: const pdfLib.TextStyle(fontSize: 10, color: PdfColors.grey700),
        ),
      ],
    ),
  );

  return document;
}
