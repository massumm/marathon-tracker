import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/runner_data.dart';

class LiveTrackingService {
  LiveTrackingService._();
  static final LiveTrackingService instance = LiveTrackingService._();

  static const _root = 'live_runners';

  final _db = FirebaseDatabase.instance;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  DatabaseReference get _myRef => _db.ref('$_root/$_uid');

  /// Start broadcasting — writes initial data and sets onDisconnect cleanup.
  Future<void> startBroadcasting(double lat, double lng,
      {String eventId = '', String categoryId = ''}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final genderSnap =
        await _db.ref('user_stats/${user.uid}/gender').get();
    final gender = (genderSnap.value as num?)?.toInt();

    final data = RunnerData(
      uid: user.uid,
      email: user.email ?? '',
      displayName: user.displayName ?? user.email ?? 'Runner',
      photoUrl: user.photoURL ?? '',
      lat: lat,
      lng: lng,
      startedAt: DateTime.now().millisecondsSinceEpoch,
      eventId: eventId,
      categoryId: categoryId,
      gender: gender,
    ).toMap();

    await _myRef.set(data);
    await _myRef.onDisconnect().remove();
  }

  /// Update location + cumulative distance while broadcasting.
  Future<void> updateLocation(
      double lat, double lng, double distanceKm,
      {bool isVehicle = false}) async {
    await _myRef.update({
      'lat': lat,
      'lng': lng,
      'distanceKm': distanceKm,
      'lastSeen': ServerValue.timestamp,
      'isVehicle': isVehicle,
    });
  }

  /// Stop broadcasting and remove from the list.
  Future<void> stopBroadcasting() async {
    await _myRef.onDisconnect().cancel();
    await _myRef.remove();
  }

  /// Stream of all currently live runners (excluding self).
  Stream<List<RunnerData>> watchRunners() {
    return _db.ref(_root).onValue.map((event) {
      final data = event.snapshot.value;
      if (data == null) return <RunnerData>[];

      final map = data as Map<dynamic, dynamic>;
      return map.entries
          .where((e) => e.key != _uid)
          .map((e) =>
              RunnerData.fromMap(e.key as String, e.value as Map<dynamic, dynamic>))
          .toList();
    });
  }
}
