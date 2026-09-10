class AppUser {
  final String id;
  final String email;
  final String username;
  final String? displayName;
  final String? avatarUrl;
  final String? bio;
  final DateTime? birthDate;

  const AppUser({
    required this.id,
    required this.email,
    required this.username,
    this.displayName,
    this.avatarUrl,
    this.bio,
    this.birthDate,
  });

  /// true jika user sudah memverifikasi usia dan berumur ≥ 20 tahun.
  bool get isAdult {
    if (birthDate == null) return false;
    final age = DateTime.now().difference(birthDate!).inDays ~/ 365;
    return age >= 20;
  }

  /// true jika biodata (tanggal lahir) belum pernah diisi.
  bool get needsBiodataSetup => birthDate == null;

  AppUser copyWith({
    String? id,
    String? email,
    String? username,
    String? displayName,
    String? avatarUrl,
    String? bio,
    DateTime? birthDate,
  }) {
    return AppUser(
      id: id ?? this.id,
      email: email ?? this.email,
      username: username ?? this.username,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      bio: bio ?? this.bio,
      birthDate: birthDate ?? this.birthDate,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'username': username,
      'displayName': displayName,
      'avatarUrl': avatarUrl,
      'bio': bio,
      'birthDate': birthDate?.toIso8601String(),
    };
  }

  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      id: map['id'] as String? ?? '',
      email: map['email'] as String? ?? '',
      username: map['username'] as String? ?? '',
      displayName:
          map['displayName'] as String? ?? map['display_name'] as String?,
      avatarUrl:
          map['avatarUrl'] as String? ?? map['avatar_url'] as String?,
      bio: map['bio'] as String?,
      birthDate: (map['birthDate'] ?? map['birth_date']) != null
          ? DateTime.tryParse(
              (map['birthDate'] ?? map['birth_date']).toString())
          : null,
    );
  }
}
