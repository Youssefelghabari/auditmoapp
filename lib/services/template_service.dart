// lib/services/template_service.dart

import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import '../models/audit_template.dart';
import '../models/models.dart' show kAuditCategories;

class TemplateService {
  static final TemplateService _i = TemplateService._();
  factory TemplateService() => _i;
  TemplateService._();

  Database? _db;

  Future<Database> get _database async {
    if (_db != null) return _db!;
    final dbPath = await getDatabasesPath();
    _db = await openDatabase(
      p.join(dbPath, 'audit_commercial.db'),
      version: 1,
      onCreate: (db, _) => _createTables(db),
      onOpen: (db) => _createTables(db),
    );
    return _db!;
  }

  Future<void> _createTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS audit_templates (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        data TEXT NOT NULL,
        is_default INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS commerce_templates (
        commerce_id TEXT NOT NULL,
        template_id TEXT NOT NULL,
        PRIMARY KEY (commerce_id)
      )
    ''');
  }

  // ─── CRUD ─────────────────────────────────────────────────────────
  Future<void> saveTemplate(AuditTemplate t) async {
    final db = await _database;
    await db.insert('audit_templates', {
      'id': t.id,
      'name': t.name,
      'data': jsonEncode(t.toJson()),
      'is_default': t.isDefault ? 1 : 0,
      'created_at': t.createdAt.toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<AuditTemplate>> getAllTemplates() async {
    final db = await _database;
    final rows = await db.query('audit_templates', orderBy: 'is_default DESC, updated_at DESC');
    return rows.map((r) => AuditTemplate.fromJson(jsonDecode(r['data'] as String))).toList();
  }

  Future<AuditTemplate?> getTemplate(String id) async {
    final db = await _database;
    final rows = await db.query('audit_templates', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return AuditTemplate.fromJson(jsonDecode(rows.first['data'] as String));
  }

  Future<void> deleteTemplate(String id) async {
    final db = await _database;
    await db.delete('audit_templates', where: 'id = ?', whereArgs: [id]);
    await db.delete('commerce_templates', where: 'template_id = ?', whereArgs: [id]);
  }

  Future<void> setActiveTemplate(String commerceId, String templateId) async {
    final db = await _database;
    await db.insert('commerce_templates', {
      'commerce_id': commerceId,
      'template_id': templateId,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<AuditTemplate?> getActiveTemplate(String commerceId) async {
    final db = await _database;
    final rows = await db.query('commerce_templates', where: 'commerce_id = ?', whereArgs: [commerceId]);
    if (rows.isEmpty) return null;
    return getTemplate(rows.first['template_id'] as String);
  }

  Future<AuditTemplate?> getDefaultTemplate() async {
    final db = await _database;
    final rows = await db.query('audit_templates', where: 'is_default = 1', limit: 1);
    if (rows.isEmpty) return null;
    return AuditTemplate.fromJson(jsonDecode(rows.first['data'] as String));
  }

  // ─── Modèle embarqué ──────────────────────────────────────────────
  Future<AuditTemplate> getBuiltinTemplate() async {
    return AuditTemplate(
      id: 'builtin',
      name: 'Conformité Commerciale Standard',
      description: 'Modèle intégré couvrant sécurité, hygiène, affichage, caisse, personnel et environnement.',
      version: '1.0',
      isDefault: true,
      createdAt: DateTime(2024, 1, 1),
      updatedAt: DateTime(2024, 1, 1),
      categories: kAuditCategories.asMap().entries.map((e) {
        final cat = e.value;
        return TemplateCategory(
          id: cat.id,
          label: cat.label,
          icon: cat.icon,
          order: e.key,
          points: cat.points.asMap().entries.map((ep) {
            final pt = ep.value;
            return TemplatePoint(
              id: pt.id,
              label: pt.label,
              description: pt.description ?? '',
              order: ep.key,
            );
          }).toList(),
        );
      }).toList(),
    );
  }

  // ─── IMPORT ───────────────────────────────────────────────────────

  /// Ouvre le sélecteur de fichiers et retourne le template parsé
  Future<AuditTemplate?> importFromFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json', 'csv', 'txt'],
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return null;

    final file = result.files.first;
    final path = file.path;
    if (path == null) return null;

    final content = await File(path).readAsString();
    final ext = p.extension(path).toLowerCase();

    AuditTemplate? template;
    if (ext == '.json') {
      template = _parseJson(content);
    } else if (ext == '.csv' || ext == '.txt') {
      template = _parseCsv(content);
    }

    if (template != null) {
      await saveTemplate(template);
    }
    return template;
  }

  /// Parse un JSON flexible: supporte plusieurs formats
  AuditTemplate? _parseJson(String content) {
    try {
      final Map<String, dynamic> j = jsonDecode(content);

      // Format natif (exporté par l'app)
      if (j.containsKey('categories')) {
        return AuditTemplate.fromJson(j);
      }

      // Format simple: { "name": "...", "sections": [ { "title": "...", "items": ["..."] } ] }
      if (j.containsKey('sections')) {
        return _fromSectionsFormat(j);
      }

      // Format plat: { "name": "...", "items": [ { "category": "...", "label": "..." } ] }
      if (j.containsKey('items')) {
        return _fromItemsFormat(j);
      }

      // Format checklist simple: { "name": "...", "checklist": ["item1", "item2"] }
      if (j.containsKey('checklist')) {
        return _fromSimpleList(j);
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  /// Parse un CSV:
  /// Format 1: Catégorie,Point,Description,Référence légale
  /// Format 2: Point (sans catégorie, tout dans une seule cat)
  AuditTemplate? _parseCsv(String content) {
    try {
      final lines = content.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
      if (lines.isEmpty) return null;

      final id = const Uuid().v4();
      final now = DateTime.now();

      // Détecter si la première ligne est un header
      final firstLine = lines.first.toLowerCase();
      int startIdx = 0;
      if (firstLine.contains('catégorie') || firstLine.contains('categorie') ||
          firstLine.contains('category') || firstLine.contains('point') ||
          firstLine.contains('label') || firstLine.contains('nom')) {
        startIdx = 1;
      }

      final Map<String, List<TemplatePoint>> catMap = {};
      int order = 0;

      for (int i = startIdx; i < lines.length; i++) {
        final cols = _splitCsvLine(lines[i]);
        if (cols.isEmpty) continue;

        String catLabel;
        String pointLabel;
        String desc = '';
        String? legalRef;

        if (cols.length == 1) {
          // Juste un label de point
          catLabel = 'Points d\'audit';
          pointLabel = cols[0];
        } else if (cols.length == 2) {
          catLabel = cols[0].isNotEmpty ? cols[0] : 'Points d\'audit';
          pointLabel = cols[1];
        } else {
          catLabel = cols[0].isNotEmpty ? cols[0] : 'Points d\'audit';
          pointLabel = cols[1];
          if (cols.length > 2) desc = cols[2];
          if (cols.length > 3) legalRef = cols[3];
        }

        if (pointLabel.isEmpty) continue;

        catMap.putIfAbsent(catLabel, () => []);
        catMap[catLabel]!.add(TemplatePoint(
          id: '${id}_p${order++}',
          label: pointLabel,
          description: desc,
          legalRef: legalRef?.isNotEmpty == true ? legalRef : null,
        ));
      }

      if (catMap.isEmpty) return null;

      final categories = catMap.entries.toList().asMap().entries.map((e) {
        final idx = e.key;
        final entry = e.value;
        return TemplateCategory(
          id: '${id}_c$idx',
          label: entry.key,
          icon: _guessIcon(entry.key),
          order: idx,
          points: entry.value,
        );
      }).toList();

      return AuditTemplate(
        id: id,
        name: 'Import CSV ${now.day}/${now.month}/${now.year}',
        description: 'Importé depuis un fichier CSV',
        createdAt: now,
        updatedAt: now,
        categories: categories,
      );
    } catch (e) {
      return null;
    }
  }

  List<String> _splitCsvLine(String line) {
    final result = <String>[];
    bool inQuotes = false;
    final buffer = StringBuffer();
    for (int i = 0; i < line.length; i++) {
      final c = line[i];
      if (c == '"') {
        inQuotes = !inQuotes;
      } else if ((c == ',' || c == ';') && !inQuotes) {
        result.add(buffer.toString().trim());
        buffer.clear();
      } else {
        buffer.write(c);
      }
    }
    result.add(buffer.toString().trim());
    return result;
  }

  AuditTemplate _fromSectionsFormat(Map<String, dynamic> j) {
    final id = const Uuid().v4();
    final now = DateTime.now();
    final sections = j['sections'] as List<dynamic>;
    final categories = sections.asMap().entries.map((e) {
      final s = e.value as Map<String, dynamic>;
      final title = s['title'] ?? s['name'] ?? s['label'] ?? 'Section ${e.key + 1}';
      final items = s['items'] as List<dynamic>? ?? s['points'] as List<dynamic>? ?? [];
      return TemplateCategory(
        id: '${id}_c${e.key}',
        label: title.toString(),
        icon: s['icon'] ?? _guessIcon(title.toString()),
        order: e.key,
        points: items.asMap().entries.map((ep) {
          final item = ep.value;
          if (item is String) {
            return TemplatePoint(id: '${id}_p${e.key}_${ep.key}', label: item, order: ep.key);
          }
          return TemplatePoint.fromJson(item as Map<String, dynamic>);
        }).toList(),
      );
    }).toList();
    return AuditTemplate(
      id: id,
      name: j['name'] ?? 'Modèle importé',
      description: j['description'] ?? '',
      version: j['version'] ?? '1.0',
      createdAt: now,
      updatedAt: now,
      categories: categories,
    );
  }

  AuditTemplate _fromItemsFormat(Map<String, dynamic> j) {
    final id = const Uuid().v4();
    final now = DateTime.now();
    final items = j['items'] as List<dynamic>;
    final Map<String, List<TemplatePoint>> catMap = {};
    for (int i = 0; i < items.length; i++) {
      final item = items[i] as Map<String, dynamic>;
      final cat = item['category'] ?? item['section'] ?? 'Points';
      catMap.putIfAbsent(cat.toString(), () => []);
      catMap[cat.toString()]!.add(TemplatePoint(
        id: '${id}_p$i',
        label: item['label'] ?? item['name'] ?? item['point'] ?? '',
        description: item['description'] ?? '',
        legalRef: item['legal_ref'],
        order: i,
      ));
    }
    final categories = catMap.entries.toList().asMap().entries.map((e) {
      return TemplateCategory(
        id: '${id}_c${e.key}',
        label: e.value.key,
        icon: _guessIcon(e.value.key),
        order: e.key,
        points: e.value.value,
      );
    }).toList();
    return AuditTemplate(
      id: id,
      name: j['name'] ?? 'Modèle importé',
      description: j['description'] ?? '',
      createdAt: now,
      updatedAt: now,
      categories: categories,
    );
  }

  AuditTemplate _fromSimpleList(Map<String, dynamic> j) {
    final id = const Uuid().v4();
    final now = DateTime.now();
    final items = j['checklist'] as List<dynamic>;
    return AuditTemplate(
      id: id,
      name: j['name'] ?? 'Modèle importé',
      description: j['description'] ?? '',
      createdAt: now,
      updatedAt: now,
      categories: [
        TemplateCategory(
          id: '${id}_c0',
          label: 'Points d\'audit',
          icon: '📋',
          order: 0,
          points: items.asMap().entries.map((e) => TemplatePoint(
            id: '${id}_p${e.key}',
            label: e.value.toString(),
            order: e.key,
          )).toList(),
        ),
      ],
    );
  }

  String _guessIcon(String label) {
    final l = label.toLowerCase();
    if (l.contains('sécu') || l.contains('secu') || l.contains('incendie') || l.contains('risque')) return '🔒';
    if (l.contains('hygièn') || l.contains('hygien') || l.contains('propreté') || l.contains('nettoye') || l.contains('propret')) return '🧼';
    if (l.contains('affich') || l.contains('info') || l.contains('document') || l.contains('mention')) return '📋';
    if (l.contains('caisse') || l.contains('paiem') || l.contains('financ') || l.contains('comptab')) return '💳';
    if (l.contains('person') || l.contains('social') || l.contains('emploi') || l.contains('rh')) return '👤';
    if (l.contains('envi') || l.contains('énergi') || l.contains('energi') || l.contains('déchet') || l.contains('déchet')) return '🌿';
    if (l.contains('qualité') || l.contains('qualite')) return '⭐';
    if (l.contains('stock') || l.contains('entrepôt') || l.contains('entrepos')) return '📦';
    if (l.contains('client') || l.contains('accueil')) return '🤝';
    if (l.contains('équip') || l.contains('équip') || l.contains('materi')) return '🔧';
    return '📋';
  }

  // ─── EXPORT ───────────────────────────────────────────────────────
  Future<void> exportTemplate(AuditTemplate template) async {
    final dir = await getTemporaryDirectory();
    final filename = '${template.name.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_')}.json';
    final file = File(p.join(dir.path, filename));
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(template.toJson()));
    await Share.shareXFiles([XFile(file.path)], text: 'Modèle d\'audit: ${template.name}');
  }

  Future<void> exportAsCsv(AuditTemplate template) async {
    final dir = await getTemporaryDirectory();
    final filename = '${template.name.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_')}.csv';
    final buffer = StringBuffer();
    buffer.writeln('Catégorie,Point,Description,Référence légale');
    for (final cat in template.categories) {
      for (final pt in cat.points) {
        buffer.writeln('"${cat.label}","${pt.label}","${pt.description}","${pt.legalRef ?? ''}"');
      }
    }
    final file = File(p.join(dir.path, filename));
    await file.writeAsString(buffer.toString());
    await Share.shareXFiles([XFile(file.path)], text: 'Export CSV: ${template.name}');
  }

  // ─── Exemple de fichier à télécharger ─────────────────────────────
  Future<void> exportSampleJson() async {
    final sample = {
      "name": "Mon modèle d'audit personnalisé",
      "description": "Exemple de format JSON supporté",
      "version": "1.0",
      "categories": [
        {
          "id": "cat1",
          "label": "Sécurité",
          "icon": "🔒",
          "points": [
            {"id": "p1", "label": "Extincteurs vérifiés", "description": "Date de vérification < 1 an"},
            {"id": "p2", "label": "Issues de secours dégagées"},
            {"id": "p3", "label": "Détecteurs de fumée fonctionnels", "legal_ref": "Art. R4227-28"},
          ]
        },
        {
          "id": "cat2",
          "label": "Affichage",
          "icon": "📋",
          "points": [
            {"id": "p4", "label": "Prix affichés sur tous les produits"},
            {"id": "p5", "label": "Horaires d'ouverture visibles"},
            {"id": "p6", "label": "SIRET affiché"},
          ]
        }
      ]
    };
    final dir = await getTemporaryDirectory();
    final file = File(p.join(dir.path, 'exemple_audit.json'));
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(sample));
    await Share.shareXFiles([XFile(file.path)], text: 'Exemple de modèle d\'audit JSON');
  }

  Future<void> exportSampleCsv() async {
    const csv = '''Catégorie,Point,Description,Référence légale
Sécurité,Extincteurs vérifiés,Date de vérification < 1 an,Art. R4227-28
Sécurité,Issues de secours dégagées,,
Sécurité,Détecteurs de fumée fonctionnels,,
Affichage,Prix affichés sur tous les produits,,
Affichage,Horaires d'ouverture visibles,,
Affichage,SIRET affiché,,
Hygiène,Surfaces propres et désinfectées,,
Hygiène,Gestion des déchets conforme,,
''';
    final dir = await getTemporaryDirectory();
    final file = File(p.join(dir.path, 'exemple_audit.csv'));
    await file.writeAsString(csv);
    await Share.shareXFiles([XFile(file.path)], text: 'Exemple de modèle d\'audit CSV');
  }
}
