import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/config/app_config.dart';
import '../../../core/services/supabase_service.dart';
import '../../anime/data/anime_offline_db.dart';
import '../domain/review.dart';

abstract class ReviewRepository {
  Stream<List<Review>> getReviewsForAnime(int animeId);
  Future<void> submitReview(Review review);
  Future<void> toggleLike(String reviewId, int animeId, String userId);

  /// Entri (bookmark/review) milik satu user untuk satu anime.
  /// Null jika user belum pernah menyimpan.
  Stream<Review?> watchUserEntry(int animeId, String userId);

  /// Semua review publik yang ditulis user ini (tab Review di profil).
  Stream<List<Review>> watchUserReviews(String userId);

  /// Daftar anime yang disimpan user (untuk halaman profil).
  Stream<List<UserAnimeEntry>> watchUserList(String userId);

  /// Hapus entri dari daftar user + review-nya.
  Future<void> deleteUserEntry({
    required int animeId,
    required String reviewId,
    required String userId,
  });

  /// Update status tontonan + progress episode pada entri user
  Future<void> updateWatchStatus({
    required int animeId,
    required String reviewId,
    required String userId,
    String? watchStatus,
    int? watchedEpisodes,
    bool? isCompleted,
  });
}

class ReviewRepositoryImpl implements ReviewRepository {
  final SupabaseClient? _injectedClient;

  SupabaseClient? get _supabase =>
      _injectedClient ??
      ((AppConfig.useSupabase && SupabaseService.isInitialized)
          ? SupabaseService.client
          : null);

  static final Map<int, List<Review>> _mockReviews = {};
  static final _mockStreamController =
      StreamController<Map<int, List<Review>>>.broadcast();

  // Penyimpanan lokal per-user saat offline/fallback.
  static final Map<String, Map<int, UserAnimeEntry>> _mockUserList = {};
  static final _mockUserController =
      StreamController<Map<String, Map<int, UserAnimeEntry>>>.broadcast();
  static final Set<String> _loadedUsers = {};

  ReviewRepositoryImpl({SupabaseClient? client}) : _injectedClient = client;

  static Future<void> _saveCacheToPrefs(String userId) async {
    try {
      final prefs = SharedPreferencesAsync();
      final userMap = _mockUserList[userId] ?? {};
      final list = userMap.values.map((e) => e.toMap()).toList();
      await prefs.setString('cached_user_anime_list_$userId', jsonEncode(list));

      final myReviews = _mockReviews.values
          .expand((l) => l)
          .where((r) => r.userId == userId)
          .map((r) => r.toMap())
          .toList();
      await prefs.setString('cached_user_reviews_$userId', jsonEncode(myReviews));
    } catch (_) {}
  }

  static Future<void> _loadCacheFromPrefs(String userId) async {
    if (_loadedUsers.contains(userId)) return;
    try {
      final prefs = SharedPreferencesAsync();
      final jsonList = await prefs.getString('cached_user_anime_list_$userId');
      if (jsonList != null && jsonList.isNotEmpty) {
        final decoded = jsonDecode(jsonList) as List;
        for (final raw in decoded) {
          final entry = UserAnimeEntry.fromMap(Map<String, dynamic>.from(raw as Map));
          _mockUserList.putIfAbsent(userId, () => {})[entry.animeId] = entry;
        }
        _mockUserController.add(_mockUserList);
      }

      final jsonReviews = await prefs.getString('cached_user_reviews_$userId');
      if (jsonReviews != null && jsonReviews.isNotEmpty) {
        final decoded = jsonDecode(jsonReviews) as List;
        for (final raw in decoded) {
          final map = Map<String, dynamic>.from(raw as Map);
          final rev = Review.fromMap(map, map['id']?.toString() ?? '');
          _saveMockDirect(rev);
        }
      }
      _loadedUsers.add(userId);
    } catch (_) {}
  }

  static void _saveMockDirect(Review review) {
    _mockReviews.putIfAbsent(review.animeId, () => []);
    final list = _mockReviews[review.animeId]!;
    list.removeWhere((r) => r.id == review.id || (r.userId == review.userId && r.animeId == review.animeId));
    list.insert(0, review);
    _mockStreamController.add(_mockReviews);
  }

  // ============ REVIEW PUBLIK PER ANIME ============

  @override
  Stream<List<Review>> getReviewsForAnime(int animeId) {
    final sb = _supabase;
    if (!AppConfig.useSupabase || !SupabaseService.isInitialized || sb == null) {
      return _mockStreamController.stream
          .map((all) => all[animeId] ?? [])
          .asBroadcastStream();
    }

    // Menggunakan stream realtime Supabase jika aktif, dengan fallback ke mock
    return sb
        .from('reviews')
        .stream(primaryKey: ['id'])
        .eq('anime_id', animeId)
        .order('created_at', ascending: false)
        .map((data) {
          return data.map((d) {
            final overall = (d['rating'] as num?)?.toDouble() ?? 8.0;
            return Review(
              id: d['id'] as String,
              animeId: (d['anime_id'] as num).toInt(),
              userId: d['user_id'] as String,
              username: d['username'] as String? ?? 'User',
              avatarUrl: d['user_avatar_url'] as String?,
              overallScore: overall,
              content: d['content'] as String? ?? '',
              likeCount: (d['likes_count'] as num?)?.toInt() ?? 0,
              createdAt: DateTime.tryParse(d['created_at'].toString()) ?? DateTime.now(),
              ratings: ReviewRating(
                story: overall,
                animation: overall,
                sound: overall,
                character: overall,
                enjoyment: overall,
              ),
              title: '',
              isRecommended: overall >= 7.0,
              hasSpoiler: false,
            );
          }).toList();
        });
  }

  @override
  Future<void> submitReview(Review review) async {
    _saveMock(review);
    await _saveCacheToPrefs(review.userId);

    final sb = _supabase;
    if (sb != null) {
      final offline = AnimeOfflineDb.getByIdSync(review.animeId);
      final title = review.animeTitle ?? offline?.title ?? '';
      final cover = review.animeImageUrl ?? offline?.imageUrl ?? '';
      final totalEp = review.totalEpisodes ?? offline?.episodes;

      try {
        await sb.from('reviews').upsert({
          'id': review.id,
          'anime_id': review.animeId,
          'user_id': review.userId,
          'username': review.username,
          'user_avatar_url': review.avatarUrl,
          'anime_title': title,
          'anime_cover_url': cover,
          'rating': review.overallScore,
          'content': review.content,
          'likes_count': review.likeCount,
          'created_at': review.createdAt.toIso8601String(),
          'watch_status': review.watchStatus,
          'watched_episodes': review.watchedEpisodes,
          'total_episodes': totalEp,
          'is_completed': review.isCompleted,
        });
      } catch (_) {
        try {
          await sb.from('reviews').upsert({
            'id': review.id,
            'anime_id': review.animeId,
            'user_id': review.userId,
            'username': review.username,
            'user_avatar_url': review.avatarUrl,
            'anime_title': title,
            'anime_cover_url': cover,
            'rating': review.overallScore,
            'content': review.content,
            'likes_count': review.likeCount,
            'created_at': review.createdAt.toIso8601String(),
          });
        } catch (_) {
          try {
            await sb.from('reviews').upsert({
              'id': review.id,
              'anime_id': review.animeId,
              'user_id': review.userId,
              'username': review.username,
              'user_avatar_url': review.avatarUrl,
              'rating': review.overallScore,
              'content': review.content,
              'likes_count': review.likeCount,
              'created_at': review.createdAt.toIso8601String(),
            });
          } catch (_) {}
        }
      }
    }
  }

  @override
  Future<void> toggleLike(String reviewId, int animeId, String userId) async {
    final list = _mockReviews[animeId];
    if (list != null) {
      final idx = list.indexWhere((r) => r.id == reviewId);
      if (idx != -1) {
        final r = list[idx];
        list[idx] = Review(
          id: r.id,
          animeId: r.animeId,
          userId: r.userId,
          username: r.username,
          avatarUrl: r.avatarUrl,
          animeTitle: r.animeTitle,
          animeImageUrl: r.animeImageUrl,
          watchedEpisodes: r.watchedEpisodes,
          totalEpisodes: r.totalEpisodes,
          isCompleted: r.isCompleted,
          watchStatus: r.watchStatus,
          ratings: r.ratings,
          overallScore: r.overallScore,
          title: r.title,
          content: r.content,
          isRecommended: r.isRecommended,
          hasSpoiler: r.hasSpoiler,
          likeCount: r.likeCount + 1,
          createdAt: r.createdAt,
        );
        _mockStreamController.add(_mockReviews);
      }
    }
  }

  // ============ ENTRI MILIK USER ============

  Review _parseReview(Map<String, dynamic> d) {
    final overall = (d['rating'] as num?)?.toDouble() ?? 8.0;
    final animeId = (d['anime_id'] as num).toInt();
    final offline = AnimeOfflineDb.getByIdSync(animeId);
    final animeTitle = (d['anime_title'] as String?) ?? offline?.title;
    final animeImageUrl = (d['anime_cover_url'] as String?) ?? offline?.imageUrl;

    final totalEp = (d['total_episodes'] as num?)?.toInt() ??
        (d['totalEpisodes'] as num?)?.toInt() ??
        offline?.episodes;
    final isComp = (d['is_completed'] == true) || (d['watch_status'] == 'completed');
    int? watchedEp = (d['watched_episodes'] as num?)?.toInt() ??
        (d['watchedEpisodes'] as num?)?.toInt();
    if (watchedEp == null || watchedEp == 0) {
      if (isComp && totalEp != null && totalEp > 0) {
        watchedEp = totalEp;
      }
    }

    return Review(
      id: d['id'] as String,
      animeId: animeId,
      userId: d['user_id'] as String,
      username: d['username'] as String? ?? 'User',
      avatarUrl: d['user_avatar_url'] as String?,
      animeTitle: animeTitle,
      animeImageUrl: animeImageUrl,
      watchedEpisodes: watchedEp,
      totalEpisodes: totalEp,
      isCompleted: isComp,
      watchStatus: (d['watch_status'] as String?) ?? (isComp ? 'completed' : 'watching'),
      overallScore: overall,
      content: d['content'] as String? ?? '',
      likeCount: (d['likes_count'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.tryParse(d['created_at'].toString()) ?? DateTime.now(),
      ratings: ReviewRating(
        story: overall,
        animation: overall,
        sound: overall,
        character: overall,
        enjoyment: overall,
      ),
      title: (d['title'] as String?) ?? '',
      isRecommended: overall >= 7.0,
      hasSpoiler: false,
    );
  }

  @override
  Stream<Review?> watchUserEntry(int animeId, String userId) {
    return Stream<Review?>.multi((controller) {
      final currentList = _mockReviews[animeId] ?? [];
      Review? current;
      for (final r in currentList) {
        if (r.userId == userId) {
          current = r;
          break;
        }
      }
      controller.add(current);

      _loadCacheFromPrefs(userId).then((_) {
        final list = _mockReviews[animeId] ?? [];
        for (final r in list) {
          if (r.userId == userId) {
            controller.add(r);
            break;
          }
        }
      }).catchError((_) {});

      final sb = _supabase;
      if (AppConfig.useSupabase && SupabaseService.isInitialized && sb != null) {
        sb
            .from('reviews')
            .select()
            .eq('anime_id', animeId)
            .eq('user_id', userId)
            .maybeSingle()
            .then((d) {
              if (d != null) {
                final r = _parseReview(Map<String, dynamic>.from(d));
                _saveMock(r);
                controller.add(r);
              }
            })
            .catchError((_) {});
      }

      final sub = _mockStreamController.stream.listen((all) {
        final list = all[animeId] ?? [];
        Review? found;
        for (final r in list) {
          if (r.userId == userId) {
            found = r;
            break;
          }
        }
        controller.add(found);
      });

      controller.onCancel = () => sub.cancel();
    });
  }

  @override
  Stream<List<Review>> watchUserReviews(String userId) {
    return Stream<List<Review>>.multi((controller) {
      final mine = _mockReviews.values
          .expand((list) => list)
          .where((r) => r.userId == userId)
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      controller.add(mine);

      _loadCacheFromPrefs(userId).then((_) {
        final cached = _mockReviews.values
            .expand((list) => list)
            .where((r) => r.userId == userId)
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        if (cached.isNotEmpty) {
          controller.add(cached);
        }
      }).catchError((_) {});

      final sb = _supabase;
      if (AppConfig.useSupabase && SupabaseService.isInitialized && sb != null) {
        sb
            .from('reviews')
            .select()
            .eq('user_id', userId)
            .order('created_at', ascending: false)
            .then((data) {
              final list = (data as List)
                  .map((d) => _parseReview(Map<String, dynamic>.from(d as Map)))
                  .toList();
              for (final r in list) {
                _saveMock(r);
              }
              controller.add(list);
            })
            .catchError((_) {});
      }

      final sub = _mockStreamController.stream.listen((all) {
        final updated = all.values
            .expand((list) => list)
            .where((r) => r.userId == userId)
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        controller.add(updated);
      });

      controller.onCancel = () => sub.cancel();
    });
  }

  @override
  Stream<List<UserAnimeEntry>> watchUserList(String userId) {
    return Stream<List<UserAnimeEntry>>.multi((controller) {
      final map = _mockUserList[userId] ?? {};
      final list = map.values.toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      controller.add(list);

      _loadCacheFromPrefs(userId).then((_) {
        final currentMap = _mockUserList[userId] ?? {};
        if (currentMap.isNotEmpty) {
          final currentList = currentMap.values.toList()
            ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
          controller.add(currentList);
        }
      }).catchError((_) {});

      final sb = _supabase;
      if (AppConfig.useSupabase && SupabaseService.isInitialized && sb != null) {
        Future.wait([
          sb
              .from('status_updates')
              .select()
              .eq('user_id', userId)
              .order('created_at', ascending: false),
          sb
              .from('reviews')
              .select()
              .eq('user_id', userId)
              .order('created_at', ascending: false),
        ]).then((results) async {
          final entries = <UserAnimeEntry>[];
          final seenAnimeIds = <int>{};

          // 1. Dari status_updates
          for (final raw in results[0] as List) {
            final d = Map<String, dynamic>.from(raw as Map);
            final animeId = (d['anime_id'] as num?)?.toInt() ?? 0;
            if (animeId <= 0) continue;
            String title = (d['anime_title'] as String?)?.trim() ?? '';
            String? imageUrl = (d['anime_cover_url'] as String?)?.trim();

            final offline = AnimeOfflineDb.getByIdSync(animeId) ?? await AnimeOfflineDb.getById(animeId);
            if (offline != null) {
              if (title.isEmpty || title == 'Tanpa Judul') {
                title = offline.title;
              }
              if (imageUrl == null || imageUrl.isEmpty) {
                imageUrl = offline.imageUrl;
              }
            }

            if (animeId > 0 && title.isNotEmpty && title != 'Tanpa Judul') {
              seenAnimeIds.add(animeId);
              final totalEp = (d['total_episodes'] as num?)?.toInt() ?? offline?.episodes;
              final isComp = (d['watch_status'] ?? '') == 'completed';
              final localEntry = _mockUserList[userId]?[animeId];
              int watchedEp = (d['watched_episodes'] as num?)?.toInt() ??
                  (d['watchedEpisodes'] as num?)?.toInt() ??
                  localEntry?.watchedEpisodes ??
                  (isComp ? (totalEp ?? 0) : 0);
              if (isComp && watchedEp == 0 && totalEp != null && totalEp > 0) {
                watchedEp = totalEp;
              }

              final entry = UserAnimeEntry(
                animeId: animeId,
                title: title,
                imageUrl: (imageUrl != null && imageUrl.isNotEmpty) ? imageUrl : null,
                watchStatus: d['watch_status'] as String? ?? 'completed',
                watchedEpisodes: watchedEp,
                totalEpisodes: totalEp,
                isCompleted: isComp,
                overallScore: (d['rating'] as num?)?.toDouble() ?? 0.0,
                reviewId: d['id'] as String? ?? '',
                updatedAt: DateTime.tryParse(d['created_at'].toString()) ?? DateTime.now(),
              );
              entries.add(entry);
              _mockUserList.putIfAbsent(userId, () => {})[animeId] = entry;
            }
          }

          // 2. Dari reviews
          for (final raw in results[1] as List) {
            final d = Map<String, dynamic>.from(raw as Map);
            final animeId = (d['anime_id'] as num?)?.toInt() ?? 0;
            if (animeId <= 0 || seenAnimeIds.contains(animeId)) continue;
            String title = (d['anime_title'] as String?)?.trim() ?? '';
            String? imageUrl = (d['anime_cover_url'] as String?)?.trim();

            final offline = AnimeOfflineDb.getByIdSync(animeId) ?? await AnimeOfflineDb.getById(animeId);
            if (offline != null) {
              if (title.isEmpty || title == 'Tanpa Judul') {
                title = offline.title;
              }
              if (imageUrl == null || imageUrl.isEmpty) {
                imageUrl = offline.imageUrl;
              }
            }

            if (animeId > 0 && title.isNotEmpty && title != 'Tanpa Judul') {
              seenAnimeIds.add(animeId);
              final score = (d['rating'] as num?)?.toDouble() ?? 0.0;
              final totalEp = (d['total_episodes'] as num?)?.toInt() ?? offline?.episodes;
              final isComp = (d['is_completed'] == true) || (d['watch_status'] == 'completed') || (d['watch_status'] == null);
              final localEntry = _mockUserList[userId]?[animeId];
              int watchedEp = (d['watched_episodes'] as num?)?.toInt() ??
                  (d['watchedEpisodes'] as num?)?.toInt() ??
                  localEntry?.watchedEpisodes ??
                  (isComp ? (totalEp ?? 0) : 0);
              if (isComp && watchedEp == 0 && totalEp != null && totalEp > 0) {
                watchedEp = totalEp;
              }

              final entry = UserAnimeEntry(
                animeId: animeId,
                title: title,
                imageUrl: (imageUrl != null && imageUrl.isNotEmpty) ? imageUrl : null,
                watchStatus: d['watch_status'] as String? ?? 'completed',
                watchedEpisodes: watchedEp,
                totalEpisodes: totalEp,
                isCompleted: isComp,
                overallScore: score,
                reviewId: d['id'] as String? ?? '',
                updatedAt: DateTime.tryParse(d['created_at'].toString()) ?? DateTime.now(),
              );
              entries.add(entry);
              _mockUserList.putIfAbsent(userId, () => {})[animeId] = entry;
            }
          }

          if (entries.isNotEmpty) {
            _saveCacheToPrefs(userId);
            _mockUserController.add(_mockUserList);
            controller.add(entries);
          }
        }).catchError((_) {});
      }

      final sub = _mockUserController.stream.listen((allUsers) {
        final currentMap = allUsers[userId] ?? {};
        final currentList = currentMap.values.toList()
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        controller.add(currentList);
      });

      controller.onCancel = () => sub.cancel();
    });
  }

  @override
  Future<void> updateWatchStatus({
    required int animeId,
    required String reviewId,
    required String userId,
    String? watchStatus,
    int? watchedEpisodes,
    bool? isCompleted,
  }) async {
    _updateMock(animeId, reviewId, watchStatus, watchedEpisodes, isCompleted);
    await _saveCacheToPrefs(userId);

    final sb = _supabase;
    if (sb != null && reviewId.isNotEmpty) {
      try {
        await sb.from('reviews').update({
          'watch_status': ?watchStatus,
          'watched_episodes': ?watchedEpisodes,
          'is_completed': ?isCompleted,
        }).eq('id', reviewId);
      } catch (_) {}

      try {
        await sb.from('status_updates').update({
          'watch_status': ?watchStatus,
          'watched_episodes': ?watchedEpisodes,
        }).eq('id', reviewId);
      } catch (_) {}
    }
  }

  @override
  Future<void> deleteUserEntry({
    required int animeId,
    required String reviewId,
    required String userId,
  }) async {
    _deleteMock(animeId, reviewId, userId);
    await _saveCacheToPrefs(userId);

    final sb = _supabase;
    if (AppConfig.useSupabase && SupabaseService.isInitialized && sb != null) {
      try {
        await sb.from('reviews').delete().eq('id', reviewId);
      } catch (_) {}
      try {
        await sb.from('status_updates').delete().eq('id', reviewId);
      } catch (_) {}
    }
  }

  // ============ HELPERS ============

  UserAnimeEntry _entryFromReview(Review r) {
    var title = r.animeTitle?.trim() ?? '';
    var imageUrl = r.animeImageUrl?.trim();
    final offline = AnimeOfflineDb.getByIdSync(r.animeId);
    if (title.isEmpty || title == 'Tanpa Judul' || imageUrl == null || imageUrl.isEmpty) {
      if (offline != null) {
        if (title.isEmpty || title == 'Tanpa Judul') {
          title = offline.title;
        }
        if (imageUrl == null || imageUrl.isEmpty) {
          imageUrl = offline.imageUrl;
        }
      }
    }

    final totalEp = r.totalEpisodes ?? offline?.episodes;
    final isComp = r.isCompleted || r.watchStatus == 'completed';
    int watchedEp = r.watchedEpisodes ?? 0;
    if (isComp && watchedEp == 0 && totalEp != null && totalEp > 0) {
      watchedEp = totalEp;
    }

    return UserAnimeEntry(
      animeId: r.animeId,
      title: title.isNotEmpty ? title : 'Anime #${r.animeId}',
      imageUrl: (imageUrl != null && imageUrl.isNotEmpty) ? imageUrl : null,
      watchStatus: r.watchStatus,
      watchedEpisodes: watchedEp,
      totalEpisodes: totalEp,
      isCompleted: isComp,
      overallScore: r.overallScore,
      reviewId: r.id,
      updatedAt: r.createdAt,
    );
  }

  void _saveMock(Review review) {
    _mockReviews.putIfAbsent(review.animeId, () => []);
    final list = _mockReviews[review.animeId]!;
    list.removeWhere((r) => r.id == review.id || (r.userId == review.userId && r.animeId == review.animeId));
    list.insert(0, review);
    _mockStreamController.add(_mockReviews);

    _mockUserList.putIfAbsent(review.userId, () => {});
    _mockUserList[review.userId]![review.animeId] = _entryFromReview(review);
    _mockUserController.add(_mockUserList);
  }

  void _updateMock(int animeId, String reviewId, String? status,
      int? watched, bool? completed) {
    final list = _mockReviews[animeId];
    if (list != null) {
      final idx = list.indexWhere((r) => r.id == reviewId);
      if (idx != -1) {
        final r = list[idx];
        final offline = AnimeOfflineDb.getByIdSync(animeId);
        final totalEp = r.totalEpisodes ?? offline?.episodes;
        final comp = completed ?? r.isCompleted;
        int? w = watched ?? r.watchedEpisodes;
        if (comp && (w == null || w == 0) && totalEp != null && totalEp > 0) {
          w = totalEp;
        }

        list[idx] = Review(
          id: r.id,
          animeId: r.animeId,
          userId: r.userId,
          username: r.username,
          avatarUrl: r.avatarUrl,
          animeTitle: r.animeTitle,
          animeImageUrl: r.animeImageUrl,
          watchedEpisodes: w,
          totalEpisodes: totalEp,
          isCompleted: comp,
          watchStatus: status ?? r.watchStatus,
          ratings: r.ratings,
          overallScore: r.overallScore,
          title: r.title,
          content: r.content,
          isRecommended: r.isRecommended,
          hasSpoiler: r.hasSpoiler,
          likeCount: r.likeCount,
          createdAt: r.createdAt,
        );
        _mockStreamController.add(_mockReviews);
      }
    }

    final uid = list?.indexWhere((r) => r.id == reviewId) != -1
        ? list?.firstWhere((r) => r.id == reviewId).userId
        : null;
    final targetUid = uid ?? _mockUserList.keys.firstWhere((k) => _mockUserList[k]?[animeId] != null, orElse: () => '');
    if (targetUid.isNotEmpty && _mockUserList[targetUid]?[animeId] != null) {
      final e = _mockUserList[targetUid]![animeId]!;
      final offline = AnimeOfflineDb.getByIdSync(animeId);
      final totalEp = e.totalEpisodes ?? offline?.episodes;
      final comp = completed ?? e.isCompleted;
      int w = watched ?? e.watchedEpisodes;
      if (comp && w == 0 && totalEp != null && totalEp > 0) {
        w = totalEp;
      }
      _mockUserList[targetUid]![animeId] = UserAnimeEntry(
        animeId: e.animeId,
        title: e.title,
        imageUrl: e.imageUrl,
        watchStatus: status ?? e.watchStatus,
        watchedEpisodes: w,
        totalEpisodes: totalEp,
        isCompleted: comp,
        overallScore: e.overallScore,
        reviewId: e.reviewId,
        updatedAt: DateTime.now(),
      );
      _mockUserController.add(_mockUserList);
    }
  }

  void _deleteMock(int animeId, String reviewId, String userId) {
    _mockReviews[animeId]?.removeWhere((r) => r.id == reviewId);
    _mockStreamController.add(_mockReviews);
    _mockUserList[userId]?.remove(animeId);
    _mockUserList[userId]?.removeWhere((k, v) => v.reviewId == reviewId);
    _mockUserController.add(_mockUserList);
  }
}
