// lib/screens/template_list_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/audit_template.dart';
import '../services/template_service.dart';
import 'template_editor_screen.dart';
import 'template_import_screen.dart';

class TemplateListScreen extends StatefulWidget {
  final String? commerceId; // si fourni, affiche le bouton "Utiliser pour ce commerce"

  const TemplateListScreen({super.key, this.commerceId});

  @override
  State<TemplateListScreen> createState() => _TemplateListScreenState();
}

class _TemplateListScreenState extends State<TemplateListScreen> {
  final _svc = TemplateService();
  List<AuditTemplate> _templates = [];
  String? _activeTemplateId;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final templates = await _svc.getAllTemplates();
    String? activeId;
    if (widget.commerceId != null) {
      final active = await _svc.getActiveTemplate(widget.commerceId!);
      activeId = active?.id;
    }
    setState(() {
      _templates = templates;
      _activeTemplateId = activeId;
      _loading = false;
    });
  }

  Future<void> _importFile() async {
    final result = await Navigator.push<AuditTemplate?>(
      context,
      MaterialPageRoute(builder: (_) => const TemplateImportScreen()),
    );
    if (result != null) _load();
  }

  Future<void> _createNew() async {
    await Navigator.push(context, MaterialPageRoute(
      builder: (_) => TemplateEditorScreen(template: null),
    ));
    _load();
  }

  Future<void> _editTemplate(AuditTemplate t) async {
    await Navigator.push(context, MaterialPageRoute(
      builder: (_) => TemplateEditorScreen(template: t),
    ));
    _load();
  }

  Future<void> _deleteTemplate(AuditTemplate t) async {
    if (t.isDefault) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Le modèle intégré ne peut pas être supprimé')));
      return;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer ce modèle ?'),
        content: Text('"${t.name}" sera définitivement supprimé.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Supprimer', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm == true) {
      await _svc.deleteTemplate(t.id);
      _load();
    }
  }

  Future<void> _selectTemplate(AuditTemplate t) async {
    if (widget.commerceId != null) {
      await _svc.setActiveTemplate(widget.commerceId!, t.id);
      if (mounted) {
        Navigator.pop(context, t);
      }
    }
  }

  void _showActions(AuditTemplate t) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFFE5E7EB), borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 12),
            Text(t.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            if (widget.commerceId != null)
              ListTile(
                leading: const Icon(Icons.check_circle_outline, color: Color(0xFF15803D)),
                title: const Text('Utiliser pour ce commerce'),
                onTap: () { Navigator.pop(ctx); _selectTemplate(t); },
              ),
            if (!t.isDefault)
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Modifier'),
                onTap: () { Navigator.pop(ctx); _editTemplate(t); },
              ),
            ListTile(
              leading: const Icon(Icons.ios_share_outlined),
              title: const Text('Exporter (JSON)'),
              onTap: () { Navigator.pop(ctx); _svc.exportTemplate(t); },
            ),
            ListTile(
              leading: const Icon(Icons.table_chart_outlined),
              title: const Text('Exporter (CSV)'),
              onTap: () { Navigator.pop(ctx); _svc.exportAsCsv(t); },
            ),
            if (!t.isDefault)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('Supprimer', style: TextStyle(color: Colors.red)),
                onTap: () { Navigator.pop(ctx); _deleteTemplate(t); },
              ),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F7F4),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1C1917),
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Modèles d\'audit', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
        actions: [
          IconButton(icon: const Icon(Icons.add, color: Colors.white), onPressed: _createNew, tooltip: 'Créer un modèle'),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Import banner
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF1C1917), Color(0xFF44403C)]),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.upload_file, color: Colors.white70, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Text('Importer un modèle', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                          const Text('JSON ou CSV • colonnes: Catégorie, Point, Description, Réf. légale', style: TextStyle(color: Colors.white54, fontSize: 11)),
                        ]),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: const Color(0xFF1C1917), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8)),
                        onPressed: _importFile,
                        child: const Text('Importer', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: _templates.isEmpty
                      ? _buildEmpty()
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _templates.length,
                          itemBuilder: (ctx, i) {
                            final t = _templates[i];
                            final isActive = t.id == _activeTemplateId;
                            return _TemplateCard(
                              template: t,
                              isActive: isActive,
                              showSelectButton: widget.commerceId != null,
                              onTap: () => _showActions(t),
                              onSelect: () => _selectTemplate(t),
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF1C1917),
        onPressed: _createNew,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Nouveau modèle', style: TextStyle(color: Colors.white)),
      ),
    );
  }

  Widget _buildEmpty() => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.description_outlined, size: 64, color: Color(0xFFD1C9BE)),
            const SizedBox(height: 16),
            const Text('Aucun modèle personnalisé', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF78716C))),
            const SizedBox(height: 8),
            const Text('Importez un fichier JSON/CSV\nou créez un nouveau modèle', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFFA8A29E))),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              icon: const Icon(Icons.upload_file),
              label: const Text('Importer un fichier'),
              onPressed: _importFile,
            ),
          ],
        ),
      );
}

class _TemplateCard extends StatelessWidget {
  final AuditTemplate template;
  final bool isActive;
  final bool showSelectButton;
  final VoidCallback onTap;
  final VoidCallback onSelect;

  const _TemplateCard({
    required this.template, required this.isActive,
    required this.showSelectButton, required this.onTap, required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final t = template;
    final fmt = DateFormat('dd/MM/yyyy');
    final totalPts = t.totalPoints;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isActive ? const Color(0xFF6D28D9) : const Color(0xFFE5E7EB), width: isActive ? 2 : 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    if (t.isDefault) Container(
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(6)),
                      child: const Text('Intégré', style: TextStyle(fontSize: 10, color: Color(0xFF6B7280))),
                    ),
                    if (isActive) Container(
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: const Color(0xFFEDE9FE), borderRadius: BorderRadius.circular(6)),
                      child: const Text('Actif', style: TextStyle(fontSize: 10, color: Color(0xFF6D28D9), fontWeight: FontWeight.w600)),
                    ),
                    Expanded(child: Text(t.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1C1917)))),
                  ]),
                  if (t.description.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(t.description, style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)), maxLines: 2, overflow: TextOverflow.ellipsis),
                  ],
                ])),
                const Icon(Icons.more_vert, color: Color(0xFF9CA3AF)),
              ]),
              const SizedBox(height: 10),

              // Stats chips
              Wrap(spacing: 6, runSpacing: 4, children: [
                _Chip('${t.categories.length} catégories'),
                _Chip('$totalPts points'),
                _Chip('v${t.version}'),
                _Chip(fmt.format(t.updatedAt)),
              ]),

              // Category icons preview
              const SizedBox(height: 8),
              Row(children: [
                ...t.categories.take(6).map((c) => Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Text(c.icon, style: const TextStyle(fontSize: 16)),
                )),
                if (t.categories.length > 6) Text('+${t.categories.length - 6}', style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
                const Spacer(),
                if (showSelectButton && !isActive)
                  TextButton(
                    style: TextButton.styleFrom(
                      backgroundColor: const Color(0xFF1C1917), foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: onSelect,
                    child: const Text('Utiliser', style: TextStyle(fontSize: 12)),
                  ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  const _Chip(this.label);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(20)),
        child: Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
      );
}
