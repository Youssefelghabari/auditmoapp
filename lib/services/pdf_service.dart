// lib/services/pdf_service.dart

import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import 'database_service.dart';

class PdfService {
  static Future<File> generateAuditReport({
    required Commerce commerce,
    required AuditSession session,
    required List<AuditResponse> responses,
    required Map<String, dynamic> stats,
  }) async {
    final pdf = pw.Document();
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm', 'fr_FR');
    final score = stats['score'] as int;
    final conformes = stats['conformes'] as int;
    final nonConformes = stats['nonConformes'] as int;

    // Build response map
    final respMap = {for (var r in responses) r.pointId: r};

    // Score color
    PdfColor scoreColor;
    if (score >= 80) {
      scoreColor = PdfColors.green700;
    } else if (score >= 60) {
      scoreColor = PdfColors.orange700;
    } else {
      scoreColor = PdfColors.red700;
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          // Header
          pw.Container(
            padding: const pw.EdgeInsets.all(20),
            decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF1C1917)),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('RAPPORT D\'AUDIT', style: pw.TextStyle(color: PdfColors.white, fontSize: 18, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 4),
                    pw.Text('Conformité Commerciale', style: const pw.TextStyle(color: PdfColors.grey300, fontSize: 11)),
                  ],
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: pw.BoxDecoration(color: scoreColor, borderRadius: pw.BorderRadius.circular(8)),
                  child: pw.Text('$score%', style: pw.TextStyle(color: PdfColors.white, fontSize: 28, fontWeight: pw.FontWeight.bold)),
                ),
              ],
            ),
          ),

          pw.SizedBox(height: 20),

          // Commerce info
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300), borderRadius: pw.BorderRadius.circular(8)),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('INFORMATIONS DU COMMERCE', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.grey600)),
                pw.SizedBox(height: 10),
                _infoRow('Nom', commerce.name),
                _infoRow('Catégorie', commerce.category),
                if (commerce.address.isNotEmpty) _infoRow('Adresse', commerce.address),
                if (commerce.latitude != null)
                  _infoRow('GPS', '${commerce.latitude!.toStringAsFixed(5)}, ${commerce.longitude!.toStringAsFixed(5)}'),
                _infoRow('Auditeur', session.auditorName.isNotEmpty ? session.auditorName : 'Non renseigné'),
                _infoRow('Date', dateFormat.format(session.date)),
              ],
            ),
          ),

          pw.SizedBox(height: 16),

          // Stats
          pw.Row(
            children: [
              _statBox('$conformes', 'Conformes', PdfColors.green700, PdfColors.green50),
              pw.SizedBox(width: 10),
              _statBox('$nonConformes', 'Non conformes', PdfColors.red700, PdfColors.red50),
              pw.SizedBox(width: 10),
              _statBox('${stats['total'] - stats['answered']}', 'Non vérifiés', PdfColors.grey600, PdfColors.grey100),
            ],
          ),

          pw.SizedBox(height: 20),

          // Non-conformities section
          if (nonConformes > 0) ...[
            pw.Text('POINTS NON CONFORMES', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.red700)),
            pw.SizedBox(height: 8),
            ...kAuditCategories.expand((cat) =>
              cat.points
                .where((p) => respMap[p.id]?.response == 'non')
                .map((p) {
                  final r = respMap[p.id]!;
                  return pw.Container(
                    margin: const pw.EdgeInsets.only(bottom: 6),
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(color: PdfColors.red50, borderRadius: pw.BorderRadius.circular(6)),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('${cat.icon} ${p.label}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                        if (r.note.isNotEmpty) pw.Text('Note: ${r.note}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                      ],
                    ),
                  );
                })
            ),
            pw.SizedBox(height: 16),
          ],

          // Results by category
          pw.Text('RÉSULTATS PAR CATÉGORIE', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800)),
          pw.SizedBox(height: 8),
          ...kAuditCategories.map((cat) {
            final ok = cat.points.where((p) => respMap[p.id]?.response == 'oui').length;
            final pct = cat.points.isEmpty ? 0 : (ok / cat.points.length * 100).round();
            PdfColor col = pct >= 80 ? PdfColors.green700 : pct >= 60 ? PdfColors.orange700 : PdfColors.red700;
            return pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 12),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('${cat.icon} ${cat.label}', style: const pw.TextStyle(fontSize: 10)),
                      pw.Text('$pct%', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: col)),
                    ],
                  ),
                  pw.SizedBox(height: 4),
                  pw.LinearProgressIndicator(value: pct / 100, backgroundColor: PdfColors.grey200, valueColor: col),
                  pw.SizedBox(height: 4),
                  // Point detail
                  ...cat.points.map((p) {
                    final r = respMap[p.id];
                    PdfColor dotColor = r == null ? PdfColors.grey400 : r.response == 'oui' ? PdfColors.green600 : r.response == 'non' ? PdfColors.red600 : PdfColors.grey400;
                    String status = r == null ? '—' : r.response == 'oui' ? '✓' : r.response == 'non' ? '✗' : 'N/A';
                    return pw.Padding(
                      padding: const pw.EdgeInsets.only(left: 12, bottom: 2),
                      child: pw.Row(
                        children: [
                          pw.Text(status, style: pw.TextStyle(fontSize: 9, color: dotColor, fontWeight: pw.FontWeight.bold)),
                          pw.SizedBox(width: 6),
                          pw.Expanded(child: pw.Text(p.label, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700))),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            );
          }),
        ],
      ),
    );

    final dir = await getApplicationDocumentsDirectory();
    final filename = 'audit_${commerce.name.replaceAll(' ', '_')}_${DateFormat('yyyyMMdd_HHmm').format(session.date)}.pdf';
    final file = File('${dir.path}/$filename');
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  static pw.Widget _infoRow(String label, String value) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 4),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.SizedBox(width: 80, child: pw.Text('$label :', style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600, fontWeight: pw.FontWeight.bold))),
            pw.Expanded(child: pw.Text(value, style: const pw.TextStyle(fontSize: 9))),
          ],
        ),
      );

  static pw.Widget _statBox(String value, String label, PdfColor textColor, PdfColor bgColor) =>
      pw.Expanded(
        child: pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(color: bgColor, borderRadius: pw.BorderRadius.circular(8)),
          child: pw.Column(
            children: [
              pw.Text(value, style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: textColor)),
              pw.Text(label, style: pw.TextStyle(fontSize: 9, color: textColor)),
            ],
          ),
        ),
      );
}
