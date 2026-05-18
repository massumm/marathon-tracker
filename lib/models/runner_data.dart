class RunnerData {
  final String uid;
  final String email;
  final String displayName;
  final String photoUrl;
  final double lat;
  final double lng;
  final int startedAt;
  final int lastSeen;
  final double distanceKm;
  final String eventId;

  RunnerData({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.photoUrl,
    required this.lat,
    required this.lng,
    required this.startedAt,
    int? lastSeen,
    this.distanceKm = 0.0,
    this.eventId = '',
  }) : lastSeen = lastSeen ?? startedAt;

  factory RunnerData.fromMap(String uid, Map<dynamic, dynamic> map) {
    final startedAt = (map['startedAt'] as num?)?.toInt() ??
        DateTime.now().millisecondsSinceEpoch;
    return RunnerData(
      uid: uid,
      email: map['email'] as String? ?? '',
      displayName: map['displayName'] as String? ?? 'Runner',
      photoUrl: map['photoUrl'] as String? ?? '',
      lat: (map['lat'] as num).toDouble(),
      lng: (map['lng'] as num).toDouble(),
      startedAt: startedAt,
      lastSeen: (map['lastSeen'] as num?)?.toInt() ?? startedAt,
      distanceKm: (map['distanceKm'] as num?)?.toDouble() ?? 0.0,
      eventId: map['eventId'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'email': email,
        'displayName': displayName,
        'photoUrl': photoUrl,
        'lat': lat,
        'lng': lng,
        'startedAt': startedAt,
        'lastSeen': lastSeen,
        'distanceKm': distanceKm,
        'eventId': eventId,
      };
}
