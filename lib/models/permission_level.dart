enum PermissionLevel {
  user,      // Regular user (default)
  moderator, // Can use moderation commands
  admin,     // Can manage permissions and use all commands
  owner      // Full system access (can't be demoted)
}

extension PermissionLevelExtension on PermissionLevel {
  String get name => toString().split('.').last;
  
  static PermissionLevel fromString(String value) {
    return PermissionLevel.values.firstWhere(
      (e) => e.name == value.toLowerCase(),
      orElse: () => PermissionLevel.user,
    );
  }
}

class UserPermission {
  final String userId;
  final PermissionLevel level;
  final String username;

  UserPermission({
    required this.userId,
    required this.level,
    required this.username,
  });

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'level': level.name,
      'username': username,
    };
  }

  factory UserPermission.fromMap(Map<String, dynamic> map) {
    return UserPermission(
      userId: map['user_id'],
      level: PermissionLevelExtension.fromString(map['level']),
      username: map['username'],
    );
  }
}
