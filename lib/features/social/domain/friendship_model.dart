enum FriendshipStatus {
  none,
  sent,
  received,
  friends,
}

class FriendUser {
  final String id;
  final String username;
  final String displayName;
  final String? avatarUrl;
  final DateTime friendedAt;

  const FriendUser({
    required this.id,
    required this.username,
    required this.displayName,
    this.avatarUrl,
    required this.friendedAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'username': username,
        'displayName': displayName,
        'avatarUrl': avatarUrl,
        'friendedAt': friendedAt.toIso8601String(),
      };

  factory FriendUser.fromMap(Map<String, dynamic> map, String docId) =>
      FriendUser(
        id: docId,
        username: map['username'] ?? 'User',
        displayName: map['displayName'] ?? map['username'] ?? 'User',
        avatarUrl: map['avatarUrl'],
        friendedAt: map['friendedAt'] != null
            ? DateTime.tryParse(map['friendedAt'].toString()) ?? DateTime.now()
            : DateTime.now(),
      );
}

class FriendRequestRecord {
  final String id;
  final String senderId;
  final String senderUsername;
  final String? senderAvatar;
  final String receiverId;
  final String status; // 'pending' | 'accepted' | 'rejected'
  final DateTime createdAt;

  const FriendRequestRecord({
    required this.id,
    required this.senderId,
    required this.senderUsername,
    this.senderAvatar,
    required this.receiverId,
    required this.status,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'senderId': senderId,
        'senderUsername': senderUsername,
        'senderAvatar': senderAvatar,
        'receiverId': receiverId,
        'status': status,
        'createdAt': createdAt.toIso8601String(),
      };

  factory FriendRequestRecord.fromMap(Map<String, dynamic> map, String docId) =>
      FriendRequestRecord(
        id: docId,
        senderId: map['senderId'] ?? '',
        senderUsername: map['senderUsername'] ?? 'User',
        senderAvatar: map['senderAvatar'],
        receiverId: map['receiverId'] ?? '',
        status: map['status'] ?? 'pending',
        createdAt: map['createdAt'] != null
            ? DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now()
            : DateTime.now(),
      );
}
