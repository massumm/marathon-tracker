enum AdminRole { superAdmin, organizer }

class AdminUser {
  final String uid;
  final String email;
  final String displayName;
  final AdminRole role;
  final int createdAt;

  const AdminUser({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.role,
    required this.createdAt,
  });

  factory AdminUser.fromMap(String uid, Map<dynamic, dynamic> map) {
    return AdminUser(
      uid: uid,
      email: map['email'] as String? ?? '',
      displayName: map['displayName'] as String? ?? '',
      role: (map['role'] as String?) == 'super_admin'
          ? AdminRole.superAdmin
          : AdminRole.organizer,
      createdAt: map['createdAt'] is num
          ? (map['createdAt'] as num).toInt()
          : int.tryParse(map['createdAt']?.toString() ?? '') ?? 0,
    );
  }

  bool get isSuperAdmin => role == AdminRole.superAdmin;

  AdminUser copyWith({String? displayName}) => AdminUser(
        uid: uid,
        email: email,
        displayName: displayName ?? this.displayName,
        role: role,
        createdAt: createdAt,
      );
}
