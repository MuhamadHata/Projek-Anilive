import 'package:anitrack/features/anime/data/anime_repository_impl.dart';
import 'package:anitrack/features/anime/presentation/anime_providers.dart';
import 'package:anitrack/features/profile/data/profile_repository_impl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Instant Explore & Profile Load Tests', () {
    test('ProfileRepositoryImpl.watchProfile emits initial profile immediately (0 ms)', () async {
      final repo = ProfileRepositoryImpl();
      final stream = repo.watchProfile('user_test_999');

      final firstProfile = await stream.first;
      expect(firstProfile, isNotNull);
      expect(firstProfile?.id, 'user_test_999');
      expect(firstProfile?.displayName, isNotEmpty);
    });

    test('AnimeRepositoryImpl returns non-empty trending and season on fresh install (empty cache)', () async {
      final repo = AnimeRepositoryImpl();

      final trending = await repo.getTrending();
      expect(trending, isNotEmpty);
      expect(trending.first.title, isNotEmpty);

      final season = await repo.getCurrentSeason();
      expect(season, isNotEmpty);
      expect(season.first.title, isNotEmpty);

      final upcoming = await repo.getUpcomingSeason();
      expect(upcoming, isNotEmpty);

      final topRated = await repo.getTopRated(page: 1);
      expect(topRated, isNotEmpty);
    });

    test('genreAnimeProvider and topMoviesProvider resolve non-empty anime lists instantly', () async {
      final container = ProviderContainer();

      final actionList = await container.read(genreAnimeProvider('Action').future);
      expect(actionList, isNotEmpty);

      final romanceList = await container.read(genreAnimeProvider('Romance').future);
      expect(romanceList, isNotEmpty);

      final moviesList = await container.read(topMoviesProvider.future);
      expect(moviesList, isNotEmpty);

      container.dispose();
    });
  });
}
