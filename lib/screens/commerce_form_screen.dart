// lib/screens/commerce_form_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../models/models.dart';
import '../services/database_service.dart';
import '../services/location_service.dart';

class CommerceFormScreen extends StatefulWidget {
  final Commerce? commerce;
  const CommerceFormScreen({super.key, this.commerce});

  @override
  State<CommerceFormScreen> createState() => _CommerceFormScreenState();
}

class _CommerceFormScreenState extends State<CommerceFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _db = DatabaseService();
  final _loc = LocationService();
  final _picker = ImagePicker();

  String _category = 'Commerce général';
  String? _photoPath;
  double? _latitude;
  double? _longitude;
  bool _loadingGps = false;
  bool _saving = false;

  final List<String> _categories = [
    'Commerce général', 'Alimentaire / Épicerie', 'Boulangerie / Pâtisserie',
    'Boucherie / Charcuterie', 'Restauration', 'Pharmacie', 'Habillement / Mode',
    'Électronique / High-tech', 'Beauté / Coiffure', 'Sport & Loisirs', 'Autre',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.commerce != null) {
      final c = widget.commerce!;
      _nameCtrl.text = c.name;
      _addressCtrl.text = c.address;
      _category = c.category;
      _photoPath = c.photoPath;
      _latitude = c.latitude;
      _longitude = c.longitude;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto(ImageSource source) async {
    final xfile = await _picker.pickImage(source: source, imageQuality: 85, maxWidth: 1920);
    if (xfile != null) setState(() => _photoPath = xfile.path);
  }

  Future<void> _getGps() async {
    setState(() => _loadingGps = true);
    try {
      final pos = await _loc.getCurrentPosition();
      if (pos != null) {
        final address = await _loc.getAddressFromCoordinates(pos.latitude, pos.longitude);
        setState(() {
          _latitude = pos.latitude;
          _longitude = pos.longitude;
          if (_addressCtrl.text.isEmpty) _addressCtrl.text = address;
        });
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Impossible d\'obtenir la position GPS')));
      }
    } finally {
      setState(() => _loadingGps = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final now = DateTime.now();
    if (widget.commerce == null) {
      final c = Commerce(
        id: const Uuid().v4(),
        name: _nameCtrl.text.trim(),
        address: _addressCtrl.text.trim(),
        category: _category,
        latitude: _latitude,
        longitude: _longitude,
        photoPath: _photoPath,
        createdAt: now,
        updatedAt: now,
      );
      await _db.insertCommerce(c);
    } else {
      final c = widget.commerce!;
      c.name = _nameCtrl.text.trim();
      c.address = _addressCtrl.text.trim();
      c.category = _category;
      c.latitude = _latitude;
      c.longitude = _longitude;
      c.photoPath = _photoPath;
      await _db.updateCommerce(c);
    }

    setState(() => _saving = false);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.commerce != null;
    return Scaffold(
      backgroundColor: const Color(0xFFF8F7F4),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1C1917),
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(isEdit ? 'Modifier le commerce' : 'Nouveau commerce',
            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
        actions: [
          if (_saving)
            const Padding(padding: EdgeInsets.all(16), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)))
          else
            TextButton(onPressed: _save, child: const Text('Enregistrer', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600))),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ─── Photo du commerce ──────────────────────────
            _SectionTitle(title: 'Photo du commerce'),
            GestureDetector(
              onTap: () => _showPhotoDialog(),
              child: Container(
                height: 200,
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE5E7EB), style: BorderStyle.solid),
                ),
                clipBehavior: Clip.antiAlias,
                child: _photoPath != null && File(_photoPath!).existsSync()
                    ? Stack(fit: StackFit.expand, children: [
                        Image.file(File(_photoPath!), fit: BoxFit.cover),
                        Positioned(
                          bottom: 8, right: 8,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)),
                            child: const Icon(Icons.edit, color: Colors.white, size: 18),
                          ),
                        ),
                      ])
                    : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        const Icon(Icons.add_a_photo_outlined, size: 48, color: Color(0xFF9CA3AF)),
                        const SizedBox(height: 8),
                        const Text('Prendre ou choisir une photo', style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 13)),
                      ]),
              ),
            ),

            const SizedBox(height: 20),

            // ─── GPS ────────────────────────────────────────
            _SectionTitle(title: 'Localisation GPS'),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (_latitude != null)
                        Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              const Icon(Icons.gps_fixed, size: 16, color: Color(0xFF15803D)),
                              const SizedBox(width: 6),
                              const Text('Position enregistrée', style: TextStyle(fontSize: 13, color: Color(0xFF15803D), fontWeight: FontWeight.w500)),
                            ]),
                            const SizedBox(height: 4),
                            Text('${_latitude!.toStringAsFixed(5)}, ${_longitude!.toStringAsFixed(5)}',
                                style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF), fontFamily: 'monospace')),
                          ],
                        ))
                      else
                        const Expanded(child: Text('Aucune position GPS', style: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)))),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1C1917),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: _loadingGps ? null : _getGps,
                        icon: _loadingGps
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.my_location, size: 16),
                        label: Text(_latitude != null ? 'Actualiser' : 'Localiser', style: const TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ─── Infos ──────────────────────────────────────
            _SectionTitle(title: 'Informations'),
            _FormCard(children: [
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Nom du commerce *', prefixIcon: Icon(Icons.store_outlined)),
                validator: (v) => v == null || v.trim().isEmpty ? 'Champ obligatoire' : null,
              ),
              const Divider(height: 1),
              DropdownButtonFormField<String>(
                value: _category,
                decoration: const InputDecoration(labelText: 'Catégorie', prefixIcon: Icon(Icons.category_outlined), border: InputBorder.none),
                items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 14)))).toList(),
                onChanged: (v) => setState(() => _category = v!),
              ),
              const Divider(height: 1),
              TextFormField(
                controller: _addressCtrl,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Adresse', prefixIcon: Icon(Icons.location_on_outlined), border: InputBorder.none),
              ),
            ]),

            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  void _showPhotoDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFFE5E7EB), borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              const Text('Photo du commerce', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
              _OptionTile(icon: Icons.camera_alt_outlined, label: 'Prendre une photo', onTap: () { Navigator.pop(ctx); _pickPhoto(ImageSource.camera); }),
              _OptionTile(icon: Icons.photo_library_outlined, label: 'Choisir depuis la galerie', onTap: () { Navigator.pop(ctx); _pickPhoto(ImageSource.gallery); }),
              if (_photoPath != null)
                _OptionTile(icon: Icons.delete_outline, label: 'Supprimer la photo', color: Colors.red, onTap: () { setState(() => _photoPath = null); Navigator.pop(ctx); }),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF6B7280), letterSpacing: 0.8)),
      );
}

class _FormCard extends StatelessWidget {
  final List<Widget> children;
  const _FormCard({required this.children});

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Column(children: children),
      );
}

class _OptionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  const _OptionTile({required this.icon, required this.label, required this.onTap, this.color});

  @override
  Widget build(BuildContext context) => ListTile(
        leading: Icon(icon, color: color ?? const Color(0xFF374151)),
        title: Text(label, style: TextStyle(color: color ?? const Color(0xFF374151), fontSize: 14)),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      );
}
