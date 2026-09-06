import 'package:anitrack/features/chat/data/direct_chat_repository.dart';
import 'package:anitrack/features/chat/domain/direct_message.dart';
import 'package:anitrack/features/notification/data/notification_repository.dart';
import 'package:anitrack/features/notification/domain/notification_model.dart';
import 'package:anitrack/features/social/data/friendship_repository.dart';
import 'package:anitrack/features/social/data/status_repository_impl.dart';
import 'package:anitrack/features/social/domain/friendship_model.dart';
import 'package:anitrack/features/social/domain/status_update.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Social and Notification Feature Tests', () {
    test('StatusRepository toggles like and updates count', () async {
      final notifRepo = NotificationRepositoryImpl();
      final repo = StatusRepositoryImpl(notificationRepo: notifRepo);

      final status = StatusUpdate(
        id: 'test_st_1',
        userId: 'author_1',
        username: 'Author',
        animeId: 100,
        animeTitle: 'Test Anime',
        animeCoverUrl: 'https://example.com/cover.jpg',
        watchStatus: 'completed',
        rating: 9.0,
        caption: 'Great anime!',
        likeCount: 5,
        createdAt: DateTime.now(),
      );
      await repo.postStatus(status);

      final feedInitial = await repo.getFeed().first;
      final target = feedInitial.firstWhere((s) => s.id == 'test_st_1');
      final initialLikes = target.likeCount;

      await repo.toggleLike(
        target.id,
        'test_user_99',
        authorId: target.userId,
        currentUsername: 'Tester',
        animeTitle: target.animeTitle,
      );

      final feedUpdated = await repo.getFeed().first;
      final updatedTarget = feedUpdated.firstWhere((s) => s.id == target.id);
      expect(updatedTarget.likedBy.contains('test_user_99'), isTrue);
      expect(updatedTarget.likeCount, equals(initialLikes + 1));
    });

    test('StatusRepository adds comments and retrieves them', () async {
      final notifRepo = NotificationRepositoryImpl();
      final repo = StatusRepositoryImpl(notificationRepo: notifRepo);

      final comment = StatusComment(
        id: 'test_cmt_1',
        statusId: 'mock_chi',
        userId: 'test_user_99',
        username: 'Tester',
        content: 'Mantap banget!',
        createdAt: DateTime.now(),
      );

      await repo.addComment(comment, authorId: 'user_sakura');
      final comments = await repo.getComments('mock_chi').first;

      expect(comments.any((c) => c.content == 'Mantap banget!'), isTrue);
    });

    test('FriendshipRepository request and accept flow', () async {
      final notifRepo = NotificationRepositoryImpl();
      final repo = FriendshipRepositoryImpl(notificationRepo: notifRepo);

      const userA = 'user_alice';
      const userB = 'user_bob';

      // Send friend request
      await repo.sendFriendRequest(
        fromUserId: userA,
        fromUsername: 'Alice',
        toUserId: userB,
      );

      final statusA = await repo.watchFriendshipStatus(userA, userB).first;
      expect(statusA, equals(FriendshipStatus.sent));

      final statusB = await repo.watchFriendshipStatus(userB, userA).first;
      expect(statusB, equals(FriendshipStatus.received));

      // Accept friend request
      await repo.acceptFriendRequest(
        currentUserId: userB,
        currentUsername: 'Bob',
        requesterId: userA,
      );

      final statusAfter = await repo.watchFriendshipStatus(userA, userB).first;
      expect(statusAfter, equals(FriendshipStatus.friends));
    });

    test('DirectChatRepository sends and reads messages', () async {
      final repo = DirectChatRepositoryImpl();
      const user1 = 'friend_a';
      const user2 = 'friend_b';

      await repo.sendMessage(
        DirectMessage(
          id: 'm1',
          senderId: user1,
          senderName: 'Friend A',
          receiverId: user2,
          content: 'Halo teman!',
          createdAt: DateTime.now(),
        ),
      );

      final messages = await repo.watchMessages(user1, user2).first;
      expect(messages.any((m) => m.content == 'Halo teman!'), isTrue);
    });

    test('NotificationRepository sends and marks as read', () async {
      final repo = NotificationRepositoryImpl();
      const userId = 'notif_test_user';

      await repo.sendNotification(
        AppNotification(
          id: 'test_notif_1',
          recipientUserId: userId,
          actorId: 'actor_1',
          actorUsername: 'Actor',
          type: NotificationType.love,
          title: 'Love Baru',
          body: 'Actor menyukai status Anda',
          createdAt: DateTime.now(),
        ),
      );

      final list = await repo.watchNotifications(userId).first;
      final added = list.firstWhere((n) => n.id == 'test_notif_1');
      expect(added.isRead, isFalse);

      await repo.markAsRead('test_notif_1');
      final listUpdated = await repo.watchNotifications(userId).first;
      final updated = listUpdated.firstWhere((n) => n.id == 'test_notif_1');
      expect(updated.isRead, isTrue);

      // Delete notification test
      await repo.deleteNotification('test_notif_1');
      final listAfterDelete = await repo.watchNotifications(userId).first;
      expect(listAfterDelete.any((n) => n.id == 'test_notif_1'), isFalse);
    });

    test('StatusRepository getStatusById returns correct status', () async {
      final notifRepo = NotificationRepositoryImpl();
      final repo = StatusRepositoryImpl(notificationRepo: notifRepo);

      final status = StatusUpdate(
        id: 'status_lookup_test',
        userId: 'author_lookup',
        username: 'Author Lookup',
        animeId: 101,
        animeTitle: 'Lookup Anime',
        animeCoverUrl: 'https://example.com/cover.jpg',
        watchStatus: 'completed',
        rating: 8.5,
        caption: 'Lookup caption',
        likeCount: 2,
        createdAt: DateTime.now(),
      );
      await repo.postStatus(status);

      final fetched = await repo.getStatusById('status_lookup_test');
      expect(fetched, isNotNull);
      expect(fetched?.id, equals('status_lookup_test'));
      expect(fetched?.animeTitle, equals('Lookup Anime'));
    });

    test('FriendshipRepository dynamic watchFriends adds friend on accept', () async {
      final notifRepo = NotificationRepositoryImpl();
      final repo = FriendshipRepositoryImpl(notificationRepo: notifRepo);

      const me = 'user_dynamic_me';
      const friend = 'user_dynamic_friend';

      await repo.sendFriendRequest(
        fromUserId: friend,
        fromUsername: 'Dynamic Friend',
        toUserId: me,
      );

      await repo.acceptFriendRequest(
        currentUserId: me,
        currentUsername: 'My Name',
        requesterId: friend,
      );

      final friendsList = await repo.watchFriends(me).first;
      expect(friendsList.any((f) => f.id == friend), isTrue);
    });
  });
}
