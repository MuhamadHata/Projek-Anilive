import 'package:anitrack/features/auth/domain/app_user.dart';
import 'package:anitrack/features/auth/presentation/auth_provider.dart';
import 'package:anitrack/features/anime/presentation/anime_providers.dart';
import 'package:anitrack/features/social/domain/status_update.dart';
import 'package:anitrack/features/social/data/status_repository_impl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anitrack/main.dart';

void main() {
  testWidgets('renders Anilive home screen when authenticated directly into Home Feed', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith(
            (ref) => Stream.value(
              AppUser(
                id: '1',
                email: 'test@test.com',
                username: 'Tester',
                birthDate: DateTime(2000, 1, 1),
              ),
            ),
          ),
          currentSeasonProvider.overrideWith((ref) async => []),
          trendingProvider.overrideWith((ref) async => []),
          topRatedProvider.overrideWith((ref, _) async => []),
          upcomingSeasonProvider.overrideWith((ref) async => []),
          genreAnimeProvider.overrideWith((ref, _) async => []),
          topMoviesProvider.overrideWith((ref) async => []),
          feedProvider.overrideWith((ref) => Stream.value([])),
        ],
        child: const AniliveApp(),
      ),
    );
    await tester.pump();
    await tester.pump();

    // Verify it directly renders Anilive on Home feed
    expect(find.text('Anilive'), findsWidgets);
    expect(find.text('Feed masih kosong. Posting status pertama!'), findsOneWidget);

    // Tap tab 'Explore'
    await tester.tap(find.text('Explore'));
    await tester.pump();

    // Tap tab 'Notifikasi'
    await tester.tap(find.text('Notifikasi'));
    await tester.pump();
  });

  testWidgets('renders populated HomeFeedScreen with anime posters, like and comment buttons', (tester) async {
    final sampleStatus = StatusUpdate(
      id: 'test_post_1',
      userId: 'user_456',
      username: 'SakuraChan',
      avatarUrl: '',
      animeId: 16498,
      animeTitle: 'Attack on Titan S4',
      animeCoverUrl: 'https://cdn.myanimelist.net/images/anime/1000/110533.jpg',
      watchStatus: 'completed',
      rating: 9.5,
      caption: 'Anime terbaik sepanjang masa!',
      likeCount: 42,
      commentCount: 7,
      likedBy: const ['1'],
      createdAt: DateTime.now().subtract(const Duration(minutes: 15)),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith(
            (ref) => Stream.value(
              AppUser(
                id: '1',
                email: 'test@test.com',
                username: 'Tester',
                birthDate: DateTime(2000, 1, 1),
              ),
            ),
          ),
          currentSeasonProvider.overrideWith((ref) async => []),
          trendingProvider.overrideWith((ref) async => []),
          topRatedProvider.overrideWith((ref, _) async => []),
          upcomingSeasonProvider.overrideWith((ref) async => []),
          genreAnimeProvider.overrideWith((ref, _) async => []),
          topMoviesProvider.overrideWith((ref) async => []),
          feedProvider.overrideWith((ref) => Stream.value([sampleStatus])),
        ],
        child: const AniliveApp(),
      ),
    );
    await tester.pump();
    await tester.pump();

    // Verify anime title, username, rating, likes and comments render
    expect(find.text('Attack on Titan S4'), findsOneWidget);
    expect(find.text('SakuraChan'), findsOneWidget);
    expect(find.text('Anime terbaik sepanjang masa!'), findsOneWidget);
    expect(find.text('42'), findsOneWidget);
    expect(find.text('7'), findsOneWidget);
  });
}
