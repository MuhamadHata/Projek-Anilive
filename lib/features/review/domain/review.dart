class ReviewRating {
  final double story;
  final double animation;
  final double sound;
  final double character;
  final double enjoyment;

  const ReviewRating({
    this.story = 8.0,
    this.animation = 8.0,
    this.sound = 8.0,
    this.character = 8.0,
    this.enjoyment = 8.0,
  });

  double get overall =>
      (story + animation + sound + character + enjoyment) / 5.0;

  Map<String, dynamic> toMap() => {
    'story': story,
    'animation': animation,
    'sound': sound,
    'character': character,
    'enjoyment': enjoyment,
  };

  factory ReviewRating.fromMap(Map<String, dynamic> map) => ReviewRating(
    story: (map['story'] as num?)?.toDouble() ?? 8.0,
    animation: (map['animation'] as num?)?.toDouble() ?? 8.0,
    sound: (map['sound'] as num?)?.toDouble() ?? 8.0,
    character: (map['character'] as num?)?.toDouble() ?? 8.0,
    enjoyment: (map['enjoyment'] as num?)?.toDouble() ?? 8.0,
  );
}

class WatchStatus {
  static const watching = 'watching';
  static const completed = 'completed';
  static const onHold = 'on_hold';
  static const dropped = 'dropped';
  static const planToWatch = 'plan_to_watch';
  static const notInterested = 'not_interested';

  static const List<String> all = [
    watching,
    completed,
    onHold,
    dropped,
    planToWatch,
    notInterested,
  ];

  static String label(String value) => switch (value) {
        watching => 'Currently Watching',
        completed => 'Completed',
        onHold => 'On Hold',
        dropped => 'Dropped',
        planToWatch => 'Plan to Watch',
        notInterested => 'Not Interested',
        _ => value,
      };
}

class Review {
  final String id;
  final int animeId;
  final String userId;
  final String username;
  final String? avatarUrl;
  final String? animeTitle;
  final String? animeImageUrl;
  final int? watchedEpisodes;
  final int? totalEpisodes;
  final bool isCompleted;
  final String? watchStatus;
  final ReviewRating ratings;
  final double overallScore;
  final String title;
  final String content;
  final bool isRecommended;
  final bool hasSpoiler;
  final int likeCount;
  final DateTime createdAt;

  const Review({
    required this.id,
    required this.animeId,
    required this.userId,
    required this.username,
    this.avatarUrl,
    this.animeTitle,
    this.animeImageUrl,
    this.watchedEpisodes,
    this.totalEpisodes,
    this.isCompleted = false,
    this.watchStatus,
    required this.ratings,
    required this.overallScore,
    required this.title,
    required this.content,
    required this.isRecommended,
    required this.hasSpoiler,
    this.likeCount = 0,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'animeId': animeId,
    'userId': userId,
    'username': username,
    'avatarUrl': avatarUrl,
    if (animeTitle != null) 'animeTitle': animeTitle,
    if (animeImageUrl != null) 'animeImageUrl': animeImageUrl,
    'watchedEpisodes': watchedEpisodes,
    'totalEpisodes': totalEpisodes,
    'isCompleted': isCompleted,
    if (watchStatus != null) 'watchStatus': watchStatus,
    'ratings': ratings.toMap(),
    'overallScore': overallScore,
    'title': title,
    'content': content,
    'isRecommended': isRecommended,
    'hasSpoiler': hasSpoiler,
    'likeCount': likeCount,
    'createdAt': createdAt.toIso8601String(),
  };

  factory Review.fromMap(Map<String, dynamic> map, String docId) => Review(
    id: docId,
    animeId: map['animeId'] ?? 0,
    userId: map['userId'] ?? '',
    username: map['username'] ?? 'User',
    avatarUrl: map['avatarUrl'],
    animeTitle: map['animeTitle'] as String?,
    animeImageUrl: map['animeImageUrl'] as String?,
    watchedEpisodes: (map['watchedEpisodes'] as num?)?.toInt(),
    totalEpisodes: (map['totalEpisodes'] as num?)?.toInt(),
    isCompleted: map['isCompleted'] == true,
    watchStatus: map['watchStatus'] as String?,
    ratings: ReviewRating.fromMap(
      Map<String, dynamic>.from(map['ratings'] ?? {}),
    ),
    overallScore: (map['overallScore'] as num?)?.toDouble() ?? 0.0,
    title: map['title'] ?? '',
    content: map['content'] ?? '',
    isRecommended: map['isRecommended'] ?? true,
    hasSpoiler: map['hasSpoiler'] ?? false,
    likeCount: map['likeCount'] ?? 0,
    createdAt: map['createdAt'] != null
        ? DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now()
        : DateTime.now(),
  );
}

/// Entri ringkas daftar anime milik satu user (untuk halaman profil).
class UserAnimeEntry {
  final int animeId;
  final String title;
  final String? imageUrl;
  final String? watchStatus;
  final int watchedEpisodes;
  final int? totalEpisodes;
  final bool isCompleted;
  final double overallScore;
  final String reviewId;
  final DateTime updatedAt;

  const UserAnimeEntry({
    required this.animeId,
    required this.title,
    this.imageUrl,
    this.watchStatus,
    this.watchedEpisodes = 0,
    this.totalEpisodes,
    this.isCompleted = false,
    this.overallScore = 0,
    required this.reviewId,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() => {
    'animeId': animeId,
    'title': title,
    'imageUrl': imageUrl,
    'watchStatus': watchStatus,
    'watchedEpisodes': watchedEpisodes,
    'totalEpisodes': totalEpisodes,
    'isCompleted': isCompleted,
    'overallScore': overallScore,
    'reviewId': reviewId,
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory UserAnimeEntry.fromMap(Map<String, dynamic> map) => UserAnimeEntry(
    animeId: (map['animeId'] as num?)?.toInt() ?? 0,
    title: map['title'] ?? '',
    imageUrl: map['imageUrl'] as String?,
    watchStatus: map['watchStatus'] as String?,
    watchedEpisodes: (map['watchedEpisodes'] as num?)?.toInt() ?? 0,
    totalEpisodes: (map['totalEpisodes'] as num?)?.toInt(),
    isCompleted: map['isCompleted'] == true,
    overallScore: (map['overallScore'] as num?)?.toDouble() ?? 0,
    reviewId: map['reviewId'] ?? '',
    updatedAt: map['updatedAt'] != null
        ? DateTime.tryParse(map['updatedAt'].toString()) ?? DateTime.now()
        : DateTime.now(),
  );
}
