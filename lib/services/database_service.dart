// lib/services/database_service.dart

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/models.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  Database? _db;

  Future<Database> get database async {
    _db ??= await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'audit_commercial.db');

    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE commerces (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            address TEXT,
            category TEXT,
            latitude REAL,
            longitude REAL,
            photo_path TEXT,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE audit_sessions (
            id TEXT PRIMARY KEY,
            commerce_id TEXT NOT NULL,
            auditor_name TEXT,
            date TEXT NOT NULL,
            status TEXT NOT NULL DEFAULT 'en_cours',
            FOREIGN KEY (commerce_id) REFERENCES commerces(id)
          )
        ''');

        await db.execute('''
          CREATE TABLE audit_responses (
            id TEXT PRIMARY KEY,
            session_id TEXT NOT NULL,
            point_id TEXT NOT NULL,
            response TEXT NOT NULL,
            note TEXT,
            photo_path TEXT,
            updated_at TEXT NOT NULL,
            FOREIGN KEY (session_id) REFERENCES audit_sessions(id)
          )
        ''');
      },
    );
  }

  // ─── Commerce ────────────────────────────────────────────
  Future<void> insertCommerce(Commerce c) async {
    final db = await database;
    await db.insert('commerces', c.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateCommerce(Commerce c) async {
    final db = await database;
    c.updatedAt = DateTime.now();
    await db.update('commerces', c.toMap(), where: 'id = ?', whereArgs: [c.id]);
  }

  Future<List<Commerce>> getAllCommerces() async {
    final db = await database;
    final rows = await db.query('commerces', orderBy: 'updated_at DESC');
    return rows.map(Commerce.fromMap).toList();
  }

  Future<Commerce?> getCommerce(String id) async {
    final db = await database;
    final rows = await db.query('commerces', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return Commerce.fromMap(rows.first);
  }

  Future<void> deleteCommerce(String id) async {
    final db = await database;
    await db.delete('commerces', where: 'id = ?', whereArgs: [id]);
  }

  // ─── Session ─────────────────────────────────────────────
  Future<void> insertSession(AuditSession s) async {
    final db = await database;
    await db.insert('audit_sessions', s.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateSession(AuditSession s) async {
    final db = await database;
    await db.update('audit_sessions', s.toMap(), where: 'id = ?', whereArgs: [s.id]);
  }

  Future<List<AuditSession>> getSessionsForCommerce(String commerceId) async {
    final db = await database;
    final rows = await db.query('audit_sessions',
        where: 'commerce_id = ?', whereArgs: [commerceId], orderBy: 'date DESC');
    return rows.map(AuditSession.fromMap).toList();
  }

  Future<AuditSession?> getLatestSession(String commerceId) async {
    final db = await database;
    final rows = await db.query('audit_sessions',
        where: 'commerce_id = ?', whereArgs: [commerceId], orderBy: 'date DESC', limit: 1);
    if (rows.isEmpty) return null;
    return AuditSession.fromMap(rows.first);
  }

  // ─── Responses ───────────────────────────────────────────
  Future<void> upsertResponse(AuditResponse r) async {
    final db = await database;
    await db.insert('audit_responses', r.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<AuditResponse>> getResponsesForSession(String sessionId) async {
    final db = await database;
    final rows = await db.query('audit_responses',
        where: 'session_id = ?', whereArgs: [sessionId]);
    return rows.map(AuditResponse.fromMap).toList();
  }

  Future<void> deleteResponse(String id) async {
    final db = await database;
    await db.delete('audit_responses', where: 'id = ?', whereArgs: [id]);
  }

  Future<Map<String, dynamic>> getAuditStats(String sessionId) async {
    final db = await database;
    final responses = await getResponsesForSession(sessionId);
    final total = kAuditCategories.fold(0, (sum, c) => sum + c.points.length);
    final answered = responses.length;
    final conformes = responses.where((r) => r.response == 'oui').length;
    final nonConformes = responses.where((r) => r.response == 'non').length;
    final score = total > 0 ? (conformes / total * 100).round() : 0;
    return {
      'total': total,
      'answered': answered,
      'conformes': conformes,
      'nonConformes': nonConformes,
      'score': score,
    };
  }
}
