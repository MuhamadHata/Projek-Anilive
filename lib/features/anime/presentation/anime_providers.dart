import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/anime_offline_db.dart';
import '../data/anime_repository_impl.dart';
import '../data/anilist_api.dart';
import '../data/jikan_api.dart';
import '../domain/anime.dart';
import '../domain/anime_repository.dart';

final jikanApiProvider = Provider<JikanApi>((ref) => JikanApi());
final aniListApiProvider = Provider<AniListApi>((ref) => AniListApi());

final animeRepositoryProvider = Provider<AnimeRepository>((ref) {
  return AnimeRepositoryImpl(api: ref.watch(jikanApiProvider));
});

final trendingProvider = FutureProvider.autoDispose<List<Anime>>((ref) {
  return ref.watch(animeRepositoryProvider).getTrending();
});

final topRatedProvider = FutureProvider.autoDispose.family<List<Anime>, int>((
  ref,
  page,
) {
  return ref.watch(animeRepositoryProvider).getTopRated(page: page);
});

final currentSeasonProvider = FutureProvider.autoDispose<List<Anime>>((ref) {
  return ref.watch(animeRepositoryProvider).getCurrentSeason();
});

final upcomingSeasonProvider = FutureProvider.autoDispose<List<Anime>>((ref) {
  return ref.watch(animeRepositoryProvider).getUpcomingSeason();
});

/// AniList genre-based categories — diurutkan berdasarkan SKOR tertinggi
/// sehingga menampilkan anime terbaik/booming di genre tsb
/// (mis. Action -> Attack on Titan, Jujutsu Kaisen).
final genreAnimeProvider = FutureProvider.autoDispose
    .family<List<Anime>, String>((ref, genre) async {
  bool matchesTargetGenre(Anime a) {
    final gLower = genre.toLowerCase().trim();
    return a.genres.any((item) {
      final iLower = item.toLowerCase().trim();
      return iLower == gLower || iLower.contains(gLower);
    });
  }

  // 1. AniList: skor >= 7.5, format TV, urut skor tertinggi
  try {
    final list = await ref.watch(aniListApiProvider).searchByGenre(
      genre,
      sort: 'SCORE_DESC',
      format: 'TV',
      minScore: 75,
    );
    final filtered = list.where((a) {
      if (!AnimeSafety.isSafe(a)) return false;
      if (!matchesTargetGenre(a)) return false;
      final f = (a.format ?? '').toUpperCase();
      return (a.episodes ?? 12) >= 8 && f != 'MOVIE' && f != 'MUSIC';
    }).toList();
    if (filtered.isNotEmpty) return filtered;
  } catch (_) {}

  // 2. Jikan: score desc + min_score 7.5
  try {
    final id = _genreNameToId(genre);
    if (id != null) {
      final list = await ref.watch(jikanApiProvider).searchAnime(
        '',
        genres: [id],
        orderBy: 'score',
        type: 'tv',
        minScore: 7.5,
      );
      final safe = AnimeSafety.filterList(list)
          .where(matchesTargetGenre)
          .toList();
      if (safe.isNotEmpty) return safe;
    }
  } catch (_) {}

  // 3. Curated statis: hasil scraping AniList/MAL (skor + genre lengkap)
  try {
    final curated =
        AnimeSafety.filterList(await AnimeOfflineDb.getTopByGenre(genre))
            .where(matchesTargetGenre)
            .toList();
    if (curated.isNotEmpty) return curated;
  } catch (_) {}

  return AnimeSafety.filterList(
    await AnimeOfflineDb.getByGenre(genre, seriesOnly: true),
  ).where(matchesTargetGenre).toList();
});

int? _genreNameToId(String name) {
  const map = {
    'action': 1,
    'adventure': 2,
    'comedy': 4,
    'drama': 8,
    'fantasy': 10,
    'romance': 22,
    'sci-fi': 24,
    'slice of life': 36,
    'supernatural': 37,
  };
  return map[name.toLowerCase()];
}

/// Film & Movie Terbaik — skor tertinggi dari AniList/MAL.
final topMoviesProvider = FutureProvider.autoDispose<List<Anime>>((ref) async {
  try {
    final list = await ref.watch(aniListApiProvider).searchByGenre(
      'Action',
      sort: 'SCORE_DESC',
      format: 'MOVIE',
      minScore: 78,
    );
    final movies = list
        .where((a) =>
            AnimeSafety.isSafe(a) &&
            ((a.format ?? '').toUpperCase() == 'MOVIE' || a.episodes == 1))
        .toList();
    if (movies.isNotEmpty) return movies;
  } catch (_) {}

  try {
    final list = await ref.watch(jikanApiProvider).searchAnime(
      '',
      orderBy: 'score',
      type: 'movie',
      minScore: 8.0,
    );
    final safe = AnimeSafety.filterList(list);
    if (safe.isNotEmpty) return safe;
  } catch (_) {}

  // Curated statis: film terbaik hasil scraping
  try {
    final curatedMovies = AnimeSafety.filterList(
      await AnimeOfflineDb.getCuratedMovies(),
    );
    if (curatedMovies.isNotEmpty) return curatedMovies;
  } catch (_) {}

  return AnimeSafety.filterList(await AnimeOfflineDb.getMovies());
});

class AnimeFilterArgs {
  final String query;
  final List<int>? genres;
  final String? status;
  final String? orderBy;
  final bool allowAdult;

  const AnimeFilterArgs({
    required this.query,
    this.genres,
    this.status,
    this.orderBy,
    this.allowAdult = false,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AnimeFilterArgs &&
          runtimeType == other.runtimeType &&
          query == other.query &&
          status == other.status &&
          orderBy == other.orderBy &&
          allowAdult == other.allowAdult &&
          _listEquals(genres, other.genres);

  @override
  int get hashCode =>
      query.hashCode ^
      (status?.hashCode ?? 0) ^
      (orderBy?.hashCode ?? 0) ^
      (allowAdult ? 1 : 0) ^
      Object.hashAll(genres ?? []);

  static bool _listEquals(List<int>? a, List<int>? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

final searchAnimeProvider = FutureProvider.autoDispose
    .family<List<Anime>, AnimeFilterArgs>((ref, args) {
      if (args.query.length < 2 && (args.genres == null || args.genres!.isEmpty) && args.status == null && args.orderBy == null) {
        return <Anime>[];
      }
      return ref.watch(animeRepositoryProvider).searchAnime(
        args.query,
        genres: args.genres,
        status: args.status,
        orderBy: args.orderBy,
        allowAdult: args.allowAdult,
      );
    });


final animeDetailProvider = StreamProvider.autoDispose.family<Anime, int>((
  ref,
  id,
) {
  return ref.watch(animeRepositoryProvider).watchAnimeDetail(id);
});

/// Anime serupa berdasarkan rekomendasi komunitas MAL.
final animeRecommendationsProvider = FutureProvider.autoDispose
    .family<List<Anime>, int>((ref, id) {
      return ref.watch(animeRepositoryProvider).getRecommendations(id);
    });
