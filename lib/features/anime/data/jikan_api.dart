import 'package:dio/dio.dart';
import '../../../core/config/app_config.dart';
import '../domain/anime.dart';

class JikanApi {
  final Dio _dio;

  JikanApi({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: AppConfig.jikanBaseUrl,
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 15),
            ),
          );

  Future<List<Anime>> getTopRated({int page = 1}) async {
    final res = await _dio.get(
      '/top/anime',
      queryParameters: {'page': page, 'limit': 20},
    );
    final data = res.data as Map<String, dynamic>;
    final list = data['data'] as List<dynamic>;
    return list.map((e) => Anime.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<Anime>> getCurrentSeason({int page = 1}) async {
    final res = await _dio.get(
      '/seasons/now',
      queryParameters: {'page': page, 'limit': 20},
    );
    final data = res.data as Map<String, dynamic>;
    final list = data['data'] as List<dynamic>;
    return list.map((e) => Anime.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<Anime>> getUpcomingSeason({int page = 1}) async {
    final res = await _dio.get(
      '/seasons/upcoming',
      queryParameters: {'page': page, 'limit': 20},
    );
    final data = res.data as Map<String, dynamic>;
    final list = data['data'] as List<dynamic>;
    return list.map((e) => Anime.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<Anime>> searchAnime(
    String query, {
    int page = 1,
    List<int>? genres,
    String? status,
    String? orderBy,
    String? type,
    double? minScore,
  }) async {
    final params = <String, dynamic>{
      'page': page,
      'limit': 20,
      'sfw': true,
    };
    if (query.isNotEmpty) params['q'] = query;
    if (genres != null && genres.isNotEmpty) {
      params['genres'] = genres.join(',');
    }
    if (status != null && status.isNotEmpty) params['status'] = status;
    if (type != null && type.isNotEmpty) params['type'] = type;
    if (minScore != null) params['min_score'] = minScore;
    if (orderBy != null && orderBy.isNotEmpty) {
      params['order_by'] = orderBy;
      params['sort'] = 'desc';
    }

    try {
      final res = await _dio.get('/anime', queryParameters: params);
      final data = res.data as Map<String, dynamic>;
      final list = data['data'] as List<dynamic>? ?? const [];
      return list
          .whereType<Map>()
          .map((item) => Anime.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    } on DioException catch (e) {
      if (e.response?.statusCode == 429 || e.response?.statusCode == 502 || e.response?.statusCode == 503 || e.response?.statusCode == 504) {
        throw Exception('Server data anime sedang sibuk. Coba lagi beberapa saat.');
      }
      throw Exception('Gagal memuat data anime. Periksa koneksi internet.');
    }
  }


  Future<Anime> getAnimeDetail(int id) async {
    try {
      final res = await _dio.get('/anime/$id/full');
      final data = res.data as Map<String, dynamic>;
      return Anime.fromJson(data['data'] as Map<String, dynamic>);
    } on DioException catch (_) {
      final res = await _dio.get('/anime/$id');
      final data = res.data as Map<String, dynamic>;
      return Anime.fromJson(data['data'] as Map<String, dynamic>);
    }
  }

  /// Judul per episode (romanji/inggris) + penanda filler/recap.
  /// Jikan mengembalikan 100 episode per halaman.
  Future<List<JikanEpisode>> getEpisodes(
    int malId, {
    int page = 1,
  }) async {
    try {
      final res = await _dio.get(
        '/anime/$malId/episodes',
        queryParameters: {'page': page},
      );
      final data = res.data as Map<String, dynamic>;
      final list =
          (data['data'] as List<dynamic>? ?? const []);
      return list
          .whereType<Map>()
          .map((e) => JikanEpisode.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } on DioException {
      return const [];
    } catch (_) {
      return const [];
    }
  }

  /// Anime serupa yang direkomendasikan pengguna MAL.
  Future<List<Anime>> getRecommendations(int malId, {int limit = 12}) async {
    try {
      final res = await _dio.get('/anime/$malId/recommendations');
      final data = res.data as Map<String, dynamic>;
      final list = data['data'] as List<dynamic>? ?? const [];
      final result = <Anime>[];
      for (final item in list) {
        if (result.length >= limit) break;
        if (item is! Map) continue;
        final entry = item['entry'];
        if (entry is! Map) continue;
        final m = Map<String, dynamic>.from(entry);
        result.add(Anime(
          id: (m['mal_id'] as num?)?.toInt() ?? 0,
          title: m['title'] as String? ?? '',
          imageUrl: (m['images']?['jpg']?['image_url'] ??
                  m['images']?['jpg']?['large_image_url'] ??
                  '') as String,
        ));
      }
      return result;
    } on DioException {
      return const [];
    } catch (_) {
      return const [];
    }
  }
}

/// Info satu episode dari Jikan.
class JikanEpisode {
  final int number;
  final String? title;
  final String? titleRomanji;
  final String? titleJapanese;
  final bool filler;
  final bool recap;

  const JikanEpisode({
    required this.number,
    this.title,
    this.titleRomanji,
    this.titleJapanese,
    this.filler = false,
    this.recap = false,
  });

  factory JikanEpisode.fromJson(Map<String, dynamic> json) {
    final titleMap = json['title'] is Map
        ? Map<String, dynamic>.from(json['title'] as Map)
        : null;
    return JikanEpisode(
      number: (json['mal_id'] as num?)?.toInt() ?? 0,
      title: titleMap != null
          ? (titleMap['default'] as String? ?? '')
          : json['title_romanji'] as String? ?? json['title'] as String?,
      titleRomanji: json['title_romanji'] as String?,
      titleJapanese: json['title_japanese'] as String?,
      filler: json['filler'] == true,
      recap: json['recap'] == true,
    );
  }
}
