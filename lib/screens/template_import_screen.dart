// lib/screens/template_import_screen.dart

import 'package:flutter/material.dart';
import '../models/audit_template.dart';
import '../services/template_service.dart';

class TemplateImportScreen extends StatefulWidget {
  const TemplateImportScreen({super.key});

  @override
  State<TemplateImportScreen> createState() => _TemplateImportScreenState();
}

class _TemplateImportScreenState extends State<TemplateImportScreen> with SingleTickerProviderStateMixin {
  final _svc = TemplateService();
  late TabController _tabCtrl;

  AuditTemplate? _preview;
  bool _importing = false;
  String? _error;
  String? _importedName;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _import() async {
    setState(() { _importing = true; _error = null; _preview = null; });
    try {
      final template = await _svc.importFromFile();
      if (template == null) {
        setState(() { _error = 'Aucun fichier sélectionné ou format non reconnu.'; _importing = false; });
        return;
      }
      setState(() { _preview = template; _importedName = template.name; _importing = false; });
    } catch (e) {
      setState(() { _error = 'Erreur lors de l\'import : $e'; _importing = false; });
    }
  }

  Future<void> _confirmImport() async {
    if (_preview == null) return;
    if (_importedName != null && _importedName!.trim().isNotEmpty) {
      _preview!.name = _importedName!.trim();
    }
    await _svc.saveTemplate(_preview!);
    if (mounted) Navigator.pop(context, _preview);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F7F4),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1C1917),
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Importer un modèle', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white38,
          tabs: const [Tab(text: 'Importer'), Tab(text: 'Formats supportés')],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [_buildImportTab(), _buildFormatsTab()],
      ),
    );
  }

  Widget _buildImportTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // CTA principal
        GestureDetector(
          onTap: _importing ? null : _import,
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF1C1917), Color(0xFF44403C)]),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(children: [
              _importing
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Icon(Icons.upload_file, color: Colors.white, size: 48),
              const SizedBox(height: 12),
              const Text('Sélectionner un fichier', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              const Text('JSON • CSV • TXT', style: TextStyle(color: Colors.white54, fontSize: 12)),
            ]),
          ),
        ),

        const SizedBox(height: 12),

        // Télécharger exemples
        Row(children: [
          Expanded(child: _ExampleBtn(
            label: 'Exemple JSON',
            icon: Icons.code,
            onTap: () => _svc.exportSampleJson(),
          )),
          const SizedBox(width: 10),
          Expanded(child: _ExampleBtn(
            label: 'Exemple CSV',
            icon: Icons.table_rows_outlined,
            onTap: () => _svc.exportSampleCsv(),
          )),
        ]),

        if (_error != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFFCA5A5))),
            child: Row(children: [
              const Icon(Icons.error_outline, color: Color(0xFFB91C1C), size: 20),
              const SizedBox(width: 10),
              Expanded(child: Text(_error!, style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 13))),
            ]),
          ),
        ],

        // Preview
        if (_preview != null) ...[
          const SizedBox(height: 20),
          const _SectionLabel('Aperçu du modèle importé'),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFF6D28D9), width: 2)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.check_circle, color: Color(0xFF15803D), size: 20),
                const SizedBox(width: 8),
                const Text('Modèle reconnu', style: TextStyle(color: Color(0xFF15803D), fontWeight: FontWeight.w600, fontSize: 13)),
              ]),
              const SizedBox(height: 12),

              // Nom éditable
              TextField(
                controller: TextEditingController(text: _importedName),
                decoration: const InputDecoration(
                  labelText: 'Nom du modèle',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                onChanged: (v) => _importedName = v,
              ),
              const SizedBox(height: 12),

              // Stats
              Row(children: [
                _PreviewStat('${_preview!.categories.length}', 'catégories'),
                const SizedBox(width: 16),
                _PreviewStat('${_preview!.totalPoints}', 'points'),
                const SizedBox(width: 16),
                _PreviewStat('v${_preview!.version}', 'version'),
              ]),
              const SizedBox(height: 12),

              // Catégories
              ...(_preview!.categories.map((cat) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(children: [
                  Text(cat.icon, style: const TextStyle(fontSize: 16)),
                  const SizedBox(width: 8),
                  Expanded(child: Text(cat.label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
                  Text('${cat.points.length} pts', style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
                ]),
              ))),

              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1C1917), foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Enregistrer ce modèle', style: TextStyle(fontWeight: FontWeight.w600)),
                  onPressed: _confirmImport,
                ),
              ),
            ]),
          ),
        ],
      ],
    );
  }

  Widget _buildFormatsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        _FormatCard(
          title: 'JSON — Format natif (recommandé)',
          icon: Icons.code,
          color: Color(0xFF2563EB),
          description: 'Format le plus complet, supporte les icônes, descriptions et références légales.',
          example: '''{\n  "name": "Mon audit",\n  "categories": [\n    {\n      "id": "cat1",\n      "label": "Sécurité",\n      "icon": "🔒",\n      "points": [\n        { "id": "p1", "label": "Extincteurs vérifiés" },\n        { "id": "p2", "label": "Issues dégagées",\n          "description": "Min 90cm de large",\n          "legal_ref": "Art. R4227-28" }\n      ]\n    }\n  ]\n}''',
        ),
        SizedBox(height: 12),
        _FormatCard(
          title: 'JSON — Format sections',
          icon: Icons.layers_outlined,
          color: Color(0xFF7C3AED),
          description: 'Format simplifié avec sections et items.',
          example: '''{\n  "name": "Mon audit",\n  "sections": [\n    {\n      "title": "Sécurité",\n      "items": [\n        "Extincteurs vérifiés",\n        "Issues dégagées"\n      ]\n    }\n  ]\n}''',
        ),
        SizedBox(height: 12),
        _FormatCard(
          title: 'CSV — Tableau structuré',
          icon: Icons.table_chart_outlined,
          color: Color(0xFF15803D),
          description: 'Séparateur virgule ou point-virgule. Première ligne = en-tête optionnel.',
          example: 'Catégorie,Point,Description,Référence légale\nSécurité,Extincteurs vérifiés,Date < 1 an,Art. R4227-28\nSécurité,Issues dégagées,,\nAffichage,Prix affichés,,',
        ),
        SizedBox(height: 12),
        _FormatCard(
          title: 'TXT — Liste simple',
          icon: Icons.list_outlined,
          color: Color(0xFFB45309),
          description: 'Un point par ligne. Tous les points seront dans une même catégorie.',
          example: 'Extincteurs vérifiés\nIssues dégagées\nPrix affichés\nHoraires visibles',
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(text, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF6B7280), letterSpacing: 0.8)),
      );
}

class _PreviewStat extends StatelessWidget {
  final String value;
  final String label;
  const _PreviewStat(this.value, this.label);

  @override
  Widget build(BuildContext context) => Column(children: [
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF1C1917))),
        Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF9CA3AF))),
      ]);
}

class _ExampleBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _ExampleBtn({required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFE5E7EB))),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 16, color: const Color(0xFF6B7280)),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF374151), fontWeight: FontWeight.w500)),
          ]),
        ),
      );
}

class _FormatCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final String description;
  final String example;

  const _FormatCard({required this.title, required this.icon, required this.color, required this.description, required this.example});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE5E7EB))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: const BorderRadius.vertical(top: Radius.circular(14))),
          child: Row(children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color))),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(description, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFFF8F9FA), borderRadius: BorderRadius.circular(8)),
              child: Text(example, style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: Color(0xFF374151), height: 1.5)),
            ),
          ]),
        ),
      ]),
    );
  }
}
