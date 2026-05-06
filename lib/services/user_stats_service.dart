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

  Future<void> updateAge(int age) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await _db.ref('user_stats/${user.uid}').update({'age': age});
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

  /// Sorted leaderboard stream (highest distance first, runs as tiebreaker).
  Stream<List<UserStats>> watchLeaderboard() {
    _db.ref('user_stats').keepSynced(true);
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
        ..sort((a, b) {
          final distCmp = b.totalDistanceKm.compareTo(a.totalDistanceKm);
          if (distCmp != 0) return distCmp;
          return b.totalRuns.compareTo(a.totalRuns);
        });
      for (int i = 0; i < list.length; i++) {
        list[i].rank = i + 1;
      }
      return list;
    });
  }

  /// Friends-only leaderboard — filtered by [friendUids], sorted by distance
  /// then runs. Pass an empty list to get an empty result.
  Stream<List<UserStats>> watchFriendLeaderboard(List<String> friendUids) {
    if (friendUids.isEmpty) return Stream.value([]);
    final allowed = friendUids.toSet();
    return watchLeaderboard().map((all) {
      final filtered =
          all.where((s) => allowed.contains(s.uid)).toList();
      for (int i = 0; i < filtered.length; i++) {
        filtered[i].rank = i + 1;
      }
      return filtered;
    });
  }

  /// Saves per-event best run stats under event_stats/{eventId}/{uid}.
  /// Keeps the best (longest distance) run for the event.
  Future<void> addEventRunStats(
      String eventId, double distanceKm, int seconds) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final ref = _db.ref('event_stats/$eventId/${user.uid}');
    final snap = await ref.get();
    final existing = snap.exists ? snap.value as Map<dynamic, dynamic> : null;
    final prevDist = (existing?['distanceKm'] as num?)?.toDouble() ?? 0.0;
    if (distanceKm >= prevDist) {
      await ref.set({
        'distanceKm': distanceKm,
        'seconds': seconds,
        'displayName': user.displayName ??
            user.email?.split('@').first ??
            'Runner',
        'photoUrl': user.photoURL ?? '',
        'completedAt': ServerValue.timestamp,
      });
    }
  }

  /// Event-specific leaderboard filtered to [memberUids], sorted by distance.
  Stream<List<UserStats>> watchEventLeaderboard(
      String eventId, List<String> memberUids) {
    if (eventId.isEmpty || memberUids.isEmpty) return Stream.value([]);
    final allowed = memberUids.toSet();
    return _db.ref('event_stats/$eventId').onValue.map((event) {
      final data = event.snapshot.value;
      if (data == null) return <UserStats>[];
      final map = data as Map<dynamic, dynamic>;
      final list = map.entries
          .where((e) => allowed.contains(e.key as String))
          .map((e) {
            final m = e.value as Map<dynamic, dynamic>;
            final s = UserStats(
              uid: e.key as String,
              displayName: m['displayName'] as String? ?? '',
              email: '',
              photoUrl: m['photoUrl'] as String? ?? '',
              totalDistanceKm:
                  (m['distanceKm'] as num?)?.toDouble() ?? 0.0,
              totalRuns: 1,
              totalSeconds: (m['seconds'] as num?)?.toInt() ?? 0,
            );
            return s;
          })
          .toList()
        ..sort((a, b) {
          final d = b.totalDistanceKm.compareTo(a.totalDistanceKm);
          return d != 0 ? d : a.totalSeconds.compareTo(b.totalSeconds);
        });
      for (int i = 0; i < list.length; i++) {
        list[i].rank = i + 1;
      }
      return list;
    });
  }
}
