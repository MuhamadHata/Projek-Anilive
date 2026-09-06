class DirectMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String? senderAvatar;
  final String receiverId;
  final String content;
  final DateTime createdAt;
  final bool isRead;

  const DirectMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    this.senderAvatar,
    required this.receiverId,
    required this.content,
    required this.createdAt,
    this.isRead = false,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'senderId': senderId,
        'senderName': senderName,
        'senderAvatar': senderAvatar,
        'receiverId': receiverId,
        'content': content,
        'createdAt': createdAt.toIso8601String(),
        'isRead': isRead,
      };

  Map<String, dynamic> toSupabaseMap() => {
        'id': id,
        'sender_id': senderId,
        'receiver_id': receiverId,
        'content': content,
        'is_read': isRead,
        'created_at': createdAt.toIso8601String(),
      };

  factory DirectMessage.fromMap(Map<String, dynamic> map, String docId) =>
      DirectMessage(
        id: docId,
        senderId: map['senderId'] ?? map['sender_id'] ?? '',
        senderName: map['senderName'] ?? map['sender_name'] ?? 'User',
        senderAvatar: map['senderAvatar'] ?? map['sender_avatar'],
        receiverId: map['receiverId'] ?? map['receiver_id'] ?? '',
        content: map['content'] ?? '',
        createdAt: (map['createdAt'] ?? map['created_at']) != null
            ? DateTime.tryParse((map['createdAt'] ?? map['created_at']).toString()) ?? DateTime.now()
            : DateTime.now(),
        isRead: map['isRead'] ?? map['is_read'] ?? false,
      );
}
