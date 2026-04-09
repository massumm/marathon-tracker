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
  final String location;
  final String bannerUrl;
  final int createdAt;
  final Map<String, RaceCategory> categories;

  EventModel({
    required this.id,
    required this.name,
    required this.date,
    required this.location,
    required this.bannerUrl,
    required this.createdAt,
    required this.categories,
  });

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
      location: map['location'] as String? ?? '',
      bannerUrl: map['bannerUrl'] as String? ?? '',
      createdAt: (map['createdAt'] as num?)?.toInt() ?? 0,
      categories: cats,
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'date': date,
        'location': location,
        'bannerUrl': bannerUrl,
        'createdAt': createdAt,
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
