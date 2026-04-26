// lib/screens/home_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../services/database_service.dart';
import 'commerce_form_screen.dart';
import 'audit_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _db = DatabaseService();
  List<Commerce> _commerces = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await _db.getAllCommerces();
    setState(() { _commerces = list; _loading = false; });
  }

  Future<void> _deleteCommerce(Commerce c) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer ce commerce ?'),
        content: Text('${c.name} et toutes ses données seront supprimés définitivement.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Supprimer', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm == true) {
      await _db.deleteCommerce(c.id);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F7F4),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1C1917),
        elevation: 0,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Audit Commercial', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
            Text('Inspection de conformité', style: TextStyle(color: Colors.white38, fontSize: 11)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Colors.white),
            onPressed: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => const CommerceFormScreen()));
              _load();
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _commerces.isEmpty
              ? _buildEmpty()
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _commerces.length,
                    itemBuilder: (ctx, i) => _CommerceCard(
                      commerce: _commerces[i],
                      onTap: () async {
                        await Navigator.push(context, MaterialPageRoute(
                          builder: (_) => AuditScreen(commerce: _commerces[i]),
                        ));
                        _load();
                      },
                      onEdit: () async {
                        await Navigator.push(context, MaterialPageRoute(
                          builder: (_) => CommerceFormScreen(commerce: _commerces[i]),
                        ));
                        _load();
                      },
                      onDelete: () => _deleteCommerce(_commerces[i]),
                    ),
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF1C1917),
        onPressed: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => const CommerceFormScreen()));
          _load();
        },
        icon: const Icon(Icons.add_business, color: Colors.white),
        label: const Text('Nouveau commerce', style: TextStyle(color: Colors.white)),
      ),
    );
  }

  Widget _buildEmpty() => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.store_outlined, size: 72, color: Color(0xFFD1C9BE)),
            const SizedBox(height: 16),
            const Text('Aucun commerce', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF78716C))),
            const SizedBox(height: 8),
            const Text('Ajoutez votre premier commerce\npour commencer un audit', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFFA8A29E))),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1C1917), foregroundColor: Colors.white),
              icon: const Icon(Icons.add),
              label: const Text('Ajouter un commerce'),
              onPressed: () async {
                await Navigator.push(context, MaterialPageRoute(builder: (_) => const CommerceFormScreen()));
                _load();
              },
            ),
          ],
        ),
      );
}

class _CommerceCard extends StatefulWidget {
  final Commerce commerce;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _CommerceCard({required this.commerce, required this.onTap, required this.onEdit, required this.onDelete});

  @override
  State<_CommerceCard> createState() => _CommerceCardState();
}

class _CommerceCardState extends State<_CommerceCard> {
  int _score = 0;
  int _sessions = 0;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final db = DatabaseService();
    final sessions = await db.getSessionsForCommerce(widget.commerce.id);
    if (sessions.isNotEmpty) {
      final stats = await db.getAuditStats(sessions.first.id);
      setState(() { _score = stats['score']; _sessions = sessions.length; });
    } else {
      setState(() { _sessions = 0; });
    }
  }

  Color get _scoreColor => _score >= 80 ? const Color(0xFF15803D) : _score >= 60 ? const Color(0xFFB45309) : const Color(0xFFB91C1C);
  Color get _scoreBg => _score >= 80 ? const Color(0xFFF0FDF4) : _score >= 60 ? const Color(0xFFFFFBEB) : const Color(0xFFFEF2F2);

  @override
  Widget build(BuildContext context) {
    final c = widget.commerce;
    final hasPhoto = c.photoPath != null && File(c.photoPath!).existsSync();
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xFFE5E7EB))),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: widget.onTap,
        child: Column(
          children: [
            // Photo ou placeholder
            ClipRRect(
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
              child: hasPhoto
                  ? Image.file(File(c.photoPath!), height: 140, width: double.infinity, fit: BoxFit.cover)
                  : Container(
                      height: 100,
                      color: const Color(0xFFF3F4F6),
                      child: const Center(child: Icon(Icons.storefront, size: 48, color: Color(0xFFD1D5DB))),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(c.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF1C1917))),
                            const SizedBox(height: 2),
                            Text(c.category, style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
                          ],
                        ),
                      ),
                      if (_sessions > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(color: _scoreBg, borderRadius: BorderRadius.circular(20)),
                          child: Text('$_score%', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _scoreColor)),
                        ),
                    ],
                  ),
                  if (c.address.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(children: [
                      const Icon(Icons.location_on_outlined, size: 14, color: Color(0xFF9CA3AF)),
                      const SizedBox(width: 4),
                      Expanded(child: Text(c.address, style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)), maxLines: 1, overflow: TextOverflow.ellipsis)),
                    ]),
                  ],
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _chip(Icons.assignment_outlined, '$_sessions audit${_sessions > 1 ? 's' : ''}'),
                      const Spacer(),
                      IconButton(onPressed: widget.onEdit, icon: const Icon(Icons.edit_outlined, size: 18), color: const Color(0xFF9CA3AF), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
                      const SizedBox(width: 16),
                      IconButton(onPressed: widget.onDelete, icon: const Icon(Icons.delete_outline, size: 18), color: const Color(0xFF9CA3AF), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(IconData icon, String label) => Row(children: [
        Icon(icon, size: 13, color: const Color(0xFF9CA3AF)),
        const SizedBox(width: 3),
        Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
      ]);
}
