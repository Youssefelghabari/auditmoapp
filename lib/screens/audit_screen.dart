// lib/screens/audit_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:uuid/uuid.dart';
import '../models/models.dart';
import '../services/database_service.dart';
import '../services/pdf_service.dart';
import 'report_screen.dart';

class AuditScreen extends StatefulWidget {
  final Commerce commerce;
  const AuditScreen({super.key, required this.commerce});

  @override
  State<AuditScreen> createState() => _AuditScreenState();
}

class _AuditScreenState extends State<AuditScreen> with SingleTickerProviderStateMixin {
  final _db = DatabaseService();
  late TabController _tabCtrl;

  AuditSession? _session;
  Map<String, AuditResponse> _responses = {};
  Map<String, dynamic> _stats = {'total': 25, 'answered': 0, 'conformes': 0, 'nonConformes': 0, 'score': 0};
  bool _loading = true;
  String? _expandedCat;
  String _auditorName = '';

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _initSession();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _initSession() async {
    var session = await _db.getLatestSession(widget.commerce.id);
    if (session == null || session.status == 'termine') {
      session = AuditSession(
        id: const Uuid().v4(),
        commerceId: widget.commerce.id,
        date: DateTime.now(),
      );
      await _db.insertSession(session);
    }
    final responses = await _db.getResponsesForSession(session.id);
    final stats = await _db.getAuditStats(session.id);
    setState(() {
      _session = session;
      _responses = {for (var r in responses) r.pointId: r};
      _stats = stats;
      _expandedCat = kAuditCategories.first.id;
      _auditorName = session!.auditorName;
      _loading = false;
    });
  }

  Future<void> _setResponse(String pointId, String value) async {
    final existing = _responses[pointId];
    if (existing?.response == value) {
      // toggle off
      await _db.deleteResponse(existing!.id);
      setState(() => _responses.remove(pointId));
    } else if (existing != null) {
      existing.response = value;
      existing.updatedAt = DateTime.now();
      await _db.upsertResponse(existing);
      setState(() => _responses[pointId] = existing);
    } else {
      final r = AuditResponse(
        id: const Uuid().v4(),
        sessionId: _session!.id,
        pointId: pointId,
        response: value,
        updatedAt: DateTime.now(),
      );
      await _db.upsertResponse(r);
      setState(() => _responses[pointId] = r);
    }
    final stats = await _db.getAuditStats(_session!.id);
    setState(() => _stats = stats);
  }

  Future<void> _setNote(String pointId, String note) async {
    var r = _responses[pointId];
    if (r == null) return;
    r.note = note;
    r.updatedAt = DateTime.now();
    await _db.upsertResponse(r);
  }

  Future<void> _pickPhoto(String pointId, ImageSource source) async {
    final picker = ImagePicker();
    final xfile = await picker.pickImage(source: source, imageQuality: 85, maxWidth: 1920);
    if (xfile == null) return;

    var r = _responses[pointId];
    if (r == null) {
      r = AuditResponse(
        id: const Uuid().v4(),
        sessionId: _session!.id,
        pointId: pointId,
        response: 'na',
        updatedAt: DateTime.now(),
      );
    }
    r.photoPath = xfile.path;
    r.updatedAt = DateTime.now();
    await _db.upsertResponse(r);
    setState(() => _responses[pointId] = r!);
  }

  Future<void> _removePhoto(String pointId) async {
    var r = _responses[pointId];
    if (r == null) return;
    r.photoPath = null;
    r.updatedAt = DateTime.now();
    await _db.upsertResponse(r);
    setState(() => _responses[pointId] = r!);
  }

  Future<void> _generatePdf() async {
    if (_session == null) return;
    final responses = _responses.values.toList();
    try {
      final file = await PdfService.generateAuditReport(
        commerce: widget.commerce,
        session: _session!,
        responses: responses,
        stats: _stats,
      );
      if (mounted) {
        await Printing.sharePdf(bytes: await file.readAsBytes(), filename: file.path.split('/').last);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur PDF: $e')));
    }
  }

  int get _score => _stats['score'] as int;
  Color get _scoreColor => _score >= 80 ? const Color(0xFF15803D) : _score >= 60 ? const Color(0xFFB45309) : const Color(0xFFB91C1C);
  Color get _scoreBg => _score >= 80 ? const Color(0xFFF0FDF4) : _score >= 60 ? const Color(0xFFFFFBEB) : const Color(0xFFFEF2F2);

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      backgroundColor: const Color(0xFFF8F7F4),
      body: NestedScrollView(
        headerSliverBuilder: (ctx, _) => [
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            backgroundColor: const Color(0xFF1C1917),
            iconTheme: const IconThemeData(color: Colors.white),
            actions: [
              IconButton(icon: const Icon(Icons.picture_as_pdf_outlined, color: Colors.white), onPressed: _generatePdf, tooltip: 'Exporter PDF'),
              IconButton(
                icon: const Icon(Icons.bar_chart, color: Colors.white),
                onPressed: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => ReportScreen(commerce: widget.commerce, session: _session!, responses: _responses.values.toList(), stats: _stats),
                )),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: _buildHeader(),
            ),
            bottom: TabBar(
              controller: _tabCtrl,
              indicatorColor: Colors.white,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white38,
              tabs: const [Tab(text: 'Audit'), Tab(text: 'Rapport')],
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabCtrl,
          children: [_buildAuditTab(), _buildReportTab()],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final c = widget.commerce;
    final hasPhoto = c.photoPath != null && File(c.photoPath!).existsSync();
    return Stack(
      fit: StackFit.expand,
      children: [
        if (hasPhoto)
          Image.file(File(c.photoPath!), fit: BoxFit.cover)
        else
          Container(color: const Color(0xFF1C1917)),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.black26, const Color(0xFF1C1917).withOpacity(0.95)],
            ),
          ),
        ),
        Positioned(
          left: 16, right: 16, bottom: 56,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(c.name, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700)),
              Text(c.category, style: const TextStyle(color: Colors.white54, fontSize: 13)),
              if (c.address.isNotEmpty)
                Row(children: [
                  const Icon(Icons.location_on, size: 12, color: Colors.white38),
                  const SizedBox(width: 4),
                  Expanded(child: Text(c.address, style: const TextStyle(color: Colors.white38, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis)),
                ]),
              const SizedBox(height: 12),
              Row(children: [
                _HeaderChip(label: '${_stats['answered']}/${_stats['total']} vérifiés', icon: Icons.check_circle_outline),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(color: _scoreBg, borderRadius: BorderRadius.circular(20)),
                  child: Text('Score : $_score%', style: TextStyle(color: _scoreColor, fontWeight: FontWeight.w700, fontSize: 13)),
                ),
              ]),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAuditTab() => ListView(
        padding: const EdgeInsets.all(12),
        children: [
          // Auditeur
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE5E7EB))),
            child: Row(children: [
              const Icon(Icons.person_outline, size: 18, color: Color(0xFF9CA3AF)),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(hintText: 'Nom de l\'auditeur (optionnel)', border: InputBorder.none, isDense: true),
                  style: const TextStyle(fontSize: 13),
                  onChanged: (v) async {
                    _auditorName = v;
                    _session!.auditorName = v;
                    await _db.updateSession(_session!);
                  },
                  controller: TextEditingController.fromValue(
                    TextEditingValue(text: _auditorName, selection: TextSelection.collapsed(offset: _auditorName.length)),
                  ),
                ),
              ),
            ]),
          ),

          ...kAuditCategories.map((cat) => _CategoryCard(
                category: cat,
                responses: _responses,
                isExpanded: _expandedCat == cat.id,
                onToggle: () => setState(() => _expandedCat = _expandedCat == cat.id ? null : cat.id),
                onSetResponse: _setResponse,
                onSetNote: _setNote,
                onPickPhoto: _pickPhoto,
                onRemovePhoto: _removePhoto,
              )),
          const SizedBox(height: 80),
        ],
      );

  Widget _buildReportTab() => ReportScreen(
        commerce: widget.commerce,
        session: _session!,
        responses: _responses.values.toList(),
        stats: _stats,
        embedded: true,
      );
}

class _HeaderChip extends StatelessWidget {
  final String label;
  final IconData icon;
  const _HeaderChip({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(20)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 12, color: Colors.white70),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ]),
      );
}

// ─── Category Card ───────────────────────────────────────────────────
class _CategoryCard extends StatelessWidget {
  final AuditCategory category;
  final Map<String, AuditResponse> responses;
  final bool isExpanded;
  final VoidCallback onToggle;
  final Future<void> Function(String, String) onSetResponse;
  final Future<void> Function(String, String) onSetNote;
  final Future<void> Function(String, ImageSource) onPickPhoto;
  final Future<void> Function(String) onRemovePhoto;

  const _CategoryCard({
    required this.category, required this.responses, required this.isExpanded,
    required this.onToggle, required this.onSetResponse, required this.onSetNote,
    required this.onPickPhoto, required this.onRemovePhoto,
  });

  int get _ok => category.points.where((p) => responses[p.id]?.response == 'oui').length;
  int get _ko => category.points.where((p) => responses[p.id]?.response == 'non').length;
  int get _done => category.points.where((p) => responses[p.id] != null).length;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _ko > 0 ? const Color(0xFFFCA5A5) : const Color(0xFFE5E7EB)),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Text(category.icon, style: const TextStyle(fontSize: 22)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(category.label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1C1917))),
                        const SizedBox(height: 2),
                        Text('$_done/${category.points.length} vérifiés · $_ok OK${_ko > 0 ? ' · $_ko NON' : ''}',
                            style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
                      ],
                    ),
                  ),
                  if (_ko > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(20)),
                      child: Text('$_ko ✗', style: const TextStyle(fontSize: 11, color: Color(0xFFB91C1C), fontWeight: FontWeight.w600)),
                    ),
                  Icon(isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: const Color(0xFF9CA3AF)),
                ],
              ),
            ),
          ),
          if (isExpanded)
            Column(
              children: [
                const Divider(height: 1, color: Color(0xFFF3F4F6)),
                ...category.points.map((pt) => _AuditPointRow(
                      point: pt,
                      response: responses[pt.id],
                      onSetResponse: (v) => onSetResponse(pt.id, v),
                      onSetNote: (v) => onSetNote(pt.id, v),
                      onPickPhoto: (src) => onPickPhoto(pt.id, src),
                      onRemovePhoto: () => onRemovePhoto(pt.id),
                    )),
              ],
            ),
        ],
      ),
    );
  }
}

// ─── Audit Point Row ─────────────────────────────────────────────────
class _AuditPointRow extends StatefulWidget {
  final AuditPointDef point;
  final AuditResponse? response;
  final Future<void> Function(String) onSetResponse;
  final Future<void> Function(String) onSetNote;
  final Future<void> Function(ImageSource) onPickPhoto;
  final Future<void> Function() onRemovePhoto;

  const _AuditPointRow({
    required this.point, required this.response,
    required this.onSetResponse, required this.onSetNote,
    required this.onPickPhoto, required this.onRemovePhoto,
  });

  @override
  State<_AuditPointRow> createState() => _AuditPointRowState();
}

class _AuditPointRowState extends State<_AuditPointRow> {
  late TextEditingController _noteCtrl;
  bool _showNote = false;

  @override
  void initState() {
    super.initState();
    _noteCtrl = TextEditingController(text: widget.response?.note ?? '');
    _showNote = (widget.response?.response == 'non') || (widget.response?.note.isNotEmpty == true);
  }

  @override
  void didUpdateWidget(_AuditPointRow old) {
    super.didUpdateWidget(old);
    final newNote = widget.response?.note ?? '';
    if (_noteCtrl.text != newNote) _noteCtrl.text = newNote;
    _showNote = (widget.response?.response == 'non') || (widget.response?.note.isNotEmpty == true);
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Color _bgColor() {
    if (widget.response == null) return Colors.white;
    return switch (widget.response!.response) {
      'oui' => const Color(0xFFF0FDF4),
      'non' => const Color(0xFFFEF2F2),
      _ => Colors.white,
    };
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.response;
    final hasPhoto = r?.photoPath != null && File(r!.photoPath!).existsSync();

    return Container(
      color: _bgColor(),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label + info
          Row(children: [
            Expanded(child: Text(widget.point.label, style: const TextStyle(fontSize: 13, color: Color(0xFF374151), height: 1.4))),
            if (widget.point.description != null)
              GestureDetector(
                onTap: () => showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: Text(widget.point.label, style: const TextStyle(fontSize: 14)),
                    content: Text(widget.point.description!, style: const TextStyle(fontSize: 13)),
                    actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
                  ),
                ),
                child: const Icon(Icons.info_outline, size: 16, color: Color(0xFF9CA3AF)),
              ),
          ]),

          const SizedBox(height: 10),

          // Response buttons
          Row(children: [
            _RespBtn(label: '✓ OUI', active: r?.response == 'oui', activeColor: const Color(0xFF15803D), activeBg: const Color(0xFFDCFCE7), onTap: () => widget.onSetResponse('oui')),
            const SizedBox(width: 8),
            _RespBtn(label: '✗ NON', active: r?.response == 'non', activeColor: const Color(0xFFB91C1C), activeBg: const Color(0xFFFEE2E2), onTap: () => widget.onSetResponse('non')),
            const SizedBox(width: 8),
            _RespBtn(label: 'N/A', active: r?.response == 'na', activeColor: const Color(0xFF6B7280), activeBg: const Color(0xFFF3F4F6), onTap: () => widget.onSetResponse('na')),
            const Spacer(),
            // Photo button
            GestureDetector(
              onTap: () => _showPhotoMenu(context),
              child: Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: hasPhoto ? const Color(0xFFEFF6FF) : const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: hasPhoto ? const Color(0xFF93C5FD) : const Color(0xFFE5E7EB)),
                ),
                child: Icon(hasPhoto ? Icons.photo : Icons.camera_alt_outlined, size: 18, color: hasPhoto ? const Color(0xFF2563EB) : const Color(0xFF9CA3AF)),
              ),
            ),
          ]),

          // Note field
          if (_showNote || r?.response == 'non') ...[
            const SizedBox(height: 8),
            TextField(
              controller: _noteCtrl,
              maxLines: 2,
              style: const TextStyle(fontSize: 12),
              decoration: const InputDecoration(
                hintText: 'Observation / remarque...',
                hintStyle: TextStyle(color: Color(0xFF9CA3AF)),
                border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                isDense: true,
              ),
              onChanged: widget.onSetNote,
            ),
          ] else if (r != null) ...[
            const SizedBox(height: 6),
            GestureDetector(
              onTap: () => setState(() => _showNote = true),
              child: const Row(children: [
                Icon(Icons.add, size: 12, color: Color(0xFF9CA3AF)),
                SizedBox(width: 4),
                Text('Ajouter une note', style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
              ]),
            ),
          ],

          // Photo preview
          if (hasPhoto) ...[
            const SizedBox(height: 8),
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(File(r!.photoPath!), height: 120, width: double.infinity, fit: BoxFit.cover),
                ),
                Positioned(
                  top: 4, right: 4,
                  child: GestureDetector(
                    onTap: widget.onRemovePhoto,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(6)),
                      child: const Icon(Icons.close, color: Colors.white, size: 14),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _showPhotoMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFFE5E7EB), borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 12),
            ListTile(leading: const Icon(Icons.camera_alt_outlined), title: const Text('Prendre une photo'), onTap: () { Navigator.pop(ctx); widget.onPickPhoto(ImageSource.camera); }),
            ListTile(leading: const Icon(Icons.photo_library_outlined), title: const Text('Depuis la galerie'), onTap: () { Navigator.pop(ctx); widget.onPickPhoto(ImageSource.gallery); }),
          ]),
        ),
      ),
    );
  }
}

class _RespBtn extends StatelessWidget {
  final String label;
  final bool active;
  final Color activeColor;
  final Color activeBg;
  final VoidCallback onTap;

  const _RespBtn({required this.label, required this.active, required this.activeColor, required this.activeBg, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: active ? activeBg : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: active ? activeColor : const Color(0xFFE5E7EB), width: active ? 1.5 : 1),
          ),
          child: Text(label, style: TextStyle(fontSize: 12, color: active ? activeColor : const Color(0xFF9CA3AF), fontWeight: active ? FontWeight.w600 : FontWeight.w400)),
        ),
      );
}
