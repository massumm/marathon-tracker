import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

import '../models/group_model.dart';

enum JoinResult { ok, alreadyMember, full, notFound, selfAdmin, requestSent }

class GroupService {
  GroupService._();
  static final GroupService instance = GroupService._();

  final _db = FirebaseDatabase.instance;
  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  static const int maxGroupsPerUser = 3;
  static const int maxMembersPerGroup = 20;

  // ── Create ────────────────────────────────────────────────────────────────

  /// Returns the new groupId, or null if the user already owns 3 groups.
  Future<String?> createGroup(String eventId, String name) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    final owned = await ownedGroupsCount();
    if (owned >= maxGroupsPerUser) return null;

    final ref = _db.ref('groups').push();
    final groupId = ref.key!;
    final now = DateTime.now().millisecondsSinceEpoch;

    final group = GroupModel(
      id: groupId,
      eventId: eventId,
      name: name,
      adminUid: user.uid,
      adminDisplayName: user.displayName ?? user.email ?? '',
      adminPhotoUrl: user.photoURL ?? '',
      createdAt: now,
      memberCount: 1,
    );

    final member = GroupMemberModel(
      uid: user.uid,
      displayName: user.displayName ?? '',
      photoUrl: user.photoURL ?? '',
      email: user.email ?? '',
      joinedAt: now,
      isAdmin: true,
    );

    await Future.wait([
      ref.set(group.toMap()),
      _db.ref('group_members/$groupId/${user.uid}').set(member.toMap()),
      _db.ref('event_groups/$eventId/$groupId').set(true),
      _db.ref('user_owned_groups/${user.uid}/$groupId').set(true),
      _db.ref('user_groups/${user.uid}/$groupId').set(true),
    ]);

    return groupId;
  }

  // ── Join ──────────────────────────────────────────────────────────────────

  Future<JoinResult> joinGroup(String groupId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return JoinResult.notFound;

    final groupSnap = await _db.ref('groups/$groupId').get();
    if (!groupSnap.exists) return JoinResult.notFound;

    final groupData = groupSnap.value as Map<dynamic, dynamic>;
    if (groupData['adminUid'] == user.uid) return JoinResult.selfAdmin;

    final memberSnap =
        await _db.ref('group_members/$groupId/${user.uid}').get();
    if (memberSnap.exists) return JoinResult.alreadyMember;

    final count = groupData['memberCount'] as int? ?? 0;
    if (count >= maxMembersPerGroup) return JoinResult.full;

    final now = DateTime.now().millisecondsSinceEpoch;
    final member = GroupMemberModel(
      uid: user.uid,
      displayName: user.displayName ?? '',
      photoUrl: user.photoURL ?? '',
      email: user.email ?? '',
      joinedAt: now,
    );

    await Future.wait([
      _db.ref('group_members/$groupId/${user.uid}').set(member.toMap()),
      _db.ref('groups/$groupId/memberCount').set(count + 1),
      _db.ref('user_groups/${user.uid}/$groupId').set(true),
    ]);

    return JoinResult.ok;
  }

  // ── Join request (scan QR → request, admin accepts/declines) ─────────────

  Future<JoinResult> requestJoin(String groupId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return JoinResult.notFound;

    final groupSnap = await _db.ref('groups/$groupId').get();
    if (!groupSnap.exists) return JoinResult.notFound;

    final groupData = groupSnap.value as Map<dynamic, dynamic>;
    if (groupData['adminUid'] == user.uid) return JoinResult.selfAdmin;

    final memberSnap =
        await _db.ref('group_members/$groupId/${user.uid}').get();
    if (memberSnap.exists) return JoinResult.alreadyMember;

    final count = groupData['memberCount'] as int? ?? 0;
    if (count >= maxMembersPerGroup) return JoinResult.full;

    final now = DateTime.now().millisecondsSinceEpoch;
    final requestData = GroupMemberModel(
      uid: user.uid,
      displayName: user.displayName ?? '',
      photoUrl: user.photoURL ?? '',
      email: user.email ?? '',
      joinedAt: now,
    );

    await _db
        .ref('group_join_requests/$groupId/${user.uid}')
        .set(requestData.toMap());

    return JoinResult.requestSent;
  }

  Future<void> acceptJoinRequest(String groupId, String uid) async {
    final requestSnap =
        await _db.ref('group_join_requests/$groupId/$uid').get();
    if (!requestSnap.exists) return;

    final requestData = requestSnap.value as Map<dynamic, dynamic>;
    final countSnap = await _db.ref('groups/$groupId/memberCount').get();
    final count = countSnap.value as int? ?? 0;
    final nameSnap = await _db.ref('groups/$groupId/name').get();
    final groupName = nameSnap.value as String? ?? '';

    await Future.wait([
      _db.ref('group_members/$groupId/$uid').set(requestData),
      _db.ref('groups/$groupId/memberCount').set(count + 1),
      _db.ref('user_groups/$uid/$groupId').set(true),
      _db.ref('group_join_requests/$groupId/$uid').remove(),
      _db.ref('group_join_responses/$groupId/$uid').set({
        'status': 'accepted',
        'groupName': groupName,
      }),
    ]);
  }

  Future<void> declineJoinRequest(String groupId, String uid) async {
    final nameSnap = await _db.ref('groups/$groupId/name').get();
    final groupName = nameSnap.value as String? ?? '';

    await Future.wait([
      _db.ref('group_join_requests/$groupId/$uid').remove(),
      _db.ref('group_join_responses/$groupId/$uid').set({
        'status': 'declined',
        'groupName': groupName,
      }),
    ]);
  }

  Stream<List<GroupMemberModel>> watchJoinRequests(String groupId) {
    return _db.ref('group_join_requests/$groupId').onValue.map((event) {
      final data = event.snapshot.value;
      if (data == null) return <GroupMemberModel>[];
      final map = data as Map<dynamic, dynamic>;
      return map.entries
          .map((e) => GroupMemberModel.fromMap(
              e.key as String, e.value as Map<dynamic, dynamic>))
          .toList()
        ..sort((a, b) => a.joinedAt.compareTo(b.joinedAt));
    });
  }

  // ── Leave ─────────────────────────────────────────────────────────────────

  Future<void> leaveGroup(String groupId) async {
    final uid = _uid;
    if (uid == null) return;

    final snap = await _db.ref('groups/$groupId/memberCount').get();
    final count = (snap.value as int? ?? 1) - 1;

    await Future.wait([
      _db.ref('group_members/$groupId/$uid').remove(),
      _db.ref('groups/$groupId/memberCount').set(count < 0 ? 0 : count),
      _db.ref('user_groups/$uid/$groupId').remove(),
    ]);
  }

  // ── Remove member (admin only) ────────────────────────────────────────────

  Future<void> removeMember(String groupId, String targetUid) async {
    final snap = await _db.ref('groups/$groupId/memberCount').get();
    final count = (snap.value as int? ?? 1) - 1;

    await Future.wait([
      _db.ref('group_members/$groupId/$targetUid').remove(),
      _db.ref('groups/$groupId/memberCount').set(count < 0 ? 0 : count),
    ]);
  }

  // ── Delete group (admin only) ─────────────────────────────────────────────

  Future<void> deleteGroup(String groupId, String eventId) async {
    final uid = _uid;
    if (uid == null) return;

    await Future.wait([
      _db.ref('groups/$groupId').remove(),
      _db.ref('group_members/$groupId').remove(),
      _db.ref('event_groups/$eventId/$groupId').remove(),
      _db.ref('user_owned_groups/$uid/$groupId').remove(),
      _db.ref('user_groups/$uid/$groupId').remove(),
    ]);
  }

  Future<void> renameGroup(String groupId, String newName) async {
    await _db.ref('groups/$groupId/name').set(newName.trim());
  }

  // ── Queries ───────────────────────────────────────────────────────────────

  Future<int> ownedGroupsCount() async {
    final uid = _uid;
    if (uid == null) return 0;
    final snap = await _db.ref('user_owned_groups/$uid').get();
    if (!snap.exists) return 0;
    return (snap.value as Map<dynamic, dynamic>).length;
  }

  Future<bool> isMember(String groupId) async {
    final uid = _uid;
    if (uid == null) return false;
    final snap = await _db.ref('group_members/$groupId/$uid').get();
    return snap.exists;
  }

  Future<GroupModel?> getGroup(String groupId) async {
    final snap = await _db.ref('groups/$groupId').get();
    if (!snap.exists) return null;
    return GroupModel.fromMap(
        groupId, snap.value as Map<dynamic, dynamic>);
  }

  /// Returns UIDs of all members across all groups the current user belongs to.
  Future<List<String>> getMyGroupMemberUids() async {
    final uid = _uid;
    if (uid == null) return [];
    final snap = await _db.ref('user_groups/$uid').get();
    if (!snap.exists) return [];
    final groupIds =
        (snap.value as Map<dynamic, dynamic>).keys.cast<String>().toList();
    final memberSnaps = await Future.wait(
        groupIds.map((gid) => _db.ref('group_members/$gid').get()));
    final uids = <String>{};
    for (final s in memberSnaps) {
      if (!s.exists) continue;
      uids.addAll(
          (s.value as Map<dynamic, dynamic>).keys.cast<String>());
    }
    uids.remove(uid);
    return uids.toList();
  }

  // ── Streams ───────────────────────────────────────────────────────────────

  /// Only returns groups for [eventId] that the current user is a member of.
  Stream<List<GroupModel>> watchMyGroupsForEvent(String eventId) {
    final uid = _uid;
    if (uid == null) return const Stream.empty();
    return _db.ref('user_groups/$uid').onValue.asyncMap((event) async {
      final data = event.snapshot.value;
      if (data == null) return <GroupModel>[];
      final groupIds =
          (data as Map<dynamic, dynamic>).keys.cast<String>().toList();
      final snaps = await Future.wait(
          groupIds.map((id) => _db.ref('groups/$id').get()));
      return snaps
          .where((s) => s.exists)
          .map((s) =>
              GroupModel.fromMap(s.key!, s.value as Map<dynamic, dynamic>))
          .where((g) => g.eventId == eventId)
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    });
  }

  Stream<List<GroupMemberModel>> watchGroupMembers(String groupId) {
    return _db.ref('group_members/$groupId').onValue.asyncMap((event) async {
      final data = event.snapshot.value;
      if (data == null) return <GroupMemberModel>[];
      final map = data as Map<dynamic, dynamic>;
      final members = map.entries
          .map((e) => GroupMemberModel.fromMap(
              e.key as String, e.value as Map<dynamic, dynamic>))
          .toList()
        ..sort((a, b) {
          if (a.isAdmin) return -1;
          if (b.isAdmin) return 1;
          return a.joinedAt.compareTo(b.joinedAt);
        });

      // Fill missing displayName/photoUrl from user_stats.
      // Also patch the stored record so future reads are correct.
      final enriched = await Future.wait(members.map((m) async {
        if (m.displayName.isNotEmpty && m.photoUrl.isNotEmpty) return m;
        try {
          final snap = await _db.ref('user_stats/${m.uid}').get();
          final stats = snap.value as Map<dynamic, dynamic>?;
          final name = m.displayName.isNotEmpty
              ? m.displayName
              : (stats?['displayName'] as String? ?? '');
          final url = m.photoUrl.isNotEmpty
              ? m.photoUrl
              : (stats?['photoUrl'] as String? ?? '');
          final updates = <String, dynamic>{};
          if (name.isNotEmpty && m.displayName.isEmpty) {
            updates['displayName'] = name;
          }
          if (url.isNotEmpty && m.photoUrl.isEmpty) {
            updates['photoUrl'] = url;
          }
          if (updates.isNotEmpty) {
            await _db
                .ref('group_members/$groupId/${m.uid}')
                .update(updates);
          }
          return GroupMemberModel(
            uid: m.uid,
            displayName: name,
            photoUrl: url,
            email: m.email,
            joinedAt: m.joinedAt,
            isAdmin: m.isAdmin,
          );
        } catch (_) {
          return m;
        }
      }));

      return enriched;
    });
  }

  /// Count of groups the current user is a member of for [eventId].
  Stream<int> watchMyGroupCountForEvent(String eventId) {
    return watchMyGroupsForEvent(eventId).map((list) => list.length);
  }

  /// All groups the current user has joined (across all events).
  Stream<List<GroupModel>> watchAllMyGroups() {
    final uid = _uid;
    if (uid == null) return const Stream.empty();
    return _db.ref('user_groups/$uid').onValue.asyncMap((event) async {
      final data = event.snapshot.value;
      if (data == null) return <GroupModel>[];
      final groupIds =
          (data as Map<dynamic, dynamic>).keys.cast<String>().toList();
      final snaps = await Future.wait(
          groupIds.map((id) => _db.ref('groups/$id').get()));
      return snaps
          .where((s) => s.exists)
          .map((s) =>
              GroupModel.fromMap(s.key!, s.value as Map<dynamic, dynamic>))
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    });
  }
}
