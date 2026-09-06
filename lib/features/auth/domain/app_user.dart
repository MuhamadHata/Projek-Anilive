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
}
