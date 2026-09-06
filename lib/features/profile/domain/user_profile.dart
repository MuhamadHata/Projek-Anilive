class UserProfile {
  final String id;
  final String username;
  final String displayName;
  final String? bio;
  final String? avatarUrl;
  final String? bannerUrl;
  final DateTime? birthDate;
  final int followersCount;
  final int followingCount;
  final int animeCompletedCount;
  final DateTime createdAt;

  const UserProfile({
    required this.id,
    required this.username,
    required this.displayName,
    this.bio,
    this.avatarUrl,
    this.bannerUrl,
    this.birthDate,
    this.followersCount = 0,
    this.followingCount = 0,
    this.animeCompletedCount = 0,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'username': username,
    'displayName': displayName,
    'bio': bio,
    'avatarUrl': avatarUrl,
    'bannerUrl': bannerUrl,
    'birthDate': birthDate?.toIso8601String(),
    'followersCount': followersCount,
    'followingCount': followingCount,
    'animeCompletedCount': animeCompletedCount,
    'createdAt': createdAt.toIso8601String(),
  };

  Map<String, dynamic> toSupabaseMap() => {
    'id': id,
    'username': username,
    'display_name': displayName,
    'bio': bio,
    'avatar_url': avatarUrl,
    'banner_url': bannerUrl,
    'birth_date': birthDate?.toIso8601String(),
    'followers_count': followersCount,
    'following_count': followingCount,
    'anime_completed_count': animeCompletedCount,
    'created_at': createdAt.toIso8601String(),
  };

  factory UserProfile.fromMap(Map<String, dynamic> map, String docId) =>
      UserProfile(
        id: docId,
        username: map['username'] ?? 'user',
        displayName: map['displayName'] ?? map['display_name'] ?? map['username'] ?? 'User',
        bio: map['bio'],
        avatarUrl: map['avatarUrl'] ?? map['avatar_url'],
        bannerUrl: map['bannerUrl'] ?? map['banner_url'],
        birthDate: (map['birthDate'] ?? map['birth_date']) != null
            ? DateTime.tryParse((map['birthDate'] ?? map['birth_date']).toString())
            : null,
        followersCount: map['followersCount'] ?? map['followers_count'] ?? 0,
        followingCount: map['followingCount'] ?? map['following_count'] ?? 0,
        animeCompletedCount: map['animeCompletedCount'] ?? map['anime_completed_count'] ?? 0,
        createdAt: (map['createdAt'] ?? map['created_at']) != null
            ? DateTime.tryParse((map['createdAt'] ?? map['created_at']).toString()) ?? DateTime.now()
            : DateTime.now(),
      );

  UserProfile copyWith({
    String? username,
    String? displayName,
    String? bio,
    String? avatarUrl,
    Object? bannerUrl = _sentinel,
    DateTime? birthDate,
    int? followersCount,
    int? followingCount,
    int? animeCompletedCount,
  }) {
    return UserProfile(
      id: id,
      username: username ?? this.username,
      displayName: displayName ?? this.displayName,
      bio: bio ?? this.bio,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      bannerUrl: bannerUrl == _sentinel ? this.bannerUrl : bannerUrl as String?,
      birthDate: birthDate ?? this.birthDate,
      followersCount: followersCount ?? this.followersCount,
      followingCount: followingCount ?? this.followingCount,
      animeCompletedCount: animeCompletedCount ?? this.animeCompletedCount,
      createdAt: createdAt,
    );
  }
}

// Sentinel untuk membedakan bannerUrl null-by-intent vs tidak diubah.
const _sentinel = Object();

class UserFollow {
  final String userId;
  final String targetUserId;
  final DateTime followedAt;

  const UserFollow({
    required this.userId,
    required this.targetUserId,
    required this.followedAt,
  });

  Map<String, dynamic> toMap() => {
    'userId': userId,
    'targetUserId': targetUserId,
    'followedAt': followedAt.toIso8601String(),
  };
}
