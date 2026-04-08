class CommentModel {
  final String commentId;
  final String uid;
  final String email;
  final String displayName;
  final String text;
  final int timestamp;

  const CommentModel({
    required this.commentId,
    required this.uid,
    required this.email,
    required this.displayName,
    required this.text,
    required this.timestamp,
  });

  factory CommentModel.fromMap(String id, Map<dynamic, dynamic> map) {
    return CommentModel(
      commentId: id,
      uid: map['uid'] as String? ?? '',
      email: map['email'] as String? ?? '',
      displayName: map['displayName'] as String? ?? '',
      text: map['text'] as String? ?? '',
      timestamp: (map['timestamp'] as num?)?.toInt() ?? 0,
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
