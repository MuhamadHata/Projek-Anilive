class ChatMessage {
  final String id;
  final int animeId;
  final String userId;
  final String username;
  final String? avatarUrl;
  final String content;
  final String type; // 'text' | 'image'
  final String? imageUrl;
  final Map<String, List<String>> reactions; // emoji -> list of userIds
  final DateTime createdAt;

  const ChatMessage({
    required this.id,
    required this.animeId,
    required this.userId,
    required this.username,
    this.avatarUrl,
    required this.content,
    this.type = 'text',
    this.imageUrl,
    this.reactions = const {},
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'animeId': animeId,
    'userId': userId,
    'username': username,
    'avatarUrl': avatarUrl,
    'content': content,
    'type': type,
    'imageUrl': imageUrl,
    'reactions': reactions,
    'createdAt': createdAt.toIso8601String(),
  };

  Map<String, dynamic> toSupabaseMap() => {
    'id': id,
    'anime_id': animeId,
    'user_id': userId,
    'username': username,
    'avatar_url': avatarUrl,
    'message': content,
    'created_at': createdAt.toIso8601String(),
  };

  factory ChatMessage.fromMap(Map<String, dynamic> map, String docId) {
    final rawReactions = map['reactions'] as Map<dynamic, dynamic>? ?? {};
    final reactionsMap = <String, List<String>>{};
    rawReactions.forEach((key, val) {
      if (val is List) {
        reactionsMap[key.toString()] = List<String>.from(val);
      }
    });

    return ChatMessage(
      id: docId,
      animeId: map['animeId'] ?? map['anime_id'] ?? 0,
      userId: map['userId'] ?? map['user_id'] ?? '',
      username: map['username'] ?? 'User',
      avatarUrl: map['avatarUrl'] ?? map['avatar_url'],
      content: map['content'] ?? map['message'] ?? '',
      type: map['type'] ?? 'text',
      imageUrl: map['imageUrl'] ?? map['image_url'],
      reactions: reactionsMap,
      createdAt: (map['createdAt'] ?? map['created_at']) != null
          ? DateTime.tryParse((map['createdAt'] ?? map['created_at']).toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

class UserPresence {
  final String userId;
  final String username;
  final bool isOnline;
  final bool isTyping;
  final DateTime lastSeen;

  const UserPresence({
    required this.userId,
    required this.username,
    this.isOnline = false,
    this.isTyping = false,
    required this.lastSeen,
  });

  Map<String, dynamic> toMap() => {
    'userId': userId,
    'username': username,
    'isOnline': isOnline,
    'isTyping': isTyping,
    'lastSeen': lastSeen.toIso8601String(),
  };

  factory UserPresence.fromMap(Map<String, dynamic> map, String docId) =>
      UserPresence(
        userId: docId,
        username: map['username'] ?? 'User',
        isOnline: map['isOnline'] ?? false,
        isTyping: map['isTyping'] ?? false,
        lastSeen: map['lastSeen'] != null
            ? DateTime.tryParse(map['lastSeen'].toString()) ?? DateTime.now()
            : DateTime.now(),
      );
}
