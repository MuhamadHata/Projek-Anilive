import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/config/app_config.dart';
import '../../../core/services/supabase_service.dart';
import '../domain/direct_message.dart';

abstract class DirectChatRepository {
  Stream<List<DirectMessage>> watchMessages(
      String currentUserId, String otherUserId);
  Future<void> sendMessage(DirectMessage message);
  Stream<List<DirectMessage>> watchAllUserMessages(String currentUserId);
}

class DirectChatRepositoryImpl implements DirectChatRepository {
  final SupabaseClient? _supabase;

  static final Map<String, List<DirectMessage>> _mockMessages = {
    'mock_user_123_user_ren': [
      DirectMessage(
        id: 'msg_1',
        senderId: 'user_ren',
        senderName: 'Ren_Anime',
        senderAvatar:
            'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150',
        receiverId: 'mock_user_123',
        content: 'Halo! Sudah nonton episode terbaru belum?',
        createdAt: DateTime.now().subtract(const Duration(minutes: 40)),
      ),
      DirectMessage(
        id: 'msg_2',
        senderId: 'mock_user_123',
        senderName: 'Saya',
        receiverId: 'user_ren',
        content: 'Sudah, seru banget! Animasinya gila sih.',
        createdAt: DateTime.now().subtract(const Duration(minutes: 35)),
      ),
    ],
  };

  static final _mockController =
      StreamController<Map<String, List<DirectMessage>>>.broadcast();

  DirectChatRepositoryImpl({SupabaseClient? client})
      : _supabase = (AppConfig.useSupabase && SupabaseService.isInitialized)
            ? (client ?? SupabaseService.client)
            : null;

  String _roomId(String u1, String u2) {
    final list = [u1, u2]..sort();
    return '${list[0]}_${list[1]}';
  }

  @override
  Stream<List<DirectMessage>> watchMessages(
      String currentUserId, String otherUserId) {
    final roomId = _roomId(currentUserId, otherUserId);

    if (!AppConfig.useSupabase || !SupabaseService.isInitialized || _supabase == null) {
      final initial = _mockMessages[roomId] ?? [];
      return _mockController.stream
          .map((map) => map[roomId] ?? [])
          .asBroadcastStream()
          .transform(
            StreamTransformer<List<DirectMessage>, List<DirectMessage>>.fromHandlers(
              handleData: (data, sink) => sink.add(data),
            ),
          )
          .startWith(initial);
    }

    return _supabase
        .from('direct_messages')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: true)
        .map((data) {
          final list = data
              .where((m) {
                final s = m['sender_id']?.toString() ?? '';
                final r = m['receiver_id']?.toString() ?? '';
                return (s == currentUserId && r == otherUserId) ||
                    (s == otherUserId && r == currentUserId);
              })
              .map((m) => DirectMessage.fromMap(m, m['id']?.toString() ?? ''))
              .toList();

          if (list.isEmpty && _mockMessages.containsKey(roomId)) {
            return _mockMessages[roomId]!;
          }
          return list;
        })
        .handleError((_) => _mockMessages[roomId] ?? []);
  }

  @override
  Future<void> sendMessage(DirectMessage message) async {
    final roomId = _roomId(message.senderId, message.receiverId);

    _mockMessages.putIfAbsent(roomId, () => []);
    _mockMessages[roomId]!.add(message);
    _mockController.add(Map.from(_mockMessages));

    if (_supabase != null) {
      try {
        await _supabase.from('direct_messages').insert(message.toSupabaseMap());
      } catch (_) {}
    }
  }

  @override
  Stream<List<DirectMessage>> watchAllUserMessages(String currentUserId) {
    if (!AppConfig.useSupabase || !SupabaseService.isInitialized || _supabase == null) {
      return _mockController.stream
          .map((map) {
            final all = <DirectMessage>[];
            for (final list in map.values) {
              all.addAll(list.where((m) =>
                  m.senderId == currentUserId || m.receiverId == currentUserId));
            }
            all.sort((a, b) => b.createdAt.compareTo(a.createdAt));
            return all;
          })
          .asBroadcastStream()
          .transform(
            StreamTransformer<List<DirectMessage>, List<DirectMessage>>.fromHandlers(
              handleData: (data, sink) => sink.add(data),
            ),
          )
          .startWith(
            _mockMessages.values
                .expand((l) => l)
                .where((m) =>
                    m.senderId == currentUserId || m.receiverId == currentUserId)
                .toList()
              ..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
          );
    }

    return _supabase
        .from('direct_messages')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .map((data) {
          final list = data
              .where((m) {
                final s = m['sender_id']?.toString() ?? '';
                final r = m['receiver_id']?.toString() ?? '';
                return s == currentUserId || r == currentUserId;
              })
              .map((m) => DirectMessage.fromMap(m, m['id']?.toString() ?? ''))
              .toList();
          return list;
        })
        .handleError((_) => <DirectMessage>[]);
  }
}

final directChatRepositoryProvider = Provider<DirectChatRepository>((ref) {
  return DirectChatRepositoryImpl();
});

final directMessagesProvider = StreamProvider.autoDispose
    .family<List<DirectMessage>, (String, String)>((ref, pair) {
  return ref.watch(directChatRepositoryProvider).watchMessages(pair.$1, pair.$2);
});

final userAllMessagesProvider = StreamProvider.autoDispose
    .family<List<DirectMessage>, String>((ref, userId) {
  return ref.watch(directChatRepositoryProvider).watchAllUserMessages(userId);
});

extension _StreamExtensions<T> on Stream<T> {
  Stream<T> startWith(T initial) async* {
    yield initial;
    yield* this;
  }
}
