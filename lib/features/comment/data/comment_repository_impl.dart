import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/config/app_config.dart';
import '../../../core/services/supabase_service.dart';
import '../domain/comment.dart';

abstract class CommentRepository {
  Stream<List<AnimeComment>> getComments(int animeId);
  Stream<List<AnimeComment>> getReplies(int animeId, String commentId);
  Future<void> addComment(AnimeComment comment);
  Future<void> addReply(int animeId, String commentId, AnimeComment reply);
  Future<void> toggleLike(int animeId, String commentId);
  Future<void> deleteComment(int animeId, String commentId);
}

class CommentRepositoryImpl implements CommentRepository {
  final SupabaseClient? _supabase;
  static final Map<String, List<AnimeComment>> _mockComments = {};
  static final _mockStreamController =
      StreamController<Map<String, List<AnimeComment>>>.broadcast();

  CommentRepositoryImpl({SupabaseClient? client})
      : _supabase = (AppConfig.useSupabase && SupabaseService.isInitialized)
            ? (client ?? SupabaseService.client)
            : null;

  @override
  Stream<List<AnimeComment>> getComments(int animeId) {
    if (!AppConfig.useSupabase || !SupabaseService.isInitialized || _supabase == null) {
      return _mockStreamController.stream
          .map((all) => all['$animeId'] ?? [])
          .asBroadcastStream();
    }

    return _mockStreamController.stream
        .map((all) => all['$animeId'] ?? [])
        .asBroadcastStream();
  }

  @override
  Stream<List<AnimeComment>> getReplies(int animeId, String commentId) {
    return _mockStreamController.stream
        .map((all) => all['$animeId:$commentId'] ?? [])
        .asBroadcastStream();
  }

  @override
  Future<void> addComment(AnimeComment comment) async {
    final key = '${comment.animeId}';
    _mockComments.putIfAbsent(key, () => []);
    _mockComments[key]!.insert(0, comment);
    _mockStreamController.add(_mockComments);
  }

  @override
  Future<void> addReply(
    int animeId,
    String commentId,
    AnimeComment reply,
  ) async {
    final key = '$animeId:$commentId';
    _mockComments.putIfAbsent(key, () => []);
    _mockComments[key]!.add(reply);
    _mockStreamController.add(_mockComments);
  }

  @override
  Future<void> toggleLike(int animeId, String commentId) async {
    final key = '$animeId';
    final list = _mockComments[key];
    if (list != null) {
      final idx = list.indexWhere((c) => c.id == commentId);
      if (idx != -1) {
        final c = list[idx];
        list[idx] = AnimeComment(
          id: c.id,
          animeId: c.animeId,
          userId: c.userId,
          username: c.username,
          avatarUrl: c.avatarUrl,
          content: c.content,
          likeCount: c.likeCount + 1,
          replyCount: c.replyCount,
          createdAt: c.createdAt,
          isDeleted: c.isDeleted,
        );
        _mockStreamController.add(_mockComments);
      }
    }
  }

  @override
  Future<void> deleteComment(int animeId, String commentId) async {
    final key = '$animeId';
    final list = _mockComments[key];
    if (list != null) {
      final idx = list.indexWhere((c) => c.id == commentId);
      if (idx != -1) {
        final c = list[idx];
        list[idx] = AnimeComment(
          id: c.id,
          animeId: c.animeId,
          userId: c.userId,
          username: c.username,
          avatarUrl: c.avatarUrl,
          content: '[Komentar ini telah dihapus]',
          likeCount: c.likeCount,
          replyCount: c.replyCount,
          createdAt: c.createdAt,
          isDeleted: true,
        );
        _mockStreamController.add(_mockComments);
      }
    }
  }
}
