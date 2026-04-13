import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

import '../models/friend_model.dart';

class FriendsService {
  FriendsService._();
  static final FriendsService instance = FriendsService._();

  final _db = FirebaseDatabase.instance;
  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  // ── User profile ──────────────────────────────────────────────────────────

  /// Write/update current user's public profile so others can search them.
  Future<void> registerProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final displayName = user.displayName ?? '';
    await _db.ref('users/${user.uid}').set({
      'email': user.email ?? '',
      'displayName': displayName,
      'displayNameLower': displayName.toLowerCase(),
    });
  }

  /// Partial prefix search on email AND displayName. Returns up to 10 results.
  Future<List<Map<String, dynamic>>> searchByQuery(String query) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return [];

    // Run both queries in parallel
    final results = await Future.wait([
      _db
          .ref('users')
          .orderByChild('email')
          .startAt(q)
          .endAt('$q\uf8ff')
          .limitToFirst(10)
          .get(),
      _db
          .ref('users')
          .orderByChild('displayNameLower')
          .startAt(q)
          .endAt('$q\uf8ff')
          .limitToFirst(10)
          .get(),
    ]);

    final seen = <String>{};
    final list = <Map<String, dynamic>>[];

    for (final snap in results) {
      if (!snap.exists) continue;
      final map = snap.value as Map<dynamic, dynamic>;
      for (final entry in map.entries) {
        final uid = entry.key as String;
        if (seen.contains(uid)) continue;
        seen.add(uid);
        final data = entry.value as Map<dynamic, dynamic>;
        list.add({
          'uid': uid,
          'email': data['email'] as String? ?? '',
          'displayName': data['displayName'] as String? ?? '',
        });
      }
    }
    return list;
  }

  // ── Friend requests ───────────────────────────────────────────────────────

  Future<void> sendRequest(
      String targetUid, String targetEmail, String targetDisplayName) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _uid == null) return;
    await _db.ref('friend_requests/$targetUid/$_uid').set({
      'email': user.email ?? '',
      'displayName': user.displayName ?? user.email ?? '',
      'photoUrl': user.photoURL ?? '',
      'sentAt': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> acceptRequest(
      String fromUid, String fromEmail, String fromDisplayName) async {
    final uid = _uid;
    final user = FirebaseAuth.instance.currentUser;
    if (uid == null || user == null) return;
    final now = DateTime.now().millisecondsSinceEpoch;

    // Write both sides of the friendship
    await _db.ref('friends/$uid/$fromUid').set({
      'email': fromEmail,
      'displayName': fromDisplayName,
      'photoUrl': '',
      'since': now,
    });
    await _db.ref('friends/$fromUid/$uid').set({
      'email': user.email ?? '',
      'displayName': user.displayName ?? user.email ?? '',
      'photoUrl': user.photoURL ?? '',
      'since': now,
    });

    // Remove the request
    await _db.ref('friend_requests/$uid/$fromUid').remove();
  }

  Future<void> rejectRequest(String fromUid) async {
    if (_uid == null) return;
    await _db.ref('friend_requests/$_uid/$fromUid').remove();
  }

  Future<void> removeFriend(String friendUid) async {
    final uid = _uid;
    if (uid == null) return;
    await _db.ref('friends/$uid/$friendUid').remove();
    await _db.ref('friends/$friendUid/$uid').remove();
  }

  // ── Status checks ─────────────────────────────────────────────────────────

  Future<bool> isFriend(String targetUid) async {
    if (_uid == null) return false;
    final snap = await _db.ref('friends/$_uid/$targetUid').get();
    return snap.exists;
  }

  Future<bool> requestSent(String targetUid) async {
    if (_uid == null) return false;
    final snap = await _db.ref('friend_requests/$targetUid/$_uid').get();
    return snap.exists;
  }

  // ── Streams ───────────────────────────────────────────────────────────────

  Stream<List<FriendModel>> watchFriends() {
    print("watchFriends: $_uid");
    if (_uid == null) return const Stream.empty();

    return _db.ref('friends/$_uid').onValue.map((event) {
      final data = event.snapshot.value;
      if (data == null) return <FriendModel>[];
      final map = data as Map<dynamic, dynamic>;
      return map.entries
          .map((e) => FriendModel.fromMap(
              e.key as String, e.value as Map<dynamic, dynamic>))
          .toList();
    });
  }

  Stream<List<FriendRequestModel>> watchRequests() {
    if (_uid == null) return const Stream.empty();
    return _db.ref('friend_requests/$_uid').onValue.map((event) {
      final data = event.snapshot.value;
      if (data == null) return <FriendRequestModel>[];
      final map = data as Map<dynamic, dynamic>;
      return map.entries
          .map((e) => FriendRequestModel.fromMap(
              e.key as String, e.value as Map<dynamic, dynamic>))
          .toList();
    });
  }

  /// One-shot fetch of friend UIDs (used by KML map to filter live runners).
  Future<List<String>> getFriendUids() async {
    if (_uid == null) return [];
    final snap = await _db.ref('friends/$_uid').get();
    if (!snap.exists) return [];
    final map = snap.value as Map<dynamic, dynamic>;
    return map.keys.cast<String>().toList();
  }

  /// Live stream of friend UIDs (including self so current user appears in leaderboard).
  Stream<List<String>> watchFriendUids() {
    final uid = _uid;
    if (uid == null) return const Stream.empty();
    return _db.ref('friends/$uid').onValue.map((event) {
      final data = event.snapshot.value;
      final uids = <String>[uid]; // always include self
      if (data is Map) uids.addAll(data.keys.cast<String>());
      return uids;
    });
  }
}
