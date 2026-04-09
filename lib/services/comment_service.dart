import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

import '../models/comment_model.dart';

class CommentService {
  CommentService._();
  static final CommentService instance = CommentService._();

  final _db = FirebaseDatabase.instance;

  /// Converts a storage path to a safe RTDB key.
  String eventKey(String storagePath) =>
      storagePath.replaceAll(RegExp(r'[.#\$\[\]/]'), '-');

  Stream<List<CommentModel>> watchComments(String storagePath) {
    return _db
        .ref('event_comments/${eventKey(storagePath)}')
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

  Stream<int> watchCommentCount(String storagePath) =>
      watchComments(storagePath).map((list) => list.length);

  Future<void> addComment(String storagePath, String text) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || text.trim().isEmpty) return;
    final ref =
        _db.ref('event_comments/${eventKey(storagePath)}').push();
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

  Future<void> deleteComment(
      String storagePath, String commentId) async {
    await _db
        .ref('event_comments/${eventKey(storagePath)}/$commentId')
        .remove();
  }
}
