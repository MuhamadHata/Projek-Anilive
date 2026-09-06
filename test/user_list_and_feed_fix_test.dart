import 'package:flutter_test/flutter_test.dart';
import 'package:anitrack/features/social/domain/status_update.dart';
import 'package:anitrack/features/review/domain/review.dart';
import 'package:anitrack/features/review/data/review_repository_impl.dart';

void main() {
  group('Feed & User List Bug Fix Tests', () {
    test('StatusUpdate.fromMap correctly parses Supabase payload without type cast error', () {
      final payload = {
        'id': 'st_1788618867700',
        'user_id': '920cfd78-02b9-4964-9e30-78fc85f42ed7',
        'username': 'hatzwle',
        'avatar_url': 'data:image/jpeg;base64,/9j/4AAQSkZJRg...',
        'anime_id': 11061,
        'anime_title': 'Hunter x Hunter (2011)',
        'anime_cover_url': 'https://cdn.myanimelist.net/images/anime/1337/99013.jpg',
        'watch_status': 'completed',
        'rating': 9.5,
        'caption': 'gon si bocil kematian',
        'like_count': 0,
        'comment_count': 0,
        'liked_by': <dynamic>[],
        'created_at': '2026-09-05T22:26:35.5177+00:00',
      };

      final status = StatusUpdate.fromMap(payload, 'st_1788618867700');
      expect(status.id, 'st_1788618867700');
      expect(status.animeTitle, 'Hunter x Hunter (2011)');
      expect(status.likedBy, isEmpty);
      expect(status.likedBy, isA<List<String>>());
      expect(status.avatarUrl, startsWith('data:image/jpeg;base64,'));
    });

    test('UserAnimeEntry serialization and deserialization retains episode counts', () {
      final now = DateTime.now();
      final entry = UserAnimeEntry(
        animeId: 11061,
        title: 'Hunter x Hunter (2011)',
        imageUrl: 'https://cdn.myanimelist.net/images/anime/1337/99013.jpg',
        watchStatus: 'completed',
        watchedEpisodes: 148,
        totalEpisodes: 148,
        isCompleted: true,
        overallScore: 9.5,
        reviewId: 'rev_123',
        updatedAt: now,
      );

      final map = entry.toMap();
      final restored = UserAnimeEntry.fromMap(map);

      expect(restored.animeId, 11061);
      expect(restored.watchedEpisodes, 148);
      expect(restored.totalEpisodes, 148);
      expect(restored.isCompleted, isTrue);
    });

    test('ReviewRepositoryImpl submitReview and updateWatchStatus preserve episode progress', () async {
      final repo = ReviewRepositoryImpl();
      const userId = 'user_test_456';
      const animeId = 11061; // Hunter x Hunter (2011)

      final review = Review(
        id: 'rev_test_1',
        animeId: animeId,
        userId: userId,
        username: 'Tester',
        animeTitle: 'Hunter x Hunter (2011)',
        watchedEpisodes: 75,
        totalEpisodes: 148,
        watchStatus: 'watching',
        isCompleted: false,
        ratings: const ReviewRating(),
        overallScore: 9.0,
        title: 'Great anime',
        content: 'Watching chimera ant arc',
        isRecommended: true,
        hasSpoiler: false,
        createdAt: DateTime.now(),
      );

      await repo.submitReview(review);

      final list = await repo.watchUserList(userId).first;
      expect(list.length, 1);
      expect(list.first.animeId, animeId);
      expect(list.first.watchedEpisodes, 75);
      expect(list.first.totalEpisodes, 148);

      // Update to completed
      await repo.updateWatchStatus(
        animeId: animeId,
        reviewId: 'rev_test_1',
        userId: userId,
        watchStatus: 'completed',
        watchedEpisodes: 148,
        isCompleted: true,
      );

      final updatedList = await repo.watchUserList(userId).first;
      expect(updatedList.first.watchedEpisodes, 148);
      expect(updatedList.first.isCompleted, isTrue);
    });
  });
}
