import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import '../domain/anime.dart';

/// Offline anime database loaded from bundled JSON asset.
/// Cleaned anime entries with titles, synonyms (romaji/English/Japanese), images.
class AnimeOfflineDb {
  static List<Anime>? _cache;
  static List<_IndexedAnime>? _indexedCache;
  static const String _assetPath = 'assets/data/anime_offline.json';
  static Map<String, List<Anime>>? _topCache;
  static const String _topAssetPath = 'assets/data/anime_top_by_genre.json';

  static bool get isLoaded => _cache != null && _cache!.isNotEmpty;

  static Future<void> ensureLoaded() async {
    if (_cache != null && _cache!.isNotEmpty) return;
    try {
      final raw = await rootBundle.loadString(_assetPath);
      final list = jsonDecode(raw) as List<dynamic>;
      final parsed = list
          .whereType<Map>()
          .map((e) => _fromOfflineJson(Map<String, dynamic>.from(e)))
          .toList();
      _cache = parsed;

      // Pre-compute normalized lowercased search index untuk pencarian instan (<3 ms)
      _indexedCache = parsed.map((a) {
        final t = a.title.toLowerCase().trim();
        final en = a.titleEnglish?.toLowerCase().trim();
        final ja = a.titleJapanese?.toLowerCase().trim();
        final syn = a.synonyms
            .map((s) => s.toLowerCase().trim())
            .where((s) => s.isNotEmpty)
            .toList();
        final variants = <String>[
          t,
          if (en != null && en.isNotEmpty) en,
          if (ja != null && ja.isNotEmpty) ja,
          ...syn,
        ];
        return _IndexedAnime(
          anime: a,
          titleLower: t,
          englishLower: en,
          variants: variants,
          combined: variants.join(' '),
        );
      }).toList();
    } catch (_) {
      _cache = [];
      _indexedCache = [];
    }
  }

  /// Strict, accurate & ultra-fast search (<3 ms)
  /// Menggunakan pra-indeks string terkomputasi tanpa alokasi memori berlebih:
  /// 1. Exact match (Rank 1000/950/900)
  /// 2. Starts with query (Rank 800/750/700)
  /// 3. Contains query (Rank 500/450/400)
  /// 4. Semua kata cocok (Rank 300)
  /// 5. Sebagian kata cocok (Rank 150)
  /// 6. Toleransi typo ringan (Rank 200) hanya saat hasil langka
  static Future<List<Anime>> search(String query, {int limit = 30}) async {
    await ensureLoaded();
    final indexed = _indexedCache ?? [];
    if (indexed.isEmpty) return [];
    final q = query.toLowerCase().trim();
    if (q.isEmpty) return [];

    final qWords =
        q.split(RegExp(r'\s+')).where((w) => w.length >= 2).toList();
    final matches = <_SearchResult>[];

    for (final item in indexed) {
      int score = 0;

      // 1. Exact match
      if (item.titleLower == q) {
        score = 1000;
      } else if (item.englishLower == q) {
        score = 950;
      } else if (item.variants.contains(q)) {
        score = 900;
      }
      // 2. Starts with query
      else if (item.titleLower.startsWith(q)) {
        score = 800;
      } else if (item.englishLower != null && item.englishLower!.startsWith(q)) {
        score = 750;
      } else if (item.variants.any((s) => s.startsWith(q))) {
        score = 700;
      }
      // 3. Contains query as substring
      else if (item.titleLower.contains(q)) {
        score = 500;
      } else if (item.englishLower != null && item.englishLower!.contains(q)) {
        score = 450;
      } else if (item.combined.contains(q)) {
        score = 400;
      }
      // 4. Multi-word search
      else if (qWords.isNotEmpty) {
        bool allWordsPresent = true;
        for (final w in qWords) {
          if (!item.combined.contains(w)) {
            allWordsPresent = false;
            break;
          }
        }
        if (allWordsPresent) {
          score = 300;
        } else if (qWords.length > 1) {
          int hit = 0;
          for (final w in qWords) {
            if (item.combined.contains(w)) hit++;
          }
          if (hit * 2 >= qWords.length) {
            score = 150;
          }
        }
      }

      if (score > 0) {
        matches.add(_SearchResult(anime: item.anime, score: score));
      }
    }

    // Jika hasil sedikit dan kata query cukup panjang, jalankan pengecekan typo
    if (matches.length < 5 && qWords.isNotEmpty && q.length >= 5) {
      final seenIds = matches.map((m) => m.anime.id).toSet();
      for (final item in indexed) {
        if (seenIds.contains(item.anime.id)) continue;
        int hit = 0;
        for (final w in qWords) {
          if (item.combined.contains(w) || _wordHits(item.combined, w)) hit++;
        }
        if (hit == qWords.length) {
          matches.add(_SearchResult(anime: item.anime, score: 200));
        }
      }
    }

    matches.sort((a, b) => b.score.compareTo(a.score));
    return matches.take(limit).map((m) => m.anime).toList();
  }

  /// Kata [word] dianggap cocok dengan teks [text] jika muncul sebagai
  /// substring, atau mirip (salah ketik 1–2 huruf) dengan salah satu kata.
  static bool _wordHits(String text, String word) {
    if (text.contains(word)) return true;
    if (word.length < 5) return false;
    final maxDist = word.length >= 8 ? 2 : 1;
    for (final t in text.split(RegExp(r'[^a-z0-9]+'))) {
      if (t.isEmpty) continue;
      if ((t.length - word.length).abs() > maxDist) continue;
      if (_editDistance(word, t) <= maxDist) return true;
    }
    return false;
  }

  /// Jarak edit Levenshtein untuk string pendek.
  static int _editDistance(String a, String b) {
    if (a == b) return 0;
    final m = a.length, n = b.length;
    var prev = List<int>.generate(n + 1, (i) => i);
    var curr = List<int>.filled(n + 1, 0);
    for (int i = 1; i <= m; i++) {
      curr[0] = i;
      for (int j = 1; j <= n; j++) {
        final cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
        var v = prev[j] + 1;
        if (curr[j - 1] + 1 < v) v = curr[j - 1] + 1;
        if (prev[j - 1] + cost < v) v = prev[j - 1] + cost;
        curr[j] = v;
      }
      final t = prev;
      prev = curr;
      curr = t;
    }
    return prev[n];
  }

  static Future<List<Anime>> getByGenre(String genre, {int limit = 20, bool seriesOnly = true}) async {
    await ensureLoaded();
    final db = _cache ?? [];
    final g = genre.toLowerCase();
    final list = <Anime>[];
    for (final a in db) {
      final matchesGenre = a.genres.any((item) => item.toLowerCase() == g || item.toLowerCase().contains(g));
      if (!matchesGenre) continue;

      final type = _typeOf(a);
      if (seriesOnly) {
        if (type == 'TV' || (a.episodes != null && a.episodes! >= 10)) {
          list.add(a);
        }
      } else {
        if (type == 'MOVIE' || type == 'SPECIAL' || (a.episodes != null && a.episodes! <= 3)) {
          list.add(a);
        }
      }
      if (list.length >= limit) break;
    }
    return list;
  }

  static Future<List<Anime>> getMovies({int limit = 20}) async {
    await ensureLoaded();
    final db = _cache ?? [];
    final list = <Anime>[];
    for (final a in db) {
      if (_typeOf(a) == 'MOVIE') {
        list.add(a);
        if (list.length >= limit) break;
      }
    }
    return list;
  }

  static Future<List<Anime>> getUpcoming({int limit = 20}) async {
    await ensureLoaded();
    final db = _cache ?? [];
    final list = <Anime>[];
    for (final a in db) {
      if (a.status?.toUpperCase() == 'UPCOMING') {
        list.add(a);
        if (list.length >= limit) break;
      }
    }
    if (list.isEmpty) {
      final currentYear = DateTime.now().year;
      for (final a in db) {
        if (a.year != null && a.year! >= currentYear) {
          list.add(a);
          if (list.length >= limit) break;
        }
      }
    }
    return list;
  }

  static Future<List<Anime>> getTopRated({int limit = 20}) async {
    await ensureLoaded();
    final db = _cache ?? [];
    return db.take(limit).toList();
  }

  static Future<Anime?> getById(int id) async {
    await ensureLoaded();
    try {
      return _cache?.firstWhere((a) => a.id == id);
    } catch (_) {
      return null;
    }
  }

  static Anime? getByIdSync(int id) {
    if (_cache == null || _cache!.isEmpty) return null;
    try {
      return _cache!.firstWhere((a) => a.id == id);
    } catch (_) {
      return null;
    }
  }

  static Anime _fromOfflineJson(Map<String, dynamic> m) {
    final title = m['title'] as String? ?? '';
    final lowerTitle = title.toLowerCase().trim();
    final synonyms = (m['synonyms'] as List<dynamic>? ?? const [])
        .whereType<String>()
        .toList();
    final englishTitle = m['titleEnglish'] as String? ??
        _englishMovieTitles[lowerTitle] ??
        (synonyms.isNotEmpty && synonyms.first != title ? synonyms.first : null);

    return Anime(
      id: (m['id'] as num?)?.toInt() ?? 0,
      title: title,
      titleEnglish: englishTitle,
      titleJapanese: synonyms.isNotEmpty ? synonyms.last : null,
      synopsis: null,
      imageUrl: m['imageUrl'] as String? ?? '',
      score: (m['score'] as num?)?.toDouble(),
      episodes: (m['episodes'] as num?)?.toInt(),
      status: m['status'] as String?,
      genres: (m['genres'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList(),
      year: (m['year'] as num?)?.toInt(),
      format: m['type'] as String?,
      synonyms: [
        ...synonyms,
        if (englishTitle != null && !synonyms.contains(englishTitle)) englishTitle,
      ],
    );
  }

  static const Map<String, String> _englishMovieTitles = {
    // Studio Ghibli
    'tonari no totoro': 'My Neighbor Totoro',
    'sen to chihiro no kamikakushi': 'Spirited Away',
    'howl no ugoku shiro': "Howl's Moving Castle",
    'majo no takkyuubin': "Kiki's Delivery Service",
    'mononoke hime': 'Princess Mononoke',
    'hotaru no haka': 'Grave of the Fireflies',
    'tenkuu no shiro laputa': 'Castle in the Sky',
    'kaze no tani no nausicaa': 'Nausicaä of the Valley of the Wind',
    'kurenai no buta': 'Porco Rosso',
    'mimi wo sumaseba': 'Whisper of the Heart',
    'gake no ue no ponyo': 'Ponyo',
    'kari-gurashi no arrietty': 'The Secret World of Arrietty',
    'kaguya-hime no monogatari': 'The Tale of the Princess Kaguya',
    'omoide no marnie': 'When Marnie Was There',
    'kimitachi wa dou ikiru ka': 'The Boy and the Heron',
    'heisei tanuki gassen ponpoko': 'Pom Poko',
    'neko no ongaeshi': 'The Cat Returns',
    'kokuriko-zaka kara': 'From Up on Poppy Hill',
    'omoide poroporo': 'Only Yesterday',
    'umi ga kikoeru': 'Ocean Waves',

    // Makoto Shinkai
    'kimi no na wa.': 'Your Name.',
    'koe no katachi': 'A Silent Voice',
    'tenki no ko': 'Weathering with You',
    'suzume no tojimari': 'Suzume',
    'byousoku 5 centimeter': '5 Centimeters per Second',
    'kotonoha no niwa': 'The Garden of Words',
    'kumo no mukou, yakusoku no basho': 'The Place Promised in Our Early Days',
    'hoshi wo ou kodomo': 'Children Who Chase Lost Voices',

    // Mamoru Hosoda
    'toki wo kakeru shoujo': 'The Girl Who Leapt Through Time',
    'summer wars': 'Summer Wars',
    'ookami kodomo no ame to yuki': 'Wolf Children',
    'bakemono no ko': 'The Boy and the Beast',
    'mirai no mirai': 'Mirai',
    'ryuu to sobakasu no hime': 'Belle',

    // Satoshi Kon & Classics
    'perfect blue': 'Perfect Blue',
    'millennium actress': 'Millennium Actress',
    'sennen joyuu': 'Millennium Actress',
    'tokyo godfathers': 'Tokyo Godfathers',
    'paprika': 'Paprika',
    'akira': 'Akira',
    'koukaku kidoutai': 'Ghost in the Shell',
    'redline': 'Redline',
    'jin-roh': 'Jin-Roh: The Wolf Brigade',

    // Popular Modern Movies
    'kimi no suizou wo tabetai': 'I Want to Eat Your Pancreas',
    'sayonara no asa ni yakusoku no hana wo kazarou': 'Maquia: When the Promised Flower Blooms',
    'jujutsu kaisen 0': 'Jujutsu Kaisen 0',
    'kimetsu no yaiba movie: mugen ressha-hen': 'Demon Slayer: Mugen Train',
    'one piece film: red': 'One Piece Film: Red',
    'one piece film: z': 'One Piece Film: Z',
    'one piece film: gold': 'One Piece Film: Gold',
    'one piece movie 14: stampede': 'One Piece: Stampede',
    'dragon ball super: broly': 'Dragon Ball Super: Broly',
    'dragon ball super: super hero': 'Dragon Ball Super: Super Hero',
    'violet evergarden movie': 'Violet Evergarden: The Movie',
    'seishun buta yarou wa yumemiru shoujo no yume wo minai': 'Rascal Does Not Dream of a Dreaming Girl',
    'kono subarashii sekai ni shukufuku wo!: kurenai densetsu': 'KonoSuba: Legend of Crimson',
    'no game no life: zero': 'No Game No Life Zero',
    'sword art online movie: ordinal scale': 'Sword Art Online: Ordinal Scale',
    'mahou shoujo madoka★magica movie 3: hangyaku no monogatari': 'Puella Magi Madoka Magica: Rebellion',
    'kara no kyoukai': 'The Garden of Sinners',
    'stand by me doraemon': 'Stand by Me Doraemon',
    'promare': 'Promare',
    'inu-oh': 'Inu-Oh',
    'look back': 'Look Back',
    'the first slam dunk': 'The First Slam Dunk',
    'blue giant': 'Blue Giant',
    'spy x family movie: code: white': 'Spy x Family Code: White',
    'haikyuu!! movie: gomi suteba no kessen': 'Haikyu!! The Dumpster Battle',
    'detective conan': 'Detective Conan',
    'meitantei conan': 'Detective Conan',
  };

  static String? _typeOf(Anime a) => (a.format ?? a.source)?.toUpperCase();

  // ===== Curated "Terbaik per Genre" (hasil scraping AniList/MAL) =====

  static Future<void> _ensureTopLoaded() async {
    if (_topCache != null) return;
    try {
      final raw = await rootBundle.loadString(_topAssetPath);
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final parsed = <String, List<Anime>>{};
      map.forEach((key, value) {
        if (key == '_meta') return;
        if (value is! List) return;
        parsed[key] = value
            .whereType<Map>()
            .map((e) => _fromTopJson(Map<String, dynamic>.from(e)))
            .where((a) => a.id > 0)
            .toList();
      });
      _topCache = parsed;
    } catch (_) {
      _topCache = {};
    }
  }

  static Anime _fromTopJson(Map<String, dynamic> m) => Anime(
        id: (m['id'] as num?)?.toInt() ?? 0,
        title: m['title'] as String? ?? '',
        titleEnglish: m['titleEnglish'] as String?,
        imageUrl: m['imageUrl'] as String? ?? '',
        score: (m['score'] as num?)?.toDouble(),
        episodes: (m['episodes'] as num?)?.toInt(),
        status: m['status'] as String?,
        year: (m['year'] as num?)?.toInt(),
        genres:
            (m['genres'] as List<dynamic>? ?? const []).whereType<String>().toList(),
      );

  /// Anime terbaik/booming per genre dari data curated statis.
  /// Selalu tersedia walau API mati.
  static Future<List<Anime>> getTopByGenre(String genre, {int limit = 20}) async {
    await _ensureTopLoaded();
    final db = _topCache ?? {};
    final key = db.keys.cast<String?>().firstWhere(
          (k) => k!.toLowerCase() == genre.toLowerCase().trim(),
          orElse: () => null,
        );
    if (key == null) return [];
    return db[key]!.take(limit).toList();
  }

  /// Film terbaik dari data curated statis.
  static Future<List<Anime>> getCuratedMovies({int limit = 20}) async {
    await _ensureTopLoaded();
    return (_topCache?['_movies'] ?? const <Anime>[]).take(limit).toList();
  }
}

class _SearchResult {
  final Anime anime;
  final int score;
  _SearchResult({required this.anime, required this.score});
}

class _IndexedAnime {
  final Anime anime;
  final String titleLower;
  final String? englishLower;
  final List<String> variants;
  final String combined;

  _IndexedAnime({
    required this.anime,
    required this.titleLower,
    this.englishLower,
    required this.variants,
    required this.combined,
  });
}
