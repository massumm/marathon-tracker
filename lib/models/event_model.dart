class RaceCategory {
  final String id;
  final String label;
  final String cutoff;
  final String kmlPath;
  final String kmlUrl;

  const RaceCategory({
    required this.id,
    required this.label,
    required this.cutoff,
    required this.kmlPath,
    required this.kmlUrl,
  });

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
  final String startTime; // 'HH:mm', e.g. '08:00' — empty for legacy events
  final String location;
  final String bannerUrl;
  final int createdAt;
  final Map<String, RaceCategory> categories;
  final String organizerUid;
  final String registrationStartDate; // 'yyyy-MM-dd', empty if no registration
  final String registrationEndDate;   // 'yyyy-MM-dd', empty if no registration
  final String registrationUrl;       // target URL, empty if no registration

  EventModel({
    required this.id,
    required this.name,
    required this.date,
    this.startTime = '',
    required this.location,
    required this.bannerUrl,
    required this.createdAt,
    required this.categories,
    this.organizerUid = '',
    this.registrationStartDate = '',
    this.registrationEndDate = '',
    this.registrationUrl = '',
  });

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

  /// True when the event date is strictly before today (event has passed).
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
      return eventDate.isBefore(today);
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
      location: map['location'] as String? ?? '',
      bannerUrl: map['bannerUrl'] as String? ?? '',
      createdAt: (map['createdAt'] as num?)?.toInt() ?? 0,
      categories: cats,
      organizerUid: map['organizerUid'] as String? ?? '',
      registrationStartDate: map['registrationStartDate'] as String? ?? '',
      registrationEndDate: map['registrationEndDate'] as String? ?? '',
      registrationUrl: map['registrationUrl'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'date': date,
        'startTime': startTime,
        'location': location,
        'bannerUrl': bannerUrl,
        'createdAt': createdAt,
        'organizerUid': organizerUid,
        'registrationStartDate': registrationStartDate,
        'registrationEndDate': registrationEndDate,
        'registrationUrl': registrationUrl,
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
