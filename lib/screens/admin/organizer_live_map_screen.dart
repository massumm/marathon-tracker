import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

import '../../../core/theme.dart';
import '../../../models/event_model.dart';
import '../../../models/runner_data.dart';
import '../../../models/user_stats.dart';
import '../../../services/admin_service.dart';
import '../../../services/kml_service.dart';
import '../../../utils/poi_marker_utils.dart';
import '../../../widgets/user_avatar.dart';

// ── Speed tier ────────────────────────────────────────────────────────────────

enum _SpeedTier { normal, medium, fast }

_SpeedTier _tierFromKmh(double kmh) {
  if (kmh >= 40) return _SpeedTier.fast;
  if (kmh >= 20) return _SpeedTier.medium;
  return _SpeedTier.normal;
}

Color _colorForTier(_SpeedTier tier) => switch (tier) {
      _SpeedTier.normal => AppTheme.speedNormal,
      _SpeedTier.medium => AppTheme.speedMedium,
      _SpeedTier.fast => AppTheme.speedFast,
    };

double _haversineM(double lat1, double lng1, double lat2, double lng2) {
  const r = 6371000.0;
  final phi1 = lat1 * math.pi / 180;
  final phi2 = lat2 * math.pi / 180;
  final dPhi = (lat2 - lat1) * math.pi / 180;
  final dLam = (lng2 - lng1) * math.pi / 180;
  final a = math.sin(dPhi / 2) * math.sin(dPhi / 2) +
      math.cos(phi1) * math.cos(phi2) * math.sin(dLam / 2) * math.sin(dLam / 2);
  return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}

/// Live runner map for the Organizer role.
/// Left panel shows a ranked runner list; right panel shows the Google Map
/// with the KML route overlaid and live runner markers.
/// No Scaffold/AppBar — the OrganizerShell owns the top bar.
class OrganizerLiveMapScreen extends StatefulWidget {
  final EventModel event;
  const OrganizerLiveMapScreen({super.key, required this.event});

  @override
  State<OrganizerLiveMapScreen> createState() => _OrganizerLiveMapScreenState();
}

class _OrganizerLiveMapScreenState extends State<OrganizerLiveMapScreen>
    with SingleTickerProviderStateMixin {
  GoogleMapController? _mapController;
  StreamSubscription<List<RunnerData>>? _runnersSub;
  List<RunnerData> _runners = [];
  String? _selectedUid;
  late TabController _tabController;
  Timer? _refreshTimer;
  bool _mapReady = false;

  // KML state
  final Map<String, Set<Polyline>> _kmlPolylineCache = {};
  final Map<String, Set<Marker>> _kmlMarkerCache = {};
  Set<Polyline> _currentPolylines = {};
  Set<Marker> _kmlMarkers = {};
  bool _kmlLoading = false;
  bool _kmlError = false;
  // Stored when _fitCameraToRoute is called before the map controller is ready.
  Set<Polyline>? _pendingFitPolylines;

  // Runner icon cache — keyed by uid so each runner gets a stable icon.
  final Map<String, BitmapDescriptor> _iconCache = {};

  static const int _pageSize = 20;
  int _runnerPage = 0;

  // Live standings / results state
  StreamSubscription<List<UserStats>>? _eventStatsSub;
  List<UserStats> _eventStats = [];
  Set<String> _finishedCats = {};
  bool _ended = false;
  int _genderFilter = 0; // 0=All  1=Male  2=Female

  // Speed tier tracking
  final Map<String, LatLng> _prevRunnerPos = {};
  final Map<String, int> _prevRunnerTime = {};
  final Map<String, _SpeedTier> _runnerTiers = {};

  @override
  void initState() {
    super.initState();
    final catCount = widget.event.categories.length;
    _tabController = TabController(
      length: catCount == 0 ? 1 : catCount,
      vsync: this,
    );
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() { _runnerPage = 0; _genderFilter = 0; });
        _loadKmlForTab(_tabController.index);
      }
    });

    _runnersSub = AdminService.instance
        .watchLiveRunnersForEvent(widget.event.id)
        .listen((runners) {
      if (!mounted) return;
      final wasEmpty = _runners.isEmpty;
      final now = DateTime.now().millisecondsSinceEpoch;
      for (final r in runners) {
        if (r.lat == 0 && r.lng == 0) continue;
        final prev = _prevRunnerPos[r.uid];
        final prevTime = _prevRunnerTime[r.uid];
        if (prev != null && prevTime != null) {
          final dt = (now - prevTime) / 1000.0;
          if (dt > 1) {
            final distM = _haversineM(
                prev.latitude, prev.longitude, r.lat, r.lng);
            final speedKmh = (distM / dt) * 3.6;
            _runnerTiers[r.uid] = _tierFromKmh(speedKmh);
          }
        }
        _prevRunnerPos[r.uid] = LatLng(r.lat, r.lng);
        _prevRunnerTime[r.uid] = now;
      }
      setState(() => _runners = runners);
      _preloadIcons(runners);
      // Auto-center on runners only when we have no KML to anchor the view.
      if (wasEmpty && runners.isNotEmpty && _mapReady && _currentPolylines.isEmpty) {
        _autoCenterOnRunners(runners);
      }
    });

    _eventStatsSub = AdminService.instance
        .watchEventResults(widget.event.id)
        .listen((stats) {
      if (mounted) setState(() => _eventStats = stats);
    });

    _finishedCats = _computeFinishedCats();
    if (widget.event.hasCutoff) {
      _ended = widget.event.cutoffDateTime.isBefore(DateTime.now());
    }

    // Tick every second: refresh online dots, cutoff end, per-category cutoffs.
    _refreshTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (widget.event.hasCutoff && !_ended) {
        if (widget.event.cutoffDateTime.isBefore(DateTime.now())) {
          setState(() => _ended = true);
          return;
        }
      }
      final finishedNow = _computeFinishedCats();
      if (!setEquals(finishedNow, _finishedCats)) {
        setState(() => _finishedCats = finishedNow);
        return;
      }
      setState(() {});
    });

    // Kick off KML load for the first tab after the first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadKmlForTab(0));
  }

  @override
  void dispose() {
    _eventStatsSub?.cancel();
    _runnersSub?.cancel();
    _refreshTimer?.cancel();
    _tabController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  // ── KML ──────────────────────────────────────────────────────────────────────

  Future<void> _loadKmlForTab(int tabIndex) async {
    if (widget.event.categories.isEmpty) return;
    final cats = widget.event.categories.entries.toList();
    if (tabIndex >= cats.length) return;
    final catKey = cats[tabIndex].key;
    final cat = cats[tabIndex].value;

    if (cat.kmlPath.isEmpty && cat.kmlUrl.isEmpty) return;

    // Serve from cache instantly.
    if (_kmlPolylineCache.containsKey(catKey)) {
      setState(() {
        _currentPolylines = _kmlPolylineCache[catKey]!;
        _kmlMarkers = _kmlMarkerCache[catKey] ?? {};
        _kmlError = false;
      });
      _fitCameraToRoute(_currentPolylines);
      return;
    }

    if (_kmlLoading) return;
    setState(() {
      _kmlLoading = true;
      _kmlError = false;
    });

    try {
      String? kmlContent;

      // Primary: Firebase Storage SDK — works on web without CORS issues
      // and handles auth token refresh automatically.
      if (cat.kmlPath.isNotEmpty) {
        final bytes = await AdminService.instance.downloadKml(cat.kmlPath);
        if (bytes != null) kmlContent = utf8.decode(bytes);
      }

      // Fallback: direct download URL (for older events where kmlPath may be absent).
      if (kmlContent == null && cat.kmlUrl.isNotEmpty) {
        final resp = await http
            .get(Uri.parse(cat.kmlUrl))
            .timeout(const Duration(seconds: 15));
        if (resp.statusCode == 200) kmlContent = resp.body;
      }

      if (!mounted) return;

      if (kmlContent != null) {
        final parsed =
            KmlService.instance.parse(kmlContent, polylineColor: AppTheme.primary);
        final customMarkers = await buildCustomPOIMarkers(parsed);
        if (!mounted) return;
        _kmlPolylineCache[catKey] = parsed.polylines;
        _kmlMarkerCache[catKey] = customMarkers;
        setState(() {
          _currentPolylines = parsed.polylines;
          _kmlMarkers = customMarkers;
          _kmlLoading = false;
        });
        _fitCameraToRoute(parsed.polylines);
      } else {
        setState(() {
          _kmlLoading = false;
          _kmlError = true;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _kmlLoading = false;
          _kmlError = true;
        });
      }
    }
  }

  /// Fits the camera to show the full route bounding box.
  /// If the map controller isn't ready yet, stores the polylines so
  /// [onMapCreated] can apply the fit once the map is initialised.
  void _fitCameraToRoute(Set<Polyline> polylines) {
    if (polylines.isEmpty) return;
    if (_mapController == null) {
      _pendingFitPolylines = polylines;
      return;
    }
    _doFit(polylines);
  }

  void _doFit(Set<Polyline> polylines) {
    double minLat = double.infinity;
    double maxLat = -double.infinity;
    double minLng = double.infinity;
    double maxLng = -double.infinity;
    for (final poly in polylines) {
      for (final pt in poly.points) {
        if (pt.latitude < minLat) minLat = pt.latitude;
        if (pt.latitude > maxLat) maxLat = pt.latitude;
        if (pt.longitude < minLng) minLng = pt.longitude;
        if (pt.longitude > maxLng) maxLng = pt.longitude;
      }
    }
    if (minLat.isInfinite) return;
    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        60.0,
      ),
    );
  }

  void _autoCenterOnRunners(List<RunnerData> runners) {
    final valid = runners.where((r) => r.lat != 0 || r.lng != 0).toList();
    if (valid.isEmpty) return;
    final lat = valid.map((r) => r.lat).reduce((a, b) => a + b) / valid.length;
    final lng = valid.map((r) => r.lng).reduce((a, b) => a + b) / valid.length;
    _mapController?.animateCamera(CameraUpdate.newLatLngZoom(LatLng(lat, lng), 14));
  }

  Set<String> _computeFinishedCats() => widget.event.categories.values
      .where((c) => widget.event.isCategoryFinished(c))
      .map((c) => c.id)
      .toSet();

  String _fmtCutoff() {
    final rem = widget.event.cutoffDateTime.difference(DateTime.now());
    if (rem.isNegative) return 'ended';
    final h = rem.inHours;
    final m = rem.inMinutes.remainder(60);
    return h > 0 ? '${h}h ${m}m' : '${m}m';
  }

  // ── Runner icons ─────────────────────────────────────────────────────────────

  /// White border ring + photo clipped to inner circle, or primary-colour
  /// initial fallback. Matches the mobile implementation exactly.
  /// Cache key: `'${uid}_${photoUrl}'` — auto-invalidates when photo changes.
  Future<BitmapDescriptor> _buildRunnerIcon(RunnerData runner) async {
    const double size = 44;
    const double border = 3;
    const double inner = size / 2 - border;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // White border ring
    canvas.drawCircle(const Offset(size / 2, size / 2), size / 2,
        Paint()..color = Colors.white);

    // Clip subsequent drawing to the inner circle
    canvas.save();
    canvas.clipPath(Path()
      ..addOval(Rect.fromCircle(
          center: const Offset(size / 2, size / 2), radius: inner)));

    bool drewPhoto = false;
    if (runner.photoUrl.isNotEmpty) {
      try {
        final resp = await http.get(Uri.parse(runner.photoUrl));
        if (resp.statusCode == 200) {
          final completer = Completer<ui.Image>();
          ui.decodeImageFromList(resp.bodyBytes, completer.complete);
          final img = await completer.future;
          final minSide = img.width < img.height
              ? img.width.toDouble()
              : img.height.toDouble();
          final src = Rect.fromLTWH((img.width - minSide) / 2,
              (img.height - minSide) / 2, minSide, minSide);
          const dst = Rect.fromLTWH(
              border, border, size - 2 * border, size - 2 * border);
          canvas.drawImageRect(img, src, dst, Paint());
          drewPhoto = true;
        }
      } catch (_) {}
    }

    if (!drewPhoto) {
      canvas.drawCircle(const Offset(size / 2, size / 2), inner,
          Paint()..color = AppTheme.primary);
      final initial = runner.displayName.isNotEmpty
          ? runner.displayName[0].toUpperCase()
          : runner.email.isNotEmpty
              ? runner.email[0].toUpperCase()
              : 'R';
      final tp = TextPainter(textDirection: TextDirection.ltr)
        ..text = TextSpan(
            text: initial,
            style: const TextStyle(
                fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white))
        ..layout();
      tp.paint(canvas, Offset((size - tp.width) / 2, (size - tp.height) / 2));
    }

    canvas.restore();

    final img =
        await recorder.endRecording().toImage(size.toInt(), size.toInt());
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(bytes!.buffer.asUint8List());
  }

  /// Fetches and caches icons for runners not yet in [_iconCache].
  /// On network failure builds a photo-less fallback so one broken URL
  /// doesn't block the others. Calls [setState] once all new icons are ready.
  Future<void> _preloadIcons(List<RunnerData> runners) async {
    bool changed = false;
    for (final r in runners) {
      final key = '${r.uid}_${r.photoUrl}';
      if (_iconCache.containsKey(key)) continue;
      try {
        _iconCache[key] = await _buildRunnerIcon(r);
      } catch (_) {
        final noPhoto = RunnerData(
          uid: r.uid, email: r.email, displayName: r.displayName,
          photoUrl: '', lat: r.lat, lng: r.lng,
          startedAt: r.startedAt, distanceKm: r.distanceKm,
          eventId: r.eventId,
        );
        _iconCache[key] = await _buildRunnerIcon(noPhoto);
      }
      changed = true;
    }
    if (changed && mounted) setState(() {});
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  static bool _isOnline(RunnerData r) =>
      DateTime.now().millisecondsSinceEpoch - r.lastSeen < 120000;

  List<RunnerData> get _filteredRunners {
    if (widget.event.categories.isEmpty) return _runners;
    final cats = widget.event.categories.entries.toList();
    final i = _tabController.index.clamp(0, cats.length - 1);
    final catKey = cats[i].key;
    final isFirst = i == 0;
    return _runners.where((r) {
      if (r.categoryId == catKey) return true;
      // Runners who started without selecting a category fall into the first tab,
      // matching the same rule used by the leaderboard screens.
      if (isFirst && r.categoryId.isEmpty) return true;
      return false;
    }).toList();
  }

  Set<Marker> _runnerMarkers(List<RunnerData> runners) {
    final markers = <Marker>{};
    for (int i = 0; i < runners.length; i++) {
      final r = runners[i];
      if (r.lat == 0 && r.lng == 0) continue;
      final selected = r.uid == _selectedUid;
      final online = _isOnline(r);
      final label = r.displayName.isNotEmpty ? r.displayName : r.email.split('@').first;
      markers.add(Marker(
        markerId: MarkerId('runner_${r.uid}'),
        position: LatLng(r.lat, r.lng),
        infoWindow: InfoWindow(
          title: '#${i + 1}  $label',
          snippet:
              '${r.distanceKm.toStringAsFixed(2)} km · ${online ? 'online' : 'offline'}',
        ),
        icon: _iconCache['${r.uid}_${r.photoUrl}'] ??
            (online
                ? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure)
                : BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed)),
        zIndexInt: selected ? 10 : online ? 5 : 1,
        onTap: () => setState(() => _selectedUid = r.uid),
      ));
    }
    return markers;
  }

  void _focusRunner(RunnerData runner) {
    if (runner.lat == 0 && runner.lng == 0) return;
    setState(() => _selectedUid = runner.uid);
    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(LatLng(runner.lat, runner.lng), 16),
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final categoryList = widget.event.categories.entries.toList();
    final filtered = _filteredRunners;
    final onlineCount = filtered.where(_isOnline).length;
    final catIdx = categoryList.isEmpty ? 0 : _tabController.index.clamp(0, categoryList.length - 1);
    final catKey = categoryList.isEmpty ? '' : categoryList[catIdx].key;
    final isCatFinished = _ended || (catKey.isNotEmpty && _finishedCats.contains(catKey));

    return Column(
      children: [
        // Live banner
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration:
                    const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              const Text(
                'LIVE',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.red,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.event.name,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (widget.event.hasCutoff && !_ended) ...[
                Text(
                  'cutoff ${_fmtCutoff()}',
                  style: const TextStyle(
                      fontSize: 11, color: AppTheme.textSecondary),
                ),
                const SizedBox(width: 10),
              ],
              if (_kmlLoading)
                const Padding(
                  padding: EdgeInsets.only(right: 10),
                  child: SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else if (_kmlError)
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: Tooltip(
                    message: 'Route could not be loaded',
                    child: Icon(Icons.route_outlined,
                        size: 15, color: Colors.orange.shade400),
                  ),
                ),
              _StatusChip(label: '$onlineCount online', online: true),
              const SizedBox(width: 8),
              _StatusChip(
                  label: '${filtered.length - onlineCount} offline',
                  online: false),
            ],
          ),
        ),

        // Category tabs
        if (categoryList.isNotEmpty) ...[
          TabBar(
            controller: _tabController,
            isScrollable: categoryList.length > 3,
            labelColor: AppTheme.primary,
            unselectedLabelColor: AppTheme.textSecondary,
            indicatorColor: AppTheme.primary,
            indicatorSize: TabBarIndicatorSize.tab,
            indicator:
                BoxDecoration(color: AppTheme.primary.withValues(alpha: 0.10)),
            tabs: categoryList.map((e) => Tab(text: e.value.label)).toList(),
          ),
        ],

        const Divider(height: 1, thickness: 1),

        // Main body: standings-only when finished, map+panel when live.
        Expanded(
          child: isCatFinished

            // ── Final standings: GoogleMap not loaded ──────────────────────
            ? Container(
                color: Colors.white,
                child: Builder(builder: (context) {
                  final cats = widget.event.categories.entries.toList();
                  final tabIdx = cats.isEmpty
                      ? 0
                      : _tabController.index.clamp(0, cats.length - 1);
                  final catKey = cats.isEmpty ? '' : cats[tabIdx].key;
                  final firstCatId = cats.isNotEmpty ? cats.first.key : null;
                  var results = catKey.isEmpty
                      ? _eventStats
                      : _eventStats.where((s) {
                          if (s.categoryId == catKey) return true;
                          if (s.categoryId.isEmpty && catKey == firstCatId) {
                            return true;
                          }
                          return false;
                        }).toList();
                  if (_genderFilter != 0) {
                    results = results
                        .where((s) => s.gender == _genderFilter - 1)
                        .toList();
                  }
                  for (int i = 0; i < results.length; i++) {
                    results[i].rank = i + 1;
                  }
                  return Column(
                    children: [
                      Container(
                        color: const Color(0xFFF8F9FA),
                        padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.flag_rounded,
                                    size: 14, color: AppTheme.textSecondary),
                                const SizedBox(width: 5),
                                const Text(
                                  'Final Standings',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  '${results.length} finisher${results.length == 1 ? '' : 's'}',
                                  style: const TextStyle(
                                      fontSize: 10,
                                      color: AppTheme.textSecondary),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            _GenderFilterRow(
                              selected: _genderFilter,
                              onChanged: (v) =>
                                  setState(() => _genderFilter = v),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1, thickness: 1),
                      Expanded(
                        child: results.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.leaderboard_outlined,
                                        size: 48,
                                        color: Colors.grey.shade300),
                                    const SizedBox(height: 12),
                                    const Text('No results yet',
                                        style: TextStyle(
                                            fontSize: 14,
                                            color: AppTheme.textSecondary)),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                padding:
                                    const EdgeInsets.fromLTRB(10, 10, 10, 16),
                                itemCount: results.length,
                                itemBuilder: (_, i) => _FinalStandingsTile(
                                  stat: results[i],
                                  tier: _runnerTiers[results[i].uid],
                                ),
                              ),
                      ),
                    ],
                  );
                }),
              )

            // ── Live: map + floating panel ─────────────────────────────────
            : Stack(
                children: [
                  GoogleMap(
                    initialCameraPosition: const CameraPosition(
                      target: LatLng(0, 0),
                      zoom: 2,
                    ),
                    polylines: _currentPolylines,
                    markers: {
                      ..._kmlMarkers,
                      ..._runnerMarkers(filtered),
                    },
                    onMapCreated: (ctrl) {
                      _mapController = ctrl;
                      _mapReady = true;
                      Future.delayed(const Duration(milliseconds: 350), () {
                        if (!mounted) return;
                        final pending = _pendingFitPolylines;
                        if (pending != null && pending.isNotEmpty) {
                          _pendingFitPolylines = null;
                          _doFit(pending);
                        } else if (_currentPolylines.isNotEmpty) {
                          _doFit(_currentPolylines);
                        } else if (_runners.isNotEmpty) {
                          _autoCenterOnRunners(_runners);
                        }
                      });
                    },
                    myLocationButtonEnabled: false,
                    zoomControlsEnabled: true,
                    mapToolbarEnabled: false,
                  ),

                  if (filtered.isEmpty)
                    Positioned(
                      bottom: 24,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.directions_run_outlined,
                                  size: 16, color: Colors.white),
                              SizedBox(width: 8),
                              Text(
                                'No runners broadcasting yet',
                                style:
                                    TextStyle(fontSize: 13, color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                  // ── Floating live panel ─────────────────────────────────
                  Positioned(
                    top: 8,
                    left: 8,
                    bottom: 8,
                    width: 208,
                    child: Container(
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: const Color(0xBB121212),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.08)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.30),
                            blurRadius: 20,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Builder(builder: (context) {
                        var display = filtered.toList();
                        if (_genderFilter != 0) {
                          display = display
                              .where((r) => r.gender == _genderFilter - 1)
                              .toList();
                        }

                        final pageCount =
                            ((display.length - 1) ~/ _pageSize + 1)
                                .clamp(1, 9999);
                        final page = _runnerPage.clamp(0, pageCount - 1);
                        final pageRunners = display
                            .skip(page * _pageSize)
                            .take(_pageSize)
                            .toList();
                        final rankOffset = page * _pageSize;

                        return Column(
                          children: [
                            Container(
                              color: const Color(0xFF1A1A2E),
                              padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.people_outline,
                                          size: 15, color: Colors.white60),
                                      const SizedBox(width: 6),
                                      Text(
                                        '${display.length} runner${display.length == 1 ? '' : 's'}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const Spacer(),
                                      const Text(
                                        'tap to locate',
                                        style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.white60),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  _GenderFilterRow(
                                    selected: _genderFilter,
                                    onChanged: (v) =>
                                        setState(() => _genderFilter = v),
                                    dark: true,
                                  ),
                                ],
                              ),
                            ),
                            const Divider(
                                height: 1,
                                thickness: 1,
                                color: Colors.white12),
                            Expanded(
                              child: display.isEmpty
                                  ? const Center(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.directions_run_outlined,
                                              size: 48, color: Colors.white24),
                                          SizedBox(height: 12),
                                          Text('No runners yet',
                                              style: TextStyle(
                                                  fontSize: 14,
                                                  color: Colors.white60)),
                                        ],
                                      ),
                                    )
                                  : ListView.builder(
                                      padding: const EdgeInsets.fromLTRB(
                                          10, 10, 10, 10),
                                      itemCount: pageRunners.length,
                                      itemBuilder: (_, i) => _MapRunnerTile(
                                        runner: pageRunners[i],
                                        rank: rankOffset + i + 1,
                                        selected: pageRunners[i].uid ==
                                            _selectedUid,
                                        tier: _runnerTiers[pageRunners[i].uid],
                                        onTap: () =>
                                            _focusRunner(pageRunners[i]),
                                      ),
                                    ),
                            ),
                            if (display.length > _pageSize) ...[
                              const Divider(
                                  height: 1,
                                  thickness: 1,
                                  color: Colors.white12),
                              Container(
                                color: const Color(0xFF1A1A2E),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 6),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.chevron_left),
                                      iconSize: 20,
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(
                                          minWidth: 32, minHeight: 32),
                                      color: page > 0
                                          ? AppTheme.primary
                                          : Colors.white24,
                                      onPressed: page > 0
                                          ? () => setState(
                                              () => _runnerPage = page - 1)
                                          : null,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      '${page + 1} / $pageCount',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    IconButton(
                                      icon: const Icon(Icons.chevron_right),
                                      iconSize: 20,
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(
                                          minWidth: 32, minHeight: 32),
                                      color: page < pageCount - 1
                                          ? AppTheme.primary
                                          : Colors.white24,
                                      onPressed: page < pageCount - 1
                                          ? () => setState(
                                              () => _runnerPage = page + 1)
                                          : null,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        );
                      }),
                    ),
                  ),
                ],
              ),
        ),              // Expanded
      ],
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _StatusChip extends StatelessWidget {
  final String label;
  final bool online;
  const _StatusChip({required this.label, required this.online});

  @override
  Widget build(BuildContext context) {
    final color = online ? AppTheme.onlineGreen : Colors.redAccent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }
}

class _MapRunnerTile extends StatelessWidget {
  final RunnerData runner;
  final int rank;
  final bool selected;
  final VoidCallback onTap;
  final _SpeedTier? tier;
  const _MapRunnerTile({
    required this.runner,
    required this.rank,
    required this.selected,
    required this.onTap,
    this.tier,
  });


  static bool _isOnline(RunnerData r) =>
      DateTime.now().millisecondsSinceEpoch - r.lastSeen < 120000;

  String _elapsed() {
    final ms =
        (DateTime.now().millisecondsSinceEpoch - runner.startedAt).clamp(0, 1 << 62);
    final h = ms ~/ 3600000;
    final m = (ms % 3600000) ~/ 60000;
    return h > 0 ? '${h}h ${m}m' : '${m}m';
  }

  @override
  Widget build(BuildContext context) {
    final label = runner.displayName.isNotEmpty
        ? runner.displayName
        : runner.email.split('@').first;
    final online = _isOnline(runner);
    final dotColor = !online
        ? Colors.redAccent
        : _colorForTier(tier ?? _SpeedTier.normal);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.primary.withValues(alpha: 0.20)
              : Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? AppTheme.primary.withValues(alpha: 0.45)
                : Colors.transparent,
          ),
          boxShadow: selected
              ? []
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
        ),
        child: Row(
          children: [
            SizedBox(
              width: 22,
              child: Text(
                '#$rank',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.white60,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(width: 5),
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 7),
            UserAvatar(label: label, photoUrl: runner.photoUrl, size: 32),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    _elapsed(),
                    style: const TextStyle(
                        fontSize: 10, color: Colors.white60),
                  ),
                  if (online && (tier == _SpeedTier.medium || tier == _SpeedTier.fast))
                    Text(
                      tier == _SpeedTier.fast ? 'FAST' : 'MED',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: _colorForTier(tier!),
                        letterSpacing: 0.5,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '${runner.distanceKm.toStringAsFixed(2)} km',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: AppTheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GenderFilterRow extends StatelessWidget {
  final int selected; // 0=All 1=Male 2=Female
  final ValueChanged<int> onChanged;
  final bool dark;
  const _GenderFilterRow({
    required this.selected,
    required this.onChanged,
    this.dark = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _chip(0, 'All'),
        const SizedBox(width: 5),
        _chip(1, 'Male'),
        const SizedBox(width: 5),
        _chip(2, 'Female'),
      ],
    );
  }

  Widget _chip(int value, String label) {
    final active = selected == value;
    return GestureDetector(
      onTap: () => onChanged(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(
          color: active
              ? AppTheme.primary.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active
                ? AppTheme.primary.withValues(alpha: 0.5)
                : dark ? Colors.white30 : Colors.grey.shade300,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            color: active
                ? AppTheme.primary
                : dark ? Colors.white60 : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _FinalStandingsTile extends StatelessWidget {
  final UserStats stat;
  final _SpeedTier? tier;
  const _FinalStandingsTile({required this.stat, this.tier});

  @override
  Widget build(BuildContext context) {
    final rank = stat.rank;
    final label = stat.displayName.isNotEmpty
        ? stat.displayName
        : stat.email.isNotEmpty
            ? stat.email.split('@').first
            : stat.uid.substring(0, 6);
    final medalColor = rank == 1
        ? const Color(0xFFFFD700)
        : rank == 2
            ? const Color(0xFFC0C0C0)
            : rank == 3
                ? const Color(0xFFCD7F32)
                : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 26,
            child: medalColor != null
                ? Icon(Icons.emoji_events_rounded,
                    size: 18, color: medalColor)
                : Text(
                    '#$rank',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textSecondary,
                    ),
                  ),
          ),
          const SizedBox(width: 6),
          UserAvatar(label: label, photoUrl: stat.photoUrl, size: 32),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  stat.timeStr,
                  style: const TextStyle(
                      fontSize: 10, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
          if (tier == _SpeedTier.medium || tier == _SpeedTier.fast) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: _colorForTier(tier!).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: _colorForTier(tier!).withValues(alpha: 0.4)),
              ),
              child: Text(
                tier == _SpeedTier.fast ? 'FAST' : 'MED',
                style: TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.w800,
                  color: _colorForTier(tier!),
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
          const SizedBox(width: 4),
          Text(
            stat.distanceStr,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppTheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}
