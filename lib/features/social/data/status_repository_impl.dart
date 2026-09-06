import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/config/app_config.dart';
import '../../../core/services/supabase_service.dart';
import '../../anime/data/anime_offline_db.dart';
import '../../notification/data/notification_repository.dart';
import '../../notification/domain/notification_model.dart';
import '../domain/status_update.dart';

abstract class StatusRepository {
  Stream<List<StatusUpdate>> getFeed();
  Future<void> postStatus(StatusUpdate status);
  Future<void> toggleLike(
    String statusId,
    String userId, {
    String? authorId,
    String? currentUsername,
    String? currentAvatarUrl,
    String? animeTitle,
  });
  Stream<List<StatusComment>> getComments(String statusId);
  Future<void> addComment(
    StatusComment comment, {
    String? authorId,
    String? animeTitle,
  });
  Future<StatusUpdate?> getStatusById(String statusId);
}

class StatusRepositoryImpl implements StatusRepository {
  final SupabaseClient? _injectedClient;
  final NotificationRepository _notificationRepo;

  SupabaseClient? get _supabase =>
      _injectedClient ??
      ((AppConfig.useSupabase && SupabaseService.isInitialized)
          ? SupabaseService.client
          : null);

  static final List<StatusUpdate> _mockFeed = [];
  static bool _hasLoadedPrefs = false;

  static final Map<String, List<StatusComment>> _mockComments = {};

  static final _mockFeedController =
      StreamController<List<StatusUpdate>>.broadcast();
  static final _mockCommentController =
      StreamController<Map<String, List<StatusComment>>>.broadcast();

  StatusRepositoryImpl({
    SupabaseClient? client,
    NotificationRepository? notificationRepo,
  })  : _injectedClient = client,
        _notificationRepo = notificationRepo ?? NotificationRepositoryImpl();

  static Future<void> _saveCacheToPrefs() async {
    try {
      final prefs = SharedPreferencesAsync();
      final list = _mockFeed.map((s) => s.toMap()).toList();
      await prefs.setString('cached_status_feed', jsonEncode(list));
    } catch (_) {}
  }

  static Future<void> _loadCacheFromPrefs() async {
    if (_hasLoadedPrefs && _mockFeed.isNotEmpty) return;
    try {
      final prefs = SharedPreferencesAsync();
      final jsonStr = await prefs.getString('cached_status_feed');
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final decoded = jsonDecode(jsonStr) as List;
        for (final raw in decoded) {
          final s = StatusUpdate.fromMap(
            Map<String, dynamic>.from(raw as Map),
            raw['id']?.toString() ?? '',
          );
          final resolved = _resolveStatus(s);
          final idx = _mockFeed.indexWhere((m) => m.id == resolved.id);
          if (idx != -1) {
            _mockFeed[idx] = resolved;
          } else {
            _mockFeed.add(resolved);
          }
        }
        _mockFeed.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        _hasLoadedPrefs = true;
      }
    } catch (_) {}
  }

  static StatusUpdate _resolveStatus(StatusUpdate it) {
    var title = it.animeTitle.trim();
    var cover = it.animeCoverUrl.trim();
    if ((title.isEmpty || title == 'Tanpa Judul' || cover.isEmpty) && it.animeId > 0) {
      final offline = AnimeOfflineDb.getByIdSync(it.animeId);
      if (offline != null) {
        if (title.isEmpty || title == 'Tanpa Judul') title = offline.title;
        if (cover.isEmpty) cover = offline.imageUrl;
      }
    }
    return it.copyWith(
      animeTitle: title,
      animeCoverUrl: cover,
    );
  }

  @override
  Stream<List<StatusUpdate>> getFeed() {
    return Stream<List<StatusUpdate>>.multi((controller) {
      // 1. Langsung emit data dari cache memori agar 0 ms / tidak pernah blank
      controller.add(List<StatusUpdate>.from(_mockFeed));

      // 2. Baca dari SharedPreferences jika memori masih kosong
      _loadCacheFromPrefs().then((_) {
        if (_mockFeed.isNotEmpty) {
          controller.add(List<StatusUpdate>.from(_mockFeed));
        }
      }).catchError((_) {});

      // 3. Jika Supabase aktif, ambil postingan terbaru via REST query (.select())
      StreamSubscription? realtimeSub;
      final sb = _supabase;
      if (sb != null) {
        sb
            .from('status_updates')
            .select()
            .order('created_at', ascending: false)
            .limit(40)
            .then((data) {
              final items = (data as List)
                  .map((map) {
                    final raw = StatusUpdate.fromMap(
                      Map<String, dynamic>.from(map as Map),
                      map['id']?.toString() ?? '',
                    );
                    return _resolveStatus(raw);
                  })
                  .toList();

              for (final it in items) {
                final idx = _mockFeed.indexWhere((m) => m.id == it.id);
                if (idx != -1) {
                  _mockFeed[idx] = it;
                } else {
                  _mockFeed.add(it);
                }
              }
              _mockFeed.sort((a, b) => b.createdAt.compareTo(a.createdAt));
              _saveCacheToPrefs();
              controller.add(List<StatusUpdate>.from(_mockFeed));
            })
            .catchError((err) {
              if (kDebugMode) {
                print('Supabase getFeed REST error: $err');
              }
            });

        // 4. Juga dengarkan realtime stream jika tersedia
        try {
          realtimeSub = sb
              .from('status_updates')
              .stream(primaryKey: ['id'])
              .order('created_at', ascending: false)
              .limit(40)
              .listen((data) {
                final items = data
                    .map((map) {
                      final raw = StatusUpdate.fromMap(map, map['id']?.toString() ?? '');
                      return _resolveStatus(raw);
                    })
                    .toList();
                for (final it in items) {
                  final idx = _mockFeed.indexWhere((m) => m.id == it.id);
                  if (idx != -1) {
                    _mockFeed[idx] = it;
                  } else {
                    _mockFeed.insert(0, it);
                  }
                }
                _mockFeed.sort((a, b) => b.createdAt.compareTo(a.createdAt));
                _saveCacheToPrefs();
                controller.add(List<StatusUpdate>.from(_mockFeed));
              }, onError: (e) {
                if (kDebugMode) {
                  print('Supabase getFeed Realtime error: $e');
                }
              });
        } catch (_) {}
      }

      // 5. Selalu dengarkan controller lokal agar postingan dan like baru langsung tampil instan
      final localSub = _mockFeedController.stream.listen((feed) {
        controller.add(List<StatusUpdate>.from(feed));
      });

      controller.onCancel = () {
        realtimeSub?.cancel();
        localSub.cancel();
      };
    });
  }

  @override
  Future<void> postStatus(StatusUpdate status) async {
    final resolved = _resolveStatus(status);
    _mockFeed.removeWhere((s) => s.id == resolved.id);
    _mockFeed.insert(0, resolved);
    _mockFeedController.add(List<StatusUpdate>.from(_mockFeed));
    _saveCacheToPrefs();

    final sb = _supabase;
    if (sb != null) {
      try {
        await sb.from('status_updates').upsert(resolved.toSupabaseMap());
      } catch (e) {
        if (kDebugMode) {
          print('Error posting status to Supabase: $e');
        }
      }
    }
  }

  @override
  Future<void> toggleLike(
    String statusId,
    String userId, {
    String? authorId,
    String? currentUsername,
    String? currentAvatarUrl,
    String? animeTitle,
  }) async {
    final index = _mockFeed.indexWhere((s) => s.id == statusId);
    bool isLiked = false;

    if (index != -1) {
      final item = _mockFeed[index];
      isLiked = item.likedBy.contains(userId);
      final newLikedBy = List<String>.from(item.likedBy);

      if (isLiked) {
        newLikedBy.remove(userId);
      } else {
        newLikedBy.add(userId);
      }

      _mockFeed[index] = item.copyWith(
        likeCount: isLiked
            ? (item.likeCount > 0 ? item.likeCount - 1 : 0)
            : item.likeCount + 1,
        likedBy: newLikedBy,
      );
      _mockFeedController.add(List.from(_mockFeed));
      _saveCacheToPrefs();
    }

    if (!isLiked && authorId != null && authorId != userId) {
      await _notificationRepo.sendNotification(
        AppNotification(
          id: 'notif_like_${DateTime.now().millisecondsSinceEpoch}',
          recipientUserId: authorId,
          actorId: userId,
          actorUsername: currentUsername ?? 'Seseorang',
          actorAvatarUrl: currentAvatarUrl,
          type: NotificationType.love,
          title: 'Menyukai Status',
          body:
              '${currentUsername ?? 'Seseorang'} menyukai status Anda mengenai "${animeTitle ?? 'anime'}"',
          referenceId: statusId,
          createdAt: DateTime.now(),
        ),
      );
    }

    final sb = _supabase;
    if (sb != null) {
      try {
        final existing = await sb
            .from('status_updates')
            .select('liked_by, like_count')
            .eq('id', statusId)
            .maybeSingle();

        if (existing != null) {
          final likedBy = (existing['liked_by'] as List<dynamic>?)
                  ?.map((e) => e.toString())
                  .toList() ??
              [];
          final alreadyLiked = likedBy.contains(userId);
          if (alreadyLiked) {
            likedBy.remove(userId);
          } else {
            likedBy.add(userId);
          }
          final currentLikes = (existing['like_count'] as int?) ?? 0;
          final updatedLikes = alreadyLiked
              ? (currentLikes > 0 ? currentLikes - 1 : 0)
              : currentLikes + 1;

          await sb.from('status_updates').update({
            'liked_by': likedBy,
            'like_count': updatedLikes,
          }).eq('id', statusId);
        }
      } catch (_) {}
    }
  }

  @override
  Stream<List<StatusComment>> getComments(String statusId) {
    final sb = _supabase;
    if (!AppConfig.useSupabase || !SupabaseService.isInitialized || sb == null) {
      final list = _mockComments[statusId] ?? [];
      return _mockCommentController.stream
          .map((all) => all[statusId] ?? [])
          .asBroadcastStream()
          .transform(
            StreamTransformer<List<StatusComment>, List<StatusComment>>.fromHandlers(
              handleData: (data, sink) => sink.add(data),
            ),
          )
          .startWith(list);
    }

    return sb
        .from('status_comments')
        .stream(primaryKey: ['id'])
        .eq('status_id', statusId)
        .order('created_at', ascending: true)
        .map((data) =>
            data.map((m) => StatusComment.fromMap(m, m['id'])).toList())
        .handleError((_) => _mockComments[statusId] ?? []);
  }

  @override
  Future<void> addComment(
    StatusComment comment, {
    String? authorId,
    String? animeTitle,
  }) async {
    _mockComments.putIfAbsent(comment.statusId, () => []);
    _mockComments[comment.statusId]!.add(comment);
    _mockCommentController.add(Map.from(_mockComments));

    final feedIndex = _mockFeed.indexWhere((s) => s.id == comment.statusId);
    if (feedIndex != -1) {
      _mockFeed[feedIndex] = _mockFeed[feedIndex].copyWith(
        commentCount: _mockFeed[feedIndex].commentCount + 1,
      );
      _mockFeedController.add(List.from(_mockFeed));
      _saveCacheToPrefs();
    }

    if (authorId != null && authorId != comment.userId) {
      await _notificationRepo.sendNotification(
        AppNotification(
          id: 'notif_cmt_${DateTime.now().millisecondsSinceEpoch}',
          recipientUserId: authorId,
          actorId: comment.userId,
          actorUsername: comment.username,
          actorAvatarUrl: comment.avatarUrl,
          type: NotificationType.comment,
          title: 'Komentar Baru',
          body:
              '${comment.username} mengomentari status Anda: "${comment.content}"',
          referenceId: comment.statusId,
          createdAt: DateTime.now(),
        ),
      );
    }

    final sb = _supabase;
    if (sb != null) {
      try {
        await sb.from('status_comments').insert(comment.toSupabaseMap());
        final currentStatus = await sb
            .from('status_updates')
            .select('comment_count')
            .eq('id', comment.statusId)
            .maybeSingle();

        if (currentStatus != null) {
          final count = (currentStatus['comment_count'] as int?) ?? 0;
          await sb.from('status_updates').update({
            'comment_count': count + 1,
          }).eq('id', comment.statusId);
        }
      } catch (_) {}
    }
  }

  @override
  Future<StatusUpdate?> getStatusById(String statusId) async {
    final memoryMatch = _mockFeed.where((s) => s.id == statusId).firstOrNull;
    if (memoryMatch != null) return memoryMatch;

    await _loadCacheFromPrefs();
    final cachedMatch = _mockFeed.where((s) => s.id == statusId).firstOrNull;
    if (cachedMatch != null) return cachedMatch;

    final sb = _supabase;
    if (sb != null) {
      try {
        final res = await sb
            .from('status_updates')
            .select()
            .eq('id', statusId)
            .maybeSingle();
        if (res != null) {
          final s = StatusUpdate.fromMap(
            Map<String, dynamic>.from(res as Map),
            res['id']?.toString() ?? '',
          );
          final resolved = _resolveStatus(s);
          final idx = _mockFeed.indexWhere((m) => m.id == resolved.id);
          if (idx != -1) {
            _mockFeed[idx] = resolved;
          } else {
            _mockFeed.add(resolved);
          }
          return resolved;
        }
      } catch (_) {}
    }
    return null;
  }
}

final statusRepositoryProvider = Provider<StatusRepository>((ref) {
  final notifRepo = ref.watch(notificationRepositoryProvider);
  return StatusRepositoryImpl(notificationRepo: notifRepo);
});

final feedProvider = StreamProvider.autoDispose<List<StatusUpdate>>((ref) {
  return ref.watch(statusRepositoryProvider).getFeed();
});

final singleStatusProvider = FutureProvider.autoDispose
    .family<StatusUpdate?, String>((ref, statusId) {
  return ref.watch(statusRepositoryProvider).getStatusById(statusId);
});

final statusCommentsProvider = StreamProvider.autoDispose
    .family<List<StatusComment>, String>((ref, statusId) {
  return ref.watch(statusRepositoryProvider).getComments(statusId);
});

extension _StreamExtensions<T> on Stream<T> {
  Stream<T> startWith(T initial) async* {
    yield initial;
    yield* this;
  }
}
