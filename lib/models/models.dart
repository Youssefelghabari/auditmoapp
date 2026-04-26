// lib/models/models.dart

class Commerce {
  final String id;
  String name;
  String address;
  String category;
  double? latitude;
  double? longitude;
  String? photoPath;
  DateTime createdAt;
  DateTime updatedAt;

  Commerce({
    required this.id,
    required this.name,
    this.address = '',
    this.category = 'Commerce général',
    this.latitude,
    this.longitude,
    this.photoPath,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'address': address,
        'category': category,
        'latitude': latitude,
        'longitude': longitude,
        'photo_path': photoPath,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory Commerce.fromMap(Map<String, dynamic> m) => Commerce(
        id: m['id'],
        name: m['name'],
        address: m['address'] ?? '',
        category: m['category'] ?? 'Commerce général',
        latitude: m['latitude'],
        longitude: m['longitude'],
        photoPath: m['photo_path'],
        createdAt: DateTime.parse(m['created_at']),
        updatedAt: DateTime.parse(m['updated_at']),
      );
}

class AuditCategory {
  final String id;
  final String label;
  final String icon;
  final List<AuditPointDef> points;

  const AuditCategory({
    required this.id,
    required this.label,
    required this.icon,
    required this.points,
  });
}

class AuditPointDef {
  final String id;
  final String label;
  final String? description;

  const AuditPointDef({
    required this.id,
    required this.label,
    this.description,
  });
}

class AuditResponse {
  final String id;
  final String sessionId;
  final String pointId;
  String response; // 'oui', 'non', 'na'
  String note;
  String? photoPath;
  DateTime updatedAt;

  AuditResponse({
    required this.id,
    required this.sessionId,
    required this.pointId,
    required this.response,
    this.note = '',
    this.photoPath,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'session_id': sessionId,
        'point_id': pointId,
        'response': response,
        'note': note,
        'photo_path': photoPath,
        'updated_at': updatedAt.toIso8601String(),
      };

  factory AuditResponse.fromMap(Map<String, dynamic> m) => AuditResponse(
        id: m['id'],
        sessionId: m['session_id'],
        pointId: m['point_id'],
        response: m['response'],
        note: m['note'] ?? '',
        photoPath: m['photo_path'],
        updatedAt: DateTime.parse(m['updated_at']),
      );
}

class AuditSession {
  final String id;
  final String commerceId;
  String auditorName;
  DateTime date;
  String status; // 'en_cours', 'termine'

  AuditSession({
    required this.id,
    required this.commerceId,
    this.auditorName = '',
    required this.date,
    this.status = 'en_cours',
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'commerce_id': commerceId,
        'auditor_name': auditorName,
        'date': date.toIso8601String(),
        'status': status,
      };

  factory AuditSession.fromMap(Map<String, dynamic> m) => AuditSession(
        id: m['id'],
        commerceId: m['commerce_id'],
        auditorName: m['auditor_name'] ?? '',
        date: DateTime.parse(m['date']),
        status: m['status'] ?? 'en_cours',
      );
}

// ─── Données de référence ───────────────────────────────────────────
const List<AuditCategory> kAuditCategories = [
  AuditCategory(
    id: 'securite',
    label: 'Sécurité & Accès',
    icon: '🔒',
    points: [
      AuditPointDef(id: 's1', label: 'Issue de secours clairement signalisée et dégagée', description: 'Vérifier que les voies d\'évacuation sont libres et balisées'),
      AuditPointDef(id: 's2', label: 'Extincteurs présents, visibles et vérifiés', description: 'Date de vérification < 1 an, accessibles'),
      AuditPointDef(id: 's3', label: 'Détecteurs de fumée fonctionnels', description: 'Tester le bouton test sur chaque détecteur'),
      AuditPointDef(id: 's4', label: 'Accès handicapé conforme (rampe, largeur portes)', description: 'Largeur min. 90 cm, pente rampe max 5%'),
      AuditPointDef(id: 's5', label: 'Éclairage de sécurité opérationnel', description: 'Blocs autonomes allumés en cas de coupure'),
    ],
  ),
  AuditCategory(
    id: 'hygiene',
    label: 'Hygiène & Propreté',
    icon: '🧼',
    points: [
      AuditPointDef(id: 'h1', label: 'Surfaces de vente propres et désinfectées'),
      AuditPointDef(id: 'h2', label: 'Sanitaires disponibles et entretenus'),
      AuditPointDef(id: 'h3', label: 'Gestion des déchets conforme (tri sélectif)'),
      AuditPointDef(id: 'h4', label: 'Produits alimentaires correctement stockés et datés', description: 'DLC/DDM visibles, chaîne du froid respectée'),
      AuditPointDef(id: 'h5', label: 'Température des zones réfrigérées conforme', description: 'Froid positif < 4°C, surgelés < -18°C'),
      AuditPointDef(id: 'h6', label: 'Personnel formé aux bonnes pratiques d\'hygiène'),
    ],
  ),
  AuditCategory(
    id: 'affichage',
    label: 'Affichage & Information',
    icon: '📋',
    points: [
      AuditPointDef(id: 'a1', label: 'Prix clairement affichés sur tous les produits'),
      AuditPointDef(id: 'a2', label: 'Horaires d\'ouverture visibles depuis l\'extérieur'),
      AuditPointDef(id: 'a3', label: 'Numéro SIRET affiché'),
      AuditPointDef(id: 'a4', label: 'Mentions légales et conditions de vente disponibles'),
      AuditPointDef(id: 'a5', label: 'Politique de retour/remboursement affichée'),
    ],
  ),
  AuditCategory(
    id: 'caisse',
    label: 'Caisse & Paiements',
    icon: '💳',
    points: [
      AuditPointDef(id: 'c1', label: 'Terminal de paiement fonctionnel'),
      AuditPointDef(id: 'c2', label: 'Tickets de caisse conformes (TVA, raison sociale)'),
      AuditPointDef(id: 'c3', label: 'Encaissements tracés et journaux de caisse tenus'),
      AuditPointDef(id: 'c4', label: 'Affichage des moyens de paiement acceptés'),
    ],
  ),
  AuditCategory(
    id: 'personnel',
    label: 'Personnel & Social',
    icon: '👤',
    points: [
      AuditPointDef(id: 'p1', label: 'Contrats de travail en règle et archivés'),
      AuditPointDef(id: 'p2', label: 'Registre du personnel tenu à jour'),
      AuditPointDef(id: 'p3', label: 'Affichage convention collective visible'),
      AuditPointDef(id: 'p4', label: 'Visite médicale du travail à jour'),
      AuditPointDef(id: 'p5', label: 'Formation sécurité du personnel réalisée'),
    ],
  ),
  AuditCategory(
    id: 'environnement',
    label: 'Environnement & Énergie',
    icon: '🌿',
    points: [
      AuditPointDef(id: 'e1', label: 'Tri des déchets professionnels conforme'),
      AuditPointDef(id: 'e2', label: 'Consommation énergétique suivie'),
      AuditPointDef(id: 'e3', label: 'Produits d\'entretien conformes (fiches de données sécurité)'),
      AuditPointDef(id: 'e4', label: 'Pas de dépôt sauvage devant l\'établissement'),
    ],
  ),
];
