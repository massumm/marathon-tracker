import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

import '../models/user_stats.dart';

class UserStatsService {
  UserStatsService._();
  static final UserStatsService instance = UserStatsService._();

  final _db = FirebaseDatabase.instance;

  /// Write/update profile fields (called on login and after edit).
  Future<void> registerOrUpdate({
    String? displayName,
    String? photoUrl,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await _db.ref('user_stats/${user.uid}').update({
      'displayName': displayName ??
          user.displayName ??
          user.email?.split('@').first ??
          'Runner',
      'email': user.email ?? '',
      'photoUrl': photoUrl ?? user.photoURL ?? '',
    });
  }

  /// Atomically add distance + time after a run is saved.
  Future<void> addRunStats(double distanceKm, int seconds) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await _db.ref('user_stats/${user.uid}').update({
      'totalDistanceKm': ServerValue.increment(distanceKm),
      'totalRuns': ServerValue.increment(1),
      'totalSeconds': ServerValue.increment(seconds),
    });
  }

  /// Stream of current user's own stats.
  Stream<UserStats?> watchMyStats() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const Stream.empty();
    return _db.ref('user_stats/$uid').onValue.map((event) {
      if (!event.snapshot.exists) return null;
      return UserStats.fromMap(
          uid, event.snapshot.value as Map<dynamic, dynamic>);
    });
  }

  /// One-shot fetch for another user's profile.
  Future<UserStats?> getUserStats(String uid) async {
    final snap = await _db.ref('user_stats/$uid').get();
    if (!snap.exists) return null;
    return UserStats.fromMap(
        uid, snap.value as Map<dynamic, dynamic>);
  }

  /// Sorted leaderboard stream (highest distance first).
  Stream<List<UserStats>> watchLeaderboard() {
    return _db
        .ref('user_stats')
        .orderByChild('totalDistanceKm')
        .onValue
        .map((event) {
      final data = event.snapshot.value;
      if (data == null) return <UserStats>[];
      final map = data as Map<dynamic, dynamic>;
      final list = map.entries
          .map((e) => UserStats.fromMap(
              e.key as String, e.value as Map<dynamic, dynamic>))
          .toList()
        ..sort((a, b) => b.totalDistanceKm.compareTo(a.totalDistanceKm));
      for (int i = 0; i < list.length; i++) {
        list[i].rank = i + 1;
      }
      return list;
    });
  }
}
