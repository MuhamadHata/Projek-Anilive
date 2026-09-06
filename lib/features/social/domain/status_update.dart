class StatusUpdate {
  final String id;
  final String userId;
  final String username;
  final String? avatarUrl;
  final int animeId;
  final String animeTitle;
  final String animeCoverUrl;
  final String watchStatus; // 'completed' | 'watching' | 'planned'
  final double? rating;
  final String caption;
  final int likeCount;
  final int commentCount;
  final List<String> likedBy;
  final DateTime createdAt;

  const StatusUpdate({
    required this.id,
    required this.userId,
    required this.username,
    this.avatarUrl,
    required this.animeId,
    required this.animeTitle,
    required this.animeCoverUrl,
    required this.watchStatus,
    this.rating,
    this.caption = '',
    this.likeCount = 0,
    this.commentCount = 0,
    this.likedBy = const [],
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'userId': userId,
        'username': username,
        'avatarUrl': avatarUrl,
        'animeId': animeId,
        'animeTitle': animeTitle,
        'animeCoverUrl': animeCoverUrl,
        'watchStatus': watchStatus,
        'rating': rating,
        'caption': caption,
        'likeCount': likeCount,
        'commentCount': commentCount,
        'likedBy': likedBy,
        'createdAt': createdAt.toIso8601String(),
      };

  Map<String, dynamic> toSupabaseMap() => {
        'id': id,
        'user_id': userId,
        'username': username,
        'avatar_url': avatarUrl,
        'anime_id': animeId,
        'anime_title': animeTitle,
        'anime_cover_url': animeCoverUrl,
        'watch_status': watchStatus,
        'rating': rating,
        'caption': caption,
        'like_count': likeCount,
        'comment_count': commentCount,
        'liked_by': likedBy,
        'created_at': createdAt.toIso8601String(),
      };

  factory StatusUpdate.fromMap(Map<String, dynamic> map, String docId) {
    final rawLiked = map['likedBy'] ?? map['liked_by'];
    final likedByList = rawLiked is List
        ? rawLiked.map((e) => e.toString()).toList()
        : const <String>[];

    return StatusUpdate(
      id: docId,
      userId: map['userId'] ?? map['user_id'] ?? '',
      username: map['username'] ?? 'User',
      avatarUrl: map['avatarUrl'] ?? map['avatar_url'],
      animeId: (map['animeId'] ?? map['anime_id']) ?? 0,
      animeTitle: map['animeTitle'] ?? map['anime_title'] ?? '',
      animeCoverUrl: map['animeCoverUrl'] ?? map['anime_cover_url'] ?? '',
      watchStatus: map['watchStatus'] ?? map['watch_status'] ?? 'completed',
      rating: (map['rating'] as num?)?.toDouble(),
      caption: map['caption'] ?? '',
      likeCount: map['likeCount'] ?? map['like_count'] ?? 0,
      commentCount: map['commentCount'] ?? map['comment_count'] ?? 0,
      likedBy: likedByList,
      createdAt: (map['createdAt'] ?? map['created_at']) != null
          ? DateTime.tryParse((map['createdAt'] ?? map['created_at']).toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  StatusUpdate copyWith({
    String? username,
    String? avatarUrl,
    int? animeId,
    String? animeTitle,
    String? animeCoverUrl,
    String? watchStatus,
    double? rating,
    String? caption,
    int? likeCount,
    int? commentCount,
    List<String>? likedBy,
  }) {
    return StatusUpdate(
      id: id,
      userId: userId,
      username: username ?? this.username,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      animeId: animeId ?? this.animeId,
      animeTitle: animeTitle ?? this.animeTitle,
      animeCoverUrl: animeCoverUrl ?? this.animeCoverUrl,
      watchStatus: watchStatus ?? this.watchStatus,
      rating: rating ?? this.rating,
      caption: caption ?? this.caption,
      likeCount: likeCount ?? this.likeCount,
      commentCount: commentCount ?? this.commentCount,
      likedBy: likedBy ?? this.likedBy,
      createdAt: createdAt,
    );
  }
}

class StatusComment {
  final String id;
  final String statusId;
  final String userId;
  final String username;
  final String? avatarUrl;
  final String content;
  final DateTime createdAt;

  const StatusComment({
    required this.id,
    required this.statusId,
    required this.userId,
    required this.username,
    this.avatarUrl,
    required this.content,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'statusId': statusId,
        'userId': userId,
        'username': username,
        'avatarUrl': avatarUrl,
        'content': content,
        'createdAt': createdAt.toIso8601String(),
      };

  Map<String, dynamic> toSupabaseMap() => {
        'id': id,
        'status_id': statusId,
        'user_id': userId,
        'username': username,
        'avatar_url': avatarUrl,
        'text': content,
        'created_at': createdAt.toIso8601String(),
      };

  factory StatusComment.fromMap(Map<String, dynamic> map, String docId) =>
      StatusComment(
        id: docId,
        statusId: map['statusId'] ?? map['status_id'] ?? '',
        userId: map['userId'] ?? map['user_id'] ?? '',
        username: map['username'] ?? 'User',
        avatarUrl: map['avatarUrl'] ?? map['avatar_url'],
        content: map['content'] ?? map['text'] ?? '',
        createdAt: (map['createdAt'] ?? map['created_at']) != null
            ? DateTime.tryParse((map['createdAt'] ?? map['created_at']).toString()) ?? DateTime.now()
            : DateTime.now(),
      );
}
