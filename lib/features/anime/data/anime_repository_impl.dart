import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/anime.dart';
import '../domain/anime_repository.dart';
import 'anilist_api.dart';
import 'anime_database_cache.dart';
import 'anime_firestore_cache.dart';
import 'anime_offline_db.dart';
import 'anime_rag_search_service.dart';
import 'jikan_api.dart';
import 'llm_search_service.dart';

class AnimeRepositoryImpl implements AnimeRepository {
  final JikanApi _api;
  final AniListApi _aniList;
  final LlmSearchService _llm;
  final AnimeRagSearchService _ragService;

  AnimeRepositoryImpl({
    JikanApi? api,
    AniListApi? aniList,
    AnimeRagSearchService? ragService,
  })  : _api = api ?? JikanApi(),
        _aniList = aniList ?? AniListApi(),
        _llm = LlmSearchService(),
        _ragService = ragService ?? AnimeRagSearchService();

  static const _cacheKeyTop = 'cache_top_rated';
  static const _cacheKeySeason = 'cache_season_now';
  static const _cacheKeyTrending = 'cache_trending';
  static const _cacheTtl = 24 * 60 * 60 * 1000; // 24 hours
  static final Map<int, Anime> _detailCache = {};
  static final Map<String, List<Anime>> _searchCache = {};

  @override
  Anime? getCachedDetail(int id) => _detailCache[id];

  static void cacheDetail(Anime anime) {
    _detailCache[anime.id] = anime;
  }

  Future<void> _setCache(String key, List<Anime> list) async {
    try {
      final prefs = SharedPreferencesAsync();
      final now = DateTime.now().millisecondsSinceEpoch;
      final payload = jsonEncode({
        't': now,
        'd': list.map((a) => _animeToJson(a)).toList(),
      });
      await prefs.setString(key, payload);
    } catch (_) {}
  }

  Future<List<Anime>> _getCache(String key) async {
    try {
      final prefs = SharedPreferencesAsync();
      final raw = await prefs.getString(key);
      if (raw == null) return [];
      final parsed = jsonDecode(raw) as Map<String, dynamic>;
      final ts = parsed['t'] as int;
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now - ts > _cacheTtl) return [];
      final items = (parsed['d'] as List<dynamic>).map((e) {
        final m = Map<String, dynamic>.from(e as Map);
        return Anime.fromJson(m);
      }).toList();
      return items;
    } catch (_) {
      return [];
    }
  }

  Map<String, dynamic> _animeToJson(Anime a) => {
    'mal_id': a.id,
    'title': a.title,
    'title_english': a.titleEnglish,
    'title_japanese': a.titleJapanese,
    'synopsis': a.synopsis,
    'images': {
      'jpg': {'large_image_url': a.imageUrl},
    },
    'score': a.score,
    'episodes': a.episodes,
    'status': a.status,
    'format': a.format,
    'genres': a.genres.map((g) => {'name': g}).toList(),
    'year': a.year,
  };

  @override
  Future<List<Anime>> getTrending() async {
    final cached = await _getCache(_cacheKeyTrending);
    if (cached.isNotEmpty) {
      _refreshTrendingInBackground();
      return _sanitizeFeed(cached, sortByPopularity: true).take(20).toList();
    }
    final offline = await AnimeOfflineDb.getTopRated(limit: 30);
    if (offline.isNotEmpty) {
      final sanitized = _sanitizeFeed(offline, sortByPopularity: true).take(20).toList();
      unawaited(_setCache(_cacheKeyTrending, sanitized));
      _refreshTrendingInBackground();
      return sanitized;
    }
    try {
      final list = await _aniList.getTrending().timeout(const Duration(seconds: 3));
      if (list.isNotEmpty) {
        await _setCache(_cacheKeyTrending, list);
        AnimeFirestoreCache.saveAnimeList(list);
        return _sanitizeFeed(list, sortByPopularity: true).take(20).toList();
      }
    } catch (_) {}
    return [];
  }

  void _refreshTrendingInBackground() {
    unawaited(() async {
      try {
        final list = await _aniList.getTrending().timeout(const Duration(seconds: 4));
        if (list.isNotEmpty) {
          await _setCache(_cacheKeyTrending, list);
          AnimeFirestoreCache.saveAnimeList(list);
        }
      } catch (_) {
        try {
          final list = await _api.getTopRated(page: 1).timeout(const Duration(seconds: 4));
          if (list.isNotEmpty) {
            await _setCache(_cacheKeyTrending, list);
          }
        } catch (_) {}
      }
    }());
  }

  @override
  Future<List<Anime>> getTopRated({int page = 1}) async {
    if (page == 1) {
      final cached = await _getCache(_cacheKeyTop);
      if (cached.isNotEmpty) {
        _refreshTopRatedInBackground();
        return _sanitizeFeed(cached);
      }
      final offline = await AnimeOfflineDb.getTopRated(limit: 30);
      if (offline.isNotEmpty) {
        final sanitized = _sanitizeFeed(offline);
        unawaited(_setCache(_cacheKeyTop, sanitized));
        _refreshTopRatedInBackground();
        return sanitized;
      }
    }
    try {
      final list = await _api.getTopRated(page: page).timeout(const Duration(seconds: 4));
      if (list.isNotEmpty) {
        if (page == 1) await _setCache(_cacheKeyTop, list);
        AnimeFirestoreCache.saveAnimeList(list);
        return _sanitizeFeed(list);
      }
    } catch (_) {}
    try {
      final list = await _aniList.searchAnime('', page: page, orderBy: 'score').timeout(const Duration(seconds: 4));
      if (list.isNotEmpty) {
        if (page == 1) await _setCache(_cacheKeyTop, list);
        AnimeFirestoreCache.saveAnimeList(list);
        return _sanitizeFeed(list);
      }
    } catch (_) {}
    return _sanitizeFeed(await AnimeOfflineDb.getTopRated());
  }

  void _refreshTopRatedInBackground() {
    unawaited(() async {
      try {
        final list = await _api.getTopRated(page: 1).timeout(const Duration(seconds: 4));
        if (list.isNotEmpty) {
          await _setCache(_cacheKeyTop, list);
          AnimeFirestoreCache.saveAnimeList(list);
        }
      } catch (_) {
        try {
          final list = await _aniList.searchAnime('', page: 1, orderBy: 'score').timeout(const Duration(seconds: 4));
          if (list.isNotEmpty) {
            await _setCache(_cacheKeyTop, list);
            AnimeFirestoreCache.saveAnimeList(list);
          }
        } catch (_) {}
      }
    }());
  }

  @override
  Future<List<Anime>> getCurrentSeason() async {
    final cached = await _getCache(_cacheKeySeason);
    if (cached.isNotEmpty) {
      _refreshSeasonInBackground();
      return _sanitizeFeed(cached);
    }
    final offline = await AnimeOfflineDb.getTopRated(limit: 30);
    if (offline.isNotEmpty) {
      final sanitized = _sanitizeFeed(offline).take(20).toList();
      unawaited(_setCache(_cacheKeySeason, sanitized));
      _refreshSeasonInBackground();
      return sanitized;
    }
    try {
      final list = await _api.getCurrentSeason().timeout(const Duration(seconds: 4));
      if (list.isNotEmpty) {
        await _setCache(_cacheKeySeason, list);
        AnimeFirestoreCache.saveAnimeList(list);
        return _sanitizeFeed(list);
      }
    } catch (_) {}
    return _sanitizeFeed(await AnimeOfflineDb.getTopRated());
  }

  void _refreshSeasonInBackground() {
    unawaited(() async {
      try {
        final list = await _api.getCurrentSeason().timeout(const Duration(seconds: 4));
        if (list.isNotEmpty) {
          await _setCache(_cacheKeySeason, list);
          AnimeFirestoreCache.saveAnimeList(list);
        }
      } catch (_) {
        try {
          final list = await _aniList.getCurrentSeason().timeout(const Duration(seconds: 4));
          if (list.isNotEmpty) {
            await _setCache(_cacheKeySeason, list);
            AnimeFirestoreCache.saveAnimeList(list);
          }
        } catch (_) {}
      }
    }());
  }

  @override
  Future<List<Anime>> getUpcomingSeason() async {
    const constKey = 'cache_season_upcoming';
    final cached = await _getCache(constKey);
    if (cached.isNotEmpty) {
      _refreshUpcomingInBackground();
      return _sanitizeFeed(cached);
    }
    final offline = await AnimeOfflineDb.getUpcoming(limit: 30);
    if (offline.isNotEmpty) {
      final sanitized = _sanitizeFeed(offline).take(20).toList();
      unawaited(_setCache(constKey, sanitized));
      _refreshUpcomingInBackground();
      return sanitized;
    }
    try {
      final list = await _api.getUpcomingSeason().timeout(const Duration(seconds: 4));
      if (list.isNotEmpty) {
        await _setCache(constKey, list);
        AnimeFirestoreCache.saveAnimeList(list);
        return _sanitizeFeed(list);
      }
    } catch (_) {}
    return _sanitizeFeed(await AnimeOfflineDb.getUpcoming());
  }

  void _refreshUpcomingInBackground() {
    unawaited(() async {
      const constKey = 'cache_season_upcoming';
      try {
        final list = await _api.getUpcomingSeason().timeout(const Duration(seconds: 4));
        if (list.isNotEmpty) {
          await _setCache(constKey, list);
          AnimeFirestoreCache.saveAnimeList(list);
        }
      } catch (_) {
        try {
          final list = await _aniList.getUpcomingSeason().timeout(const Duration(seconds: 4));
          if (list.isNotEmpty) {
            await _setCache(constKey, list);
            AnimeFirestoreCache.saveAnimeList(list);
          }
        } catch (_) {}
      }
    }());
  }

  @override
  Future<List<Anime>> searchAnime(
    String query, {
    int page = 1,
    List<int>? genres,
    String? status,
    String? orderBy,
    bool allowAdult = false,
  }) async {
    final q = query.trim();
    final hasGenre = genres != null && genres.isNotEmpty;
    final hasFilter = hasGenre || status != null || orderBy != null;
    if (q.isEmpty && !hasFilter) return [];

    final cacheKey =
        '${q.toLowerCase()}_${genres?.join(',')}_${status}_${orderBy}_$allowAdult';
    if (_searchCache.containsKey(cacheKey)) {
      return _searchCache[cacheKey]!;
    }

    // 1. Offline DB strict & ranked search (instan & akurat <3 ms)
    final isDescriptive = _ragService.isDescriptiveQuery(q);
    if (q.isNotEmpty && !isDescriptive) {
      try {
        final offline = await AnimeOfflineDb.search(q);
        final processed = _postProcess(
          offline,
          q,
          genres: genres,
          status: status,
          orderBy: orderBy,
          strictRealness: false, // database lokal = judul resmi MAL
          allowAdult: allowAdult,
        );
        if (processed.isNotEmpty) {
          _searchCache[cacheKey] = processed;
          return processed;
        }
      } catch (_) {}
    }

    // 2. RAG Semantic Search (Retrieval-Augmented Generation):
    // Memahami kueri deskriptif / konsep / alur cerita / bahasa Indonesia / karakter
    if (q.length >= 3 && !hasFilter) {
      try {
        final ragResult = await _ragService.searchWithRag(q);
        if (ragResult != null && ragResult.animes.isNotEmpty) {
          final processedRag = _postProcess(
            ragResult.animes,
            q,
            genres: genres,
            status: status,
            orderBy: orderBy,
            strictRealness: false,
            allowAdult: allowAdult,
          );
          if (processedRag.isNotEmpty) {
            AnimeDatabaseCache.saveAnimeList(processedRag);
            _searchCache[cacheKey] = processedRag;
            return processedRag;
          }
        }
      } catch (_) {}
    }

    // 3. Fallback pencarian database lokal / Supabase cached_animes
    try {
      final dbMatches = await AnimeDatabaseCache.searchLocal(query: q);
      if (dbMatches.isNotEmpty) {
        final processedDb = _postProcess(
          dbMatches,
          q,
          genres: genres,
          status: status,
          orderBy: orderBy,
          strictRealness: false,
          allowAdult: allowAdult,
        );
        if (processedDb.isNotEmpty) {
          _searchCache[cacheKey] = processedDb;
          return processedDb;
        }
      }
    } catch (_) {}

    // 4. API search (AniList / Jikan) hanya jika query >= 3 karakter atau ada filter spesifik
    if (q.length >= 3 || hasFilter) {
      final raw = await _searchOnce(q,
              page: page, genres: genres, status: status, orderBy: orderBy)
          .timeout(const Duration(milliseconds: 2500), onTimeout: () => []);
      final results = _postProcess(
        raw,
        q,
        genres: genres,
        status: status,
        orderBy: orderBy,
        strictRealness: true, // buang MV/entri obskur dari API live
        allowAdult: allowAdult,
      );
      if (results.isNotEmpty) {
        AnimeDatabaseCache.saveAnimeList(results);
        _searchCache[cacheKey] = results;
        return results;
      }
    }

    // 3. Fallback khusus genre-only (tanpa teks): curated lalu offline umum
    if (hasGenre) {
      try {
        final curated = await AnimeOfflineDb.getTopByGenre(
          _genreNameFromId(genres.first),
          limit: 30,
        );
        if (curated.isNotEmpty) {
          _searchCache[cacheKey] = curated;
          return curated;
        }
      } catch (_) {}
      try {
        final offlineGenre = await AnimeOfflineDb.getByGenre(
          _genreNameFromId(genres.first),
          limit: 30,
          seriesOnly: false,
        );
        if (offlineGenre.isNotEmpty) {
          _searchCache[cacheKey] = offlineGenre;
          return offlineGenre;
        }
      } catch (_) {}
    }

    // 4. LLM fallback: hanya jika query panjang >= 3 dan tidak ada filter
    if (q.length >= 3 && !hasFilter) {
      try {
        final llmTitle = await _llm.normalizeQuery(q).timeout(
              const Duration(seconds: 2),
              onTimeout: () => null,
            );
        if (llmTitle != null && llmTitle.toLowerCase() != q.toLowerCase()) {
          try {
            final offlineLlm = await AnimeOfflineDb.search(llmTitle);
            final processedLlm = _postProcess(
              offlineLlm,
              llmTitle,
              genres: genres,
              status: status,
              orderBy: orderBy,
              strictRealness: false,
              allowAdult: allowAdult,
            );
            if (processedLlm.isNotEmpty) {
              _searchCache[cacheKey] = processedLlm;
              return processedLlm;
            }
          } catch (_) {}
          final raw2 = await _searchOnce(llmTitle,
                  page: page, genres: genres, status: status, orderBy: orderBy)
              .timeout(const Duration(milliseconds: 2000), onTimeout: () => []);
          final results2 = _postProcess(
            raw2,
            llmTitle,
            genres: genres,
            status: status,
            orderBy: orderBy,
            strictRealness: true,
            allowAdult: allowAdult,
          );
          if (results2.isNotEmpty) {
            AnimeFirestoreCache.saveAnimeList(results2);
            _searchCache[cacheKey] = results2;
            return results2;
          }
        }
      } catch (_) {}
    }

    // 5. Firestore cache last resort
    try {
      final local = await AnimeFirestoreCache.searchLocal(query: q);
      if (local.isNotEmpty) {
        _searchCache[cacheKey] = local;
        return local;
      }
    } catch (_) {}
    return [];
  }

  /// Normalisasi judul untuk deduplication: huruf kecil, buang tanda baca & spasi berlebih.
  static String _normalizeTitle(String t) =>
      t.toLowerCase().replaceAll(RegExp(r'[^a-z0-9\s]'), '').replaceAll(RegExp(r'\s+'), ' ').trim();

  /// Pipeline konsisten untuk SEMUA sumber hasil:
  /// relevansi -> filter user (genre/status/urutan) -> hanya anime sungguhan -> deduplicate.
  List<Anime> _postProcess(
    List<Anime> list,
    String q, {
    List<int>? genres,
    String? status,
    String? orderBy,
    required bool strictRealness,
    bool allowAdult = false,
  }) {
    var out = _filterRelevant(list, q);
    out = _applyUserFilters(out, genres: genres, status: status, orderBy: orderBy);
    out = out.where((a) => _isGenuineAnime(a, strict: strictRealness)).toList();
    out = AnimeSafety.filterList(out, allowAdult: allowAdult);
    // Deduplication by ID + normalized title
    final seenIds = <int>{};
    final seenTitles = <String>{};
    final deduped = <Anime>[];
    for (final a in out) {
      final normTitle = _normalizeTitle(a.title);
      if (seenIds.contains(a.id) || seenTitles.contains(normTitle)) continue;
      seenIds.add(a.id);
      seenTitles.add(normTitle);
      deduped.add(a);
    }
    return deduped.take(40).toList();
  }

  /// Terapkan pilihan user secara seragam — termasuk pada hasil offline
  /// yang sebelumnya lolos tanpa filter.
  List<Anime> _applyUserFilters(
    List<Anime> list, {
    List<int>? genres,
    String? status,
    String? orderBy,
  }) {
    var out = list;

    if (genres != null && genres.isNotEmpty) {
      final names =
          genres.map(_genreNameFromId).where((n) => n.isNotEmpty).toList();
      out = out
          .where((a) => a.genres.any((g) =>
              names.any((n) => g.toLowerCase().contains(n.toLowerCase()))))
          .toList();
    }

    if (status != null && status.isNotEmpty) {
      final wanted = switch (status) {
        'airing' => ['RELEASING', 'CURRENTLY AIRING', 'AIRING'],
        'complete' => ['FINISHED', 'COMPLETE'],
        'upcoming' => ['NOT_YET_RELEASED', 'UPCOMING'],
        _ => <String>[],
      };
      if (wanted.isNotEmpty) {
        out = out.where((a) {
          final s = (a.status ?? '').toUpperCase();
          return wanted.any((w) => s.contains(w));
        }).toList();
      }
    }

    switch (orderBy) {
      case 'score':
        out.sort((a, b) => (b.score ?? 0).compareTo(a.score ?? 0));
      case 'start_date':
        out.sort((a, b) => (b.year ?? 0).compareTo(a.year ?? 0));
      case 'popularity':
        out.sort((a, b) =>
            ((b.members ?? b.popularity ?? 0))
                .compareTo(a.members ?? a.popularity ?? 0));
    }
    return out;
  }

  /// Hanya anime/movie yang benar-benar tayang & cukup dikenal
  /// (muncul di hasil pencarian umum seperti Google).
  bool _isGenuineAnime(Anime a, {required bool strict}) {
    final f = (a.format ?? '').toUpperCase();
    // Video musik / PV / iklan = bukan anime serial maupun film.
    if (f == 'MUSIC' || f == 'PV' || f == 'CM') return false;

    if (!strict) return true;

    // Untuk hasil API live: wajib punya sinyal kredibilitas komunitas.
    final reach = a.members ?? a.popularity ?? 0;
    final credible = reach >= 800 ||
        a.score != null ||
        a.rank != null ||
        (a.favoritesCount ?? 0) >= 15 ||
        (a.episodes != null && a.episodes! >= 4);
    return credible;
  }

  /// Pipeline untuk feed beranda: buang konten dewasa & entri tak dikenal + deduplicate.
  /// [sortByPopularity] mengurutkan berdasarkan jumlah penonton agar
  /// section "Terpopuler" benar-benar menampilkan anime paling populer.
  List<Anime> _sanitizeFeed(List<Anime> list, {bool sortByPopularity = false}) {
    var out = list
        .where(AnimeSafety.isSafe)
        .where((a) => _isGenuineAnime(a, strict: true))
        .toList();
    if (sortByPopularity) {
      out.sort((a, b) => (b.members ?? b.popularity ?? 0)
          .compareTo(a.members ?? a.popularity ?? 0));
    }
    // Deduplication by ID + normalized title
    final seenIds = <int>{};
    final seenTitles = <String>{};
    final deduped = <Anime>[];
    for (final a in out) {
      final normTitle = _normalizeTitle(a.title);
      if (seenIds.contains(a.id) || seenTitles.contains(normTitle)) continue;
      seenIds.add(a.id);
      seenTitles.add(normTitle);
      deduped.add(a);
    }
    return deduped;
  }

  /// Konversi ID genre MAL ke nama genre.
  static const Map<int, String> _genreIdNames = {
    1: 'Action',
    2: 'Adventure',
    4: 'Comedy',
    8: 'Drama',
    10: 'Fantasy',
    22: 'Romance',
    24: 'Sci-Fi',
    36: 'Slice of Life',
    37: 'Supernatural',
  };

  String _genreNameFromId(int id) => _genreIdNames[id] ?? '';

  Future<List<Anime>> _searchOnce(
    String q, {
    int page = 1,
    List<int>? genres,
    String? status,
    String? orderBy,
  }) async {
    final list = <Anime>[];
    final seen = <int>{};

    try {
      final anilistResults = await _aniList.searchAnime(
        q,
        page: page,
        status: status,
        orderBy: orderBy,
        genres: genres?.map(_genreNameFromId).where((n) => n.isNotEmpty).toList(),
      );
      for (final a in anilistResults) {
        if (seen.add(a.id)) {
          list.add(a);
        }
      }
    } catch (_) {}

    try {
      final jikanResults = await _api.searchAnime(
        q,
        page: page,
        genres: genres,
        status: status,
        orderBy: orderBy,
      );
      for (final a in jikanResults) {
        if (seen.add(a.id)) {
          list.add(a);
        }
      }
    } catch (_) {}

    return list;
  }  /// Hanya tampilkan hasil yang benar-benar berhubungan dengan query:
  /// minimal satu kata penting dari query muncul di salah satu varian judul.
  List<Anime> _filterRelevant(List<Anime> list, String q) {
    if (list.isEmpty) return list;
    final tokens = q
        .toLowerCase()
        .split(RegExp(r'[\s:,\-]+'))
        .where((t) => t.length >= 2)
        .toList();
    if (tokens.isEmpty) return list;

    bool relevant(Anime a) {
      final variants = [
        a.title,
        if (a.titleEnglish != null) a.titleEnglish!,
        if (a.titleJapanese != null) a.titleJapanese!,
        ...a.synonyms,
      ].map((s) => s.toLowerCase()).toList();
      return variants.any((v) => tokens.any(v.contains));
    }

    return list.where(relevant).take(40).toList();
  }

  Future<Anime?> _fetchFullDetailFromNetwork(int id) async {
    try {
      final anilistFuture =
          _aniList.getAnimeDetail(id).timeout(const Duration(seconds: 4));
      final jikanFuture =
          _api.getAnimeDetail(id).timeout(const Duration(seconds: 4));

      Anime? fullDetail;
      try {
        final anilistDetail = await anilistFuture;
        try {
          final jikanDetail = await jikanFuture;
          fullDetail = Anime(
            id: jikanDetail.id,
            title: jikanDetail.title.isNotEmpty
                ? jikanDetail.title
                : anilistDetail.title,
            titleEnglish: jikanDetail.titleEnglish ?? anilistDetail.titleEnglish,
            titleJapanese:
                jikanDetail.titleJapanese ?? anilistDetail.titleJapanese,
            synopsis: (jikanDetail.synopsis != null &&
                    jikanDetail.synopsis!.isNotEmpty)
                ? jikanDetail.synopsis
                : anilistDetail.synopsis,
            imageUrl: jikanDetail.imageUrl.isNotEmpty
                ? jikanDetail.imageUrl
                : anilistDetail.imageUrl,
            score: jikanDetail.score ?? anilistDetail.score,
            episodes: jikanDetail.episodes ?? anilistDetail.episodes,
            status: jikanDetail.status ?? anilistDetail.status,
            genres: jikanDetail.genres.isNotEmpty
                ? jikanDetail.genres
                : anilistDetail.genres,
            year: jikanDetail.year ?? anilistDetail.year,
            source: jikanDetail.source ?? anilistDetail.source,
            studios: jikanDetail.studios.isNotEmpty
                ? jikanDetail.studios
                : anilistDetail.studios,
            characters: jikanDetail.characters.length >=
                    anilistDetail.characters.length
                ? jikanDetail.characters
                : anilistDetail.characters,
            durationText:
                jikanDetail.durationText ?? anilistDetail.durationText,
            airedString: jikanDetail.airedString ?? anilistDetail.airedString,
            ratingAge: jikanDetail.ratingAge,
            rank: jikanDetail.rank,
            popularity: jikanDetail.popularity ?? anilistDetail.popularity,
            members: jikanDetail.members,
            favoritesCount:
                jikanDetail.favoritesCount ?? anilistDetail.favoritesCount,
            trailerUrl: jikanDetail.trailerUrl ?? anilistDetail.trailerUrl,
            openingThemes: jikanDetail.openingThemes,
            endingThemes: jikanDetail.endingThemes,
            streamingPlatforms: jikanDetail.streamingPlatforms,
          );
        } catch (_) {
          fullDetail = anilistDetail;
        }
      } catch (_) {
        try {
          fullDetail = await jikanFuture;
        } catch (_) {
          fullDetail = null;
        }
      }
      return fullDetail;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<Anime> getAnimeDetail(int id) async {
    // 1. Cek memory cache (0 ms)
    if (_detailCache.containsKey(id)) {
      return _detailCache[id]!;
    }

    // 2. Ambil data instan dari AnimeOfflineDb sebagai basis terjamin (0 ms)
    final offline = AnimeOfflineDb.getByIdSync(id) ?? await AnimeOfflineDb.getById(id);
    if (offline != null) {
      _detailCache[id] = offline;
      // Perkaya data secara non-blocking di latar belakang
      _fetchFullDetailFromNetwork(id).then((full) {
        if (full != null) {
          _detailCache[id] = full;
          AnimeDatabaseCache.saveAnime(full);
        }
      }).catchError((_) {});
      return offline;
    }

    // 3. Cek database cache (lokal persisten & cloud Supabase)
    final dbCached = await AnimeDatabaseCache.getAnimeById(id);
    if (dbCached != null) {
      _detailCache[id] = dbCached;
      return dbCached;
    }

    // 4. Fallback jika anime belum ada di database lokal/cloud: fetch dari network
    final net = await _fetchFullDetailFromNetwork(id);
    if (net != null) {
      _detailCache[id] = net;
      AnimeDatabaseCache.saveAnime(net);
      return net;
    }

    throw Exception('Gagal memuat detail anime. Periksa koneksi internet.');
  }

  @override
  Stream<Anime> watchAnimeDetail(int id) async* {
    // 1. Pancarkan seketika dari cache memori jika ada (0 ms)
    if (_detailCache.containsKey(id)) {
      final cached = _detailCache[id]!;
      yield cached;
      // Jika data sudah kaya (memiliki karakter/themes/trailer), tidak perlu fetch ulang
      if (cached.characters.isNotEmpty || cached.trailerUrl != null) {
        return;
      }
    }

    // 2. Pancarkan seketika dari AnimeOfflineDb jika ada (0 ms - zero buffering)
    final offline = AnimeOfflineDb.getByIdSync(id) ?? await AnimeOfflineDb.getById(id);
    if (offline != null) {
      _detailCache.putIfAbsent(id, () => offline);
      yield offline;
    } else {
      // 2b. Cek database cache (lokal persisten & cloud Supabase)
      final dbCached = await AnimeDatabaseCache.getAnimeById(id);
      if (dbCached != null) {
        _detailCache[id] = dbCached;
        yield dbCached;
        if (dbCached.characters.isNotEmpty || dbCached.trailerUrl != null) {
          return;
        }
      }
    }

    // 3. Ambil pengayaan lengkap (trailer YouTube, karakter, lagu OP/ED) di latar belakang
    try {
      final fullDetail = await _fetchFullDetailFromNetwork(id);
      if (fullDetail != null) {
        _detailCache[id] = fullDetail;
        AnimeDatabaseCache.saveAnime(fullDetail);
        yield fullDetail;
      }
    } catch (_) {}
  }

  /// Rekomendasi serupa — selalu tersedia untuk setiap anime.
  /// Strategi berlapis:
  ///   1. Rekomendasi komunitas MAL untuk anime tsb.
  ///   2. Anime segenre populer dari AniList (POPULARITY_DESC, skor >= 7.0)
  ///   3. Curated offline per genre
  /// Hasil akhir disaring (aman + genuine) lalu diperingkat:
  /// kemiripan genre dengan anime yang dibuka lebih dulu, baru popularitas.
  @override
  Future<List<Anime>> getRecommendations(int id) async {
    final seen = <int>{id};
    final pool = <Anime>[];

    Anime? base;
    try {
      base = await getAnimeDetail(id);
    } catch (_) {}
    final baseGenres = base?.genres ?? const <String>[];

    // 1. Rekomendasi komunitas MAL
    try {
      for (final a in await _api.getRecommendations(id)) {
        if (seen.add(a.id)) pool.add(a);
      }
    } catch (_) {}

    // 2. Anime segenre populer dari AniList
    if (pool.length < 12 && baseGenres.isNotEmpty) {
      for (final g in baseGenres.take(2)) {
        try {
          final list = await _aniList.searchByGenre(
            g,
            sort: 'POPULARITY_DESC',
            minScore: 70,
          );
          for (final a in list) {
            if (seen.add(a.id)) pool.add(a);
          }
        } catch (_) {}
        if (pool.length >= 24) break;
      }
    }

    // 3. Curated offline per genre
    if (pool.length < 12 && baseGenres.isNotEmpty) {
      for (final g in baseGenres.take(3)) {
        try {
          final list = await AnimeOfflineDb.getTopByGenre(g, limit: 15);
          for (final a in list) {
            if (seen.add(a.id)) pool.add(a);
          }
        } catch (_) {}
        if (pool.length >= 20) break;
      }
    }

    // Saring, lalu peringkat: overlap genre dulu, baru popularitas.
    final safe = pool
        .where(AnimeSafety.isSafe)
        .where((a) => _isGenuineAnime(a, strict: true))
        .toList();

    int genreOverlap(Anime a) =>
        a.genres.where((g) => baseGenres.contains(g)).length;

    safe.sort((a, b) {
      final g = genreOverlap(b).compareTo(genreOverlap(a));
      if (g != 0) return g;
      return (b.members ?? b.popularity ?? 0)
          .compareTo(a.members ?? a.popularity ?? 0);
    });

    return safe.take(15).toList();
  }
}
