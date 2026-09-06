enum NotificationType {
  love,
  comment,
  friendRequest,
  friendAccepted,
}

class AppNotification {
  final String id;
  final String recipientUserId;
  final String actorId;
  final String actorUsername;
  final String? actorAvatarUrl;
  final NotificationType type;
  final String title;
  final String body;
  final String? referenceId; // statusId, friendshipId, etc.
  final DateTime createdAt;
  final bool isRead;

  const AppNotification({
    required this.id,
    required this.recipientUserId,
    required this.actorId,
    required this.actorUsername,
    this.actorAvatarUrl,
    required this.type,
    required this.title,
    required this.body,
    this.referenceId,
    required this.createdAt,
    this.isRead = false,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'recipientUserId': recipientUserId,
        'actorId': actorId,
        'actorUsername': actorUsername,
        'actorAvatarUrl': actorAvatarUrl,
        'type': type.name,
        'title': title,
        'body': body,
        'referenceId': referenceId,
        'createdAt': createdAt.toIso8601String(),
        'isRead': isRead,
      };

  Map<String, dynamic> toSupabaseMap() => {
        'id': id,
        'recipient_user_id': recipientUserId,
        'actor_id': actorId,
        'actor_username': actorUsername,
        'actor_avatar_url': actorAvatarUrl,
        'type': type.name,
        'title': title,
        'body': body,
        'reference_id': referenceId,
        'is_read': isRead,
        'created_at': createdAt.toIso8601String(),
      };

  factory AppNotification.fromMap(Map<String, dynamic> map, String docId) {
    NotificationType parseType(String? val) {
      switch (val) {
        case 'love':
          return NotificationType.love;
        case 'comment':
          return NotificationType.comment;
        case 'friendRequest':
        case 'friend_request':
          return NotificationType.friendRequest;
        case 'friendAccepted':
        case 'friend_accepted':
          return NotificationType.friendAccepted;
        default:
          return NotificationType.love;
      }
    }

    return AppNotification(
      id: docId,
      recipientUserId: map['recipientUserId'] ?? map['recipient_user_id'] ?? '',
      actorId: map['actorId'] ?? map['actor_id'] ?? '',
      actorUsername: map['actorUsername'] ?? map['actor_username'] ?? 'Pengguna',
      actorAvatarUrl: map['actorAvatarUrl'] ?? map['actor_avatar_url'],
      type: parseType(map['type']),
      title: map['title'] ?? 'Notifikasi',
      body: map['body'] ?? '',
      referenceId: map['referenceId'] ?? map['reference_id'],
      createdAt: (map['createdAt'] ?? map['created_at']) != null
          ? DateTime.tryParse((map['createdAt'] ?? map['created_at']).toString()) ?? DateTime.now()
          : DateTime.now(),
      isRead: map['isRead'] ?? map['is_read'] ?? false,
    );
  }

  AppNotification copyWith({
    bool? isRead,
  }) {
    return AppNotification(
      id: id,
      recipientUserId: recipientUserId,
      actorId: actorId,
      actorUsername: actorUsername,
      actorAvatarUrl: actorAvatarUrl,
      type: type,
      title: title,
      body: body,
      referenceId: referenceId,
      createdAt: createdAt,
      isRead: isRead ?? this.isRead,
    );
  }
}
