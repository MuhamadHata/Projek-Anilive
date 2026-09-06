class Anime {
  final int id;
  final String title;
  final String? titleEnglish;
  final String? titleJapanese;
  final String? synopsis;
  final String imageUrl;
  final double? score;
  final int? episodes;
  final String? status;
  final List<String> genres;
  final int? year;
  final String? source;
  final String? format;
  final List<String> studios;
  final List<AnimeCharacter> characters;
  final List<String> synonyms;
  final String? durationText;
  final String? airedString;
  final String? ratingAge;
  final int? rank;
  final int? popularity;
  final int? members;
  final bool isAdult;
  final int? favoritesCount;
  final String? trailerUrl;
  final List<String> openingThemes;
  final List<String> endingThemes;
  final List<String> streamingPlatforms;

  const Anime({
    required this.id,
    required this.title,
    this.titleEnglish,
    this.titleJapanese,
    this.synopsis,
    required this.imageUrl,
    this.score,
    this.episodes,
    this.status,
    this.genres = const [],
    this.year,
    this.source,
    this.format,
    this.studios = const [],
    this.characters = const [],
    this.synonyms = const [],
    this.durationText,
    this.airedString,
    this.ratingAge,
    this.rank,
    this.popularity,
    this.members,
    this.isAdult = false,
    this.favoritesCount,
    this.trailerUrl,
    this.openingThemes = const [],
    this.endingThemes = const [],
    this.streamingPlatforms = const [],
  });

  static String? cleanSynopsis(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    var text = raw
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&quot;', '"')
        .replaceAll('&amp;', '&')
        .replaceAll('&#039;', "'")
        .replaceAll('&mdash;', '—')
        .replaceAll('&ndash;', '–')
        .replaceAll('&hellip;', '…')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .trim();
    // Remove trailing "(Source: ...)" or "[Written by ...]" blocks
    text = text.replaceAll(
      RegExp(r'\s*\((Source|Sumber)\s*:.*?\)\s*$', caseSensitive: false, multiLine: true),
      '',
    );
    text = text.replaceAll(
      RegExp(r'\s*\[Written by MAL Rewrite\]\s*$', caseSensitive: false),
      '',
    );
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    return text.isEmpty ? null : text;
  }

  factory Anime.fromJson(Map<String, dynamic> json) {
    final images = json['images'] is Map
        ? Map<String, dynamic>.from(json['images'] as Map)
        : const <String, dynamic>{};
    final jpg = images['jpg'] is Map
        ? Map<String, dynamic>.from(images['jpg'] as Map)
        : const <String, dynamic>{};
    final imageUrl =
        (jpg['maximum_image_url'] ?? jpg['large_image_url'] ?? jpg['image_url'] ?? '') as String;
    final rawGenres =
        json['genres'] is List ? json['genres'] as List : const [];
    final genresList = rawGenres
        .whereType<Map>()
        .map((g) => g['name'])
        .whereType<String>()
        .toList();

    final rawStudios = json['studios'] is List
        ? (json['studios'] as List)
        : (json['producers'] is List ? json['producers'] as List : const []);
    final studiosList = rawStudios
        .whereType<Map>()
        .map((s) => s['name'])
        .whereType<String>()
        .toList();

    final rawChars = json['characters'] is List
        ? json['characters'] as List
        : const [];
    final charsList = rawChars
        .whereType<Map>()
        .map((c) => AnimeCharacter.fromJson(Map<String, dynamic>.from(c)))
        .toList();

    final aired = json['aired'] is Map ? Map<String, dynamic>.from(json['aired'] as Map) : null;
    final theme = json['theme'] is Map ? Map<String, dynamic>.from(json['theme'] as Map) : null;
    final trailer = json['trailer'] is Map ? Map<String, dynamic>.from(json['trailer'] as Map) : null;
    final trailerUrl = (trailer?['url'] as String?)?.isNotEmpty == true
        ? trailer!['url'] as String
        : (trailer?['youtube_id'] != null && (trailer!['youtube_id'] as String).isNotEmpty
            ? 'https://www.youtube.com/watch?v=${trailer['youtube_id']}'
            : null);

    return Anime(
      id: (json['mal_id'] as num?)?.toInt() ?? 0,
      title: json['title'] as String? ?? '',
      titleEnglish: json['title_english'] as String?,
      titleJapanese: json['title_japanese'] as String?,
      synopsis: cleanSynopsis(json['synopsis'] as String?),
      imageUrl: imageUrl,
      score: (json['score'] as num?)?.toDouble(),
      episodes: (json['episodes'] as num?)?.toInt(),
      status: json['status'] as String?,
      genres: genresList,
      year: (json['year'] as num?)?.toInt() ?? (json['aired']?['prop']?['from']?['year'] as num?)?.toInt(),
      source: json['source'] as String?,
      format: (json['type'] as String?)?.toUpperCase(),
      studios: studiosList,
      characters: charsList,
      durationText: json['duration'] as String?,
      airedString: aired?['string'] as String?,
      ratingAge: json['rating'] as String?,
      rank: (json['rank'] as num?)?.toInt(),
      popularity: (json['popularity'] as num?)?.toInt(),
      members: (json['members'] as num?)?.toInt(),
      isAdult: (json['rating'] as String? ?? '').startsWith('Rx'),
      favoritesCount: (json['favorites'] as num?)?.toInt(),
      trailerUrl: trailerUrl,
      openingThemes: (theme?['openings'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList(),
      endingThemes: (theme?['endings'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList(),
      streamingPlatforms: (json['streaming'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map((s) => s['name'])
          .whereType<String>()
          .toList(),
    );
  }

  /// Durasi per episode dalam menit, jika bisa diparse dari durationText
  /// (mis. "24 min per ep" -> 24).
  int? get episodeDurationMinutes {
    final t = durationText;
    if (t == null) return null;
    final match = RegExp(r'(\d+)').firstMatch(t);
    if (match == null) return null;
    return int.tryParse(match.group(1)!);
  }
}

class AnimeCharacter {
  final String name;
  final String? imageUrl;
  final String role;
  final String? voiceActorName;

  const AnimeCharacter({
    required this.name,
    this.imageUrl,
    required this.role,
    this.voiceActorName,
  });

  factory AnimeCharacter.fromJson(Map<String, dynamic> json) {
    final imageUrl = (json['image_url'] ?? json['images']?['jpg']?['image_url'] ?? '') as String;

    // Voice actor Jepang (dari Jikan)
    String? vaName;
    final vas = json['voice_actors'] is List ? json['voice_actors'] as List : const [];
    for (final va in vas.whereType<Map>()) {
      if ((va['language'] as String?)?.toLowerCase() == 'japanese') {
        vaName = (va['person'] as Map?)?['name'] as String?;
        break;
      }
    }

    return AnimeCharacter(
      name: json['name'] as String? ?? '',
      imageUrl: imageUrl.isEmpty ? null : imageUrl,
      role: json['role'] as String? ?? 'Main',
      voiceActorName: vaName,
    );
  }
}

/// Saringan konten dewasa — dipakai seragam di seluruh aplikasi.
/// [allowAdult] = true diizinkan hanya untuk user yang sudah terverifikasi ≥ 20 tahun.
class AnimeSafety {
  static const Set<String> _adultGenres = {'hentai', 'h', 'erotica'};

  /// Mengembalikan true jika anime aman untuk ditampilkan.
  /// Jika [allowAdult] = true (user ≥20 tahun), konten dewasa diizinkan.
  static bool isSafe(Anime a, {bool allowAdult = false}) {
    if (allowAdult) return true; // user terverifikasi: semua boleh tampil
    if (a.isAdult) return false;
    for (final g in a.genres) {
      if (_adultGenres.contains(g.trim().toLowerCase())) return false;
    }
    return true;
  }

  static List<Anime> filterList(List<Anime> list, {bool allowAdult = false}) =>
      list.where((a) => isSafe(a, allowAdult: allowAdult)).toList();
}
