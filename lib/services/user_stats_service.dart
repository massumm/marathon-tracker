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
    final resolvedName = displayName ?? user.displayName;
    final data = <String, dynamic>{
      'email': user.email ?? '',
      'photoUrl': photoUrl ?? user.photoURL ?? '',
    };
    // Only write displayName when we have a real value — never fall back to
    // the email prefix, which would silently overwrite the stored username.
    if (resolvedName != null && resolvedName.isNotEmpty) {
      data['displayName'] = resolvedName;
    }
    await _db.ref('user_stats/${user.uid}').update(data);
  }

  Future<void> updateAge(int age) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await _db.ref('user_stats/${user.uid}').update({'age': age});
  }

  /// Atomically add distance + time after a run is saved.
  /// [runId] is used to persist a local backup before the RTDB write so that
  /// stats can be replayed if the process is killed before RTDB flushes to disk.
  Future<void> addRunStats(double distanceKm, int seconds,
      {required String runId, String eventId = ''}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // await OfflineStorageService.instance.savePendingStat(
    //   runId: runId,
    //   uid: user.uid,
    //   distanceKm: distanceKm,
    //   seconds: seconds,
    //   eventId: eventId,
    // );

    await _db.ref('user_stats/${user.uid}').update({
      'totalDistanceKm': ServerValue.increment(distanceKm),
      'totalRuns': ServerValue.increment(1),
      'totalSeconds': ServerValue.increment(seconds),
    });

    if (eventId.isNotEmpty) {
      await addEventRunStats(eventId, distanceKm, seconds);
    }

    // await OfflineStorageService.instance.markStatConfirmed(runId);
  }

  /// Replays any unconfirmed pending stats (those whose RTDB write may have
  /// been lost when the process was killed offline). Called on startup.
  // Future<void> syncPendingStats() async {
  //   final pending = await OfflineStorageService.instance.getUnconfirmedStats();
  //   for (final entry in pending) {
  //     final uid = entry['uid'] as String? ?? '';
  //     final distanceKm = (entry['distanceKm'] as num?)?.toDouble() ?? 0.0;
  //     final seconds = (entry['seconds'] as num?)?.toInt() ?? 0;
  //     final eventId = entry['eventId'] as String? ?? '';
  //     final runId = entry['runId'] as String? ?? '';
  //     if (uid.isEmpty || runId.isEmpty) continue;

  //     await _db.ref('user_stats/$uid').update({
  //       'totalDistanceKm': ServerValue.increment(distanceKm),
  //       'totalRuns': ServerValue.increment(1),
  //       'totalSeconds': ServerValue.increment(seconds),
  //     });
  //     await OfflineStorageService.instance.markStatConfirmed(runId);

  //     if (eventId.isNotEmpty) {
  //       await addEventRunStats(eventId, distanceKm, seconds);
  //     }
  //   }
  //   await OfflineStorageService.instance.pruneConfirmedStats();
  // }

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
    return UserStats.fromMap(uid, snap.value as Map<dynamic, dynamic>);
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
      final filtered = all.where((s) => allowed.contains(s.uid)).toList();
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

    // .get() requires a live connection — gracefully skip the comparison
    // if offline. RTDB persistence will queue the .set() and sync later.
    try {
      final snap = await ref.get();
      final existing = snap.exists ? snap.value as Map<dynamic, dynamic> : null;
      final prevDist = (existing?['distanceKm'] as num?)?.toDouble() ?? 0.0;
      if (distanceKm < prevDist) return; // previous run was longer — keep it
    } catch (_) {
      // Network unavailable — fall through and write; RTDB will reconcile.
    }

    await ref.set({
      'distanceKm': distanceKm,
      'seconds': seconds,
      'displayName': user.displayName ?? 'Runner',
      'photoUrl': user.photoURL ?? '',
      'completedAt': ServerValue.timestamp,
    });
  }

  /// Event-specific leaderboard filtered to [memberUids], sorted by distance.
  /// Cross-references user_stats so display names are always resolved.
  Stream<List<UserStats>> watchEventLeaderboard(
      String eventId, List<String> memberUids) {
    if (eventId.isEmpty || memberUids.isEmpty) return Stream.value([]);
    final allowed = memberUids.toSet();
    return _db.ref('event_stats/$eventId').onValue.asyncMap((event) async {
      final data = event.snapshot.value;
      if (data == null) return <UserStats>[];
      final map = data as Map<dynamic, dynamic>;

      final statsSnap = await _db.ref('user_stats').get();
      final statsMap = statsSnap.exists
          ? statsSnap.value as Map<dynamic, dynamic>
          : <dynamic, dynamic>{};

      final list =
          map.entries.where((e) => allowed.contains(e.key as String)).map((e) {
        final uid = e.key as String;
        final m = e.value as Map<dynamic, dynamic>;
        final userStats = statsMap[uid];
        final profileName = userStats is Map
            ? (userStats['displayName'] as String? ?? '')
            : '';
        final runName = m['displayName'] as String? ?? '';
        // Prefer user_stats (authoritative, always up-to-date) over the name
        // snapshot embedded in the run record (may be stale or an email prefix).
        final resolvedName = profileName.isNotEmpty ? profileName : runName;
        final resolvedEmail =
            userStats is Map ? (userStats['email'] as String? ?? '') : '';
        final storedPhoto = m['photoUrl'] as String? ?? '';
        final resolvedPhoto = storedPhoto.isNotEmpty
            ? storedPhoto
            : (userStats is Map
                ? (userStats['photoUrl'] as String? ?? '')
                : '');
        return UserStats(
          uid: uid,
          displayName: resolvedName,
          email: resolvedEmail,
          photoUrl: resolvedPhoto,
          totalDistanceKm: (m['distanceKm'] as num?)?.toDouble() ?? 0.0,
          totalRuns: 1,
          totalSeconds: (m['seconds'] as num?)?.toInt() ?? 0,
        );
      }).toList()
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
