import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

import '../models/comment_model.dart';

class CommentService {
  CommentService._();
  static final CommentService instance = CommentService._();

  final _db = FirebaseDatabase.instance;

  /// Converts a storage path / event id to a safe RTDB key.
  String eventKey(String path) =>
      path.replaceAll(RegExp(r'[.#\$\[\]/]'), '-');

  // ── Watching ──────────────────────────────────────────────────────────────

  Stream<List<CommentModel>> watchComments(String eventId) {
    return _db
        .ref('event_comments/${eventKey(eventId)}')
        .orderByChild('timestamp')
        .onValue
        .map((event) {
      final data = event.snapshot.value;
      if (data == null) return <CommentModel>[];
      final map = data as Map<dynamic, dynamic>;
      final list = map.entries
          .map((e) => CommentModel.fromMap(
              e.key as String, e.value as Map<dynamic, dynamic>))
          .toList()
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
      return list;
    });
  }

  Stream<int> watchCommentCount(String eventId) =>
      watchComments(eventId).map((list) => list.length);

  // ── Comments ──────────────────────────────────────────────────────────────

  Future<void> addComment(String eventId, String text) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || text.trim().isEmpty) return;
    final ref =
        _db.ref('event_comments/${eventKey(eventId)}').push();
    await ref.set({
      'uid': user.uid,
      'email': user.email ?? '',
      'displayName': user.displayName ??
          user.email?.split('@').first ??
          'Runner',
      'photoUrl': user.photoURL ?? '',
      'text': text.trim(),
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> deleteComment(String eventId, String commentId) async {
    await _db
        .ref('event_comments/${eventKey(eventId)}/$commentId')
        .remove();
  }

  // ── Likes ─────────────────────────────────────────────────────────────────

  Future<void> toggleLike(String eventId, String commentId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final ref = _db.ref(
        'event_comments/${eventKey(eventId)}/$commentId/likes/${user.uid}');
    final snap = await ref.get();
    if (snap.exists) {
      await ref.remove();
    } else {
      await ref.set(true);
    }
  }

  // ── Replies ───────────────────────────────────────────────────────────────

  Future<void> addReply(
      String eventId, String commentId, String text) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || text.trim().isEmpty) return;
    final ref = _db
        .ref('event_comments/${eventKey(eventId)}/$commentId/replies')
        .push();
    await ref.set({
      'uid': user.uid,
      'displayName': user.displayName ??
          user.email?.split('@').first ??
          'Runner',
      'photoUrl': user.photoURL ?? '',
      'text': text.trim(),
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> deleteReply(
      String eventId, String commentId, String replyId) async {
    await _db
        .ref(
            'event_comments/${eventKey(eventId)}/$commentId/replies/$replyId')
        .remove();
  }

  // ── Group comments (group_comments/{groupId}) ─────────────────────────────

  Stream<List<CommentModel>> watchGroupComments(String groupId) {
    return _db
        .ref('group_comments/$groupId')
        .orderByChild('timestamp')
        .onValue
        .map((event) {
      final data = event.snapshot.value;
      if (data == null) return <CommentModel>[];
      final map = data as Map<dynamic, dynamic>;
      final list = map.entries
          .map((e) => CommentModel.fromMap(
              e.key as String, e.value as Map<dynamic, dynamic>))
          .toList()
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
      return list;
    });
  }

  Future<void> addGroupComment(String groupId, String text) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || text.trim().isEmpty) return;
    final ref = _db.ref('group_comments/$groupId').push();
    await ref.set({
      'uid': user.uid,
      'email': user.email ?? '',
      'displayName': user.displayName ??
          user.email?.split('@').first ??
          'Runner',
      'photoUrl': user.photoURL ?? '',
      'text': text.trim(),
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> deleteGroupComment(String groupId, String commentId) async {
    await _db.ref('group_comments/$groupId/$commentId').remove();
  }

  Future<void> toggleGroupLike(String groupId, String commentId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final ref =
        _db.ref('group_comments/$groupId/$commentId/likes/${user.uid}');
    final snap = await ref.get();
    if (snap.exists) {
      await ref.remove();
    } else {
      await ref.set(true);
    }
  }

  Future<void> addGroupReply(
      String groupId, String commentId, String text) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || text.trim().isEmpty) return;
    final ref =
        _db.ref('group_comments/$groupId/$commentId/replies').push();
    await ref.set({
      'uid': user.uid,
      'displayName': user.displayName ??
          user.email?.split('@').first ??
          'Runner',
      'photoUrl': user.photoURL ?? '',
      'text': text.trim(),
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> deleteGroupReply(
      String groupId, String commentId, String replyId) async {
    await _db
        .ref('group_comments/$groupId/$commentId/replies/$replyId')
        .remove();
  }
}
