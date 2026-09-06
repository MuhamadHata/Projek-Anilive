import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/config/app_config.dart';
import '../../../core/services/supabase_service.dart';
import '../domain/anime.dart';

/// Layanan penyimpanan database terpadu untuk anime:
/// 1. Memory Cache (0 ms)
/// 2. SharedPreferencesAsync Local Persistent Storage (0 ms)
/// 3. Supabase Cloud Database `public.cached_animes` (< 150 ms)
class AnimeDatabaseCache {
  static final Map<int, Anime> _memoryCache = {};
  static final Set<int> _savedIds = {};

  static SupabaseClient? get _supabase =>
      (AppConfig.useSupabase && SupabaseService.isInitialized)
          ? SupabaseService.client
          : null;

  /// Simpan satu anime ke memori, lokal persisten, dan database cloud Supabase
  static Future<void> saveAnime(Anime anime) async {
    _memoryCache[anime.id] = anime;
    _saveToLocal(anime);
    _syncToSupabase(anime);
  }

  /// Simpan batch anime (mis. hasil trending, ranking, season) ke database
  static Future<void> saveAnimeList(List<Anime> list) async {
    for (final anime in list) {
      _memoryCache[anime.id] = anime;
    }
    _saveListToLocal(list);
    _syncListToSupabase(list);
  }

  /// Dapatkan detail anime dari database:
  /// Memori -> Lokal Persisten -> Supabase Cloud
  static Future<Anime?> getAnimeById(int id) async {
    // 1. Cek memory cache (0 ms)
    if (_memoryCache.containsKey(id)) {
      return _memoryCache[id];
    }

    // 2. Cek penyimpanan lokal persisten (0 ms)
    final local = await _loadFromLocal(id);
    if (local != null) {
      _memoryCache[id] = local;
      return local;
    }

    // 3. Cek database cloud Supabase (cepat karena query primary key indeks)
    final sb = _supabase;
    if (sb != null) {
      try {
        final data = await sb
            .from('cached_animes')
            .select()
            .eq('id', id)
            .maybeSingle();

        if (data != null) {
          final anime = fromSupabaseMap(Map<String, dynamic>.from(data));
          _memoryCache[id] = anime;
          _saveToLocal(anime);
          return anime;
        }
      } catch (e) {
        if (kDebugMode) {
          print('Supabase cached_animes get error: $e');
        }
      }
    }

    return null;
  }

  /// Cari anime yang sudah tersimpan di cache lokal
  static Future<List<Anime>> searchLocal({
    required String query,
    int limit = 20,
  }) async {
    final q = query.toLowerCase().trim();
    if (q.isEmpty) return [];

    return _memoryCache.values
        .where((a) => _matches(a, q))
        .take(limit)
        .toList();
  }

  static bool _matches(Anime anime, String q) {
    return anime.title.toLowerCase().contains(q) ||
        (anime.titleEnglish?.toLowerCase().contains(q) ?? false) ||
        (anime.titleJapanese?.toLowerCase().contains(q) ?? false) ||
        anime.genres.any((g) => g.toLowerCase().contains(q));
  }

  // ===========================================================================
  // PENYIMPANAN PERSISTEN LOKAL (SharedPreferencesAsync)
  // ===========================================================================
  static Future<void> _saveToLocal(Anime a) async {
    try {
      final prefs = SharedPreferencesAsync();
      final raw = jsonEncode(toDbJson(a));
      await prefs.setString('cached_anime_${a.id}', raw);
    } catch (_) {}
  }

  static Future<void> _saveListToLocal(List<Anime> list) async {
    try {
      final prefs = SharedPreferencesAsync();
      for (final a in list.take(30)) {
        final raw = jsonEncode(toDbJson(a));
        await prefs.setString('cached_anime_${a.id}', raw);
      }
    } catch (_) {}
  }

  static Future<Anime?> _loadFromLocal(int id) async {
    try {
      final prefs = SharedPreferencesAsync();
      final raw = await prefs.getString('cached_anime_$id');
      if (raw != null && raw.isNotEmpty) {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        return fromDbJson(map);
      }
    } catch (_) {}
    return null;
  }

  // ===========================================================================
  // SINKRONISASI CLOUD SUPABASE (NON-BLOCKING BACKGROUND SYNC)
  // ===========================================================================
  static void _syncToSupabase(Anime a) {
    final sb = _supabase;
    if (sb == null) return;
    if (_savedIds.contains(a.id) && a.characters.isEmpty) return;

    _savedIds.add(a.id);
    sb.from('cached_animes').upsert(toSupabaseMap(a)).then((_) {
      if (kDebugMode) {
        print('Saved anime to Supabase database: ${a.title} (${a.id})');
      }
    }).catchError((e) {
      if (kDebugMode) {
        print('Error saving anime to Supabase: $e');
      }
    });
  }

  static void _syncListToSupabase(List<Anime> list) {
    final sb = _supabase;
    if (sb == null || list.isEmpty) return;

    final toUpsert = list
        .where((a) => !_savedIds.contains(a.id))
        .take(15)
        .map(toSupabaseMap)
        .toList();

    if (toUpsert.isEmpty) return;

    for (final a in list) {
      _savedIds.add(a.id);
    }

    sb.from('cached_animes').upsert(toUpsert).then((_) {
      if (kDebugMode) {
        print('Batch saved ${toUpsert.length} animes to Supabase database');
      }
    }).catchError((e) {
      if (kDebugMode) {
        print('Error batch saving animes to Supabase: $e');
      }
    });
  }

  // ===========================================================================
  // SERIALIZERS / MAPPERS
  // ===========================================================================
  static Map<String, dynamic> toSupabaseMap(Anime a) => {
    'id': a.id,
    'title': a.title,
    'title_english': a.titleEnglish,
    'title_japanese': a.titleJapanese,
    'synopsis': a.synopsis,
    'image_url': a.imageUrl,
    'score': a.score,
    'episodes': a.episodes,
    'status': a.status,
    'genres': a.genres,
    'year': a.year,
    'format': a.format,
    'trailer_url': a.trailerUrl,
    'characters': a.characters.map((c) => {
      'name': c.name,
      'image_url': c.imageUrl,
      'role': c.role,
      'voice_actor_name': c.voiceActorName,
    }).toList(),
    'opening_themes': a.openingThemes,
    'ending_themes': a.endingThemes,
    'streaming_platforms': a.streamingPlatforms,
    'studios': a.studios,
    'updated_at': DateTime.now().toIso8601String(),
  };

  static Anime fromSupabaseMap(Map<String, dynamic> m) {
    final charsRaw = m['characters'] as List<dynamic>? ?? const [];
    final characters = charsRaw.whereType<Map>().map((c) {
      return AnimeCharacter(
        name: c['name']?.toString() ?? '',
        imageUrl: c['image_url']?.toString(),
        role: c['role']?.toString() ?? 'Main',
        voiceActorName: c['voice_actor_name']?.toString(),
      );
    }).toList();

    return Anime(
      id: (m['id'] as num?)?.toInt() ?? 0,
      title: m['title']?.toString() ?? '',
      titleEnglish: m['title_english']?.toString(),
      titleJapanese: m['title_japanese']?.toString(),
      synopsis: m['synopsis']?.toString(),
      imageUrl: m['image_url']?.toString() ?? '',
      score: (m['score'] as num?)?.toDouble(),
      episodes: (m['episodes'] as num?)?.toInt(),
      status: m['status']?.toString(),
      genres: (m['genres'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(),
      year: (m['year'] as num?)?.toInt(),
      format: m['format']?.toString(),
      trailerUrl: m['trailer_url']?.toString(),
      characters: characters,
      openingThemes: (m['opening_themes'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(),
      endingThemes: (m['ending_themes'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(),
      streamingPlatforms: (m['streaming_platforms'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(),
      studios: (m['studios'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(),
    );
  }

  static Map<String, dynamic> toDbJson(Anime a) => {
    'id': a.id,
    'title': a.title,
    'titleEnglish': a.titleEnglish,
    'titleJapanese': a.titleJapanese,
    'synopsis': a.synopsis,
    'imageUrl': a.imageUrl,
    'score': a.score,
    'episodes': a.episodes,
    'status': a.status,
    'genres': a.genres,
    'year': a.year,
    'format': a.format,
    'trailerUrl': a.trailerUrl,
    'characters': a.characters.map((c) => {
      'name': c.name,
      'imageUrl': c.imageUrl,
      'role': c.role,
      'voiceActorName': c.voiceActorName,
    }).toList(),
    'openingThemes': a.openingThemes,
    'endingThemes': a.endingThemes,
    'streamingPlatforms': a.streamingPlatforms,
    'studios': a.studios,
  };

  static Anime fromDbJson(Map<String, dynamic> m) {
    final charsRaw = m['characters'] as List<dynamic>? ?? const [];
    final characters = charsRaw.whereType<Map>().map((c) {
      return AnimeCharacter(
        name: c['name']?.toString() ?? '',
        imageUrl: c['imageUrl']?.toString(),
        role: c['role']?.toString() ?? 'Main',
        voiceActorName: c['voiceActorName']?.toString(),
      );
    }).toList();

    return Anime(
      id: (m['id'] as num?)?.toInt() ?? 0,
      title: m['title']?.toString() ?? '',
      titleEnglish: m['titleEnglish']?.toString(),
      titleJapanese: m['titleJapanese']?.toString(),
      synopsis: m['synopsis']?.toString(),
      imageUrl: m['imageUrl']?.toString() ?? '',
      score: (m['score'] as num?)?.toDouble(),
      episodes: (m['episodes'] as num?)?.toInt(),
      status: m['status']?.toString(),
      genres: (m['genres'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(),
      year: (m['year'] as num?)?.toInt(),
      format: m['format']?.toString(),
      trailerUrl: m['trailerUrl']?.toString(),
      characters: characters,
      openingThemes: (m['openingThemes'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(),
      endingThemes: (m['endingThemes'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(),
      streamingPlatforms: (m['streamingPlatforms'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(),
      studios: (m['studios'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(),
    );
  }
}
