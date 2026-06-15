class RaceCategory {
  final String id;
  final String label;
  final String cutoff; // display string, e.g. "03:45" or legacy "90 Minutes"
  final String kmlPath;
  final String kmlUrl;

  const RaceCategory({
    required this.id,
    required this.label,
    required this.cutoff,
    required this.kmlPath,
    required this.kmlUrl,
  });

  /// Total cutoff minutes derived from [cutoff]; 0 = no cutoff.
  int get cutoffMinutes => parseCutoffMinutes(cutoff);

  /// Parses a cutoff display string into total minutes. Accepts "HH:MM",
  /// "HH:MM suffix" ("03:45 Hours") and legacy phrases ("2 Hours 30 Minutes",
  /// "90 Minutes"). Returns 0 when nothing parseable ("No Cut-Off Time").
  static int parseCutoffMinutes(String raw) {
    final s = raw.trim();
    if (s.contains(':')) {
      final parts = s.split(':');
      if (parts.length != 2) return 0;
      final h = int.tryParse(parts[0].trim());
      final m = int.tryParse(parts[1].trim().split(' ').first);
      if (h == null || m == null) return 0;
      return h * 60 + m;
    }
    var total = 0;
    for (final match in RegExp(r'(\d+)\s*(hour|minute)', caseSensitive: false)
        .allMatches(s)) {
      final n = int.parse(match.group(1)!);
      total += match.group(2)!.toLowerCase() == 'hour' ? n * 60 : n;
    }
    return total;
  }

  factory RaceCategory.fromMap(String id, Map<dynamic, dynamic> map) {
    return RaceCategory(
      id: id,
      label: map['label'] as String? ?? '',
      cutoff: map['cutoff'] as String? ?? '',
      kmlPath: map['kmlPath'] as String? ?? '',
      kmlUrl: map['kmlUrl'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'label': label,
        'cutoff': cutoff,
        'kmlPath': kmlPath,
        'kmlUrl': kmlUrl,
      };
}

class EventModel {
  final String id;
  final String name;
  final String date;
  final String startTime;    // 'HH:mm', e.g. '08:00' — empty for legacy events
  final String endTime;      // 'HH:mm', e.g. '17:20' — explicit finish time; takes priority over cutoff calculation
  final int cutoffMinutes;   // 0 = no cutoff; e.g. 300 = 5 h from startTime
  final String location;
  final String bannerUrl;
  final int createdAt;
  final Map<String, RaceCategory> categories;
  final String organizerUid;
  final String registrationStartDate;
  final String registrationEndDate;
  final String registrationUrl;
  final int chipTimeMinutes; // minutes after startTime within which runners may start
  final int graceTimeMinutes; // minutes after finish line before auto-stop (0 = immediate)

  EventModel({
    required this.id,
    required this.name,
    required this.date,
    this.startTime = '',
    this.endTime = '',
    this.cutoffMinutes = 0,
    required this.location,
    required this.bannerUrl,
    required this.createdAt,
    required this.categories,
    this.organizerUid = '',
    this.registrationStartDate = '',
    this.registrationEndDate = '',
    this.registrationUrl = '',
    this.chipTimeMinutes = 10,
    this.graceTimeMinutes = 10,
  });

  bool get hasCutoff => cutoffMinutes > 0 && startTime.isNotEmpty;

  /// True when [cat]'s own cutoff has passed, relative to this event's start.
  /// Always false when the category has no cutoff or the event has no
  /// startTime (mirrors [hasCutoff] — without a start there is no deadline).
  bool isCategoryFinished(RaceCategory cat, {DateTime? now}) {
    if (cat.cutoffMinutes <= 0 || startTime.isEmpty) return false;
    final deadline = eventDateTime.add(Duration(minutes: cat.cutoffMinutes));
    return (now ?? DateTime.now()).isAfter(deadline);
  }

  /// Wall-clock time when the event closes: eventDateTime + cutoffMinutes.
  DateTime get cutoffDateTime =>
      eventDateTime.add(Duration(minutes: cutoffMinutes));

  /// Combines [date] and [startTime] into a full DateTime.
  /// Falls back to end-of-day (23:59) when no time is set.
  DateTime get eventDateTime {
    try {
      final parts = date.split('-');
      if (parts.length != 3) return DateTime(0);
      final y = int.parse(parts[0]);
      final mo = int.parse(parts[1]);
      final d = int.parse(parts[2]);
      if (startTime.isNotEmpty) {
        final tp = startTime.split(':');
        if (tp.length == 2) {
          final h = int.tryParse(tp[0]) ?? 0;
          final m = int.tryParse(tp[1]) ?? 0;
          return DateTime(y, mo, d, h, m);
        }
      }
      return DateTime(y, mo, d, 23, 59);
    } catch (_) {
      return DateTime(0);
    }
  }

  /// True when today falls within the registration window and a URL is set.
  bool get isRegistrationOpen {
    if (registrationUrl.isEmpty ||
        registrationStartDate.isEmpty ||
        registrationEndDate.isEmpty) {
      return false;
    }
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final start = _parseDate(registrationStartDate);
      final end = _parseDate(registrationEndDate);
      if (start == null || end == null) return false;
      return !today.isBefore(start) && !today.isAfter(end);
    } catch (_) {
      return false;
    }
  }

  /// True when a registration URL is set (regardless of date range).
  bool get hasRegistration => registrationUrl.isNotEmpty;

  static DateTime? _parseDate(String s) {
    final parts = s.split('-');
    if (parts.length != 3) return null;
    final y = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final d = int.tryParse(parts[2]);
    if (y == null || m == null || d == null) return null;
    return DateTime(y, m, d);
  }

  /// Wall-clock moment when the whole event is over.
  /// Uses the explicit [endTime] (HH:mm) when set; otherwise falls back to
  /// startTime + the longest cutoff (event-level or per-category).
  DateTime? get finishDateTime {
    if (date.isEmpty) return null;

    // Explicit end time takes priority over cutoff calculation.
    if (endTime.isNotEmpty) {
      try {
        final dp = date.split('-');
        final tp = endTime.split(':');
        if (dp.length == 3 && tp.length == 2) {
          return DateTime(
            int.parse(dp[0]), int.parse(dp[1]), int.parse(dp[2]),
            int.tryParse(tp[0]) ?? 0, int.tryParse(tp[1]) ?? 0,
          );
        }
      } catch (_) {}
    }

    // Fall back to startTime + max cutoff across event-level + all categories.
    // Categories with no cutoff (0 min) are simply skipped — they don't prevent
    // the event from having a finish time derived from the ones that DO have one.
    if (startTime.isNotEmpty) {
      var maxMins = cutoffMinutes;
      for (final c in categories.values) {
        if (c.cutoffMinutes > maxMins) maxMins = c.cutoffMinutes;
      }
      if (maxMins > 0) return eventDateTime.add(Duration(minutes: maxMins));
    }

    // Last resort: end of the event day (23:59). Ensures the timer always fires
    // and the LIVE button flips at midnight even for events with no cutoff/endTime.
    try {
      final dp = date.split('-');
      return DateTime(int.parse(dp[0]), int.parse(dp[1]), int.parse(dp[2]), 23, 59);
    } catch (_) {
      return null;
    }
  }

  /// True while the event is actively underway: after startTime, before finishDateTime.
  bool get isRunning {
    if (isResultsReady) return false;
    final finish = finishDateTime;
    if (finish == null) return false;
    final now = DateTime.now();
    return now.isAfter(eventDateTime) && now.isBefore(finish);
  }

  /// True once final results can be shown: every cutoff has passed, or
  /// failing that, the event date is behind us.
  bool get isResultsReady {
    if (isFinished) return true;
    final finish = finishDateTime;
    return finish != null && DateTime.now().isAfter(finish);
  }

  /// True when the event date is before today, OR when today's event has
  /// passed its finishDateTime (endTime or startTime + max cutoff).
  bool get isFinished {
    try {
      final parts = date.split('-');
      if (parts.length != 3) return false;
      final eventDate = DateTime(
        int.parse(parts[0]),
        int.parse(parts[1]),
        int.parse(parts[2]),
      );
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      if (eventDate.isBefore(today)) return true;
      // Also finished when today's event has passed its computed end time.
      final finish = finishDateTime;
      return finish != null && now.isAfter(finish);
    } catch (_) {
      return false;
    }
  }

  /// True when the event date (yyyy-MM-dd) matches today's local date.
  bool get isToday {
    try {
      final parts = date.split('-');
      if (parts.length != 3) return false;
      final eventDate = DateTime(
        int.parse(parts[0]),
        int.parse(parts[1]),
        int.parse(parts[2]),
      );
      final now = DateTime.now();
      return eventDate.year == now.year &&
          eventDate.month == now.month &&
          eventDate.day == now.day;
    } catch (_) {
      return false;
    }
  }

  factory EventModel.fromMap(String id, Map<dynamic, dynamic> map) {
    final cats = <String, RaceCategory>{};
    final rawCats = map['categories'];
    if (rawCats is Map) {
      for (final e in rawCats.entries) {
        cats[e.key as String] =
            RaceCategory.fromMap(e.key as String, e.value as Map<dynamic, dynamic>);
      }
    }
    return EventModel(
      id: id,
      name: map['name'] as String? ?? '',
      date: map['date'] as String? ?? '',
      startTime: map['startTime'] as String? ?? '',
      endTime: map['endTime'] as String? ?? '',
      cutoffMinutes: (map['cutoffMinutes'] as num?)?.toInt() ?? 0,
      location: map['location'] as String? ?? '',
      bannerUrl: map['bannerUrl'] as String? ?? '',
      createdAt: (map['createdAt'] as num?)?.toInt() ?? 0,
      categories: cats,
      organizerUid: map['organizerUid'] as String? ?? '',
      registrationStartDate: map['registrationStartDate'] as String? ?? '',
      registrationEndDate: map['registrationEndDate'] as String? ?? '',
      registrationUrl: map['registrationUrl'] as String? ?? '',
      chipTimeMinutes: (map['chipTimeMinutes'] as num?)?.toInt() ?? 10,
      graceTimeMinutes: (map['graceTimeMinutes'] as num?)?.toInt() ?? 10,
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'date': date,
        'startTime': startTime,
        if (endTime.isNotEmpty) 'endTime': endTime,
        'cutoffMinutes': cutoffMinutes,
        'location': location,
        'bannerUrl': bannerUrl,
        'createdAt': createdAt,
        'organizerUid': organizerUid,
        'registrationStartDate': registrationStartDate,
        'registrationEndDate': registrationEndDate,
        'registrationUrl': registrationUrl,
        'chipTimeMinutes': chipTimeMinutes,
        'graceTimeMinutes': graceTimeMinutes,
        'categories': {
          for (final e in categories.entries) e.key: e.value.toMap()
        },
      };
}

/// The four fixed race categories with their defaults.
const List<Map<String, String>> kRaceCategories = [
  {
    'id': 'half_marathon',
    'label': '21.1K Half Marathon',
    'cutoff': '03:45 Hours',
  },
  {
    'id': '15k',
    'label': '15K Run',
    'cutoff': '2 Hours 30 Minutes',
  },
  {
    'id': '7_5k',
    'label': '7.5K Celebration Run',
    'cutoff': '90 Minutes',
  },
  {
    'id': '1k',
    'label': '1K Kids Run',
    'cutoff': 'No Cut-Off Time',
  },
];
