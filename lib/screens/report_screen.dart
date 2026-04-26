// lib/screens/report_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../services/pdf_service.dart';
import 'package:printing/printing.dart';

class ReportScreen extends StatelessWidget {
  final Commerce commerce;
  final AuditSession session;
  final List<AuditResponse> responses;
  final Map<String, dynamic> stats;
  final bool embedded;

  const ReportScreen({
    super.key,
    required this.commerce,
    required this.session,
    required this.responses,
    required this.stats,
    this.embedded = false,
  });

  int get _score => stats['score'] as int;
  Color get _scoreColor => _score >= 80 ? const Color(0xFF15803D) : _score >= 60 ? const Color(0xFFB45309) : const Color(0xFFB91C1C);
  Color get _scoreBg => _score >= 80 ? const Color(0xFFF0FDF4) : _score >= 60 ? const Color(0xFFFFFBEB) : const Color(0xFFFEF2F2);

  @override
  Widget build(BuildContext context) {
    final respMap = {for (var r in responses) r.pointId: r};
    final nonConformes = responses.where((r) => r.response == 'non').toList();

    final body = ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Score card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: _scoreBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: _scoreColor.withOpacity(0.2))),
          child: Row(children: [
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Score global', style: TextStyle(fontSize: 12, color: _scoreColor, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text('$_score%', style: TextStyle(fontSize: 42, fontWeight: FontWeight.w800, color: _scoreColor)),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: _score / 100,
                    minHeight: 6,
                    backgroundColor: _scoreColor.withOpacity(0.15),
                    valueColor: AlwaysStoppedAnimation(_scoreColor),
                  ),
                ),
              ],
            )),
            const SizedBox(width: 20),
            Column(children: [
              _StatMini('${stats['conformes']}', 'Conformes', const Color(0xFF15803D)),
              const SizedBox(height: 8),
              _StatMini('${stats['nonConformes']}', 'Non conf.', const Color(0xFFB91C1C)),
              const SizedBox(height: 8),
              _StatMini('${(stats['total'] as int) - (stats['answered'] as int)}', 'À vérifier', const Color(0xFF6B7280)),
            ]),
          ]),
        ),

        const SizedBox(height: 16),

        // Info commerce
        _InfoCard(commerce: commerce, session: session),

        const SizedBox(height: 16),

        // Non-conformités
        if (nonConformes.isNotEmpty) ...[
          const _SectionLabel(label: '⚠ Points non conformes'),
          ...nonConformes.map((r) {
            final cat = kAuditCategories.firstWhere((c) => c.points.any((p) => p.id == r.pointId), orElse: () => kAuditCategories.first);
            final pt = cat.points.firstWhere((p) => p.id == r.pointId);
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFFCA5A5))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${cat.icon} ${pt.label}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF374151))),
                if (r.note.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text('→ ${r.note}', style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF), fontStyle: FontStyle.italic)),
                ],
              ]),
            );
          }),
          const SizedBox(height: 16),
        ],

        // Par catégorie
        const _SectionLabel(label: 'Résultats par catégorie'),
        ...kAuditCategories.map((cat) {
          final ok = cat.points.where((p) => respMap[p.id]?.response == 'oui').length;
          final ko = cat.points.where((p) => respMap[p.id]?.response == 'non').length;
          final done = cat.points.where((p) => respMap[p.id] != null).length;
          final pct = cat.points.isEmpty ? 0 : (ok / cat.points.length * 100).round();
          final col = pct >= 80 ? const Color(0xFF15803D) : pct >= 60 ? const Color(0xFFB45309) : const Color(0xFFB91C1C);
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE5E7EB))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(cat.icon, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                Expanded(child: Text(cat.label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
                Text('$pct%', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: col)),
              ]),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(value: pct / 100, minHeight: 5, backgroundColor: const Color(0xFFF3F4F6), valueColor: AlwaysStoppedAnimation(col)),
              ),
              const SizedBox(height: 6),
              Text('$ok conformes · $ko non-conformes · ${cat.points.length - done} non vérifiés', style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
            ]),
          );
        }),
        const SizedBox(height: 80),
      ],
    );

    if (embedded) return body;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F7F4),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1C1917),
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Rapport d\'audit', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined, color: Colors.white),
            onPressed: () async {
              final file = await PdfService.generateAuditReport(commerce: commerce, session: session, responses: responses, stats: stats);
              await Printing.sharePdf(bytes: await file.readAsBytes(), filename: file.path.split('/').last);
            },
          ),
        ],
      ),
      body: body,
    );
  }
}

class _StatMini extends StatelessWidget {
  final String value;
  final String label;
  final Color color;
  const _StatMini(this.value, this.label, this.color);

  @override
  Widget build(BuildContext context) => Column(children: [
        Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: color)),
        Text(label, style: TextStyle(fontSize: 9, color: color.withOpacity(0.7))),
      ]);
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF6B7280), letterSpacing: 0.8)),
      );
}

class _InfoCard extends StatelessWidget {
  final Commerce commerce;
  final AuditSession session;
  const _InfoCard({required this.commerce, required this.session});

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd/MM/yyyy HH:mm');
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE5E7EB))),
      child: Column(children: [
        _Row('Commerce', commerce.name),
        _Row('Catégorie', commerce.category),
        if (commerce.address.isNotEmpty) _Row('Adresse', commerce.address),
        if (commerce.latitude != null) _Row('GPS', '${commerce.latitude!.toStringAsFixed(5)}, ${commerce.longitude!.toStringAsFixed(5)}'),
        _Row('Date', fmt.format(session.date)),
        if (session.auditorName.isNotEmpty) _Row('Auditeur', session.auditorName),
      ]),
    );
  }

  Widget _Row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 80, child: Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF), fontWeight: FontWeight.w500))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 12, color: Color(0xFF374151)))),
        ]),
      );
}
