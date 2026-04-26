// lib/screens/template_editor_screen.dart

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/audit_template.dart';
import '../services/template_service.dart';

class TemplateEditorScreen extends StatefulWidget {
  final AuditTemplate? template;
  const TemplateEditorScreen({super.key, required this.template});

  @override
  State<TemplateEditorScreen> createState() => _TemplateEditorScreenState();
}

class _TemplateEditorScreenState extends State<TemplateEditorScreen> {
  final _svc = TemplateService();
  final _uuid = const Uuid();
  late TextEditingController _nameCtrl;
  late TextEditingController _descCtrl;
  late List<TemplateCategory> _categories;
  bool _saving = false;

  final List<String> _iconOptions = ['📋', '🔒', '🧼', '💳', '👤', '🌿', '⭐', '📦', '🤝', '🔧', '🏪', '⚠', '✅', '🔍', '📊'];

  @override
  void initState() {
    super.initState();
    final t = widget.template;
    _nameCtrl = TextEditingController(text: t?.name ?? '');
    _descCtrl = TextEditingController(text: t?.description ?? '');
    _categories = t?.categories.map((c) => TemplateCategory(
      id: c.id, label: c.label, icon: c.icon, order: c.order,
      points: c.points.map((p) => TemplatePoint(id: p.id, label: p.label, description: p.description, required: p.required, order: p.order, legalRef: p.legalRef)).toList(),
    )).toList() ?? [];
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  void _addCategory() {
    final id = _uuid.v4();
    setState(() {
      _categories.add(TemplateCategory(
        id: id, label: 'Nouvelle catégorie', icon: '📋', order: _categories.length, points: [],
      ));
    });
    // Scroll to bottom & open editor
    Future.delayed(const Duration(milliseconds: 100), () => _editCategoryName(_categories.length - 1));
  }

  void _removeCategory(int idx) {
    if (_categories[idx].points.isNotEmpty) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Supprimer la catégorie ?'),
          content: Text('${_categories[idx].points.length} point(s) sera supprimé(s).'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
            TextButton(onPressed: () { setState(() => _categories.removeAt(idx)); Navigator.pop(ctx); }, child: const Text('Supprimer', style: TextStyle(color: Colors.red))),
          ],
        ),
      );
    } else {
      setState(() => _categories.removeAt(idx));
    }
  }

  void _addPoint(int catIdx) {
    final id = _uuid.v4();
    setState(() {
      _categories[catIdx].points.add(TemplatePoint(
        id: id, label: '', order: _categories[catIdx].points.length,
      ));
    });
  }

  void _removePoint(int catIdx, int ptIdx) {
    setState(() => _categories[catIdx].points.removeAt(ptIdx));
  }

  void _editCategoryName(int idx) {
    final ctrl = TextEditingController(text: _categories[idx].label);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nom de la catégorie'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: ctrl, autofocus: true, decoration: const InputDecoration(hintText: 'Ex: Sécurité incendie')),
          const SizedBox(height: 12),
          const Text('Icône :', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          StatefulBuilder(builder: (ctx, setSt) => Wrap(
            spacing: 8, runSpacing: 8,
            children: _iconOptions.map((icon) {
              final selected = _categories[idx].icon == icon;
              return GestureDetector(
                onTap: () { setState(() => _categories[idx].icon = icon); setSt(() {}); },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: selected ? const Color(0xFFEDE9FE) : const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: selected ? const Color(0xFF6D28D9) : Colors.transparent),
                  ),
                  child: Text(icon, style: const TextStyle(fontSize: 20)),
                ),
              );
            }).toList(),
          )),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          TextButton(
            onPressed: () {
              if (ctrl.text.trim().isNotEmpty) setState(() => _categories[idx].label = ctrl.text.trim());
              Navigator.pop(ctx);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Le nom du modèle est obligatoire')));
      return;
    }
    // Validation: au moins une catégorie avec un point
    for (final cat in _categories) {
      for (int i = cat.points.length - 1; i >= 0; i--) {
        if (cat.points[i].label.trim().isEmpty) cat.points.removeAt(i);
      }
    }
    final nonEmptyCats = _categories.where((c) => c.points.isNotEmpty).toList();
    if (nonEmptyCats.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ajoutez au moins un point d\'audit')));
      return;
    }

    setState(() => _saving = true);
    final now = DateTime.now();
    final template = AuditTemplate(
      id: widget.template?.id ?? _uuid.v4(),
      name: _nameCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      createdAt: widget.template?.createdAt ?? now,
      updatedAt: now,
      categories: nonEmptyCats.asMap().entries.map((e) { e.value.order = e.key; return e.value; }).toList(),
    );
    await _svc.saveTemplate(template);
    setState(() => _saving = false);
    if (mounted) Navigator.pop(context, template);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F7F4),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1C1917),
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(widget.template == null ? 'Nouveau modèle' : 'Modifier le modèle',
            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
        actions: [
          if (_saving)
            const Padding(padding: EdgeInsets.all(16), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)))
          else
            TextButton(onPressed: _save, child: const Text('Enregistrer', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600))),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Infos générales
          _SLabel('Informations générales'),
          Container(
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE5E7EB))),
            child: Column(children: [
              TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Nom du modèle *', prefixIcon: Icon(Icons.description_outlined), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14)),
              ),
              const Divider(height: 1),
              TextField(
                controller: _descCtrl,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Description (optionnelle)', prefixIcon: Icon(Icons.notes), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14), border: InputBorder.none),
              ),
            ]),
          ),

          const SizedBox(height: 20),

          Row(children: [
            const Expanded(child: _SLabel('Catégories & points')),
            TextButton.icon(
              onPressed: _addCategory,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Catégorie', style: TextStyle(fontSize: 12)),
            ),
          ]),

          if (_categories.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE5E7EB), style: BorderStyle.solid)),
              child: Column(children: [
                const Icon(Icons.add_box_outlined, size: 40, color: Color(0xFF9CA3AF)),
                const SizedBox(height: 8),
                const Text('Aucune catégorie', style: TextStyle(color: Color(0xFF9CA3AF))),
                const SizedBox(height: 8),
                ElevatedButton(onPressed: _addCategory, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1C1917), foregroundColor: Colors.white), child: const Text('Ajouter une catégorie')),
              ]),
            ),

          ...(_categories.asMap().entries.map((e) {
            final catIdx = e.key;
            final cat = e.value;
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE5E7EB))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Category header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: const BoxDecoration(color: Color(0xFFF8F7F4), borderRadius: BorderRadius.vertical(top: Radius.circular(14))),
                  child: Row(children: [
                    GestureDetector(
                      onTap: () => _editCategoryName(catIdx),
                      child: Text(cat.icon, style: const TextStyle(fontSize: 22)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _editCategoryName(catIdx),
                        child: Text(cat.label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                      ),
                    ),
                    Text('${cat.points.length} pts', style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      onPressed: () => _editCategoryName(catIdx),
                      color: const Color(0xFF9CA3AF), padding: EdgeInsets.zero, constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 18),
                      onPressed: () => _removeCategory(catIdx),
                      color: Colors.red, padding: EdgeInsets.zero, constraints: const BoxConstraints(),
                    ),
                  ]),
                ),

                // Points
                ...cat.points.asMap().entries.map((pe) {
                  final ptIdx = pe.key;
                  final pt = pe.value;
                  return Container(
                    decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFF3F4F6)))),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    child: Row(children: [
                      const Text('•', style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 16)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          TextField(
                            controller: TextEditingController(text: pt.label),
                            style: const TextStyle(fontSize: 13),
                            decoration: const InputDecoration(
                              hintText: 'Point d\'audit...',
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                            onChanged: (v) => pt.label = v,
                          ),
                          TextField(
                            controller: TextEditingController(text: pt.description),
                            style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
                            decoration: const InputDecoration(
                              hintText: 'Description / réf. légale (optionnel)',
                              hintStyle: TextStyle(fontSize: 11),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                            onChanged: (v) => pt.description = v,
                          ),
                        ]),
                      ),
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline, size: 18),
                        onPressed: () => _removePoint(catIdx, ptIdx),
                        color: const Color(0xFF9CA3AF), padding: EdgeInsets.zero, constraints: const BoxConstraints(),
                      ),
                    ]),
                  );
                }),

                // Add point button
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: GestureDetector(
                    onTap: () => _addPoint(catIdx),
                    child: Row(children: [
                      const Icon(Icons.add, size: 16, color: Color(0xFF6D28D9)),
                      const SizedBox(width: 6),
                      const Text('Ajouter un point', style: TextStyle(fontSize: 12, color: Color(0xFF6D28D9), fontWeight: FontWeight.w500)),
                    ]),
                  ),
                ),
              ]),
            );
          })),

          const SizedBox(height: 80),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF1C1917),
        onPressed: _addCategory,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Catégorie', style: TextStyle(color: Colors.white)),
      ),
    );
  }
}

class _SLabel extends StatelessWidget {
  final String text;
  const _SLabel(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF6B7280), letterSpacing: 0.8)),
      );
}
