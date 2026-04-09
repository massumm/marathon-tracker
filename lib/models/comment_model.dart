class ReplyModel {
  final String replyId;
  final String uid;
  final String displayName;
  final String photoUrl;
  final String text;
  final int timestamp;

  const ReplyModel({
    required this.replyId,
    required this.uid,
    required this.displayName,
    required this.photoUrl,
    required this.text,
    required this.timestamp,
  });

  factory ReplyModel.fromMap(String id, Map<dynamic, dynamic> map) {
    return ReplyModel(
      replyId: id,
      uid: map['uid'] as String? ?? '',
      displayName: map['displayName'] as String? ?? '',
      photoUrl: map['photoUrl'] as String? ?? '',
      text: map['text'] as String? ?? '',
      timestamp: (map['timestamp'] as num?)?.toInt() ?? 0,
    );
  }

  String get label => displayName.isNotEmpty ? displayName : 'Runner';

  String get timeAgo {
    final diff = DateTime.now().millisecondsSinceEpoch - timestamp;
    final secs = diff ~/ 1000;
    if (secs < 60) return '${secs}s';
    final mins = secs ~/ 60;
    if (mins < 60) return '${mins}m';
    final hours = mins ~/ 60;
    if (hours < 24) return '${hours}h';
    return '${hours ~/ 24}d';
  }
}

class CommentModel {
  final String commentId;
  final String uid;
  final String email;
  final String displayName;
  final String photoUrl;
  final String text;
  final int timestamp;
  final Map<String, bool> likes;
  final List<ReplyModel> replies;

  const CommentModel({
    required this.commentId,
    required this.uid,
    required this.email,
    required this.displayName,
    required this.photoUrl,
    required this.text,
    required this.timestamp,
    this.likes = const {},
    this.replies = const [],
  });

  factory CommentModel.fromMap(String id, Map<dynamic, dynamic> map) {
    final likesMap = <String, bool>{};
    final rawLikes = map['likes'];
    if (rawLikes is Map) {
      for (final e in rawLikes.entries) {
        likesMap[e.key as String] = true;
      }
    }

    final repliesList = <ReplyModel>[];
    final rawReplies = map['replies'];
    if (rawReplies is Map) {
      for (final e in rawReplies.entries) {
        if (e.value is Map) {
          repliesList.add(ReplyModel.fromMap(
              e.key as String, e.value as Map<dynamic, dynamic>));
        }
      }
      repliesList.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    }

    return CommentModel(
      commentId: id,
      uid: map['uid'] as String? ?? '',
      email: map['email'] as String? ?? '',
      displayName: map['displayName'] as String? ?? '',
      photoUrl: map['photoUrl'] as String? ?? '',
      text: map['text'] as String? ?? '',
      timestamp: (map['timestamp'] as num?)?.toInt() ?? 0,
      likes: likesMap,
      replies: repliesList,
    );
  }

  String get label =>
      displayName.isNotEmpty ? displayName : email.split('@').first;

  String get timeAgo {
    final diff = DateTime.now().millisecondsSinceEpoch - timestamp;
    final secs = diff ~/ 1000;
    if (secs < 60) return '${secs}s';
    final mins = secs ~/ 60;
    if (mins < 60) return '${mins}m';
    final hours = mins ~/ 60;
    if (hours < 24) return '${hours}h';
    return '${hours ~/ 24}d';
  }
}
