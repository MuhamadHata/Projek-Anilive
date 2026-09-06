import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_tokens.dart';
import '../../auth/presentation/auth_provider.dart';
import '../../notification/data/notification_repository.dart';
import '../../notification/presentation/notifications_screen.dart';
import '../../profile/presentation/profile_screen.dart';
import '../data/status_repository_impl.dart';
import '../domain/status_update.dart';
import 'post_status_screen.dart';
import 'status_comments_sheet.dart';
import 'status_detail_screen.dart';
import '../../chat/presentation/friend_chats_screen.dart';

class HomeFeedScreen extends ConsumerWidget {
  const HomeFeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedAsync = ref.watch(feedProvider);
    final currentUser =
        ref.watch(authNotifierProvider).value ??
        ref.watch(authRepositoryProvider).currentUser;
    final currentUserId = currentUser?.id ?? 'mock_user_123';
    final unreadCount =
        ref.watch(unreadNotificationsCountProvider(currentUserId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: Image.asset(
                'assets/images/anilive_logo.png',
                width: 28,
                height: 28,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const Icon(
                  Icons.live_tv,
                  size: AppIconSize.md,
                  color: AppColors.accent,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            const Text('Anilive'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Pesan & Teman',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const FriendChatsScreen(),
                ),
              );
            },
            icon: const Icon(Icons.forum_outlined),
          ),
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                tooltip: 'Notifikasi',
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const NotificationsScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.notifications_outlined),
              ),
              if (unreadCount > 0)
                Positioned(
                  top: AppSpacing.sm,
                  right: AppSpacing.sm,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: AppColors.dangerBright,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 14,
                      minHeight: 14,
                    ),
                    child: Text(
                      unreadCount > 9 ? '9+' : unreadCount.toString(),
                      style: AppTypography.micro.copyWith(
                        color: AppColors.textOnAccent,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(feedProvider);
          await Future.delayed(const Duration(milliseconds: 300));
        },
        child: feedAsync.when(
          data: (items) => items.isEmpty
              ? SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Container(
                    height: MediaQuery.of(context).size.height * 0.7,
                    alignment: Alignment.center,
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.feed_outlined,
                          size: AppIconSize.hero,
                          color: AppColors.textFaint,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'Feed masih kosong. Posting status pertama!',
                          textAlign: TextAlign.center,
                          style: AppTypography.bodyMuted,
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  itemCount: items.length,
                  itemBuilder: (_, i) => _StatusFeedCard(status: items[i]),
                ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Container(
              height: MediaQuery.of(context).size.height * 0.7,
              alignment: Alignment.center,
              child: Text('Error: $e', style: AppTypography.bodyMuted),
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.accent,
        foregroundColor: AppColors.textOnAccent,
        onPressed: () {
          final user =
              ref.read(authNotifierProvider).value ??
              ref.read(authRepositoryProvider).currentUser;
          if (user != null) {
            Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const PostStatusScreen()));
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _StatusFeedCard extends ConsumerWidget {
  final StatusUpdate status;

  const _StatusFeedCard({required this.status});

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes} menit lalu';
    if (diff.inHours < 24) return '${diff.inHours} jam lalu';
    return '${diff.inDays} hari lalu';
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'completed':
        return 'baru selesai menonton!';
      case 'watching':
        return 'sedang menonton!';
      case 'planned':
        return 'berencana menonton!';
      default:
        return 'update status nonton!';
    }
  }

  Widget _buildAvatar(String? avatarUrl) {
    if (avatarUrl != null && avatarUrl.isNotEmpty && !avatarUrl.startsWith('grad:')) {
      if (avatarUrl.startsWith('data:')) {
        try {
          final bytes = base64Decode(avatarUrl.split(',').last);
          return CircleAvatar(
            radius: AppIconSize.md,
            backgroundColor: AppColors.surfaceAlt,
            backgroundImage: MemoryImage(bytes),
          );
        } catch (_) {}
      } else if (avatarUrl.startsWith('http://') || avatarUrl.startsWith('https://')) {
        return CircleAvatar(
          radius: AppIconSize.md,
          backgroundColor: AppColors.surfaceAlt,
          backgroundImage: CachedNetworkImageProvider(avatarUrl),
          onBackgroundImageError: (_, _) {},
        );
      }
    }
    return const CircleAvatar(
      radius: AppIconSize.md,
      backgroundColor: AppColors.surfaceAlt,
      child: Icon(
        Icons.person,
        size: AppIconSize.sm,
        color: AppColors.textMuted,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser =
        ref.watch(authNotifierProvider).value ??
        ref.watch(authRepositoryProvider).currentUser;
    final currentUserId = currentUser?.id ?? 'mock_user_123';
    final isLiked = status.likedBy.contains(currentUserId);
    final timeStr = _timeAgo(status.createdAt);

    return Card(
      color: AppColors.surfaceDialog,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User Header - clickable to profile
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ProfileScreen(userId: status.userId),
                  ),
                );
              },
              child: Row(
                children: [
                  _buildAvatar(status.avatarUrl),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(status.username, style: AppTypography.bodyStrong),
                        Text(
                          timeStr,
                          style: AppTypography.captionFaint.copyWith(
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right,
                    size: AppIconSize.sm,
                    color: AppColors.textFaint,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(_statusLabel(status.watchStatus),
                style: AppTypography.bodyMuted),
            const SizedBox(height: AppSpacing.sm),

            // Anime Content Row with Poster Image - tap to open detail
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => StatusDetailScreen(statusId: status.id),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Anime Poster
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      child: SizedBox(
                        width: 76,
                        height: 108,
                        child: status.animeCoverUrl.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: status.animeCoverUrl,
                                fit: BoxFit.cover,
                                placeholder: (_, _) => Container(
                                  color: AppColors.surfaceAlt,
                                  child: const Center(
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.accent,
                                    ),
                                  ),
                                ),
                                errorWidget: (_, _, _) => Container(
                                  color: AppColors.surfaceAlt,
                                  child: const Icon(
                                    Icons.movie_creation_outlined,
                                    color: AppColors.textFaint,
                                    size: AppIconSize.lg,
                                  ),
                                ),
                              )
                            : Container(
                                color: AppColors.surfaceAlt,
                                child: const Icon(
                                  Icons.movie_creation_outlined,
                                  color: AppColors.textFaint,
                                  size: AppIconSize.lg,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    // Anime Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            status.animeTitle,
                            style: AppTypography.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (status.rating != null) ...[
                            const SizedBox(height: AppSpacing.xs),
                            Row(
                              children: [
                                const Icon(
                                  Icons.star_rounded,
                                  size: AppIconSize.sm,
                                  color: AppColors.star,
                                ),
                                const SizedBox(width: AppSpacing.xs),
                                Text(
                                  '${status.rating!.toStringAsFixed(1)} / 10',
                                  style: AppTypography.bodyStrong.copyWith(
                                    color: AppColors.star,
                                  ),
                                ),
                              ],
                            ),
                          ],
                          if (status.caption.isNotEmpty) ...[
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              status.caption,
                              style: AppTypography.body,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Actions: Realtime Love & Chat/Comment buttons
            Row(
              children: [
                InkWell(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  onTap: () {
                    ref.read(statusRepositoryProvider).toggleLike(
                          status.id,
                          currentUserId,
                          authorId: status.userId,
                          currentUsername: currentUser?.username ?? 'Pengguna',
                          currentAvatarUrl: currentUser?.avatarUrl,
                          animeTitle: status.animeTitle,
                        );
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xs,
                      vertical: AppSpacing.xs,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isLiked ? Icons.favorite : Icons.favorite_border,
                          size: AppIconSize.md,
                          color: isLiked
                              ? AppColors.dangerBright
                              : AppColors.dangerBright,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          '${status.likeCount}',
                          style: AppTypography.bodyMuted.copyWith(
                            color: isLiked
                                ? AppColors.dangerBright
                                : AppColors.textMuted,
                            fontWeight: isLiked
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.xl),
                InkWell(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  onTap: () {
                    StatusCommentsSheet.show(context, status);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xs,
                      vertical: AppSpacing.xs,
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.chat_bubble_outline,
                          size: AppIconSize.md,
                          color: AppColors.textMuted,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          '${status.commentCount}',
                          style: AppTypography.bodyMuted,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
