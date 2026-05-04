import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../models/event_model.dart';
import '../../services/admin_service.dart';
import 'route_editor_screen.dart';

class EventFormScreen extends StatefulWidget {
  final EventModel? existing;
  final String organizerUid;
  const EventFormScreen({super.key, this.existing, this.organizerUid = ''});

  @override
  State<EventFormScreen> createState() => _EventFormScreenState();
}

class _EventFormScreenState extends State<EventFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _dateCtrl;
  late final TextEditingController _locationCtrl;

  late final String _tmpEventId;
  bool _saving = false;

  // Banner
  String _bannerUrl = '';
  Uint8List? _bannerPreview;

  // Dynamic race categories
  final List<_CategoryEntry> _categories = [];

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameCtrl = TextEditingController(text: e?.name ?? '');
    _dateCtrl = TextEditingController(text: e?.date ?? '');
    _locationCtrl = TextEditingController(text: e?.location ?? '');
    _tmpEventId =
        widget.existing?.id ?? DateTime.now().millisecondsSinceEpoch.toString();
    _bannerUrl = e?.bannerUrl ?? '';

    if (e != null && e.categories.isNotEmpty) {
      for (final entry in e.categories.entries) {
        final cat = entry.value;
        _categories.add(_CategoryEntry(
          labelCtrl: TextEditingController(text: cat.label),
          cutoffCtrl: TextEditingController(text: cat.cutoff),
          existingKmlPath: cat.kmlPath,
          existingKmlUrl: cat.kmlUrl,
        ));
      }
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _dateCtrl.dispose();
    _locationCtrl.dispose();
    for (final c in _categories) {
      c.labelCtrl.dispose();
      c.cutoffCtrl.dispose();
    }
    super.dispose();
  }

  void _addCategory() {
    setState(() {
      _categories.add(_CategoryEntry(
        labelCtrl: TextEditingController(),
        cutoffCtrl: TextEditingController(),
      ));
    });
  }

  void _removeCategory(int index) {
    setState(() {
      final entry = _categories.removeAt(index);
      entry.labelCtrl.dispose();
      entry.cutoffCtrl.dispose();
    });
  }

  Future<void> _pickBanner() async {
    final result = await AdminService.instance.pickFile('image/jpeg,image/png');
    if (result == null) return;
    if (result.bytes.length > 3 * 1024 * 1024) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Image too large. Please choose an image under 3 MB.')),
      );
      return;
    }
    setState(() => _bannerPreview = result.bytes);
  }

  Future<void> _pickKml(int index) async {
    final result = await AdminService.instance.pickFile('.kml');
    if (result == null) return;
    setState(() {
      _categories[index].pickedFileName = result.name;
      _categories[index].pickedBytes = result.bytes;
    });
  }

  Future<void> _openRouteEditor(int index) async {
    final catId = 'cat_$index';
    final result = await Navigator.of(context).push<RouteEditorResult>(
      MaterialPageRoute(
        builder: (_) => RouteEditorScreen(
          eventId: _tmpEventId,
          categoryId: catId,
          existingKmlPath: _categories[index].existingKmlPath,
        ),
        fullscreenDialog: true,
      ),
    );
    if (result != null) {
      setState(() {
        _categories[index].existingKmlPath = result.kmlPath;
        _categories[index].existingKmlUrl = result.kmlUrl;
        _categories[index].pickedBytes = null;
        _categories[index].pickedFileName = '';
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    // Validate at least one category
    if (_categories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one race category'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final existingId = widget.existing?.id;

      // Upload banner if new
      String bannerUrl = _bannerUrl;
      if (_bannerPreview != null) {
        bannerUrl = await AdminService.instance
            .uploadBanner(_tmpEventId, _bannerPreview!);
      }

      // Build categories map
      final catMaps = <String, Map<String, dynamic>>{};
      for (var i = 0; i < _categories.length; i++) {
        final entry = _categories[i];
        final catId = 'cat_$i';
        String kmlPath = entry.existingKmlPath;
        String kmlUrl = entry.existingKmlUrl;

        if (entry.pickedBytes != null) {
          kmlPath = 'events/$_tmpEventId/kml/$catId.kml';
          kmlUrl = await AdminService.instance.uploadKml(
              _tmpEventId, catId, entry.pickedFileName, entry.pickedBytes!);
        }

        catMaps[catId] = {
          'label': entry.labelCtrl.text.trim(),
          'cutoff': entry.cutoffCtrl.text.trim(),
          'kmlPath': kmlPath,
          'kmlUrl': kmlUrl,
        };
      }

      final data = {
        'name': _nameCtrl.text.trim(),
        'date': _dateCtrl.text.trim(),
        'location': _locationCtrl.text.trim(),
        'bannerUrl': bannerUrl,
        'createdAt':
            widget.existing?.createdAt ?? DateTime.now().millisecondsSinceEpoch,
        'organizerUid': widget.existing?.organizerUid ?? widget.organizerUid,
        'categories': catMaps,
      };

      if (existingId != null) {
        await AdminService.instance.updateEvent(existingId, data);
      } else {
        await AdminService.instance.createEvent(data);
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: Text(isEdit ? 'Edit Event' : 'Create New Event'),
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: ElevatedButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.save, size: 18),
                label: const Text('Save Event'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppTheme.primary,
                  elevation: 0,
                ),
              ),
            ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(28),
              children: [
                // ── Banner ───────────────────────────────────────────────
                _buildSectionHeader('Event Banner', null),
                const SizedBox(height: 12),
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: _saving ? null : _pickBanner,
                    child: Container(
                      height: 200,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: AppTheme.primary.withValues(alpha: 0.3),
                          width: 1.5,
                          strokeAlign: BorderSide.strokeAlignInside,
                        ),
                        image: _bannerPreview != null
                            ? DecorationImage(
                                image: MemoryImage(_bannerPreview!),
                                fit: BoxFit.cover)
                            : _bannerUrl.isNotEmpty
                                ? DecorationImage(
                                    image: NetworkImage(_bannerUrl),
                                    fit: BoxFit.cover)
                                : null,
                      ),
                      child: (_bannerPreview == null && _bannerUrl.isEmpty)
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.cloud_upload_outlined,
                                      size: 44, color: Colors.grey.shade400),
                                  const SizedBox(height: 10),
                                  Text('Click to upload banner image',
                                      style: TextStyle(
                                          color: Colors.grey.shade500,
                                          fontSize: 14)),
                                ],
                              ),
                            )
                          : Align(
                              alignment: Alignment.bottomRight,
                              child: Padding(
                                padding: const EdgeInsets.all(10),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.black54,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text('Change',
                                      style: TextStyle(
                                          color: Colors.white, fontSize: 12)),
                                ),
                              ),
                            ),
                    ),
                  ),
                ),

                const SizedBox(height: 28),

                // ── Event info ───────────────────────────────────────────
                _buildSectionHeader('Event Information', null),
                const SizedBox(height: 14),
                _buildField(
                  controller: _nameCtrl,
                  label: 'Event Name',
                  hint: 'e.g. Iwaki Sunshine Marathon 2025',
                  icon: Icons.event,
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _buildField(
                        controller: _dateCtrl,
                        label: 'Date',
                        hint: 'e.g. 2025-11-23',
                        icon: Icons.calendar_today,
                        validator: (v) =>
                            v == null || v.trim().isEmpty ? 'Required' : null,
                        readOnly: true,
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2030),
                          );
                          if (picked != null) {
                            _dateCtrl.text =
                                '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _buildField(
                        controller: _locationCtrl,
                        label: 'Location',
                        hint: 'e.g. Iwaki City, Fukushima',
                        icon: Icons.location_on_outlined,
                        validator: (v) =>
                            v == null || v.trim().isEmpty ? 'Required' : null,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 32),

                // ── Race categories ──────────────────────────────────────
                _buildSectionHeader(
                  'Race Categories',
                  TextButton.icon(
                    onPressed: _saving ? null : _addCategory,
                    icon: const Icon(Icons.add_circle_outline, size: 18),
                    label: const Text('Add Category'),
                  ),
                ),
                const SizedBox(height: 14),

                if (_categories.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.category_outlined,
                              size: 40, color: Colors.grey.shade400),
                          const SizedBox(height: 10),
                          Text('No categories added yet',
                              style: TextStyle(
                                  color: Colors.grey.shade500, fontSize: 14)),
                          const SizedBox(height: 6),
                          Text('Click "Add Category" to add race distances',
                              style: TextStyle(
                                  color: Colors.grey.shade400, fontSize: 12)),
                        ],
                      ),
                    ),
                  )
                else
                  ...List.generate(_categories.length, (i) {
                    final entry = _categories[i];
                    final hasKml = entry.pickedBytes != null ||
                        entry.existingKmlPath.isNotEmpty;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: hasKml
                              ? AppTheme.trackingGreen.withValues(alpha: 0.4)
                              : Colors.grey.shade200,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header row
                          Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color:
                                      AppTheme.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Center(
                                  child: Text(
                                    '${i + 1}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.primary,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Category ${i + 1}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              const Spacer(),
                              if (hasKml)
                                const Padding(
                                  padding: EdgeInsets.only(right: 8),
                                  child: Icon(Icons.check_circle,
                                      color: AppTheme.trackingGreen, size: 20),
                                ),
                              IconButton(
                                icon: const Icon(Icons.close,
                                    size: 18, color: Colors.redAccent),
                                tooltip: 'Remove category',
                                onPressed:
                                    _saving ? null : () => _removeCategory(i),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // Title + cutoff row
                          Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: TextFormField(
                                  controller: entry.labelCtrl,
                                  decoration: _inputDeco(
                                    'Title',
                                    'e.g. 21.1Km Half Marathon',
                                    Icons.directions_run,
                                  ),
                                  validator: (v) =>
                                      v == null || v.trim().isEmpty
                                          ? 'Required'
                                          : null,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: entry.cutoffCtrl,
                                  decoration: _inputDeco(
                                    'Cut-Off Time',
                                    'e.g. 03:45 Hours',
                                    Icons.timer_outlined,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 14),

                          // KML: upload or draw on map
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _saving ? null : () => _pickKml(i),
                                  icon: Icon(
                                    hasKml
                                        ? Icons.swap_horiz
                                        : Icons.upload_file,
                                    size: 16,
                                  ),
                                  label: Text(
                                    entry.pickedFileName.isNotEmpty
                                        ? entry.pickedFileName
                                        : entry.existingKmlPath.isNotEmpty
                                            ? entry.existingKmlPath
                                                .split('/')
                                                .last
                                            : 'Upload KML',
                                    style: const TextStyle(fontSize: 13),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppTheme.primary,
                                    side: BorderSide(
                                        color: AppTheme.primary
                                            .withValues(alpha: 0.4)),
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8)),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 10),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              OutlinedButton.icon(
                                onPressed:
                                    _saving ? null : () => _openRouteEditor(i),
                                icon: const Icon(Icons.map_outlined, size: 16),
                                label: const Text('Draw on Map',
                                    style: TextStyle(fontSize: 13)),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.deepOrange,
                                  side: BorderSide(
                                      color: Colors.deepOrange
                                          .withValues(alpha: 0.5)),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8)),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 10),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, Widget? action) {
    return Row(
      children: [
        Text(
          title.toUpperCase(),
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppTheme.textSecondary,
            letterSpacing: 0.8,
          ),
        ),
        const Spacer(),
        if (action != null) action,
      ],
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    String? Function(String?)? validator,
    bool readOnly = false,
    VoidCallback? onTap,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      readOnly: readOnly,
      onTap: onTap,
      decoration: _inputDeco(label, hint, icon),
    );
  }

  InputDecoration _inputDeco(String label, String hint, IconData icon) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, size: 20, color: AppTheme.textSecondary),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      filled: true,
      fillColor: Colors.white,
    );
  }
}

class _CategoryEntry {
  final TextEditingController labelCtrl;
  final TextEditingController cutoffCtrl;
  String existingKmlPath;
  String existingKmlUrl;
  String pickedFileName;
  Uint8List? pickedBytes;

  _CategoryEntry({
    required this.labelCtrl,
    required this.cutoffCtrl,
    this.existingKmlPath = '',
    this.existingKmlUrl = '',
    this.pickedFileName = '',
    this.pickedBytes,
  });
}
