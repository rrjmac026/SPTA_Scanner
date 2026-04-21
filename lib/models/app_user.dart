enum UserRole { admin, teacher, pending }

class AppUser {
  final String uid;
  final String name;
  final String email;
  final String photoUrl;
  final UserRole role;
  final DateTime createdAt;

  AppUser({
    required this.uid,
    required this.name,
    required this.email,
    required this.photoUrl,
    required this.role,
    required this.createdAt,
  });

  bool get isAdmin => role == UserRole.admin;
  bool get isTeacher => role == UserRole.teacher;
  bool get isPending => role == UserRole.pending;

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'name': name,
        'email': email,
        'photoUrl': photoUrl,
        'role': role.name,
        'createdAt': createdAt.toIso8601String(),
      };

  factory AppUser.fromMap(Map<String, dynamic> map) => AppUser(
        uid: map['uid'] as String,
        name: map['name'] as String,
        email: map['email'] as String,
        photoUrl: map['photoUrl'] as String? ?? '',
        role: UserRole.values.firstWhere(
          (r) => r.name == map['role'],
          orElse: () => UserRole.pending,
        ),
        createdAt: DateTime.parse(map['createdAt'] as String),
      );

  AppUser copyWith({UserRole? role}) => AppUser(
        uid: uid,
        name: name,
        email: email,
        photoUrl: photoUrl,
        role: role ?? this.role,
        createdAt: createdAt,
      );
}