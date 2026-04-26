// lib/models/audit_template.dart

class AuditTemplate {
  final String id;
  String name;
  String description;
  String version;
  DateTime createdAt;
  DateTime updatedAt;
  bool isDefault;
  List<TemplateCategory> categories;

  AuditTemplate({
    required this.id,
    required this.name,
    this.description = '',
    this.version = '1.0',
    required this.createdAt,
    required this.updatedAt,
    this.isDefault = false,
    required this.categories,
  });

  int get totalPoints => categories.fold(0, (s, c) => s + c.points.length);

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'version': version,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'is_default': isDefault,
        'categories': categories.map((c) => c.toJson()).toList(),
      };

  factory AuditTemplate.fromJson(Map<String, dynamic> j) => AuditTemplate(
        id: j['id'] ?? _uid(),
        name: j['name'] ?? 'Modèle sans nom',
        description: j['description'] ?? '',
        version: j['version'] ?? '1.0',
        createdAt: j['created_at'] != null ? DateTime.parse(j['created_at']) : DateTime.now(),
        updatedAt: j['updated_at'] != null ? DateTime.parse(j['updated_at']) : DateTime.now(),
        isDefault: j['is_default'] ?? false,
        categories: (j['categories'] as List<dynamic>? ?? [])
            .map((c) => TemplateCategory.fromJson(c as Map<String, dynamic>))
            .toList(),
      );

  static String _uid() => DateTime.now().millisecondsSinceEpoch.toString();
}

class TemplateCategory {
  final String id;
  String label;
  String icon;
  int order;
  List<TemplatePoint> points;

  TemplateCategory({
    required this.id,
    required this.label,
    this.icon = '📋',
    this.order = 0,
    required this.points,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'icon': icon,
        'order': order,
        'points': points.map((p) => p.toJson()).toList(),
      };

  factory TemplateCategory.fromJson(Map<String, dynamic> j) => TemplateCategory(
        id: j['id'] ?? _uid(),
        label: j['label'] ?? j['name'] ?? 'Catégorie',
        icon: j['icon'] ?? '📋',
        order: j['order'] ?? 0,
        points: (j['points'] as List<dynamic>? ?? [])
            .map((p) => TemplatePoint.fromJson(p as Map<String, dynamic>))
            .toList(),
      );

  static String _uid() => DateTime.now().millisecondsSinceEpoch.toString();
}

class TemplatePoint {
  final String id;
  String label;
  String description;
  bool required;
  int order;
  String? legalRef; // référence légale / réglementaire optionnelle

  TemplatePoint({
    required this.id,
    required this.label,
    this.description = '',
    this.required = true,
    this.order = 0,
    this.legalRef,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'description': description,
        'required': required,
        'order': order,
        if (legalRef != null) 'legal_ref': legalRef,
      };

  factory TemplatePoint.fromJson(Map<String, dynamic> j) => TemplatePoint(
        id: j['id'] ?? _uid(),
        label: j['label'] ?? j['name'] ?? '',
        description: j['description'] ?? '',
        required: j['required'] ?? true,
        order: j['order'] ?? 0,
        legalRef: j['legal_ref'],
      );

  static String _uid() => DateTime.now().millisecondsSinceEpoch.toString();
}
