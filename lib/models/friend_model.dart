class FriendModel {
  final String uid;
  final String email;
  final String displayName;
  final int since;
  bool isRunning;

  FriendModel({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.since,
    this.isRunning = false,
  });

  factory FriendModel.fromMap(String uid, Map<dynamic, dynamic> map) {
    return FriendModel(
      uid: uid,
      email: map['email'] as String? ?? '',
      displayName: map['displayName'] as String? ?? '',
      since: (map['since'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
        'email': email,
        'displayName': displayName,
        'since': since,
      };

  String get label =>
      displayName.isNotEmpty ? displayName : email.split('@').first;
}

class FriendRequestModel {
  final String fromUid;
  final String email;
  final String displayName;
  final int sentAt;

  const FriendRequestModel({
    required this.fromUid,
    required this.email,
    required this.displayName,
    required this.sentAt,
  });

  factory FriendRequestModel.fromMap(String fromUid, Map<dynamic, dynamic> map) {
    return FriendRequestModel(
      fromUid: fromUid,
      email: map['email'] as String? ?? '',
      displayName: map['displayName'] as String? ?? '',
      sentAt: (map['sentAt'] as num?)?.toInt() ?? 0,
    );
  }

  String get label =>
      displayName.isNotEmpty ? displayName : email.split('@').first;
}
