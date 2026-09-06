import 'package:flutter_test/flutter_test.dart';
import 'package:anitrack/features/anime/data/anime_database_cache.dart';
import 'package:anitrack/features/anime/data/anime_rag_search_service.dart';
import 'package:anitrack/features/anime/data/anime_repository_impl.dart';
import 'package:anitrack/features/anime/domain/anime.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AnimeDatabaseCache & RAG Tests', () {
    const sampleAnime = Anime(
      id: 888123,
      title: 'Chainsaw Man Database Test',
      titleEnglish: 'Chainsaw Man',
      imageUrl: 'https://example.com/csm.jpg',
      score: 8.6,
      episodes: 12,
      status: 'Finished Airing',
      genres: ['Action', 'Supernatural'],
      trailerUrl: 'https://youtube.com/watch?v=sample',
      characters: [
        AnimeCharacter(
          name: 'Denji',
          role: 'Main',
          voiceActorName: 'Kikunosuke Toya',
        ),
      ],
      openingThemes: ['KICK BACK by Kenshi Yonezu'],
      endingThemes: ['CHAINSAW BLOOD'],
    );

    test('AnimeDatabaseCache serialization and deserialization retains all fields', () {
      final map = AnimeDatabaseCache.toSupabaseMap(sampleAnime);
      expect(map['id'], equals(888123));
      expect(map['title'], equals('Chainsaw Man Database Test'));
      expect(map['trailer_url'], equals('https://youtube.com/watch?v=sample'));

      final restored = AnimeDatabaseCache.fromSupabaseMap(map);
      expect(restored.id, equals(sampleAnime.id));
      expect(restored.title, equals(sampleAnime.title));
      expect(restored.trailerUrl, equals(sampleAnime.trailerUrl));
      expect(restored.characters.length, equals(1));
      expect(restored.characters.first.name, equals('Denji'));
      expect(restored.characters.first.voiceActorName, equals('Kikunosuke Toya'));
      expect(restored.openingThemes, contains('KICK BACK by Kenshi Yonezu'));
    });

    test('AnimeDatabaseCache saveAnime and getAnimeById retrieves instantly from cache', () async {
      await AnimeDatabaseCache.saveAnime(sampleAnime);
      final retrieved = await AnimeDatabaseCache.getAnimeById(888123);
      expect(retrieved, isNotNull);
      expect(retrieved?.id, equals(sampleAnime.id));
      expect(retrieved?.title, equals(sampleAnime.title));
    });

    test('AnimeRagSearchService.isDescriptiveQuery identifies natural language descriptions', () {
      final rag = AnimeRagSearchService();

      expect(rag.isDescriptiveQuery('naruto'), isFalse);
      expect(rag.isDescriptiveQuery('bleach'), isFalse);
      expect(rag.isDescriptiveQuery('anime tentang dokter reinkarnasi'), isTrue);
      expect(rag.isDescriptiveQuery('ninja rambut kuning rubah ekor'), isTrue);
      expect(rag.isDescriptiveQuery('anime masak baju robek'), isTrue);
      expect(rag.isDescriptiveQuery('orang masuk dunia game terjebak'), isTrue);
    });

    test('AnimeRepositoryImpl returns anime from AnimeDatabaseCache without network delay', () async {
      final repo = AnimeRepositoryImpl();
      const testDbAnime = Anime(
        id: 777456,
        title: 'Cached Database Anime',
        imageUrl: 'https://example.com/cached.jpg',
        score: 9.0,
      );

      await AnimeDatabaseCache.saveAnime(testDbAnime);

      final detail = await repo.getAnimeDetail(777456);
      expect(detail.id, equals(777456));
      expect(detail.title, equals('Cached Database Anime'));
    });
  });
}
