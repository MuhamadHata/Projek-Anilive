class AnimeComment {
  final String id;
  final int animeId;
  final String userId;
  final String username;
  final String? avatarUrl;
  final String content;
  final int likeCount;
  final int replyCount;
  final DateTime createdAt;
  final bool isDeleted;

  const AnimeComment({
    required this.id,
    required this.animeId,
    required this.userId,
    required this.username,
    this.avatarUrl,
    required this.content,
    this.likeCount = 0,
    this.replyCount = 0,
    required this.createdAt,
    this.isDeleted = false,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'animeId': animeId,
    'userId': userId,
    'username': username,
    'avatarUrl': avatarUrl,
    'content': content,
    'likeCount': likeCount,
    'replyCount': replyCount,
    'createdAt': createdAt.toIso8601String(),
    'isDeleted': isDeleted,
  };

  factory AnimeComment.fromMap(Map<String, dynamic> map, String docId) =>
      AnimeComment(
        id: docId,
        animeId: map['animeId'] ?? 0,
        userId: map['userId'] ?? '',
        username: map['username'] ?? 'User',
        avatarUrl: map['avatarUrl'],
        content: map['content'] ?? '',
        likeCount: map['likeCount'] ?? 0,
        replyCount: map['replyCount'] ?? 0,
        createdAt: map['createdAt'] != null
            ? DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now()
            : DateTime.now(),
        isDeleted: map['isDeleted'] ?? false,
      );
}
