import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:xml/xml.dart';

import '../../../core/config.dart';
import '../../../core/theme.dart';
import '../../../services/admin_service.dart';

// ── Return type ───────────────────────────────────────────────────────────────

class RouteEditorResult {
  final String kmlUrl;
  final String kmlPath;
  final double distanceKm;
  const RouteEditorResult({
    required this.kmlUrl,
    required this.kmlPath,
    this.distanceKm = 0.0,
  });
}

// ── Marker types ──────────────────────────────────────────────────────────────

enum _MarkerType {
  start,
  finish,
  water,
  restroom,
  snack,
  medical,
  info,
}

extension _MarkerTypeX on _MarkerType {
  String get label {
    switch (this) {
      case _MarkerType.start:
        return 'Start';
      case _MarkerType.finish:
        return 'Finish';
      case _MarkerType.water:
        return 'Water Station';
      case _MarkerType.restroom:
        return 'Restroom';
      case _MarkerType.snack:
        return 'Snacks';
      case _MarkerType.medical:
        return 'Medical Aid';
      case _MarkerType.info:
        return 'Info / Lobby';
    }
  }

  double get hue {
    switch (this) {
      case _MarkerType.start:
        return BitmapDescriptor.hueGreen;
      case _MarkerType.finish:
        return BitmapDescriptor.hueRed;
      case _MarkerType.water:
        return BitmapDescriptor.hueBlue;
      case _MarkerType.restroom:
        return BitmapDescriptor.hueOrange;
      case _MarkerType.snack:
        return BitmapDescriptor.hueCyan;
      case _MarkerType.medical:
        return BitmapDescriptor.hueRose;
      case _MarkerType.info:
        return BitmapDescriptor.hueViolet;
    }
  }

  Color get color {
    switch (this) {
      case _MarkerType.start:
        return Colors.green;
      case _MarkerType.finish:
        return Colors.red;
      case _MarkerType.water:
        return Colors.blue;
      case _MarkerType.restroom:
        return Colors.orange;
      case _MarkerType.snack:
        return Colors.cyan.shade700;
      case _MarkerType.medical:
        return Colors.pink;
      case _MarkerType.info:
        return Colors.purple;
    }
  }

  IconData get icon {
    switch (this) {
      case _MarkerType.start:
        return Icons.play_circle_outline;
      case _MarkerType.finish:
        return Icons.flag_outlined;
      case _MarkerType.water:
        return Icons.water_drop_outlined;
      case _MarkerType.restroom:
        return Icons.wc_outlined;
      case _MarkerType.snack:
        return Icons.fastfood_outlined;
      case _MarkerType.medical:
        return Icons.local_hospital_outlined;
      case _MarkerType.info:
        return Icons.info_outline;
    }
  }

  String get kmlColor {
    final c = color;
    const a = 'ff';
    final bVal = (c.b * 255.0).round().clamp(0, 255);
    final gVal = (c.g * 255.0).round().clamp(0, 255);
    final rVal = (c.r * 255.0).round().clamp(0, 255);
    final b = bVal.toRadixString(16).padLeft(2, '0');
    final g = gVal.toRadixString(16).padLeft(2, '0');
    final r = rVal.toRadixString(16).padLeft(2, '0');
    return '$a$b$g$r';
  }
}

class _PlacedMarker {
  final String id;
  final LatLng position;
  final String name;
  final _MarkerType type;
  _PlacedMarker({
    required this.id,
    required this.position,
    required this.name,
    required this.type,
  });
}

class _MarkerDialogResult {
  final String name;
  final _MarkerType type;
  _MarkerDialogResult(this.name, this.type);
}

// ── Screen ────────────────────────────────────────────────────────────────────

enum _EditMode { route, marker }

class RouteEditorScreen extends StatefulWidget {
  final String eventId;
  final String categoryId;

  /// Storage path of an existing KML (e.g. events/xxx/kml/cat_0.kml).
  /// When non-empty the editor loads and displays the saved route on open.
  final String existingKmlPath;

  const RouteEditorScreen({
    super.key,
    required this.eventId,
    required this.categoryId,
    this.existingKmlPath = '',
  });

  @override
  State<RouteEditorScreen> createState() => _RouteEditorScreenState();
}

class _RouteEditorScreenState extends State<RouteEditorScreen> {
  final Completer<GoogleMapController> _mapCompleter = Completer();
  final TextEditingController _searchCtrl = TextEditingController();

  _EditMode _mode = _EditMode.route;
  bool _saving = false;
  bool _loading = false;
  bool _searchLoading = false;

  // Custom marker icons — built once, cached here
  BitmapDescriptor? _routeDotIcon;
  final _typeIcons = <_MarkerType, BitmapDescriptor>{};

  final List<LatLng> _routePoints = [];
  final List<_PlacedMarker> _markers = [];
  int _markerCounter = 0;

  // ── Dialog cooldown: prevents the tap that dismisses the dialog from
  // immediately re-triggering _onMapTap on web.
  bool _dialogOpen = false;
  DateTime? _dialogClosedAt;

  @override
  void initState() {
    super.initState();
    _buildIcons();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.existingKmlPath.isNotEmpty) {
        _loadExistingKml();
      } else {
        _moveToCurrentLocation();
      }
    });
  }

  Future<void> _buildIcons() async {
    final dot = await _makeDotIcon();
    final icons = <_MarkerType, BitmapDescriptor>{};
    for (final t in _MarkerType.values) {
      icons[t] = await _makeTypeIcon(t);
    }
    if (!mounted) return;
    setState(() {
      _routeDotIcon = dot;
      _typeIcons.addAll(icons);
    });
  }

  static Future<BitmapDescriptor> _makeDotIcon() async {
    const int sz = 18;
    final recorder = ui.PictureRecorder();
    final c = Canvas(recorder);
    const cx = sz / 2.0;

    // soft shadow
    c.drawCircle(const Offset(cx + 0.5, cx + 0.5), cx - 1,
        Paint()..color = Colors.black26);
    // white ring
    c.drawCircle(const Offset(cx, cx), cx - 1, Paint()..color = Colors.white);
    // blue core
    c.drawCircle(const Offset(cx, cx), cx - 3.5,
        Paint()..color = const Color(0xFF4285F4));

    final img = await recorder.endRecording().toImage(sz, sz);
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(bytes!.buffer.asUint8List());
  }

  static Future<BitmapDescriptor> _makeTypeIcon(_MarkerType type) async {
    const int sz = 48;
    const double cx = sz / 2.0;
    const double r = cx - 2;

    final recorder = ui.PictureRecorder();
    final c = Canvas(recorder);

    // drop shadow
    c.drawCircle(const Offset(cx + 1.5, cx + 1.5), r,
        Paint()..color = Colors.black.withValues(alpha: 0.28));
    // filled circle
    c.drawCircle(const Offset(cx, cx), r, Paint()..color = type.color);
    // white border
    c.drawCircle(
        const Offset(cx, cx),
        r,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5);
    // icon glyph
    final tp = TextPainter(textDirection: TextDirection.ltr)
      ..text = TextSpan(
        text: String.fromCharCode(type.icon.codePoint),
        style: TextStyle(
          fontSize: sz * 0.44,
          fontFamily: type.icon.fontFamily,
          color: Colors.white,
        ),
      )
      ..layout();
    tp.paint(c, Offset(cx - tp.width / 2, cx - tp.height / 2));

    final img = await recorder.endRecording().toImage(sz, sz);
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(bytes!.buffer.asUint8List());
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Load existing KML ─────────────────────────────────────────────────────

  Future<void> _loadExistingKml() async {
    setState(() => _loading = true);
    try {
      final bytes =
          await AdminService.instance.downloadKml(widget.existingKmlPath);
      if (bytes == null || !mounted) {
        if (mounted) setState(() => _loading = false);
        return;
      }

      final doc = XmlDocument.parse(utf8.decode(bytes));
      final points = <LatLng>[];
      final markers = <_PlacedMarker>[];
      int counter = 0;

      for (final pm in doc.findAllElements('Placemark')) {
        // ── Polyline route ──
        final lineEls = pm.findElements('LineString');
        if (lineEls.isNotEmpty) {
          final coordText =
              lineEls.first.findElements('coordinates').first.innerText.trim();
          // Coordinates may be separated by whitespace or newlines
          for (final token in coordText.split(RegExp(r'\s+'))) {
            if (token.isEmpty) continue;
            final parts = token.split(',');
            if (parts.length >= 2) {
              final lng = double.tryParse(parts[0]);
              final lat = double.tryParse(parts[1]);
              if (lat != null && lng != null) {
                points.add(LatLng(lat, lng));
              }
            }
          }
        }

        // ── Point marker ──
        final pointEls = pm.findElements('Point');
        if (pointEls.isNotEmpty) {
          final coordText =
              pointEls.first.findElements('coordinates').first.innerText.trim();
          final parts = coordText.split(',');
          if (parts.length >= 2) {
            final lng = double.tryParse(parts[0].trim());
            final lat = double.tryParse(parts[1].trim());
            if (lat != null && lng != null) {
              final name =
                  pm.findElements('name').firstOrNull?.innerText.trim() ?? '';
              final styleId =
                  (pm.findElements('styleUrl').firstOrNull?.innerText ?? '')
                      .replaceFirst('#', '');
              _MarkerType type = _MarkerType.water;
              for (final t in _MarkerType.values) {
                if (t.name == styleId) {
                  type = t;
                  break;
                }
              }
              markers.add(_PlacedMarker(
                id: 'marker_${counter++}',
                position: LatLng(lat, lng),
                name: name,
                type: type,
              ));
            }
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _routePoints.addAll(points);
        _markers.addAll(markers);
        _markerCounter = counter;
        _loading = false;
      });

      // Animate camera to fit the loaded route
      if (points.isNotEmpty) {
        final ctrl = await _mapCompleter.future;
        if (!mounted) return;
        var minLat = points.first.latitude;
        var maxLat = points.first.latitude;
        var minLng = points.first.longitude;
        var maxLng = points.first.longitude;
        for (final p in points) {
          if (p.latitude < minLat) minLat = p.latitude;
          if (p.latitude > maxLat) maxLat = p.latitude;
          if (p.longitude < minLng) minLng = p.longitude;
          if (p.longitude > maxLng) maxLng = p.longitude;
        }
        ctrl.animateCamera(CameraUpdate.newLatLngBounds(
          LatLngBounds(
            southwest: LatLng(minLat - 0.001, minLng - 0.001),
            northeast: LatLng(maxLat + 0.001, maxLng + 0.001),
          ),
          60,
        ));
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Current location ──────────────────────────────────────────────────────

  Future<void> _moveToCurrentLocation() async {
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.medium),
      );
      final ctrl = await _mapCompleter.future;
      if (mounted) {
        ctrl.animateCamera(CameraUpdate.newLatLngZoom(
            LatLng(pos.latitude, pos.longitude), 15));
      }
    } catch (_) {}
  }

  // ── Search ────────────────────────────────────────────────────────────────

  Future<void> _searchLocation(String query) async {
    query = query.trim();
    if (query.isEmpty) return;
    setState(() => _searchLoading = true);
    try {
      final uri = Uri.https('maps.googleapis.com', '/maps/api/geocode/json', {
        'address': query,
        'key': AppConfig.googleMapsApiKey,
      });
      final resp = await http.get(uri);
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final results = data['results'] as List?;
      if (results != null && results.isNotEmpty) {
        final loc = results[0]['geometry']['location'] as Map<String, dynamic>;
        final lat = (loc['lat'] as num).toDouble();
        final lng = (loc['lng'] as num).toDouble();
        final ctrl = await _mapCompleter.future;
        if (mounted) {
          ctrl.animateCamera(CameraUpdate.newLatLngZoom(LatLng(lat, lng), 14));
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location not found')),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Search failed')),
        );
      }
    } finally {
      if (mounted) setState(() => _searchLoading = false);
    }
  }

  // ── Map interactions ──────────────────────────────────────────────────────

  void _onMapTap(LatLng pos) {
    if (_mode == _EditMode.route) {
      setState(() => _routePoints.add(pos));
      return;
    }

    // Marker mode — guard against the click that dismissed the dialog
    // propagating back to the map and immediately re-opening it.
    if (_dialogOpen) return;
    final closedAt = _dialogClosedAt;
    if (closedAt != null &&
        DateTime.now().difference(closedAt).inMilliseconds < 400) {
      return;
    }

    _showAddMarkerDialog(pos);
  }

  void _undo() {
    setState(() {
      if (_mode == _EditMode.route && _routePoints.isNotEmpty) {
        _routePoints.removeLast();
      } else if (_mode == _EditMode.marker && _markers.isNotEmpty) {
        _markers.removeLast();
      }
    });
  }

  void _clear() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear all?'),
        content: const Text('This will remove all route points and markers.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _routePoints.clear();
                _markers.clear();
              });
            },
            child: const Text('Clear', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddMarkerDialog(LatLng pos) async {
    _dialogOpen = true;
    final result = await showDialog<_MarkerDialogResult>(
      context: context,
      builder: (_) => const _AddMarkerDialog(),
    );
    _dialogOpen = false;
    _dialogClosedAt = DateTime.now();

    if (result != null && mounted) {
      setState(() {
        _markers.add(_PlacedMarker(
          id: 'marker_${_markerCounter++}',
          position: pos,
          name: result.name,
          type: result.type,
        ));
      });
    }
  }

  // ── Save ──────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    if (_routePoints.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Draw at least 2 points to define a route.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final kmlBytes = _generateKml();
      final kmlUrl = await AdminService.instance.uploadKml(
        widget.eventId,
        widget.categoryId,
        '${widget.categoryId}.kml',
        kmlBytes,
      );
      final kmlPath = 'events/${widget.eventId}/kml/${widget.categoryId}.kml';
      final cumDists = _computeCumulativeDistances();
      final distanceKm = cumDists.isNotEmpty ? cumDists.last / 1000.0 : 0.0;
      if (mounted) {
        Navigator.pop(
          context,
          RouteEditorResult(kmlUrl: kmlUrl, kmlPath: kmlPath, distanceKm: distanceKm),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Save failed: $e'), backgroundColor: Colors.red),
        );
        setState(() => _saving = false);
      }
    }
  }

  // ── KML generator ─────────────────────────────────────────────────────────

  Uint8List _generateKml() {
    final buf = StringBuffer();
    buf.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    buf.writeln('<kml xmlns="http://www.opengis.net/kml/2.2">');
    buf.writeln('<Document>');
    for (final t in _MarkerType.values) {
      buf.writeln('<Style id="${t.name}">');
      buf.writeln('  <IconStyle>');
      buf.writeln('    <color>${t.kmlColor}</color>');
      buf.writeln('    <scale>1.1</scale>');
      buf.writeln('  </IconStyle>');
      buf.writeln('  <LabelStyle><scale>0.8</scale></LabelStyle>');
      buf.writeln('</Style>');
    }
    if (_routePoints.length >= 2) {
      buf.writeln('<Placemark>');
      buf.writeln('  <name>Route</name>');
      buf.writeln('  <Style><LineStyle><color>ff0055ff</color>'
          '<width>4</width></LineStyle></Style>');
      buf.writeln('  <LineString><tessellate>1</tessellate>');
      buf.writeln('    <coordinates>');
      for (final pt in _routePoints) {
        buf.writeln('      ${pt.longitude},${pt.latitude},0');
      }
      buf.writeln('    </coordinates></LineString>');
      buf.writeln('</Placemark>');
    }
    for (final m in _markers) {
      buf.writeln('<Placemark>');
      buf.writeln('  <name>${_xmlEscape(m.name)}</name>');
      buf.writeln('  <styleUrl>#${m.type.name}</styleUrl>');
      buf.writeln('  <Point><coordinates>'
          '${m.position.longitude},${m.position.latitude},0'
          '</coordinates></Point>');
      buf.writeln('</Placemark>');
    }
    buf.writeln('</Document></kml>');
    return Uint8List.fromList(utf8.encode(buf.toString()));
  }

  String _xmlEscape(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');

  // ── Distance helpers ──────────────────────────────────────────────────────

  List<double> _computeCumulativeDistances() {
    if (_routePoints.isEmpty) return [];
    final out = <double>[0.0];
    for (int i = 1; i < _routePoints.length; i++) {
      final prev = _routePoints[i - 1];
      final curr = _routePoints[i];
      out.add(out.last + Geolocator.distanceBetween(
        prev.latitude, prev.longitude,
        curr.latitude, curr.longitude,
      ));
    }
    return out;
  }

  String _fmtDist(double m) =>
      m < 1000 ? '${m.toStringAsFixed(0)} m' : '${(m / 1000).toStringAsFixed(2)} km';



  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cumDists = _computeCumulativeDistances();
    final polylines = _routePoints.isNotEmpty
        ? {
            Polyline(
              polylineId: const PolylineId('route'),
              points: _routePoints,
              color: AppTheme.primary,
              width: 4,
            )
          }
        : <Polyline>{};

    final markers = _markers
        .map((m) => Marker(
              markerId: MarkerId(m.id),
              position: m.position,
              icon: _typeIcons[m.type] ??
                  BitmapDescriptor.defaultMarkerWithHue(m.type.hue),
              anchor: const Offset(0.5, 0.5),
              infoWindow: InfoWindow(title: m.name, snippet: m.type.label),
            ))
        .toSet();

    final routeDots = _routePoints.asMap().entries.map((e) {
      return Marker(
        markerId: MarkerId('pt_${e.key}'),
        position: e.value,
        icon: _routeDotIcon ??
            BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        anchor: const Offset(0.5, 0.5),
        infoWindow: InfoWindow(
          title: 'Point ${e.key + 1}',
          snippet: cumDists.isNotEmpty
              ? 'From start: ${_fmtDist(cumDists[e.key])}'
              : null,
        ),
        // In marker mode the dot consumes the tap, so forward it manually.
        onTap: _mode == _EditMode.marker ? () => _onMapTap(e.value) : null,
      );
    }).toSet();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Route Editor'),
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2)),
            )
          else
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: ElevatedButton.icon(
                onPressed: _routePoints.length >= 2 ? _save : null,
                icon: const Icon(Icons.save, size: 18),
                label: const Text('Save Route'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppTheme.primary,
                  disabledBackgroundColor: Colors.white38,
                  elevation: 0,
                ),
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // ── Toolbar: mode buttons + undo/clear ──────────────────
              Container(
                color: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    _ModeButton(
                      icon: Icons.route,
                      label: 'Draw Route',
                      active: _mode == _EditMode.route,
                      onTap: () => setState(() => _mode = _EditMode.route),
                    ),
                    const SizedBox(width: 8),
                    _ModeButton(
                      icon: Icons.place_outlined,
                      label: 'Add Marker',
                      active: _mode == _EditMode.marker,
                      onTap: () => setState(() => _mode = _EditMode.marker),
                    ),
                    const SizedBox(width: 8),
                    Tooltip(
                      message: 'Watch tutorial',
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () async {
                          final uri =
                              Uri.parse(AppConfig.drawOnMapTutorialUrl);
                          try {
                            await launchUrl(uri,
                                mode: LaunchMode.externalApplication);
                          } catch (_) {}
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF0000)
                                .withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: const Color(0xFFFF0000)
                                  .withValues(alpha: 0.25),
                            ),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.play_circle_outline_rounded,
                                  size: 16, color: Color(0xFFCC0000)),
                              SizedBox(width: 5),
                              Text('Tutorial',
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFFCC0000))),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${_routePoints.length} pts'
                      '${cumDists.isNotEmpty ? ' · ${_fmtDist(cumDists.last)}' : ''}'
                      ' · ${_markers.length} markers',
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.textSecondary),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.undo),
                      tooltip: 'Undo last',
                      onPressed: (_mode == _EditMode.route &&
                                  _routePoints.isNotEmpty) ||
                              (_mode == _EditMode.marker && _markers.isNotEmpty)
                          ? _undo
                          : null,
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline,
                          color: Colors.redAccent),
                      tooltip: 'Clear all',
                      onPressed:
                          (_routePoints.isNotEmpty || _markers.isNotEmpty)
                              ? _clear
                              : null,
                    ),
                  ],
                ),
              ),

              // ── Search bar ──────────────────────────────────────────
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Search location…',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _searchLoading
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2)),
                          )
                        : null,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                  onSubmitted: _searchLocation,
                  textInputAction: TextInputAction.search,
                ),
              ),

              const Divider(height: 1),

              // ── Instruction banner ──────────────────────────────────
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                color: _mode == _EditMode.route
                    ? AppTheme.primary.withValues(alpha: 0.08)
                    : Colors.orange.withValues(alpha: 0.08),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Icon(
                      _mode == _EditMode.route
                          ? Icons.touch_app
                          : Icons.location_on_outlined,
                      size: 16,
                      color: _mode == _EditMode.route
                          ? AppTheme.primary
                          : Colors.orange,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _mode == _EditMode.route
                          ? 'Tap on the map to add route points. '
                              'Points connect in order.'
                          : 'Tap on the map to place a marker '
                              '(water, restroom, snacks…)',
                      style: TextStyle(
                        fontSize: 12,
                        color: _mode == _EditMode.route
                            ? AppTheme.primary
                            : Colors.orange.shade800,
                      ),
                    ),
                  ],
                ),
              ),

              // ── Map ────────────────────────────────────────────────
              Expanded(
                child: GoogleMap(
                  initialCameraPosition: const CameraPosition(
                    target: LatLng(AppConfig.defaultLat, AppConfig.defaultLng),
                    zoom: 14,
                  ),
                  onMapCreated: (c) => _mapCompleter.complete(c),
                  onTap: _onMapTap,
                  polylines: polylines,
                  markers: {...routeDots, ...markers},
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                  zoomControlsEnabled: true,
                ),
              ),

              // ── Marker legend ───────────────────────────────────────
              if (_markers.isNotEmpty)
                Container(
                  color: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _markers.map((m) {
                        return Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: m.type.color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: m.type.color.withValues(alpha: 0.4)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(m.type.icon, size: 13, color: m.type.color),
                              const SizedBox(width: 4),
                              Text(m.name,
                                  style: TextStyle(
                                      fontSize: 12, color: m.type.color)),
                              const SizedBox(width: 4),
                              GestureDetector(
                                onTap: () => setState(() => _markers.remove(m)),
                                child: Icon(Icons.close,
                                    size: 12, color: m.type.color),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
            ],
          ),

          // ── Loading overlay while KML is being fetched ───────────
          if (_loading)
            const ColoredBox(
              color: Color(0x88FFFFFF),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 12),
                    Text('Loading route…',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Add-marker dialog ─────────────────────────────────────────────────────────
// Separate StatefulWidget so its setState never touches the parent scope,
// which previously caused the "dirty widget in wrong build scope" assertion.

class _AddMarkerDialog extends StatefulWidget {
  const _AddMarkerDialog();

  @override
  State<_AddMarkerDialog> createState() => _AddMarkerDialogState();
}

class _AddMarkerDialogState extends State<_AddMarkerDialog> {
  final _nameCtrl = TextEditingController();
  _MarkerType _selectedType = _MarkerType.water;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Marker'),
      content: SizedBox(
        width: 340,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameCtrl,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Marker Name',
                hintText: 'e.g. Water Station 1',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Type',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _MarkerType.values.map((t) {
                final sel = t == _selectedType;
                return GestureDetector(
                  onTap: () => setState(() => _selectedType = t),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: sel
                          ? t.color.withValues(alpha: 0.15)
                          : Colors.grey.shade100,
                      border: Border.all(
                          color: sel ? t.color : Colors.grey.shade300,
                          width: sel ? 1.5 : 1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(t.icon, size: 14, color: t.color),
                        const SizedBox(width: 4),
                        Text(t.label,
                            style: TextStyle(
                                fontSize: 12,
                                color: sel ? t.color : Colors.grey.shade700,
                                fontWeight:
                                    sel ? FontWeight.w600 : FontWeight.normal)),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          // Pop with no result → caller treats this as cancel
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            final name = _nameCtrl.text.trim().isNotEmpty
                ? _nameCtrl.text.trim()
                : _selectedType.label;
            Navigator.pop(context, _MarkerDialogResult(name, _selectedType));
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}

// ── Mode button ───────────────────────────────────────────────────────────────

class _ModeButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _ModeButton({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active
              ? AppTheme.primary.withValues(alpha: 0.12)
              : Colors.white,
          border: Border.all(
            color: active ? AppTheme.primary : Colors.grey.shade400,
            width: active ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 16,
                color: active ? AppTheme.primary : const Color(0xFF444444)),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                color: active ? AppTheme.primary : const Color(0xFF444444),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
