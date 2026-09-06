import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/config/app_config.dart';
import '../domain/anime.dart';
import 'anime_database_cache.dart';
import 'anime_offline_db.dart';
import 'anilist_api.dart';
import 'jikan_api.dart';

class AnimeRagResult {
  final List<Anime> animes;
  final String? reasoning;
  final List<String> matchedKeywords;
  final bool isFromRag;

  const AnimeRagResult({
    required this.animes,
    this.reasoning,
    this.matchedKeywords = const [],
    this.isFromRag = false,
  });
}

/// Sistem Pencarian Semantik Berbasis RAG (Retrieval-Augmented Generation):
/// 1. Menganalisis kueri bahasa alami / alur cerita / karakter (bahasa Indonesia / Inggris).
/// 2. Menggunakan LLM untuk mengekstrak entitas kanonikal anime & alasan pencocokan.
/// 3. Mengambil (Grounding) data anime nyata dari Database Lokal & Supabase.
/// 4. Menyimpan hasil pencarian semantik ke database agar kueri serupa instan (0 ms).
class AnimeRagSearchService {
  final Dio _dio;
  final AniListApi _aniList;
  final JikanApi _jikan;

  static final Map<String, AnimeRagResult> _ragMemoryCache = {};

  AnimeRagSearchService({Dio? dio, AniListApi? aniList, JikanApi? jikan})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: AppConfig.llmBaseUrl,
              connectTimeout: const Duration(seconds: 4),
              receiveTimeout: const Duration(seconds: 6),
              headers: {
                'Authorization': 'Bearer ${AppConfig.llmApiKey}',
                'Content-Type': 'application/json',
              },
            ),
          ),
      _aniList = aniList ?? AniListApi(),
      _jikan = jikan ?? JikanApi();

  /// Mendeteksi apakah kueri memerlukan pemahaman semantik RAG
  /// (misal kalimat deskripsi, bahasa Indonesia, ciri-ciri karakter/alur)
  bool isDescriptiveQuery(String query) {
    final q = query.toLowerCase().trim();
    if (q.length < 5) return false;

    // Kata-kata penanda deskripsi cerita / bahasa alami
    final naturalKeywords = [
      'anime',
      'tentang',
      'yang',
      'anak',
      'masuk',
      'dunia',
      'reinkarnasi',
      'isekai',
      'rambut',
      'mata',
      'pedang',
      'iblis',
      'setan',
      'masak',
      'makanan',
      'baju',
      'robek',
      'dokter',
      'idol',
      'pahlawan',
      'hero',
      'raja',
      'sihir',
      'sekolah',
      'kekuatan',
      'sekali pukul',
      'rubah',
      'ekor',
      'ninja',
      'detektif',
      'buku',
      'catatan',
      'kematian',
      'game',
      'terjebak',
      'virtual',
    ];

    final words = q.split(RegExp(r'\s+'));
    if (words.length >= 3) return true;
    return naturalKeywords.any((k) => q.contains(k));
  }

  /// Eksekusi RAG Pipeline: Pemahaman Kueri -> Grounding Database -> Sintesis Hasil
  Future<AnimeRagResult?> searchWithRag(String userQuery) async {
    final cleanQuery = userQuery.trim();
    if (cleanQuery.length < 3) return null;

    final cacheKey = cleanQuery.toLowerCase();

    // 1. Cek memory cache RAG (0 ms)
    if (_ragMemoryCache.containsKey(cacheKey)) {
      return _ragMemoryCache[cacheKey];
    }

    // 2. Cek local persistent cache RAG (0 ms)
    final cached = await _loadRagFromPrefs(cacheKey);
    if (cached != null) {
      _ragMemoryCache[cacheKey] = cached;
      return cached;
    }

    // 3. Panggil LLM untuk Query Understanding & Semantic Retrieval
    if (AppConfig.llmApiKey.isEmpty) return null;
    try {
      final res = await _dio.post(
        '/chat/completions',
        data: {
          'model': AppConfig.llmModel,
          'messages': [
            {
              'role': 'system',
              'content':
                  'You are an expert anime database retriever and recommendation assistant. '
                  'The user is searching for an anime using natural language, plot description, '
                  'character appearance, powers, or Indonesian/English keywords.\n'
                  'Identify the top 1 to 4 official canonical anime titles that match this request.\n'
                  'Respond STRICTLY in JSON format with this structure:\n'
                  '{\n'
                  '  "titles": ["Canonical Title 1", "Canonical Title 2"],\n'
                  '  "keywords": ["tag1", "tag2"],\n'
                  '  "reasoning": "Penjelasan 1 kalimat singkat dalam bahasa Indonesia mengapa anime ini cocok"\n'
                  '}\n'
                  'No markdown wrappers, only pure JSON string.',
            },
            {'role': 'user', 'content': cleanQuery},
          ],
          'max_tokens': 160,
          'temperature': 0.2,
        },
      ).timeout(const Duration(seconds: 4));

      final choices = res.data['choices'] as List<dynamic>?;
      if (choices == null || choices.isEmpty) return null;

      final message = choices[0]['message'] as Map<String, dynamic>?;
      final content = message?['content'] as String?;
      if (content == null || content.isEmpty) return null;

      // Bersihkan kemungkinan markdown code fence (```json ... ```)
      var jsonStr = content.trim();
      if (jsonStr.startsWith('```')) {
        jsonStr = jsonStr.replaceFirst(RegExp(r'^```(json)?\s*'), '');
        jsonStr = jsonStr.replaceFirst(RegExp(r'\s*```$'), '');
      }

      final parsed = jsonDecode(jsonStr) as Map<String, dynamic>;
      final titles = (parsed['titles'] as List<dynamic>? ?? const [])
          .map((e) => e.toString().trim())
          .where((t) => t.isNotEmpty)
          .toList();
      final keywords = (parsed['keywords'] as List<dynamic>? ?? const [])
          .map((e) => e.toString().trim())
          .toList();
      final reasoning = parsed['reasoning']?.toString();

      if (titles.isEmpty) return null;

      // 4. Grounding: Ambil anime nyata dari Database (Offline DB & Supabase Database Cache)
      final matchedAnimes = <Anime>[];
      final seenIds = <int>{};

      for (final title in titles) {
        // A. Cek di AnimeOfflineDb (30.306 anime)
        final offlineMatches = await AnimeOfflineDb.search(title, limit: 3);
        for (final a in offlineMatches) {
          if (seenIds.add(a.id)) {
            matchedAnimes.add(a);
            // Simpan ke database cache
            AnimeDatabaseCache.saveAnime(a);
          }
        }

        // B. Jika belum ketemu di offline DB, coba cari di Supabase atau API eksternal
        if (matchedAnimes.isEmpty) {
          try {
            final apiResults = await _aniList.searchAnime(title);
            for (final a in apiResults.take(2)) {
              if (seenIds.add(a.id)) {
                matchedAnimes.add(a);
                AnimeDatabaseCache.saveAnime(a);
              }
            }
          } catch (_) {
            try {
              final jikanResults = await _jikan.searchAnime(title);
              for (final a in jikanResults.take(2)) {
                if (seenIds.add(a.id)) {
                  matchedAnimes.add(a);
                  AnimeDatabaseCache.saveAnime(a);
                }
              }
            } catch (_) {}
          }
        }
      }

      if (matchedAnimes.isNotEmpty) {
        final result = AnimeRagResult(
          animes: matchedAnimes,
          reasoning: reasoning,
          matchedKeywords: keywords,
          isFromRag: true,
        );

        _ragMemoryCache[cacheKey] = result;
        _saveRagToPrefs(cacheKey, result);
        return result;
      }
    } catch (e) {
      if (kDebugMode) {
        print('RAG search error: $e');
      }
    }

    return null;
  }

  // ===========================================================================
  // PERSISTENCE LOCAL CACHE FOR RAG QUERIES
  // ===========================================================================
  Future<void> _saveRagToPrefs(String query, AnimeRagResult result) async {
    try {
      final prefs = SharedPreferencesAsync();
      final data = {
        'reasoning': result.reasoning,
        'keywords': result.matchedKeywords,
        'anime_ids': result.animes.map((a) => a.id).toList(),
      };
      await prefs.setString('rag_cache_$query', jsonEncode(data));
    } catch (_) {}
  }

  Future<AnimeRagResult?> _loadRagFromPrefs(String query) async {
    try {
      final prefs = SharedPreferencesAsync();
      final raw = await prefs.getString('rag_cache_$query');
      if (raw != null && raw.isNotEmpty) {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        final reasoning = map['reasoning'] as String?;
        final keywords = (map['keywords'] as List<dynamic>? ?? const [])
            .map((e) => e.toString())
            .toList();
        final ids = (map['anime_ids'] as List<dynamic>? ?? const [])
            .whereType<num>()
            .map((n) => n.toInt())
            .toList();

        final animes = <Anime>[];
        for (final id in ids) {
          final a = AnimeOfflineDb.getByIdSync(id) ??
              await AnimeDatabaseCache.getAnimeById(id);
          if (a != null) {
            animes.add(a);
          }
        }

        if (animes.isNotEmpty) {
          return AnimeRagResult(
            animes: animes,
            reasoning: reasoning,
            matchedKeywords: keywords,
            isFromRag: true,
          );
        }
      }
    } catch (_) {}
    return null;
  }
}
