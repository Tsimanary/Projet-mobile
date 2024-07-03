import 'package:pdf/widgets.dart' as pdfLib;
import 'package:pdf/pdf.dart';
import 'package:flutter/material.dart';
import '../Models/medic.dart'; // Assurez-vous que le chemin est correct

pdfLib.Document generateInvoicePdf(String numAchat, String nomClient, String dateAchat, List<Medic> medics, Map<String, TextEditingController> quantityControllers, double totalPrice) {
  final pdfLib.Document pdf = pdfLib.Document();

  pdf.addPage(
    pdfLib.MultiPage(
      pageFormat: PdfPageFormat.a4,
      build: (pdfLib.Context context) => <pdfLib.Widget>[
        pdfLib.Header(level: 1, text: 'Facture'),
        pdfLib.Paragraph(text: 'Numéro d\'Achat: $numAchat'),
        pdfLib.Paragraph(text: 'Date d\'Achat: $dateAchat'),
        pdfLib.Paragraph(text: 'Nom du Client: $nomClient'),
        pdfLib.Paragraph(text: 'Détails de l\'Achat:'),
        for (var medic in medics)
          if (quantityControllers[medic.numMed]?.text.isNotEmpty ?? false)
            pdfLib.Paragraph(text: '${medic.designMed} (Num: ${medic.numMed}): ${quantityControllers[medic.numMed]?.text} x ${medic.prixMed} Ar'),
        pdfLib.Paragraph(text: 'Prix Total: $totalPrice Ar'),
      ],
    ),
  );

  return pdf;
}
