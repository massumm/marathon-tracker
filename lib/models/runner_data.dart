class RunnerData {
  final String uid;
  final String email;
  final String displayName;
  final String photoUrl;
  final double lat;
  final double lng;
  final int startedAt;

  const RunnerData({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.photoUrl,
    required this.lat,
    required this.lng,
    required this.startedAt,
  });

  factory RunnerData.fromMap(String uid, Map<dynamic, dynamic> map) {
    return RunnerData(
      uid: uid,
      email: map['email'] as String? ?? '',
      displayName: map['displayName'] as String? ?? 'Runner',
      photoUrl: map['photoUrl'] as String? ?? '',
      lat: (map['lat'] as num).toDouble(),
      lng: (map['lng'] as num).toDouble(),
      startedAt: (map['startedAt'] as num?)?.toInt() ??
          DateTime.now().millisecondsSinceEpoch,
    );
  }

  Map<String, dynamic> toMap() => {
        'email': email,
        'displayName': displayName,
        'photoUrl': photoUrl,
        'lat': lat,
        'lng': lng,
        'startedAt': startedAt,
      };
}
