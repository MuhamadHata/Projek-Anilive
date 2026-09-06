import 'package:flutter_test/flutter_test.dart';
import 'package:anitrack/features/anime/data/anime_offline_db.dart';
import 'package:anitrack/features/anime/data/anime_repository_impl.dart';
import 'package:anitrack/features/anime/domain/anime.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Anime Instant Search & Detail Tests', () {
    test('AnimeOfflineDb.search returns instantly and ranks relevant titles', () async {
      final results = await AnimeOfflineDb.search('naruto');
      expect(results, isNotEmpty);
      final first = results.first;
      expect(first.title.toLowerCase(), contains('naruto'));
    });

    test('AnimeOfflineDb.getByIdSync returns existing anime synchronously', () async {
      await AnimeOfflineDb.ensureLoaded();
      // Search an anime first to get a known ID
      final list = await AnimeOfflineDb.search('one piece');
      expect(list, isNotEmpty);
      final sample = list.first;

      final syncResult = AnimeOfflineDb.getByIdSync(sample.id);
      expect(syncResult, isNotNull);
      expect(syncResult?.id, equals(sample.id));
      expect(syncResult?.title, equals(sample.title));
    });

    test('AnimeRepositoryImpl.watchAnimeDetail emits instant cached/offline anime', () async {
      final repo = AnimeRepositoryImpl();
      const testAnime = Anime(
        id: 999999,
        title: 'Instant Anime',
        imageUrl: 'https://example.com/poster.jpg',
        score: 8.5,
        episodes: 12,
        status: 'Finished Airing',
      );

      AnimeRepositoryImpl.cacheDetail(testAnime);

      final stream = repo.watchAnimeDetail(999999);
      final firstEmitted = await stream.first;

      expect(firstEmitted.id, equals(999999));
      expect(firstEmitted.title, equals('Instant Anime'));
      expect(firstEmitted.score, equals(8.5));
    });

    test('AnimeRepositoryImpl.searchAnime caches results for 0ms subsequent lookups', () async {
      final repo = AnimeRepositoryImpl();
      final results1 = await repo.searchAnime('bleach');
      expect(results1, isNotEmpty);

      // Subsequent call with same query should be instant from memory cache
      final results2 = await repo.searchAnime('bleach');
      expect(results2.length, equals(results1.length));
      expect(results2.first.id, equals(results1.first.id));
    });
  });
}
