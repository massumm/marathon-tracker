class UserStats {
  final String uid;
  final String displayName;
  final String email;
  final String photoUrl;
  final double totalDistanceKm;
  final int totalRuns;
  final int totalSeconds;
  int rank;

  UserStats({
    required this.uid,
    required this.displayName,
    required this.email,
    required this.photoUrl,
    required this.totalDistanceKm,
    required this.totalRuns,
    required this.totalSeconds,
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
    );
  }

  String get label =>
      displayName.isNotEmpty ? displayName : email.split('@').first;

  String get distanceStr => '${totalDistanceKm.toStringAsFixed(2)} km';

  String get timeStr {
    final h = totalSeconds ~/ 3600;
    final m = (totalSeconds % 3600) ~/ 60;
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }

  double get avgPaceKmH =>
      totalSeconds > 0 ? totalDistanceKm / (totalSeconds / 3600) : 0;

  String get avgPaceStr => avgPaceKmH > 0
      ? '${avgPaceKmH.toStringAsFixed(1)} km/h'
      : '-';
}
