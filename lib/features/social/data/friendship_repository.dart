import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/config/app_config.dart';
import '../../../core/services/supabase_service.dart';
import '../../notification/data/notification_repository.dart';
import '../../notification/domain/notification_model.dart';
import '../domain/friendship_model.dart';

abstract class FriendshipRepository {
  Stream<FriendshipStatus> watchFriendshipStatus(
      String currentUserId, String targetUserId);
  Future<void> sendFriendRequest({
    required String fromUserId,
    required String fromUsername,
    String? fromAvatar,
    required String toUserId,
  });
  Future<void> acceptFriendRequest({
    required String currentUserId,
    required String currentUsername,
    String? currentAvatar,
    required String requesterId,
  });
  Future<void> rejectFriendRequest(String currentUserId, String requesterId);
  Future<void> unfriend(String currentUserId, String friendId);
  Stream<List<FriendUser>> watchFriends(String userId);
}

class FriendshipRepositoryImpl implements FriendshipRepository {
  final SupabaseClient? _supabase;
  final NotificationRepository _notificationRepo;

  // In-memory mock storage for friends & requests
  static final Set<String> _mockFriendsPairs = {'mock_user_123_user_ren'};
  static final Map<String, FriendRequestRecord> _mockRequests = {
    'user_sakura_mock_user_123': FriendRequestRecord(
      id: 'req_1',
      senderId: 'user_sakura',
      senderUsername: 'SakuraChan',
      senderAvatar:
          'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150',
      receiverId: 'mock_user_123',
      status: 'pending',
      createdAt: DateTime.now().subtract(const Duration(minutes: 10)),
    ),
  };

  static final _mockFriendshipController =
      StreamController<void>.broadcast();

  FriendshipRepositoryImpl({
    SupabaseClient? client,
    NotificationRepository? notificationRepo,
  })  : _supabase = (AppConfig.useSupabase && SupabaseService.isInitialized)
            ? (client ?? SupabaseService.client)
            : null,
        _notificationRepo = notificationRepo ?? NotificationRepositoryImpl();

  (String, String) _orderedPair(String u1, String u2) {
    return u1.compareTo(u2) < 0 ? (u1, u2) : (u2, u1);
  }

  String _pairKey(String u1, String u2) {
    final pair = _orderedPair(u1, u2);
    return '${pair.$1}_${pair.$2}';
  }

  FriendshipStatus _mockCheckStatus(String currentUserId, String targetUserId) {
    final pair = _pairKey(currentUserId, targetUserId);
    if (_mockFriendsPairs.contains(pair)) {
      return FriendshipStatus.friends;
    }
    final sentKey = '${currentUserId}_$targetUserId';
    if (_mockRequests[sentKey]?.status == 'pending') {
      return FriendshipStatus.sent;
    }
    final receivedKey = '${targetUserId}_$currentUserId';
    if (_mockRequests[receivedKey]?.status == 'pending') {
      return FriendshipStatus.received;
    }
    return FriendshipStatus.none;
  }

  @override
  Stream<FriendshipStatus> watchFriendshipStatus(
      String currentUserId, String targetUserId) {
    if (currentUserId == targetUserId) {
      return Stream.value(FriendshipStatus.none);
    }

    if (!AppConfig.useSupabase || !SupabaseService.isInitialized || _supabase == null) {
      return _mockFriendshipController.stream
          .map((_) => _mockCheckStatus(currentUserId, targetUserId))
          .asBroadcastStream()
          .transform(
            StreamTransformer<FriendshipStatus, FriendshipStatus>.fromHandlers(
              handleData: (data, sink) => sink.add(data),
            ),
          )
          .startWith(_mockCheckStatus(currentUserId, targetUserId));
    }

    final pair = _orderedPair(currentUserId, targetUserId);
    return _supabase
        .from('friendships')
        .stream(primaryKey: ['id'])
        .map((data) {
          final match = data.cast<Map<String, dynamic>?>().firstWhere(
                (f) =>
                    f?['user_a'] == pair.$1 && f?['user_b'] == pair.$2,
                orElse: () => null,
              );

          if (match == null) {
            return _mockCheckStatus(currentUserId, targetUserId);
          }

          final status = match['status'] as String? ?? 'none';
          if (status == 'accepted') return FriendshipStatus.friends;
          if (status == 'pending') {
            final requester = match['requester_id'] as String? ?? '';
            return requester == currentUserId
                ? FriendshipStatus.sent
                : FriendshipStatus.received;
          }
          return FriendshipStatus.none;
        })
        .handleError((_) => _mockCheckStatus(currentUserId, targetUserId));
  }

  static final Map<String, Map<String, dynamic>> _profilesCache = {};

  @override
  Future<void> sendFriendRequest({
    required String fromUserId,
    required String fromUsername,
    String? fromAvatar,
    required String toUserId,
  }) async {
    String resolvedFromUsername = fromUsername;
    String? resolvedFromAvatar = fromAvatar;

    if (_supabase != null &&
        (fromUsername == 'Pengguna' || fromAvatar == null || fromAvatar.isEmpty)) {
      try {
        final profile = await _supabase
            .from('profiles')
            .select('username, display_name, avatar_url')
            .eq('id', fromUserId)
            .maybeSingle();
        if (profile != null) {
          final u = profile['username'] as String? ?? '';
          final d = profile['display_name'] as String? ?? '';
          if (d.isNotEmpty) {
            resolvedFromUsername = d;
          } else if (u.isNotEmpty) {
            resolvedFromUsername = u;
          }
          resolvedFromAvatar ??= profile['avatar_url'] as String?;
        }
      } catch (_) {}
    }

    final reqKey = '${fromUserId}_$toUserId';
    _mockRequests[reqKey] = FriendRequestRecord(
      id: 'req_${DateTime.now().millisecondsSinceEpoch}',
      senderId: fromUserId,
      senderUsername: resolvedFromUsername,
      senderAvatar: resolvedFromAvatar,
      receiverId: toUserId,
      status: 'pending',
      createdAt: DateTime.now(),
    );
    _mockFriendshipController.add(null);

    await _notificationRepo.sendNotification(
      AppNotification(
        id: 'notif_${DateTime.now().millisecondsSinceEpoch}',
        recipientUserId: toUserId,
        actorId: fromUserId,
        actorUsername: resolvedFromUsername,
        actorAvatarUrl: resolvedFromAvatar,
        type: NotificationType.friendRequest,
        title: 'Permintaan Pertemanan',
        body: '$resolvedFromUsername ingin berteman dengan Anda',
        referenceId: fromUserId,
        createdAt: DateTime.now(),
      ),
    );

    if (_supabase != null) {
      final pair = _orderedPair(fromUserId, toUserId);
      try {
        await _supabase.from('friendships').upsert({
          'user_a': pair.$1,
          'user_b': pair.$2,
          'requester_id': fromUserId,
          'status': 'pending',
          'created_at': DateTime.now().toIso8601String(),
        });
      } catch (_) {}
    }
  }

  @override
  Future<void> acceptFriendRequest({
    required String currentUserId,
    required String currentUsername,
    String? currentAvatar,
    required String requesterId,
  }) async {
    String resolvedCurrentUsername = currentUsername;
    String? resolvedCurrentAvatar = currentAvatar;

    if (_supabase != null &&
        (currentUsername == 'Pengguna' ||
            currentAvatar == null ||
            currentAvatar.isEmpty)) {
      try {
        final profile = await _supabase
            .from('profiles')
            .select('username, display_name, avatar_url')
            .eq('id', currentUserId)
            .maybeSingle();
        if (profile != null) {
          final u = profile['username'] as String? ?? '';
          final d = profile['display_name'] as String? ?? '';
          if (d.isNotEmpty) {
            resolvedCurrentUsername = d;
          } else if (u.isNotEmpty) {
            resolvedCurrentUsername = u;
          }
          resolvedCurrentAvatar ??= profile['avatar_url'] as String?;
        }
      } catch (_) {}
    }

    final reqKey = '${requesterId}_$currentUserId';
    final request = _mockRequests[reqKey];
    _mockRequests.remove(reqKey);
    _mockFriendsPairs.add(_pairKey(currentUserId, requesterId));

    _mockFriendsByUser.putIfAbsent(currentUserId, () => []);
    if (!_mockFriendsByUser[currentUserId]!.any((f) => f.id == requesterId)) {
      _mockFriendsByUser[currentUserId]!.insert(
        0,
        FriendUser(
          id: requesterId,
          username: request?.senderUsername ?? 'Teman',
          displayName: request?.senderUsername ?? 'Teman',
          avatarUrl: request?.senderAvatar,
          friendedAt: DateTime.now(),
        ),
      );
    }
    _mockFriendsByUser.putIfAbsent(requesterId, () => []);
    if (!_mockFriendsByUser[requesterId]!.any((f) => f.id == currentUserId)) {
      _mockFriendsByUser[requesterId]!.insert(
        0,
        FriendUser(
          id: currentUserId,
          username: resolvedCurrentUsername,
          displayName: resolvedCurrentUsername,
          avatarUrl: resolvedCurrentAvatar,
          friendedAt: DateTime.now(),
        ),
      );
    }

    _mockFriendshipController.add(null);

    await _notificationRepo.sendNotification(
      AppNotification(
        id: 'notif_${DateTime.now().millisecondsSinceEpoch}',
        recipientUserId: requesterId,
        actorId: currentUserId,
        actorUsername: resolvedCurrentUsername,
        actorAvatarUrl: resolvedCurrentAvatar,
        type: NotificationType.friendAccepted,
        title: 'Permintaan Diterima',
        body: '$resolvedCurrentUsername menerima permintaan pertemanan Anda',
        referenceId: currentUserId,
        createdAt: DateTime.now(),
      ),
    );

    if (_supabase != null) {
      final pair = _orderedPair(currentUserId, requesterId);
      try {
        await _supabase.from('friendships').update({
          'status': 'accepted',
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('user_a', pair.$1).eq('user_b', pair.$2);
      } catch (_) {}
    }
  }

  @override
  Future<void> rejectFriendRequest(
      String currentUserId, String requesterId) async {
    final reqKey = '${requesterId}_$currentUserId';
    _mockRequests.remove(reqKey);
    _mockFriendshipController.add(null);

    if (_supabase != null) {
      final pair = _orderedPair(currentUserId, requesterId);
      try {
        await _supabase
            .from('friendships')
            .delete()
            .eq('user_a', pair.$1)
            .eq('user_b', pair.$2);
      } catch (_) {}
    }
  }

  @override
  Future<void> unfriend(String currentUserId, String friendId) async {
    _mockFriendsPairs.remove(_pairKey(currentUserId, friendId));
    _mockFriendsByUser[currentUserId]?.removeWhere((f) => f.id == friendId);
    _mockFriendsByUser[friendId]?.removeWhere((f) => f.id == currentUserId);
    _mockFriendshipController.add(null);

    if (_supabase != null) {
      final pair = _orderedPair(currentUserId, friendId);
      try {
        await _supabase
            .from('friendships')
            .delete()
            .eq('user_a', pair.$1)
            .eq('user_b', pair.$2);
      } catch (_) {}
    }
  }

  static final Map<String, List<FriendUser>> _mockFriendsByUser = {
    'mock_user_123': [
      FriendUser(
        id: 'user_ren',
        username: 'Ren_Anime',
        displayName: 'Ren Anime',
        avatarUrl:
            'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150',
        friendedAt: DateTime.now().subtract(const Duration(days: 3)),
      ),
    ],
  };

  @override
  Stream<List<FriendUser>> watchFriends(String userId) {
    final initial = _mockFriendsByUser[userId] ?? [];

    if (!AppConfig.useSupabase || !SupabaseService.isInitialized || _supabase == null) {
      return _mockFriendshipController.stream
          .map((_) => _mockFriendsByUser[userId] ?? [])
          .asBroadcastStream()
          .transform(
            StreamTransformer<List<FriendUser>, List<FriendUser>>.fromHandlers(
              handleData: (data, sink) => sink.add(data),
            ),
          )
          .startWith(initial);
    }

    return _supabase
        .from('friendships')
        .stream(primaryKey: ['id'])
        .asyncMap((data) async {
          final accepted = data
              .where((f) =>
                  (f['user_a'] == userId || f['user_b'] == userId) &&
                  f['status'] == 'accepted')
              .toList();

          if (accepted.isEmpty && _mockFriendsByUser.containsKey(userId)) {
            return _mockFriendsByUser[userId]!;
          }

          final friendIds = accepted
              .map((f) =>
                  (f['user_a'] == userId ? f['user_b'] : f['user_a'])
                      ?.toString() ??
                  '')
              .where((id) => id.isNotEmpty)
              .toList();

          if (friendIds.isNotEmpty) {
            try {
              final profilesData = await _supabase
                  .from('profiles')
                  .select('id, username, display_name, avatar_url')
                  .inFilter('id', friendIds);
              for (final p in profilesData) {
                final pid = p['id']?.toString() ?? '';
                if (pid.isNotEmpty) _profilesCache[pid] = p;
              }
            } catch (_) {}
          }

          final friends = <FriendUser>[];
          for (final f in accepted) {
            final friendId =
                (f['user_a'] == userId ? f['user_b'] : f['user_a'])
                        ?.toString() ??
                    '';
            final p = _profilesCache[friendId];
            final local = _mockFriendsByUser[userId]
                ?.where((m) => m.id == friendId)
                .firstOrNull;

            final username =
                p?['username'] as String? ?? local?.username ?? 'Pengguna';
            final rawDisplay = p?['display_name'] as String?;
            final displayName = (rawDisplay != null && rawDisplay.isNotEmpty)
                ? rawDisplay
                : (username != 'Pengguna'
                    ? username
                    : (local?.displayName ?? 'Pengguna'));
            final avatarUrl = p?['avatar_url'] as String? ?? local?.avatarUrl;

            friends.add(
              FriendUser(
                id: friendId,
                username: username,
                displayName: displayName,
                avatarUrl: avatarUrl,
                friendedAt: DateTime.tryParse(
                        f['updated_at']?.toString() ?? '') ??
                    DateTime.now(),
              ),
            );
          }
          return friends;
        })
        .handleError((_) => _mockFriendsByUser[userId] ?? []);
  }
}

extension _StreamExtensions<T> on Stream<T> {
  Stream<T> startWith(T initial) async* {
    yield initial;
    yield* this;
  }
}

final friendshipRepositoryProvider = Provider<FriendshipRepository>((ref) {
  final notifRepo = ref.watch(notificationRepositoryProvider);
  return FriendshipRepositoryImpl(notificationRepo: notifRepo);
});

final friendshipStatusProvider = StreamProvider.autoDispose
    .family<FriendshipStatus, (String, String)>((ref, tuple) {
  return ref
      .watch(friendshipRepositoryProvider)
      .watchFriendshipStatus(tuple.$1, tuple.$2);
});

final userFriendsProvider = StreamProvider.autoDispose
    .family<List<FriendUser>, String>((ref, userId) {
  return ref.watch(friendshipRepositoryProvider).watchFriends(userId);
});
