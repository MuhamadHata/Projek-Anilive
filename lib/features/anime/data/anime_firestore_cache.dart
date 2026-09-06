import '../domain/anime.dart';
import 'anime_database_cache.dart';

/// Legacy adapter yang meneruskan seluruh pemanggilan cache ke AnimeDatabaseCache
/// (Memory + SharedPreferencesAsync + Supabase Cloud).
class AnimeFirestoreCache {
  static Future<void> saveAnime(Anime anime) async {
    await AnimeDatabaseCache.saveAnime(anime);
  }

  static Future<void> saveAnimeList(List<Anime> list) async {
    await AnimeDatabaseCache.saveAnimeList(list);
  }

  static Future<Anime?> getAnimeById(int id) async {
    return await AnimeDatabaseCache.getAnimeById(id);
  }

  static Future<List<Anime>> searchLocal({
    required String query,
    int limit = 20,
  }) async {
    return await AnimeDatabaseCache.searchLocal(query: query, limit: limit);
  }

  static bool matches(Anime anime, String query) {
    final q = query.toLowerCase();
    return anime.title.toLowerCase().contains(q) ||
        (anime.titleEnglish?.toLowerCase().contains(q) ?? false) ||
        (anime.titleJapanese?.toLowerCase().contains(q) ?? false) ||
        anime.genres.any((g) => g.toLowerCase().contains(q));
  }
}
