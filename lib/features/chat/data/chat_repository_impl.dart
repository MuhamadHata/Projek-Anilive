import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/config/app_config.dart';
import '../../../core/services/supabase_service.dart';
import '../domain/chat_models.dart';

abstract class ChatRepository {
  Stream<List<ChatMessage>> getMessages(int animeId);
  Stream<List<UserPresence>> getOnlineUsers(int animeId);
  Future<void> sendMessage(ChatMessage message);
  Future<void> setPresence(
    int animeId,
    String userId,
    String username,
    bool isOnline, {
    bool isTyping = false,
  });
}

class ChatRepositoryImpl implements ChatRepository {
  final SupabaseClient? _supabase;
  static final Map<int, List<ChatMessage>> _mockMessages = {};
  static final Map<int, List<UserPresence>> _mockPresence = {};
  static final _mockMsgController =
      StreamController<Map<int, List<ChatMessage>>>.broadcast();
  static final _mockPresenceController =
      StreamController<Map<int, List<UserPresence>>>.broadcast();

  ChatRepositoryImpl({SupabaseClient? client})
      : _supabase = (AppConfig.useSupabase && SupabaseService.isInitialized)
            ? (client ?? SupabaseService.client)
            : null;

  @override
  Stream<List<ChatMessage>> getMessages(int animeId) {
    if (!AppConfig.useSupabase || !SupabaseService.isInitialized || _supabase == null) {
      return _mockMsgController.stream
          .map((all) => all[animeId] ?? [])
          .asBroadcastStream();
    }

    return _supabase
        .from('live_chat_messages')
        .stream(primaryKey: ['id'])
        .eq('anime_id', animeId)
        .order('created_at', ascending: true)
        .map((data) =>
            data.map((m) => ChatMessage.fromMap(m, m['id']?.toString() ?? '')).toList())
        .handleError((_) => _mockMessages[animeId] ?? []);
  }

  @override
  Stream<List<UserPresence>> getOnlineUsers(int animeId) {
    return _mockPresenceController.stream
        .map((all) => (all[animeId] ?? []).where((p) => p.isOnline).toList())
        .asBroadcastStream();
  }

  @override
  Future<void> sendMessage(ChatMessage message) async {
    _mockMessages.putIfAbsent(message.animeId, () => []);
    _mockMessages[message.animeId]!.insert(0, message);
    _mockMsgController.add(_mockMessages);

    if (_supabase != null) {
      try {
        await _supabase.from('live_chat_messages').insert(message.toSupabaseMap());
      } catch (_) {}
    }
  }

  @override
  Future<void> setPresence(
    int animeId,
    String userId,
    String username,
    bool isOnline, {
    bool isTyping = false,
  }) async {
    _mockPresence.putIfAbsent(animeId, () => []);
    final list = _mockPresence[animeId]!;
    list.removeWhere((p) => p.userId == userId);
    if (isOnline) {
      list.add(
        UserPresence(
          userId: userId,
          username: username,
          isOnline: true,
          isTyping: isTyping,
          lastSeen: DateTime.now(),
        ),
      );
    }
    _mockPresenceController.add(_mockPresence);
  }
}
