import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_tokens.dart';
import '../../auth/presentation/auth_provider.dart';
import '../../profile/presentation/profile_screen.dart';
import '../../social/data/friendship_repository.dart';
import '../../social/presentation/status_detail_screen.dart';
import '../data/notification_repository.dart';
import '../domain/notification_model.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.isNegative || diff.inMinutes < 1) return 'Baru saja';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m lalu';
    if (diff.inHours < 24) return '${diff.inHours}j lalu';
    return '${diff.inDays}h lalu';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser =
        ref.watch(authNotifierProvider).value ??
        ref.watch(authRepositoryProvider).currentUser;
    final currentUserId = currentUser?.id ?? 'mock_user_123';
    final notifsAsync = ref.watch(userNotificationsProvider(currentUserId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Notifikasi'),
        actions: [
          IconButton(
            tooltip: 'Tandai semua dibaca',
            icon: const Icon(Icons.done_all, size: AppIconSize.md),
            onPressed: () {
              ref
                  .read(notificationRepositoryProvider)
                  .markAllAsRead(currentUserId);
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(userNotificationsProvider(currentUserId));
        },
        child: notifsAsync.when(
          data: (items) {
            if (items.isEmpty) {
              return SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Container(
                  height: MediaQuery.of(context).size.height * 0.7,
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.notifications_none,
                        size: AppIconSize.hero,
                        color: AppColors.textFaint,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Belum ada notifikasi',
                        style: AppTypography.bodyMuted,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.xxl,
                        ),
                        child: Text(
                          'Aktivitas seperti love, komentar, dan permintaan pertemanan akan muncul di sini.',
                          textAlign: TextAlign.center,
                          style: AppTypography.captionFaint,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            return ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final notif = items[index];
                return _NotificationTile(
                  notification: notif,
                  currentUserId: currentUserId,
                  currentUsername: currentUser?.username ?? 'Pengguna',
                  currentUserAvatar: currentUser?.avatarUrl,
                  timeStr: _timeAgo(notif.createdAt),
                );
              },
            );
          },
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.accent),
          ),
          error: (e, _) => SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Container(
              height: MediaQuery.of(context).size.height * 0.7,
              alignment: Alignment.center,
              child: Text(
                'Gagal memuat notifikasi: $e',
                style: AppTypography.bodyMuted,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NotificationTile extends ConsumerWidget {
  final AppNotification notification;
  final String currentUserId;
  final String currentUsername;
  final String? currentUserAvatar;
  final String timeStr;

  const _NotificationTile({
    required this.notification,
    required this.currentUserId,
    required this.currentUsername,
    this.currentUserAvatar,
    required this.timeStr,
  });

  IconData _iconForType(NotificationType type) {
    switch (type) {
      case NotificationType.love:
        return Icons.favorite_rounded;
      case NotificationType.comment:
        return Icons.chat_bubble_rounded;
      case NotificationType.friendRequest:
        return Icons.person_add_rounded;
      case NotificationType.friendAccepted:
        return Icons.people_rounded;
    }
  }

  Color _colorForType(NotificationType type) {
    switch (type) {
      case NotificationType.love:
        return AppColors.dangerBright;
      case NotificationType.comment:
        return AppColors.accent;
      case NotificationType.friendRequest:
        return AppColors.star;
      case NotificationType.friendAccepted:
        return AppColors.success;
    }
  }

  String _typeLabel(NotificationType type) {
    switch (type) {
      case NotificationType.love:
        return 'Menyukai Status';
      case NotificationType.comment:
        return 'Komentar Baru';
      case NotificationType.friendRequest:
        return 'Permintaan Pertemanan';
      case NotificationType.friendAccepted:
        return 'Pertemanan Diterima';
    }
  }

  Widget _buildFallbackAvatar(String username) {
    final initial = username.isNotEmpty ? username[0].toUpperCase() : '?';
    final gradientColors = AppColors.avatarGradient(username.hashCode);
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: AppTypography.title.copyWith(
          color: AppColors.textOnAccent,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildActorAvatar(String? avatarUrl, String username, Color iconColor, IconData iconData) {
    Widget imageContent;

    if (avatarUrl != null && avatarUrl.isNotEmpty && !avatarUrl.startsWith('grad:')) {
      if (avatarUrl.startsWith('data:')) {
        try {
          final bytes = base64Decode(avatarUrl.split(',').last);
          imageContent = CircleAvatar(
            radius: 22,
            backgroundColor: AppColors.surfaceAlt,
            backgroundImage: MemoryImage(bytes),
          );
        } catch (_) {
          imageContent = _buildFallbackAvatar(username);
        }
      } else if (avatarUrl.startsWith('http://') || avatarUrl.startsWith('https://')) {
        imageContent = CircleAvatar(
          radius: 22,
          backgroundColor: AppColors.surfaceAlt,
          backgroundImage: CachedNetworkImageProvider(avatarUrl),
          onBackgroundImageError: (_, _) {},
        );
      } else {
        imageContent = _buildFallbackAvatar(username);
      }
    } else {
      imageContent = _buildFallbackAvatar(username);
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: iconColor.withAlpha(150),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: iconColor.withAlpha(45),
                blurRadius: 8,
                spreadRadius: 1,
              ),
            ],
          ),
          child: imageContent,
        ),
        Positioned(
          bottom: -1,
          right: -1,
          child: Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: AppColors.surfaceDialog,
              shape: BoxShape.circle,
              border: Border.all(color: iconColor, width: 1.2),
            ),
            child: Icon(
              iconData,
              size: AppIconSize.xs,
              color: iconColor,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final iconData = _iconForType(notification.type);
    final iconColor = _colorForType(notification.type);

    // Ambil foto profil actor secara reaktif bila di notifikasi belum tersimpan
    final actorProfile = notification.actorId.isNotEmpty
        ? ref.watch(profileProvider(notification.actorId)).value
        : null;
    final resolvedUsername = (actorProfile != null &&
            actorProfile.displayName.isNotEmpty &&
            actorProfile.displayName != 'Pengguna')
        ? actorProfile.displayName
        : (actorProfile != null &&
                actorProfile.username.isNotEmpty &&
                actorProfile.username != 'Pengguna')
            ? actorProfile.username
            : (notification.actorUsername.isNotEmpty &&
                    notification.actorUsername != 'Pengguna')
                ? notification.actorUsername
                : 'Pengguna';
    final avatarUrl = (actorProfile?.avatarUrl != null &&
            actorProfile!.avatarUrl!.isNotEmpty &&
            !actorProfile.avatarUrl!.startsWith('grad:'))
        ? actorProfile.avatarUrl
        : (notification.actorAvatarUrl != null &&
                notification.actorAvatarUrl!.isNotEmpty &&
                !notification.actorAvatarUrl!.startsWith('grad:'))
            ? notification.actorAvatarUrl
            : null;

    // Format body text agar tidak muncul "Pengguna" jika ada nama asli
    String displayBody = notification.body;
    if (notification.type == NotificationType.friendRequest) {
      displayBody = resolvedUsername != 'Pengguna'
          ? '$resolvedUsername ingin berteman dengan Anda'
          : (notification.body.isNotEmpty
              ? notification.body
              : 'Seseorang ingin berteman dengan Anda');
    } else if (notification.type == NotificationType.friendAccepted) {
      displayBody = resolvedUsername != 'Pengguna'
          ? '$resolvedUsername menerima permintaan pertemanan Anda'
          : (notification.body.isNotEmpty
              ? notification.body
              : 'Permintaan pertemanan Anda telah diterima');
    } else {
      if (resolvedUsername != 'Pengguna' && displayBody.contains('Pengguna')) {
        displayBody = displayBody.replaceAll('Pengguna', resolvedUsername);
      }
    }

    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: notification.isRead
            ? AppColors.surface.withAlpha(160)
            : AppColors.surfaceDialog,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: notification.isRead
              ? AppColors.border.withAlpha(70)
              : iconColor.withAlpha(110),
          width: 1.2,
        ),
        boxShadow: notification.isRead
            ? null
            : [
                BoxShadow(
                  color: iconColor.withAlpha(25),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          onTap: () {
            if (!notification.isRead) {
              ref
                  .read(notificationRepositoryProvider)
                  .markAsRead(notification.id);
            }
            if ((notification.type == NotificationType.love ||
                    notification.type == NotificationType.comment) &&
                notification.referenceId != null &&
                notification.referenceId!.isNotEmpty) {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => StatusDetailScreen(
                    statusId: notification.referenceId!,
                  ),
                ),
              );
            } else if (notification.actorId.isNotEmpty) {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ProfileScreen(userId: notification.actorId),
                ),
              );
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar dengan ring bercahaya dan badge icon
                _buildActorAvatar(
                  avatarUrl,
                  resolvedUsername,
                  iconColor,
                  iconData,
                ),
                const SizedBox(width: AppSpacing.md),
                // Konten teks & tombol aksi
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header chip kategori + waktu
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: iconColor.withAlpha(28),
                              borderRadius:
                                  BorderRadius.circular(AppRadius.pill),
                              border: Border.all(
                                color: iconColor.withAlpha(80),
                                width: 0.8,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  iconData,
                                  size: 11,
                                  color: iconColor,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _typeLabel(notification.type),
                                  style: AppTypography.micro.copyWith(
                                    color: iconColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.access_time_rounded,
                                size: 11,
                                color: AppColors.textFaint,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                timeStr,
                                style: AppTypography.micro.copyWith(
                                  color: AppColors.textFaint,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),

                      // Teks Notifikasi dengan kontras jelas
                      Text(
                        displayBody,
                        style: AppTypography.body.copyWith(
                          color: notification.isRead
                              ? AppColors.textMuted
                              : AppColors.textPrimary,
                          height: 1.35,
                        ),
                      ),

                      // Action buttons untuk Permintaan Pertemanan
                      if (notification.type == NotificationType.friendRequest) ...[
                        const SizedBox(height: AppSpacing.md),
                        Row(
                          children: [
                            // Tombol Terima Desain Modern
                            Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius:
                                    BorderRadius.circular(AppRadius.pill),
                                onTap: () async {
                                  final myProfile = ref
                                      .read(profileProvider(currentUserId))
                                      .value;
                                  final myUsername = (myProfile != null &&
                                          myProfile.displayName.isNotEmpty &&
                                          myProfile.displayName != 'Pengguna')
                                      ? myProfile.displayName
                                      : (myProfile != null &&
                                              myProfile.username.isNotEmpty &&
                                              myProfile.username != 'Pengguna')
                                          ? myProfile.username
                                          : currentUsername;
                                  final myAvatar = (myProfile?.avatarUrl !=
                                              null &&
                                          myProfile!.avatarUrl!.isNotEmpty &&
                                          !myProfile.avatarUrl!
                                              .startsWith('grad:'))
                                      ? myProfile.avatarUrl
                                      : currentUserAvatar;

                                  await ref
                                      .read(friendshipRepositoryProvider)
                                      .acceptFriendRequest(
                                        currentUserId: currentUserId,
                                        currentUsername: myUsername,
                                        currentAvatar: myAvatar,
                                        requesterId: notification.actorId,
                                      );
                                  await ref
                                      .read(notificationRepositoryProvider)
                                      .deleteNotification(notification.id);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Berteman dengan $resolvedUsername',
                                        ),
                                      ),
                                    );
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.lg,
                                    vertical: AppSpacing.sm,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.success,
                                    borderRadius:
                                        BorderRadius.circular(AppRadius.pill),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.success.withAlpha(90),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.check_circle_rounded,
                                        size: AppIconSize.sm,
                                        color: AppColors.textOnAccent,
                                      ),
                                      const SizedBox(width: AppSpacing.xs),
                                      Text(
                                        'Terima',
                                        style: AppTypography.caption.copyWith(
                                          color: AppColors.textOnAccent,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),

                            // Tombol Tolak Desain Modern
                            Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius:
                                    BorderRadius.circular(AppRadius.pill),
                                onTap: () async {
                                  await ref
                                      .read(friendshipRepositoryProvider)
                                      .rejectFriendRequest(
                                        currentUserId,
                                        notification.actorId,
                                      );
                                  await ref
                                      .read(notificationRepositoryProvider)
                                      .deleteNotification(notification.id);
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.lg,
                                    vertical: AppSpacing.sm,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceAlt.withAlpha(180),
                                    borderRadius:
                                        BorderRadius.circular(AppRadius.pill),
                                    border: Border.all(
                                      color:
                                          AppColors.dangerBright.withAlpha(140),
                                      width: 1.2,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.dangerBright
                                            .withAlpha(30),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.cancel_outlined,
                                        size: AppIconSize.sm,
                                        color: AppColors.dangerBright,
                                      ),
                                      const SizedBox(width: AppSpacing.xs),
                                      Text(
                                        'Tolak',
                                        style: AppTypography.caption.copyWith(
                                          color: AppColors.dangerBright,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],

                      // Pintasan Lihat Status untuk love & comment
                      if ((notification.type == NotificationType.love ||
                              notification.type == NotificationType.comment) &&
                          notification.referenceId != null &&
                          notification.referenceId!.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Ketuk untuk lihat status',
                              style: AppTypography.micro.copyWith(
                                color: AppColors.accentSoft,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 3),
                            const Icon(
                              Icons.chevron_right,
                              size: 13,
                              color: AppColors.accentSoft,
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                // Titik Indikator Belum Dibaca
                if (!notification.isRead) ...[
                  const SizedBox(width: AppSpacing.xs),
                  Container(
                    width: 9,
                    height: 9,
                    margin: const EdgeInsets.only(top: 4),
                    decoration: BoxDecoration(
                      color: iconColor,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: iconColor.withAlpha(140),
                          blurRadius: 6,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
