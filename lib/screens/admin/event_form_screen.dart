import 'dart:typed_data';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config.dart';
import '../../../core/theme.dart';
import '../../../models/event_model.dart';
import '../../../services/admin_service.dart';
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
  late final TextEditingController _timeCtrl;
  late final TextEditingController _chipTimeCtrl; // display only, e.g. "10 min"
  int _chipTimeMinutes = 10;
  late final TextEditingController
      _graceTimeCtrl; // display only, e.g. "10 min"
  int _graceTimeMinutes = 10;
  late final TextEditingController _locationCtrl;
  late final TextEditingController _regStartCtrl;
  late final TextEditingController _regEndCtrl;
  late final TextEditingController _regUrlCtrl;

  late final String _tmpEventId;
  bool _saving = false;
  late final ScrollController _scrollCtrl;

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
    _timeCtrl = TextEditingController(text: e?.startTime ?? '');
    _locationCtrl = TextEditingController(text: e?.location ?? '');
    _regStartCtrl = TextEditingController(text: e?.registrationStartDate ?? '');
    _regEndCtrl = TextEditingController(text: e?.registrationEndDate ?? '');
    _regUrlCtrl = TextEditingController(text: e?.registrationUrl ?? '');
    _chipTimeMinutes = e?.chipTimeMinutes ?? 10;
    _chipTimeCtrl = TextEditingController(text: '$_chipTimeMinutes min');
    _graceTimeMinutes = e?.graceTimeMinutes ?? 10;
    _graceTimeCtrl = TextEditingController(text: '$_graceTimeMinutes min');
    _tmpEventId =
        widget.existing?.id ?? DateTime.now().millisecondsSinceEpoch.toString();
    _bannerUrl = e?.bannerUrl ?? '';
    _scrollCtrl = ScrollController();

    if (e != null && e.categories.isNotEmpty) {
      for (final entry in e.categories.entries) {
        final cat = entry.value;
        _categories.add(_CategoryEntry(
          labelCtrl: TextEditingController(text: cat.label),
          cutoffCtrl: TextEditingController(text: cat.cutoff),
          existingKmlPath: cat.kmlPath,
          existingKmlUrl: cat.kmlUrl,
          distanceKm: cat.distanceKm,
        ));
      }
    }
  }

  Future<void> _pickChipTime() async {
    int mins = _chipTimeMinutes;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setD) {
        return AlertDialog(
          title: const Text('Chip Time Window',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          content: _SpinBox(
            label: 'Minutes after start',
            value: mins,
            min: 0,
            max: 120,
            step: 5,
            onChanged: (v) => setD(() => mins = v),
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _chipTimeMinutes = mins;
                  _chipTimeCtrl.text = '$_chipTimeMinutes min';
                });
                Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white),
              child: const Text('Set'),
            ),
          ],
        );
      }),
    );
  }

  Future<void> _pickGraceTime() async {
    int mins = _graceTimeMinutes;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setD) {
        return AlertDialog(
          title: const Text('Grace Time',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          content: _SpinBox(
            label: 'Minutes after finish',
            value: mins,
            min: 0,
            max: 60,
            step: 5,
            onChanged: (v) => setD(() => mins = v),
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _graceTimeMinutes = mins;
                  _graceTimeCtrl.text = '$_graceTimeMinutes min';
                });
                Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white),
              child: const Text('Set'),
            ),
          ],
        );
      }),
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _dateCtrl.dispose();
    _timeCtrl.dispose();
    _locationCtrl.dispose();
    _regStartCtrl.dispose();
    _regEndCtrl.dispose();
    _regUrlCtrl.dispose();
    _chipTimeCtrl.dispose();
    _graceTimeCtrl.dispose();
    for (final c in _categories) {
      c.labelCtrl.dispose();
      c.cutoffCtrl.dispose();
    }
    _scrollCtrl.dispose();
    super.dispose();
  }

  DateTime? _parseEventDate() {
    final parts = _dateCtrl.text.trim().split('-');
    if (parts.length != 3) return null;
    final y = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final d = int.tryParse(parts[2]);
    if (y == null || m == null || d == null) return null;
    return DateTime(y, m, d);
  }

  DateTime? _parseDate(String text) {
    final parts = text.trim().split('-');
    if (parts.length != 3) return null;
    final y = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final d = int.tryParse(parts[2]);
    if (y == null || m == null || d == null) return null;
    return DateTime(y, m, d);
  }

  String _endTimeForCutoff(int cutoffMinutes) {
    if (cutoffMinutes == 0) return '';
    final tp = _timeCtrl.text.trim().split(':');
    if (tp.length != 2) return '';
    final startH = int.tryParse(tp[0]) ?? 0;
    final startM = int.tryParse(tp[1]) ?? 0;
    final total = startH * 60 + startM + cutoffMinutes;
    final endH = (total ~/ 60) % 24;
    final endM = total % 60;
    return '${endH.toString().padLeft(2, '0')}:${endM.toString().padLeft(2, '0')}';
  }

  String _computeEndTime() {
    int maxCutoff = 0;
    for (final entry in _categories) {
      final mins =
          RaceCategory.parseCutoffMinutes(entry.cutoffCtrl.text.trim());
      if (mins > maxCutoff) maxCutoff = mins;
    }
    return _endTimeForCutoff(maxCutoff);
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
            content:
                Text('Image too large. Please choose an image under 3 MB.')),
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
        _categories[index].distanceKm = result.distanceKm;
        _categories[index].pickedBytes = null;
        _categories[index].pickedFileName = '';
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    // Validate registration dates don't exceed event date
    final eventDate = _parseEventDate();
    if (eventDate != null) {
      final regStart = _parseDate(_regStartCtrl.text);
      final regEnd = _parseDate(_regEndCtrl.text);
      if (regStart != null && !regStart.isBefore(eventDate)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('Registration start date must be before the event date.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
      if (regEnd != null && !regEnd.isBefore(eventDate)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('Registration end date must be before the event date.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
    }

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

        final catCutoffMins =
            RaceCategory.parseCutoffMinutes(entry.cutoffCtrl.text.trim());
        catMaps[catId] = {
          'label': entry.labelCtrl.text.trim(),
          'cutoff': entry.cutoffCtrl.text.trim(),
          'kmlPath': kmlPath,
          'kmlUrl': kmlUrl,
          'endTime': _endTimeForCutoff(catCutoffMins),
          if (entry.distanceKm > 0) 'distanceKm': entry.distanceKm,
        };
      }

      final orgUid = widget.existing?.organizerUid ?? widget.organizerUid;
      // Denormalize the organizer's name onto the event so regular users can
      // display it — the admins node is not readable by non-admins.
      String organizerName = widget.existing?.organizerName ?? '';
      if (orgUid.isNotEmpty) {
        try {
          final admin = await AdminService.instance.fetchAdminUser(orgUid);
          if (admin != null && admin.displayName.isNotEmpty) {
            organizerName = admin.displayName;
          }
        } catch (_) {
          // Keep any existing name if the lookup fails.
        }
      }

      final data = {
        'name': _nameCtrl.text.trim(),
        'date': _dateCtrl.text.trim(),
        'startTime': _timeCtrl.text.trim(),
        'endTime': _computeEndTime(),
        'chipTimeMinutes': _chipTimeMinutes,
        'graceTimeMinutes': _graceTimeMinutes,
        'location': _locationCtrl.text.trim(),
        'bannerUrl': bannerUrl,
        'createdAt':
            widget.existing?.createdAt ?? DateTime.now().millisecondsSinceEpoch,
        'organizerUid': orgUid,
        if (organizerName.isNotEmpty) 'organizerName': organizerName,
        'registrationStartDate': _regStartCtrl.text.trim(),
        'registrationEndDate': _regEndCtrl.text.trim(),
        'registrationUrl': _regUrlCtrl.text.trim(),
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
      body: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerSignal: (event) {
          if (event is PointerScrollEvent) {
            final offset = (_scrollCtrl.offset + event.scrollDelta.dy)
                .clamp(0.0, _scrollCtrl.position.maxScrollExtent);
            _scrollCtrl.jumpTo(offset);
          }
        },
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Form(
              key: _formKey,
              child: ListView(
                controller: _scrollCtrl,
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
                            final today = DateTime.now();
                            final existing = _parseEventDate();
                            // Allow editing an event that already has a past date,
                            // but new events can only pick today or later.
                            final first =
                                (existing != null && existing.isBefore(today))
                                    ? existing
                                    : today;
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: existing ?? today,
                              firstDate: first,
                              lastDate: DateTime(2035),
                            );
                            if (picked != null) {
                              setState(() {
                                _dateCtrl.text =
                                    '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
                                // Clear reg dates that became invalid after event date change
                                final regStart = _parseDate(_regStartCtrl.text);
                                final regEnd = _parseDate(_regEndCtrl.text);
                                if (regStart != null &&
                                    !regStart.isBefore(picked)) {
                                  _regStartCtrl.clear();
                                }
                                if (regEnd != null &&
                                    !regEnd.isBefore(picked)) {
                                  _regEndCtrl.clear();
                                }
                              });
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: _buildField(
                          controller: _timeCtrl,
                          label: 'Start Time',
                          hint: 'e.g. 08:00',
                          icon: Icons.access_time_rounded,
                          validator: (v) =>
                              v == null || v.trim().isEmpty ? 'Required' : null,
                          readOnly: true,
                          onTap: () async {
                            final initial = TimeOfDay.now();
                            final picked = await showTimePicker(
                              context: context,
                              initialTime: initial,
                              builder: (ctx, child) => MediaQuery(
                                data: MediaQuery.of(ctx)
                                    .copyWith(alwaysUse24HourFormat: true),
                                child: child!,
                              ),
                            );
                            if (picked != null) {
                              setState(() {
                                _timeCtrl.text =
                                    '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
                              });
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  // if (_computeEndTime().isNotEmpty) ...[
                  //   const SizedBox(height: 10),
                  //   Container(
                  //     padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  //     decoration: BoxDecoration(
                  //       color: AppTheme.primary.withValues(alpha: 0.07),
                  //       borderRadius: BorderRadius.circular(10),
                  //       border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
                  //     ),
                  //     child: Row(
                  //       children: [
                  //         const Icon(Icons.timer_off_rounded, size: 18, color: AppTheme.primary),
                  //         const SizedBox(width: 8),
                  //         Text(
                  //           'End Time (auto): ${_computeEndTime()}',
                  //           style: const TextStyle(
                  //             fontSize: 13,
                  //             fontWeight: FontWeight.w600,
                  //             color: AppTheme.primary,
                  //           ),
                  //         ),
                  //       ],
                  //     ),
                  //   ),
                  // ],
                  const SizedBox(height: 14),
                  _buildField(
                    controller: _chipTimeCtrl,
                    label: 'Chip Time',
                    hint: 'e.g. 10 min',
                    icon: Icons.timer_rounded,
                    readOnly: true,
                    onTap: _pickChipTime,
                  ),
                  const SizedBox(height: 14),
                  _buildField(
                    controller: _graceTimeCtrl,
                    label: 'Grace Time',
                    hint: 'e.g. 10 min',
                    icon: Icons.timer_off_outlined,
                    readOnly: true,
                    onTap: _pickGraceTime,
                  ),
                  const SizedBox(height: 14),
                  _buildField(
                    controller: _locationCtrl,
                    label: 'Location',
                    hint: 'e.g. Iwaki City, Fukushima',
                    icon: Icons.location_on_outlined,
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Required' : null,
                  ),

                  const SizedBox(height: 32),

                  // ── Registration ─────────────────────────────────────────
                  _buildSectionHeader('Registration', null),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Set a date range and URL to show a "Register Now" button in the app.',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade500),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: _buildField(
                                controller: _regStartCtrl,
                                label: 'Registration Start',
                                hint: 'e.g. 2025-10-01',
                                icon: Icons.event_available_outlined,
                                readOnly: true,
                                onTap: () async {
                                  final eventDate = _parseEventDate();
                                  if (eventDate == null) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content: Text(
                                              'Please set the event date first.')),
                                    );
                                    return;
                                  }
                                  final lastAllowed = eventDate
                                      .subtract(const Duration(days: 1));
                                  final today = DateTime.now();
                                  final initial =
                                      _parseDate(_regStartCtrl.text) ??
                                          (today.isBefore(lastAllowed)
                                              ? today
                                              : lastAllowed);
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: initial,
                                    firstDate: DateTime.now(),
                                    lastDate: lastAllowed,
                                  );
                                  if (picked != null) {
                                    setState(() {
                                      _regStartCtrl.text =
                                          '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
                                      // End date must be re-selected after start date changes.
                                      _regEndCtrl.clear();
                                    });
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: _buildField(
                                controller: _regEndCtrl,
                                label: 'Registration End',
                                hint: 'e.g. 2025-11-20',
                                icon: Icons.event_busy_outlined,
                                readOnly: true,
                                onTap: () async {
                                  final eventDate = _parseEventDate();
                                  if (eventDate == null) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content: Text(
                                              'Please set the event date first.')),
                                    );
                                    return;
                                  }
                                  final regStart =
                                      _parseDate(_regStartCtrl.text);
                                  if (regStart == null) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content: Text(
                                              'Please set the registration start date first.')),
                                    );
                                    return;
                                  }
                                  final firstAllowed =
                                      regStart.add(const Duration(days: 1));
                                  final lastAllowed = eventDate
                                      .subtract(const Duration(days: 1));
                                  final initial =
                                      _parseDate(_regEndCtrl.text) ??
                                          (firstAllowed.isBefore(lastAllowed)
                                              ? firstAllowed
                                              : lastAllowed);
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: initial,
                                    firstDate: firstAllowed,
                                    lastDate: lastAllowed,
                                  );
                                  if (picked != null) {
                                    setState(() {
                                      _regEndCtrl.text =
                                          '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
                                    });
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        _buildField(
                          controller: _regUrlCtrl,
                          label: 'Registration URL',
                          hint: 'https://example.com/register',
                          icon: Icons.link_rounded,
                        ),
                        const SizedBox(height: 4),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: () => setState(() {
                              _regStartCtrl.clear();
                              _regEndCtrl.clear();
                              _regUrlCtrl.clear();
                            }),
                            icon: const Icon(Icons.clear, size: 15),
                            label: const Text('Clear registration',
                                style: TextStyle(fontSize: 12)),
                            style: TextButton.styleFrom(
                                foregroundColor: Colors.red),
                          ),
                        ),
                      ],
                    ),
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
                                        color: AppTheme.trackingGreen,
                                        size: 20),
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
                                    readOnly: true,
                                    onTap: () async {
                                      final existing =
                                          entry.cutoffCtrl.text.trim();
                                      final mins =
                                          RaceCategory.parseCutoffMinutes(
                                              existing);
                                      final initial = mins > 0
                                          ? TimeOfDay(
                                              hour: (mins ~/ 60) % 24,
                                              minute: mins % 60,
                                            )
                                          : const TimeOfDay(hour: 3, minute: 0);
                                      final picked = await showTimePicker(
                                        context: context,
                                        initialTime: initial,
                                        builder: (ctx, child) => MediaQuery(
                                          data: MediaQuery.of(ctx).copyWith(
                                              alwaysUse24HourFormat: true),
                                          child: child!,
                                        ),
                                      );
                                      if (picked != null) {
                                        entry.cutoffCtrl.text =
                                            '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
                                      }
                                    },
                                    decoration: _inputDeco(
                                      'Cut-Off Time',
                                      'e.g. 03:45',
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
                                    onPressed:
                                        _saving ? null : () => _pickKml(i),
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
                                          borderRadius:
                                              BorderRadius.circular(8)),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 14, vertical: 10),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                OutlinedButton.icon(
                                  onPressed: _saving
                                      ? null
                                      : () => _openRouteEditor(i),
                                  icon:
                                      const Icon(Icons.map_outlined, size: 16),
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
                                const SizedBox(width: 6),
                                Tooltip(
                                  message: 'Watch tutorial',
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(8),
                                    onTap: () async {
                                      final uri = Uri.parse(
                                          AppConfig.drawOnMapTutorialUrl);
                                      try {
                                        await launchUrl(uri,
                                            mode:
                                                LaunchMode.externalApplication);
                                      } catch (_) {}
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFF0000)
                                            .withValues(alpha: 0.08),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: const Color(0xFFFF0000)
                                              .withValues(alpha: 0.25),
                                        ),
                                      ),
                                      child: const Icon(
                                        Icons.play_circle_outline_rounded,
                                        size: 20,
                                        color: Color(0xFFCC0000),
                                      ),
                                    ),
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
    Widget? suffixIcon,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      readOnly: readOnly,
      onTap: onTap,
      decoration: _inputDeco(label, hint, icon, suffixIcon: suffixIcon),
    );
  }

  InputDecoration _inputDeco(String label, String hint, IconData icon,
      {Widget? suffixIcon}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, size: 20, color: AppTheme.textSecondary),
      suffixIcon: suffixIcon,
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

// ── Simple integer spin-box ───────────────────────────────────────────────────

class _SpinBox extends StatelessWidget {
  final String label;
  final int value;
  final int min;
  final int max;
  final int step;
  final ValueChanged<int> onChanged;

  const _SpinBox({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.step = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label,
            style:
                const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
        const SizedBox(height: 6),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.remove_circle_outline),
              onPressed:
                  value - step >= min ? () => onChanged(value - step) : null,
            ),
            SizedBox(
              width: 40,
              child: Text(
                value.toString().padLeft(2, '0'),
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              onPressed:
                  value + step <= max ? () => onChanged(value + step) : null,
            ),
          ],
        ),
      ],
    );
  }
}

class _CategoryEntry {
  final TextEditingController labelCtrl;
  final TextEditingController cutoffCtrl;
  String existingKmlPath;
  String existingKmlUrl;
  double distanceKm;
  String pickedFileName = '';
  Uint8List? pickedBytes;

  _CategoryEntry({
    required this.labelCtrl,
    required this.cutoffCtrl,
    this.existingKmlPath = '',
    this.existingKmlUrl = '',
    this.distanceKm = 0.0,
  });
}
