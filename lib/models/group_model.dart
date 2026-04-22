class GroupModel {
  final String id;
  final String eventId;
  final String name;
  final String adminUid;
  final String adminDisplayName;
  final String adminPhotoUrl;
  final int createdAt;
  int memberCount;

  GroupModel({
    required this.id,
    required this.eventId,
    required this.name,
    required this.adminUid,
    required this.adminDisplayName,
    required this.adminPhotoUrl,
    required this.createdAt,
    this.memberCount = 0,
  });

  factory GroupModel.fromMap(String id, Map<dynamic, dynamic> map) {
    return GroupModel(
      id: id,
      eventId: map['eventId'] as String? ?? '',
      name: map['name'] as String? ?? '',
      adminUid: map['adminUid'] as String? ?? '',
      adminDisplayName: map['adminDisplayName'] as String? ?? '',
      adminPhotoUrl: map['adminPhotoUrl'] as String? ?? '',
      createdAt: map['createdAt'] as int? ?? 0,
      memberCount: map['memberCount'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
        'eventId': eventId,
        'name': name,
        'adminUid': adminUid,
        'adminDisplayName': adminDisplayName,
        'adminPhotoUrl': adminPhotoUrl,
        'createdAt': createdAt,
        'memberCount': memberCount,
      };
}

class GroupMemberModel {
  final String uid;
  final String displayName;
  final String photoUrl;
  final String email;
  final int joinedAt;
  final bool isAdmin;

  GroupMemberModel({
    required this.uid,
    required this.displayName,
    required this.photoUrl,
    required this.email,
    required this.joinedAt,
    this.isAdmin = false,
  });

  String get label =>
      displayName.isNotEmpty ? displayName : email.split('@').first;

  factory GroupMemberModel.fromMap(String uid, Map<dynamic, dynamic> map) {
    return GroupMemberModel(
      uid: uid,
      displayName: map['displayName'] as String? ?? '',
      photoUrl: map['photoUrl'] as String? ?? '',
      email: map['email'] as String? ?? '',
      joinedAt: map['joinedAt'] as int? ?? 0,
      isAdmin: map['isAdmin'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
        'displayName': displayName,
        'photoUrl': photoUrl,
        'email': email,
        'joinedAt': joinedAt,
        'isAdmin': isAdmin,
      };
}
