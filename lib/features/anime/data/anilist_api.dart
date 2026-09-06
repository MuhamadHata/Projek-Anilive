import 'package:dio/dio.dart';
import '../domain/anime.dart';

class AniListApi {
  final Dio _dio;

  AniListApi({Dio? dio})
    : _dio = dio ??
          Dio(
            BaseOptions(
              baseUrl: 'https://graphql.anilist.co',
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 15),
              validateStatus: (status) => status != null && status < 500,
            ),
          );

  Future<List<Anime>> searchAnime(
    String query, {
    int page = 1,
    String? status,
    String? orderBy,
    List<String>? genres,
  }) async {
    final cleanQuery = query.trim();
    final hasSearch = cleanQuery.isNotEmpty;
    final variables = <String, dynamic>{
      'page': page,
      'search': hasSearch ? cleanQuery : null,
      'status': _status(status),
      'sort': [_sort(orderBy, hasSearch: hasSearch)],
      if (genres != null && genres.isNotEmpty)
        'genre_in': genres.map((g) => _genreName(g)).toList(),
    }..removeWhere((_, value) => value == null);

    final res = await _post(_searchQuery, variables);
    final media = res['data']?['Page']?['media'] as List<dynamic>? ?? const [];
    return media
        .whereType<Map>()
        .map((item) => _fromMedia(Map<String, dynamic>.from(item)))
        .where((anime) => anime.id > 0)
        .toList();
  }

  Future<List<Anime>> getTrending({int page = 1}) async {
    final res = await _post(_searchQuery, {
      'page': page,
      'sort': ['TRENDING_DESC'],
    });
    final media = res['data']?['Page']?['media'] as List<dynamic>? ?? const [];
    return media
        .whereType<Map>()
        .map((item) => _fromMedia(Map<String, dynamic>.from(item)))
        .where((anime) => anime.id > 0)
        .toList();
  }

  Future<List<Anime>> getCurrentSeason({int page = 1}) async {
    final now = DateTime.now();
    final variables = {
      'page': page,
      'season': _season(now.month),
      'seasonYear': now.year,
      'sort': ['POPULARITY_DESC'],
    };
    final res = await _post(_searchQuery, variables);
    final media = res['data']?['Page']?['media'] as List<dynamic>? ?? const [];
    return media
        .whereType<Map>()
        .map((item) => _fromMedia(Map<String, dynamic>.from(item)))
        .where((anime) => anime.id > 0)
        .toList();
  }

  Future<List<Anime>> getUpcomingSeason({int page = 1}) async {
    final now = DateTime.now();
    int month = now.month + 3;
    int year = now.year;
    if (month > 12) {
      month -= 12;
      year += 1;
    }
    final variables = {
      'page': page,
      'season': _season(month),
      'seasonYear': year,
      'sort': ['POPULARITY_DESC'],
    };
    final res = await _post(_searchQuery, variables);
    final media = res['data']?['Page']?['media'] as List<dynamic>? ?? const [];
    return media
        .whereType<Map>()
        .map((item) => _fromMedia(Map<String, dynamic>.from(item)))
        .where((anime) => anime.id > 0)
        .toList();
  }

  Future<Anime> getAnimeDetail(int id) async {
    // 1. Try search by AniList internal ID first
    final resById = await _post(_detailQuery, {'id': id});
    final mediaById = resById['data']?['Media'] as Map<String, dynamic>?;
    if (mediaById != null) {
      return _fromMedia(mediaById);
    }
    // 2. Fallback to MAL ID query
    final res = await _post(_detailQuery, {'idMal': id});
    final media = res['data']?['Media'] as Map<String, dynamic>?;
    if (media != null) {
      return _fromMedia(media);
    }
    throw Exception('Detail anime tidak ditemukan');
  }

  /// Pencarian berbasis genre, diurutkan berdasarkan skor (anime terbaik
  /// yang sedang booming di komunitas). Format & skor minimum bisa disaring.
  Future<List<Anime>> searchByGenre(
    String genre, {
    int page = 1,
    String sort = 'SCORE_DESC',
    String? format,
    int? minScore,
  }) async {
    final variables = <String, dynamic>{
      'page': page,
      'genre': _genreName(genre),
      'sort': [sort],
      'format': ?format,
      'minScore': ?minScore,
    }..removeWhere((_, value) => value == null);
    final res = await _post(_genreQuery, variables);
    final media = res['data']?['Page']?['media'] as List<dynamic>? ?? const [];
    return media
        .whereType<Map>()
        .map((item) => _fromMedia(Map<String, dynamic>.from(item)))
        .where((anime) => anime.id > 0)
        .toList();
  }

  /// Nama genre AniList/MAL yang dikenali dari input bebas.
  String _genreName(String raw) {
    final g = raw.trim().toLowerCase();
    return switch (g) {
      'action' => 'Action',
      'adventure' => 'Adventure',
      'comedy' => 'Comedy',
      'drama' => 'Drama',
      'ecchi' => 'Ecchi',
      'fantasy' => 'Fantasy',
      'horror' => 'Horror',
      'mahou shoujo' => 'Mahou Shoujo',
      'mecha' => 'Mecha',
      'music' => 'Music',
      'mystery' => 'Mystery',
      'psychological' => 'Psychological',
      'romance' => 'Romance',
      'sci-fi' || 'scifi' || 'science fiction' => 'Sci-Fi',
      'slice of life' => 'Slice of Life',
      'sports' => 'Sports',
      'supernatural' => 'Supernatural',
      'thriller' => 'Thriller',
      _ => raw.trim(),
    };
  }

  Future<Map<String, dynamic>> _post(String query, Map<String, dynamic> variables) async {
    try {
      final res = await _dio.post('', data: {'query': query, 'variables': variables});
      if (res.data is Map) {
        return Map<String, dynamic>.from(res.data as Map);
      }
      return <String, dynamic>{};
    } on DioException catch (_) {
      return <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }

Anime _fromMedia(Map<String, dynamic> media) {
    final title = media['title'] as Map<String, dynamic>? ?? const {};
    final cover = media['coverImage'] as Map<String, dynamic>? ?? const {};
    final idMal = (media['idMal'] as num?)?.toInt();
    final rawDescription = (media['description'] as String?)
        ?.replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&quot;', '"')
        .replaceAll('&amp;', '&');
    final synopsis = Anime.cleanSynopsis(rawDescription);

    final studiosEdges = media['studios']?['edges'] as List<dynamic>? ?? const [];
    final studiosList = studiosEdges
        .whereType<Map>()
        .map((e) => (e['node'] as Map<String, dynamic>?)?['name'] as String?)
        .whereType<String>()
        .toList();

    final charEdges = media['characters']?['edges'] as List<dynamic>? ?? const [];
    final charsList = charEdges
        .whereType<Map>()
        .map((e) {
          final node = e['node'] as Map<String, dynamic>? ?? const {};
          final nameMap = node['name'] as Map<String, dynamic>? ?? const {};
          final image = node['image'] as Map<String, dynamic>? ?? const {};
          return AnimeCharacter(
            name: nameMap['full'] as String? ?? '',
            imageUrl: image['large'] as String?,
            role: e['role'] as String? ?? 'Main',
          );
        })
        .toList();

    return Anime(
      id: idMal ?? (media['id'] as num?)?.toInt() ?? 0,
      title: title['romaji'] as String? ?? title['english'] as String? ?? '',
      titleEnglish: title['english'] as String?,
      titleJapanese: title['native'] as String?,
      synopsis: synopsis,
      imageUrl: cover['extraLarge'] as String? ?? cover['large'] as String? ?? cover['medium'] as String? ?? '',
      score: (media['averageScore'] as num?) == null
          ? null
          : (media['averageScore'] as num).toDouble() / 10,
      episodes: (media['episodes'] as num?)?.toInt(),
      status: media['status'] as String?,
      genres: (media['genres'] as List<dynamic>? ?? const []).whereType<String>().toList(),
      year: (media['seasonYear'] as num?)?.toInt(),
      source: media['source'] as String?,
      format: media['format'] as String?,
      studios: studiosList,
      characters: charsList,
      durationText: (media['duration'] as num?) != null
          ? '${media['duration']} min per ep'
          : null,
      airedString: _dateRange(media['startDate'], media['endDate']),
      popularity: (media['popularity'] as num?)?.toInt(),
      favoritesCount: (media['favourites'] as num?)?.toInt(),
      isAdult: media['isAdult'] == true,
      trailerUrl: _trailerUrl(media['trailer']),
    );
  }

  static String? _trailerUrl(dynamic trailer) {
    if (trailer is! Map) return null;
    final id = trailer['id']?.toString();
    final site = (trailer['site'] as String?)?.toLowerCase();
    if (id == null || id.isEmpty) return null;
    if (site == 'youtube') {
      return 'https://www.youtube.com/watch?v=$id';
    }
    if (site == 'dailymotion') {
      return 'https://www.dailymotion.com/video/$id';
    }
    return null;
  }

  static const List<String> _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
    'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
  ];

  static String? _dateRange(dynamic start, dynamic end) {
    String? fmt(dynamic d) {
      if (d is! Map) return null;
      final y = d['year'] as num?;
      if (y == null) return null;
      final m = (d['month'] as num?)?.toInt();
      final day = d['day'] as num?;
      final mm = m != null && m >= 1 && m <= 12 ? _months[m - 1] : '';
      final dd = day != null ? '$day ' : '';
      return '$dd$mm $y'.trim();
    }

    final s = fmt(start);
    final e = fmt(end);
    if (s == null && e == null) return null;
    if (s != null && e != null) return '$s – $e';
    return s ?? e;
  }

  String? _status(String? value) {
    return switch (value) {
      'airing' => 'RELEASING',
      'complete' => 'FINISHED',
      'upcoming' => 'NOT_YET_RELEASED',
      _ => null,
    };
  }

  String _sort(String? value, {required bool hasSearch}) {
    return switch (value) {
      'start_date' => 'START_DATE_DESC',
      'score' => 'SCORE_DESC',
      'popularity' => 'POPULARITY_DESC',
      _ => hasSearch ? 'SEARCH_MATCH' : 'POPULARITY_DESC',
    };
  }

  String _season(int month) {
    if (month <= 2) return 'WINTER';
    if (month <= 5) return 'SPRING';
    if (month <= 8) return 'SUMMER';
    return 'FALL';
  }
}

const _genreQuery = r'''
query ($page: Int, $genre: String, $sort: [MediaSort], $format: MediaFormat, $minScore: Int) {
  Page(page: $page, perPage: 20) {
    media(type: ANIME, genre_in: [$genre], format: $format, averageScore_greater: $minScore, sort: $sort) {
      id
      idMal
      title { romaji english native }
      description(asHtml: false)
      coverImage { extraLarge large medium }
      averageScore
      episodes
      duration
      status
      genres
      seasonYear
      source
      popularity
      favourites
      trailer { id site }
      startDate { year month day }
      endDate { year month day }
      studios {
        edges {
          node { name }
        }
      }
      characters(sort: [ROLE, RELEVANCE, ID]) {
        edges {
          role
          node {
            name { full }
            image { large }
          }
        }
      }
    }
  }
}
''';

const _searchQuery = r'''
query ($page: Int, $search: String, $status: MediaStatus, $season: MediaSeason, $seasonYear: Int, $sort: [MediaSort], $genre_in: [String]) {
  Page(page: $page, perPage: 20) {
    media(type: ANIME, search: $search, status: $status, season: $season, seasonYear: $seasonYear, sort: $sort, genre_in: $genre_in) {
      id
      idMal
      title { romaji english native }
      description(asHtml: false)
      coverImage { extraLarge large medium }
      averageScore
      episodes
      duration
      status
      genres
      seasonYear
      source
      popularity
      favourites
      trailer { id site }
      startDate { year month day }
      endDate { year month day }
      studios {
        edges {
          node { name }
        }
      }
      characters(sort: [ROLE, RELEVANCE, ID]) {
        edges {
          role
          node {
            name { full }
            image { large }
          }
        }
      }
    }
  }
}
''';

const _detailQuery = r'''
query ($id: Int, $idMal: Int) {
  Media(id: $id, idMal: $idMal, type: ANIME) {
    id
    idMal
    title { romaji english native }
    description(asHtml: false)
    coverImage { extraLarge large medium }
    averageScore
    duration
    episodes
    status
    genres
    seasonYear
    source
    popularity
    favourites
    trailer { id site }
    startDate { year month day }
    endDate { year month day }
    studios {
      edges {
        node { name }
      }
    }
    characters(sort: [ROLE, RELEVANCE, ID]) {
      edges {
        role
        node {
          name { full }
          image { large }
        }
      }
    }
  }
}
''';

