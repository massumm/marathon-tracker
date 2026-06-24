class UserStats {
  final String uid;
  final String displayName;
  final String email;
  final String photoUrl;
  final double totalDistanceKm;
  final int totalRuns;
  final int totalSeconds;
  final int age;
  // 0 = male, 1 = female, null = not set
  final int? gender;
  final String phone;
  final String categoryId;
  // Daily Challenge (free run) cumulative totals.
  final double dailyDistanceKm;
  final int dailyRuns;
  final int dailySeconds;
  int rank;

  UserStats({
    required this.uid,
    required this.displayName,
    required this.email,
    required this.photoUrl,
    required this.totalDistanceKm,
    required this.totalRuns,
    required this.totalSeconds,
    this.age = 0,
    this.gender,
    this.phone = '',
    this.categoryId = '',
    this.dailyDistanceKm = 0,
    this.dailyRuns = 0,
    this.dailySeconds = 0,
    this.rank = 0,
  });

  factory UserStats.fromMap(String uid, Map<dynamic, dynamic> map) {
    return UserStats(
      uid: uid,
      displayName: map['displayName'] as String? ?? '',
      email: map['email'] as String? ?? '',
      photoUrl: map['photoUrl'] as String? ?? '',
      totalDistanceKm: (map['totalDistanceKm'] as num?)?.toDouble() ?? 0,
      totalRuns: (map['totalRuns'] as num?)?.toInt() ?? 0,
      totalSeconds: (map['totalSeconds'] as num?)?.toInt() ?? 0,
      age: (map['age'] as num?)?.toInt() ?? 0,
      gender: (map['gender'] as num?)?.toInt(),
      phone: map['phone'] as String? ?? '',
      dailyDistanceKm: (map['dcDistanceKm'] as num?)?.toDouble() ?? 0,
      dailyRuns: (map['dcRuns'] as num?)?.toInt() ?? 0,
      dailySeconds: (map['dcSeconds'] as num?)?.toInt() ?? 0,
    );
  }

  String get dailyDistanceStr => '${dailyDistanceKm.toStringAsFixed(2)} km';

  String get label {
    if (displayName.isNotEmpty) return displayName;
    if (email.isNotEmpty) return email.split('@').first;
    return uid.length >= 6 ? uid.substring(0, 6) : uid;
  }

  String get distanceStr => '${totalDistanceKm.toStringAsFixed(2)} km';

  String get timeStr {
    final h = totalSeconds ~/ 3600;
    final m = (totalSeconds % 3600) ~/ 60;
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }

  double get avgPaceKmH =>
      totalSeconds > 0 ? totalDistanceKm / (totalSeconds / 3600) : 0;

  String get avgPaceStr {
    if (avgPaceKmH <= 0) return '-';
    final minPerKm = 60.0 / avgPaceKmH;
    final mins = minPerKm.floor();
    final secs = ((minPerKm - mins) * 60).round();
    return '$mins:${secs.toString().padLeft(2, '0')}/km';
  }

  int get totalSteps => (totalDistanceKm * 1000 / 0.762).round();

  String get stepsStr {
    if (totalSteps >= 1000) {
      return '${(totalSteps / 1000).toStringAsFixed(1)}k';
    }
    return '$totalSteps';
  }

  int get totalCalories => (totalDistanceKm * 65).round();

  String get caloriesStr => '$totalCalories kcal';
}
