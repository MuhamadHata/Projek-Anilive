import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/settings_screen.dart';
import '../../anime/presentation/explore_screen.dart';
import '../../auth/presentation/auth_provider.dart';
import '../../review/domain/review.dart';
import '../../review/presentation/write_review_screen.dart'
    show reviewRepositoryProvider, userAnimeListProvider;
import '../data/profile_repository_impl.dart';
import '../domain/user_profile.dart';
import 'banner_picker_sheet.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:anitrack/core/theme/app_tokens.dart';
import '../../chat/presentation/direct_chat_screen.dart';
import '../../chat/presentation/friend_chats_screen.dart';
import '../../social/data/friendship_repository.dart';
import '../../social/domain/friendship_model.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepositoryImpl();
});

final profileProvider = StreamProvider.autoDispose.family<UserProfile?, String>(
  (ref, userId) {
    return ref.watch(profileRepositoryProvider).watchProfile(userId);
  },
);

final followStatusProvider = FutureProvider.autoDispose
    .family<bool, (String, String)>((ref, ids) {
      return ref.watch(profileRepositoryProvider).isFollowing(ids.$1, ids.$2);
    });

/// Semua review publik milik satu user (tab Review di profil).
final userReviewsProvider =
    StreamProvider.autoDispose.family<List<Review>, String>((ref, userId) {
      return ref.watch(reviewRepositoryProvider).watchUserReviews(userId);
    });

class ProfileScreen extends ConsumerWidget {
  final String userId;

  /// true = ditampilkan sebagai tab di dalam HomeScreen yang sudah punya
  /// AppBar "Profil" sendiri, jadi Scaffold/AppBar kedua tidak dibuat
  /// (mencegah dua header "Profil" bertumpuk).
  final bool embedded;

  const ProfileScreen({super.key, required this.userId, this.embedded = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileProvider(userId));
    final currentUser =
        ref.watch(authNotifierProvider).value ??
        ref.read(authRepositoryProvider).currentUser;
    final isOwnProfile = currentUser?.id == userId;

    final body = profileAsync.when(
      data: (profile) {
        if (profile == null) {
          return const Center(child: Text('Profil tidak ditemukan'));
        }
        return _ProfileBody(
          profile: profile,
          currentUserId: currentUser?.id,
          isOwnProfile: isOwnProfile,
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Gagal memuat profil: $e')),
    );

    return DefaultTabController(
      length: 3,
      child: embedded
          ? Scaffold(backgroundColor: AppColors.background, body: body)
          : Scaffold(
              backgroundColor: AppColors.background,
              appBar: AppBar(
                title: const Text('Profil'),
                backgroundColor: Colors.transparent,
                actions: [
                  if (isOwnProfile)
                    IconButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const SettingsScreen()),
                      ),
                      icon: const Icon(Icons.settings_outlined),
                    ),
                ],
              ),
              body: body,
            ),
    );
  }
}

// ============================================================
// HEADER PROFIL : banner gradien, avatar, statistik, tombol
// ============================================================

class _ProfileBody extends ConsumerWidget {
  final UserProfile profile;
  final String? currentUserId;
  final bool isOwnProfile;

  const _ProfileBody({
    required this.profile,
    required this.currentUserId,
    required this.isOwnProfile,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final followAsync = currentUserId != null && !isOwnProfile
        ? ref.watch(followStatusProvider((currentUserId!, profile.id)))
        : const AsyncValue.data(false);

    final friendAsync = currentUserId != null && !isOwnProfile
        ? ref.watch(friendshipStatusProvider((currentUserId!, profile.id)))
        : const AsyncValue.data(FriendshipStatus.none);

    final listAsync = ref.watch(userAnimeListProvider(profile.id));
    final dynamicCompleted = listAsync.value
        ?.where((e) => e.isCompleted || e.watchStatus == 'completed')
        .length;
    final completedCount = (dynamicCompleted != null && dynamicCompleted > 0)
        ? dynamicCompleted
        : (profile.animeCompletedCount > 0
            ? profile.animeCompletedCount
            : (dynamicCompleted ?? 0));

    final tabController = DefaultTabController.of(context);

    // CustomScrollView: seluruh header ikut tergulir, TabBar tetap
    // menempel di atas (pinned), dan tiap tab punya area scroll sendiri.
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(profileProvider(profile.id));
        ref.invalidate(userAnimeListProvider(profile.id));
        ref.invalidate(userReviewsProvider(profile.id));
        if (currentUserId != null) {
          ref.invalidate(followStatusProvider((currentUserId!, profile.id)));
          ref.invalidate(friendshipStatusProvider((currentUserId!, profile.id)));
        }
        await Future.delayed(const Duration(milliseconds: 300));
      },
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: _buildHeader(
              context,
              ref,
              followAsync,
              friendAsync,
              completedCount,
            ),
          ),
          SliverPersistentHeader(
            pinned: true,
            delegate: _PinnedTabBarDelegate(controller: tabController),
          ),
          SliverFillRemaining(
            hasScrollBody: true,
            child: TabBarView(
              controller: tabController,
              children: [
                _ActivityTab(userId: profile.id),
                _ReviewsTab(userId: profile.id),
                _AnimeListTab(userId: profile.id, isOwnProfile: isOwnProfile),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<bool> followAsync,
    AsyncValue<FriendshipStatus> friendAsync,
    int completedCount,
  ) {
    return Column(
      children: [
        // ---- Banner + Avatar ----
        Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.bottomCenter,
          children: [
            // Banner area
            _BannerView(
              bannerUrl: profile.bannerUrl,
              height: 140,
            ),
            // Ganti banner button (only for own profile)
            if (isOwnProfile)
              Positioned(
                top: AppSpacing.sm,
                right: AppSpacing.sm,
                child: GestureDetector(
                  onTap: () => _openBannerPicker(context, ref),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surface.withAlpha(200),
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.photo_camera_outlined,
                          size: AppIconSize.xs,
                          color: AppColors.textPrimary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Ganti Banner',
                          style: AppTypography.micro,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            Positioned(
              bottom: -44,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.background,
                  border: Border.all(
                    color: AppColors.accent,
                    width: 2,
                  ),
                ),
                child: _AvatarView(profile: profile, size: 88),
              ),
            ),
          ],
        ),
        const SizedBox(height: 52),

        // ---- Nama & username ----
        Text(
          profile.displayName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.display,
        ),
        Text(
          '@${profile.username}',
          style: AppTypography.bodyMuted,
        ),
        const SizedBox(height: AppSpacing.sm),

        // ---- Achievement Badge Wibu ----
        _AchievementBadgePill(
          completedCount: completedCount,
          onTap: () => _showAchievementTiersSheet(context, completedCount),
        ),

        if (profile.bio != null && profile.bio!.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
            child: Text(
              profile.bio!,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.body,
            ),
          ),
        ],

        const SizedBox(height: AppSpacing.sm),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.calendar_today_outlined,
              size: 11,
              color: AppColors.textMuted,
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              'Bergabung ${_formatMonthYear(profile.createdAt)}',
              style: AppTypography.captionFaint.copyWith(
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),

        const SizedBox(height: AppSpacing.lg),

        // ---- Statistik ----
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          child: Row(
            children: [
              _StatPill(
                value: completedCount.toString(),
                label: 'Selesai',
                icon: Icons.check_circle_outline,
              ),
              const SizedBox(width: AppSpacing.md),
              _StatPill(
                value: profile.followersCount.toString(),
                label: 'Followers',
                icon: Icons.people_outline,
              ),
              const SizedBox(width: AppSpacing.md),
              _StatPill(
                value: profile.followingCount.toString(),
                label: 'Following',
                icon: Icons.person_add_alt_1_outlined,
              ),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.lg),

        // ---- Tombol aksi ----
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          child: SizedBox(
            width: double.infinity,
            child: isOwnProfile
                ? Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _openEditSheet(context, ref),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.accentSoft,
                            side: const BorderSide(color: AppColors.accent),
                            padding: const EdgeInsets.symmetric(
                              vertical: AppSpacing.md,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppRadius.md),
                            ),
                          ),
                          icon: const Icon(Icons.tune, size: AppIconSize.md),
                          label: const Text('Sunting Profil'),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      OutlinedButton.icon(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const FriendChatsScreen(),
                            ),
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textPrimary,
                          side: const BorderSide(color: AppColors.border),
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                            vertical: AppSpacing.md,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                        ),
                        icon: const Icon(
                          Icons.forum_outlined,
                          size: AppIconSize.md,
                        ),
                        label: const Text('Chat'),
                      ),
                    ],
                  )
                : friendAsync.when(
                    data: (fStatus) {
                      final isFriend = fStatus == FriendshipStatus.friends;
                      final isSent = fStatus == FriendshipStatus.sent;
                      final isReceived = fStatus == FriendshipStatus.received;

                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              if (isFriend) ...[
                                Expanded(
                                  child: FilledButton.icon(
                                    onPressed: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => DirectChatScreen(
                                            targetUserId: profile.id,
                                            targetUsername: profile.username,
                                            targetAvatarUrl: profile.avatarUrl,
                                          ),
                                        ),
                                      );
                                    },
                                    style: FilledButton.styleFrom(
                                      backgroundColor: AppColors.accent,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: AppSpacing.md,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(
                                            AppRadius.md),
                                      ),
                                    ),
                                    icon: const Icon(
                                      Icons.chat_bubble_outline,
                                      size: AppIconSize.md,
                                    ),
                                    label: const Text('Kirim Pesan'),
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                InkWell(
                                  borderRadius:
                                      BorderRadius.circular(AppRadius.md),
                                  onTap: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            const FriendChatsScreen(),
                                      ),
                                    );
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: AppSpacing.md,
                                      vertical: AppSpacing.md,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.surfaceAlt,
                                      borderRadius:
                                          BorderRadius.circular(AppRadius.md),
                                      border:
                                          Border.all(color: AppColors.border),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.people,
                                          size: AppIconSize.sm,
                                          color: AppColors.success,
                                        ),
                                        SizedBox(width: AppSpacing.xs),
                                        Text('Teman',
                                            style: AppTypography.caption),
                                      ],
                                    ),
                                  ),
                                ),
                              ] else if (isReceived) ...[
                                Expanded(
                                  child: FilledButton.icon(
                                    onPressed: currentUserId == null
                                        ? null
                                        : () async {
                                            final currentUser = ref
                                                    .read(authNotifierProvider)
                                                    .value ??
                                                ref
                                                    .read(
                                                        authRepositoryProvider)
                                                    .currentUser;
                                            await ref
                                                .read(
                                                    friendshipRepositoryProvider)
                                                .acceptFriendRequest(
                                                  currentUserId: currentUserId!,
                                                  currentUsername: currentUser
                                                          ?.username ??
                                                      'Pengguna',
                                                  currentAvatar:
                                                      currentUser?.avatarUrl,
                                                  requesterId: profile.id,
                                                );
                                            ref.invalidate(
                                                friendshipStatusProvider((
                                              currentUserId!,
                                              profile.id
                                            )));
                                          },
                                    style: FilledButton.styleFrom(
                                      backgroundColor: AppColors.success,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: AppSpacing.md,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(
                                            AppRadius.md),
                                      ),
                                    ),
                                    icon: const Icon(Icons.check,
                                        size: AppIconSize.md),
                                    label: const Text('Terima Teman'),
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.xs),
                                IconButton(
                                  onPressed: currentUserId == null
                                      ? null
                                      : () async {
                                          await ref
                                              .read(
                                                  friendshipRepositoryProvider)
                                              .rejectFriendRequest(
                                                currentUserId!,
                                                profile.id,
                                              );
                                          ref.invalidate(
                                              friendshipStatusProvider((
                                            currentUserId!,
                                            profile.id
                                          )));
                                        },
                                  icon: const Icon(Icons.close,
                                      color: AppColors.dangerBright),
                                ),
                              ] else if (isSent) ...[
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: null,
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: AppSpacing.md,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(
                                            AppRadius.md),
                                      ),
                                    ),
                                    icon: const Icon(Icons.hourglass_top,
                                        size: AppIconSize.md),
                                    label: const Text('Permintaan Terkirim'),
                                  ),
                                ),
                              ] else ...[
                                Expanded(
                                  child: FilledButton.icon(
                                    onPressed: currentUserId == null
                                        ? null
                                        : () async {
                                            final currentUser = ref
                                                    .read(authNotifierProvider)
                                                    .value ??
                                                ref
                                                    .read(
                                                        authRepositoryProvider)
                                                    .currentUser;
                                            final myProfile = currentUserId != null
                                                ? ref
                                                    .read(profileProvider(
                                                        currentUserId!))
                                                    .value
                                                : null;
                                            final myUsername = (myProfile !=
                                                        null &&
                                                    myProfile.displayName
                                                        .isNotEmpty &&
                                                    myProfile.displayName !=
                                                        'Pengguna')
                                                ? myProfile.displayName
                                                : (myProfile != null &&
                                                        myProfile.username
                                                            .isNotEmpty &&
                                                        myProfile.username !=
                                                            'Pengguna')
                                                    ? myProfile.username
                                                    : (currentUser?.username ??
                                                        'Pengguna');
                                            final myAvatar = (myProfile
                                                            ?.avatarUrl !=
                                                        null &&
                                                    myProfile!
                                                        .avatarUrl!.isNotEmpty &&
                                                    !myProfile.avatarUrl!
                                                        .startsWith('grad:'))
                                                ? myProfile.avatarUrl
                                                : (currentUser?.avatarUrl !=
                                                            null &&
                                                        currentUser!.avatarUrl!
                                                            .isNotEmpty &&
                                                        !currentUser.avatarUrl!
                                                            .startsWith('grad:'))
                                                    ? currentUser.avatarUrl
                                                    : null;

                                            await ref
                                                .read(
                                                    friendshipRepositoryProvider)
                                                .sendFriendRequest(
                                                  fromUserId: currentUserId!,
                                                  fromUsername: myUsername,
                                                  fromAvatar: myAvatar,
                                                  toUserId: profile.id,
                                                );
                                            ref.invalidate(
                                                friendshipStatusProvider((
                                              currentUserId!,
                                              profile.id
                                            )));
                                          },
                                    style: FilledButton.styleFrom(
                                      backgroundColor: AppColors.accent,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: AppSpacing.md,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(
                                            AppRadius.md),
                                      ),
                                    ),
                                    icon: const Icon(
                                      Icons.person_add_alt_1,
                                      size: AppIconSize.md,
                                    ),
                                    label: const Text('Tambah Teman'),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          followAsync.when(
                            data: (following) => SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: currentUserId == null
                                    ? null
                                    : () async {
                                        final repo =
                                            ref.read(profileRepositoryProvider);
                                        if (following) {
                                          await repo.unfollow(
                                              currentUserId!, profile.id);
                                        } else {
                                          await repo.follow(
                                              currentUserId!, profile.id);
                                        }
                                        ref.invalidate(
                                          followStatusProvider(
                                              (currentUserId!, profile.id)),
                                        );
                                        ref.invalidate(
                                            profileProvider(profile.id));
                                        ref.invalidate(
                                            profileProvider(currentUserId!));
                                      },
                                icon: Icon(
                                  following ? Icons.check : Icons.add,
                                  size: AppIconSize.sm,
                                ),
                                label: Text(following ? 'Mengikuti' : 'Ikuti'),
                              ),
                            ),
                            loading: () => const SizedBox(),
                            error: (_, _) => const SizedBox(),
                          ),
                        ],
                      );
                    },
                    loading: () => const LinearProgressIndicator(),
                    error: (_, _) => const SizedBox(),
                  ),
          ),
        ),
      ],
    );
  }

  void _openEditSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (_) => _EditProfileSheet(profile: profile),
    );
  }

  void _openBannerPicker(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (_) => BannerPickerSheet(
        userId: profile.id,
        onBannerSelected: (url) async {
          final repo = ref.read(profileRepositoryProvider);
          // url kosong = hapus banner (kembali ke gradient default)
          final updated = profile.copyWith(
            bannerUrl: url.isEmpty ? null : url,
          );
          await repo.updateProfile(updated);
          ref.invalidate(profileProvider(profile.id));
        },
      ),
    );
  }
}

// ============================================================
// TABBAR PINNED (tetap terlihat saat header digulir)
// ============================================================

class _PinnedTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabController controller;

  const _PinnedTabBarDelegate({required this.controller});

  static const double _height = 72;

  @override
  double get minExtent => _height;

  @override
  double get maxExtent => _height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: AppColors.background,
      child: TabBar(
        controller: controller,
        indicatorColor: AppColors.accent,
        indicatorSize: TabBarIndicatorSize.label,
        labelColor: AppColors.textPrimary,
        unselectedLabelColor: AppColors.textMuted,
        labelStyle: AppTypography.bodyStrong,
        dividerColor: AppColors.border,
        tabs: const [
          Tab(
            text: 'Aktivitas',
            icon: Icon(Icons.bolt_outlined, size: AppIconSize.md),
          ),
          Tab(
            text: 'Review',
            icon: Icon(Icons.rate_review_outlined, size: AppIconSize.md),
          ),
          Tab(
            text: 'Daftar Anime',
            icon: Icon(Icons.list_alt, size: AppIconSize.md),
          ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _PinnedTabBarDelegate oldDelegate) =>
      oldDelegate.controller != controller;
}

// ============================================================
// BANNER (foto / GIF kustom atau gradien default)
// ============================================================

class _BannerView extends StatelessWidget {
  final String? bannerUrl;
  final double height;

  const _BannerView({this.bannerUrl, this.height = 140});

  @override
  Widget build(BuildContext context) {
    Widget gradient() => Container(
          height: height,
          width: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.accent, AppColors.accentDeep],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(AppRadius.xl),
              bottomRight: Radius.circular(AppRadius.xl),
            ),
          ),
        );

    final url = bannerUrl;
    if (url == null || url.isEmpty) return gradient();

    return ClipRRect(
      borderRadius: const BorderRadius.only(
        bottomLeft: Radius.circular(AppRadius.xl),
        bottomRight: Radius.circular(AppRadius.xl),
      ),
      child: CachedNetworkImage(
        imageUrl: url,
        width: double.infinity,
        height: height,
        fit: BoxFit.cover,
        placeholder: (_, p1) => gradient(),
        errorWidget: (_, p1, p2) => gradient(),
      ),
    );
  }
}

// ============================================================
// AVATAR (gradien preset / URL gambar)
// ============================================================

const List<List<Color>> _avatarGradients = AppColors.avatarGradients;

int gradientIndexFor(String id) => id.hashCode.abs() % _avatarGradients.length;

class _AvatarView extends StatelessWidget {
  final UserProfile profile;
  final double size;

  const _AvatarView({required this.profile, required this.size});

  @override
  Widget build(BuildContext context) {
    final initial = profile.displayName.isNotEmpty
        ? profile.displayName[0].toUpperCase()
        : '?';

    Widget fallback() => Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: _avatarGradients[gradientIndexFor(profile.id)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            initial,
            style: AppTypography.statNumber.copyWith(
              fontSize: size * 0.42,
              color: AppColors.textOnAccent,
            ),
          ),
        );

    final url = profile.avatarUrl;
    if (url == null || url.isEmpty || url.startsWith('grad:')) {
      return fallback();
    }
    // Foto tersimpan sebagai data URI base64 di dokumen Firestore.
    if (url.startsWith('data:')) {
      try {
        final bytes = base64Decode(url.split(',').last);
        return ClipOval(
          child: Image.memory(
            bytes,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => fallback(),
          ),
        );
      } catch (_) {
        return fallback();
      }
    }
    return ClipOval(
      child: Image.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback(),
      ),
    );
  }
}

// ============================================================
// STAT PILL
// ============================================================

class _StatPill extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;

  const _StatPill({
    required this.value,
    required this.label,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.surfaceAlt),
        ),
        child: Column(
          children: [
            Icon(icon, size: AppIconSize.sm, color: AppColors.accent),
            const SizedBox(height: AppSpacing.xs),
            Text(value, style: AppTypography.title),
            Text(label, style: AppTypography.micro),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// BADGE ACHIEVEMENT WIBU / OTAKU
// ============================================================

class WibuBadge {
  final String title;
  final String emoji;
  final Color color;
  final int minAnime;
  final String requirement;

  const WibuBadge({
    required this.title,
    required this.emoji,
    required this.color,
    required this.minAnime,
    required this.requirement,
  });

  static const List<WibuBadge> all = [
    WibuBadge(
      title: 'Wibu Baru',
      emoji: '🌱',
      color: AppColors.textMuted,
      minAnime: 0,
      requirement: 'Mulai petualangan anime',
    ),
    WibuBadge(
      title: 'Wibu Pemula',
      emoji: '🥉',
      color: AppColors.accentSoft,
      minAnime: 3,
      requirement: 'Tamatkan 3 anime',
    ),
    WibuBadge(
      title: 'Penikmat Anime',
      emoji: '🍿',
      color: AppColors.warning,
      minAnime: 10,
      requirement: 'Tamatkan 10 anime',
    ),
    WibuBadge(
      title: 'Wibu Aktif',
      emoji: '⚡',
      color: AppColors.accent,
      minAnime: 25,
      requirement: 'Tamatkan 25 anime',
    ),
    WibuBadge(
      title: 'Otaku Sejati',
      emoji: '🔥',
      color: AppColors.dangerBright,
      minAnime: 50,
      requirement: 'Tamatkan 50 anime',
    ),
    WibuBadge(
      title: 'Sepuh Wibu',
      emoji: '👑',
      color: AppColors.star,
      minAnime: 75,
      requirement: 'Tamatkan 75 anime',
    ),
    WibuBadge(
      title: 'Mahaguru Wibu',
      emoji: '🌌',
      color: AppColors.star,
      minAnime: 100,
      requirement: 'Tamatkan 100+ anime',
    ),
  ];

  static WibuBadge forCount(int count) {
    for (int i = all.length - 1; i >= 0; i--) {
      if (count >= all[i].minAnime) return all[i];
    }
    return all.first;
  }

  static WibuBadge? nextTier(int count) {
    for (final b in all) {
      if (count < b.minAnime) return b;
    }
    return null;
  }
}

class _AchievementBadgePill extends StatelessWidget {
  final int completedCount;
  final VoidCallback onTap;

  const _AchievementBadgePill({
    required this.completedCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final badge = WibuBadge.forCount(completedCount);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs + 1,
        ),
        decoration: BoxDecoration(
          color: badge.color.withAlpha(28),
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: badge.color.withAlpha(90), width: 1.2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(badge.emoji, style: AppTypography.body),
            const SizedBox(width: AppSpacing.xs),
            Text(
              badge.title,
              style: AppTypography.caption.copyWith(
                color: badge.color,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Icon(
              Icons.chevron_right,
              size: 14,
              color: badge.color.withAlpha(160),
            ),
          ],
        ),
      ),
    );
  }
}

void _showAchievementTiersSheet(BuildContext context, int completedCount) {
  final currentBadge = WibuBadge.forCount(completedCount);
  final next = WibuBadge.nextTier(completedCount);

  showModalBottomSheet(
    context: context,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
    ),
    isScrollControlled: true,
    builder: (sheetContext) => Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.xxl,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.star.withAlpha(30),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: const Icon(
                    Icons.military_tech_outlined,
                    color: AppColors.star,
                    size: AppIconSize.md,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tingkatan Wibu',
                        style: AppTypography.headline,
                      ),
                      Text(
                        '$completedCount anime telah ditamatkan',
                        style: AppTypography.captionFaint,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (next != null) ...[
              const SizedBox(height: AppSpacing.md),
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.arrow_upward,
                      size: AppIconSize.sm,
                      color: AppColors.accent,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'Tamatkan ${next.minAnime - completedCount} anime lagi untuk meraih badge "${next.title}" (${next.emoji})!',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.accentSoft,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Daftar Pangkat & Achievement',
              style: AppTypography.titleSmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            ...WibuBadge.all.map((tier) {
              final isUnlocked = completedCount >= tier.minAnime;
              final isCurrent = tier.title == currentBadge.title;

              return Container(
                margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: isCurrent
                      ? tier.color.withAlpha(30)
                      : isUnlocked
                          ? AppColors.surfaceAlt
                          : AppColors.surfaceAlt.withAlpha(100),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(
                    color: isCurrent
                        ? tier.color
                        : isUnlocked
                            ? AppColors.border
                            : AppColors.border.withAlpha(60),
                    width: isCurrent ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Text(tier.emoji, style: AppTypography.display),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                tier.title,
                                style: AppTypography.bodyStrong.copyWith(
                                  color: isUnlocked
                                      ? AppColors.textPrimary
                                      : AppColors.textMuted,
                                ),
                              ),
                              if (isCurrent) ...[
                                const SizedBox(width: AppSpacing.xs),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 1,
                                  ),
                                  decoration: BoxDecoration(
                                    color: tier.color,
                                    borderRadius:
                                        BorderRadius.circular(AppRadius.pill),
                                  ),
                                  child: Text(
                                    'Aktif',
                                    style: AppTypography.micro.copyWith(
                                      color: AppColors.background,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          Text(
                            tier.requirement,
                            style: AppTypography.captionFaint,
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      isUnlocked
                          ? Icons.check_circle
                          : Icons.lock_outline,
                      size: AppIconSize.md,
                      color: isCurrent
                          ? tier.color
                          : isUnlocked
                              ? AppColors.success
                              : AppColors.textMuted.withAlpha(100),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    ),
  );
}


// ============================================================
// TAB 1 : AKTIVITAS (diturunkan dari daftar anime user)
// ============================================================

class _ActivityTab extends ConsumerWidget {
  final String userId;

  const _ActivityTab({required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listAsync = ref.watch(userAnimeListProvider(userId));

    return listAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Gagal memuat aktivitas: $e')),
      data: (entries) {
        final recent = (entries.toList()
              ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt)))
            .take(15)
            .toList();

        if (recent.isEmpty) {
          return const _EmptyState(
            icon: Icons.bolt_outlined,
            title: 'Belum ada aktivitas',
            subtitle:
                'Aktivitas menonton dan menyimpan anime akan tampil di sini.',
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.xl,
          ),
          itemCount: recent.length,
          separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
          itemBuilder: (context, i) {
            final e = recent[i];
            final (icon, color, action) = e.isCompleted
                ? (
                    Icons.check_circle,
                    AppColors.success,
                    'Menyelesaikan',
                  )
                : e.watchedEpisodes > 0
                    ? (
                        Icons.play_circle_fill,
                        AppColors.accent,
                        'Menonton episode ${e.watchedEpisodes}',
                      )
                    : (
                        Icons.bookmark_add,
                        AppColors.warning,
                        'Menambahkan ke daftar',
                      );

            return Card(
              color: AppColors.surface,
              margin: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: ListTile(
                leading: CircleAvatar(
                  radius: 18,
                  backgroundColor: color.withAlpha(40),
                  child: Icon(icon, size: AppIconSize.md, color: color),
                ),
                title: Text.rich(
                  TextSpan(
                    text: '$action ',
                    style: AppTypography.bodyMuted,
                    children: [
                      TextSpan(
                        text: e.title.isNotEmpty ? e.title : 'Tanpa Judul',
                        style: AppTypography.bodyStrong,
                      ),
                    ],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text(
                    [
                      if (e.overallScore > 0)
                        'Skor ${e.overallScore.toStringAsFixed(1)}',
                      _timeAgo(e.updatedAt),
                    ].join(' • '),
                    style: AppTypography.captionFaint.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
                onTap: () => _goToDetail(context, e.animeId, e.title),
              ),
            );
          },
        );
      },
    );
  }
}

// ============================================================
// TAB 2 : REVIEW
// ============================================================

class _ReviewsTab extends ConsumerWidget {
  final String userId;

  const _ReviewsTab({required this.userId});

  Color _scoreColor(double s) {
    if (s >= 8) return AppColors.success;
    if (s >= 6) return AppColors.warning;
    return AppColors.danger;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviewsAsync = ref.watch(userReviewsProvider(userId));

    return reviewsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, p1) => const _EmptyState(
        icon: Icons.rate_review_outlined,
        title: 'Belum ada review',
        subtitle:
            'Review yang ditulis pada halaman detail anime akan tampil di sini.',
      ),
      data: (reviews) {
        if (reviews.isEmpty) {
          return const _EmptyState(
            icon: Icons.rate_review_outlined,
            title: 'Belum ada review',
            subtitle:
                'Review yang ditulis pada halaman detail anime akan tampil di sini.',
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.xl,
          ),
          itemCount: reviews.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, i) {
            final r = reviews[i];
            return Card(
              color: AppColors.surface,
              margin: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadius.md),
                onTap: () =>
                    _goToDetail(context, r.animeId, r.animeTitle ?? ''),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: _scoreColor(r.overallScore).withAlpha(46),
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                            ),
                            child: Text(
                              r.overallScore.toStringAsFixed(1),
                              style: AppTypography.caption.copyWith(
                                fontWeight: FontWeight.bold,
                                color: _scoreColor(r.overallScore),
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              r.animeTitle ?? 'Anime #${r.animeId}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.caption,
                            ),
                          ),
                          if (r.hasSpoiler)
                            const Icon(
                              Icons.warning_amber_rounded,
                              size: AppIconSize.xs,
                              color: AppColors.warning,
                            ),
                        ],
                      ),
                      if (r.title.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          r.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.titleSmall,
                        ),
                      ],
                      if (r.content.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          r.content,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.caption.copyWith(height: 1.45),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        '${r.createdAt.day} ${_monthName(r.createdAt.month)} '
                        '${r.createdAt.year} • ${r.likeCount} suka',
                        style: AppTypography.captionFaint,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ============================================================
// TAB 3 : DAFTAR ANIME (dengan filter status)
// ============================================================

class _AnimeListTab extends ConsumerStatefulWidget {
  final String userId;
  final bool isOwnProfile;

  const _AnimeListTab({required this.userId, required this.isOwnProfile});

  @override
  ConsumerState<_AnimeListTab> createState() => _AnimeListTabState();
}

class _AnimeListTabState extends ConsumerState<_AnimeListTab> {
  String? _filter; // null = Semua

  @override
  Widget build(BuildContext context) {
    final listAsync = ref.watch(userAnimeListProvider(widget.userId));

    return listAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Gagal memuat daftar: $e')),
      data: (entries) {
        if (entries.isEmpty) {
          return _EmptyState(
            icon: Icons.list_alt,
            title: 'Daftar masih kosong',
            subtitle: widget.isOwnProfile
                ? 'Buka salah satu anime lalu tekan tombol "+" untuk menambahkannya.'
                : 'User ini belum menyimpan anime apa pun.',
          );
        }

        final filtered = _filter == null
            ? entries
            : entries.where((e) => e.watchStatus == _filter).toList();

        return Column(
          children: [
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.sm,
                ),
                children: [
                  _FilterChip(
                    label: 'Semua',
                    selected: _filter == null,
                    onTap: () => setState(() => _filter = null),
                  ),
                  for (final s in WatchStatus.all)
                    _FilterChip(
                      label: WatchStatus.label(s),
                      selected: _filter == s,
                      onTap: () => setState(() => _filter = s),
                    ),
                ],
              ),
            ),
            Expanded(
              child: filtered.isEmpty
                  ? const Center(
                      child: Text(
                        'Tidak ada anime dengan status ini.',
                        style: AppTypography.bodyMuted,
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        AppSpacing.xs,
                        AppSpacing.lg,
                        AppSpacing.xl,
                      ),
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: AppSpacing.sm),
                      itemBuilder: (context, i) => _AnimeEntryCard(
                        entry: filtered[i],
                        userId: widget.userId,
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.sm),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppColors.accent : AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(
              color: selected
                  ? AppColors.accent
                  : AppColors.surfaceAlt,
            ),
          ),
          child: Text(
            label,
            style: AppTypography.caption.copyWith(
              fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              color: selected ? AppColors.textOnAccent : AppColors.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}

class _AnimeEntryCard extends ConsumerWidget {
  final UserAnimeEntry entry;
  final String userId;

  const _AnimeEntryCard({required this.entry, required this.userId});

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surfaceDialog,
        title: const Text('Hapus dari Daftar?'),
        content: Text('"${entry.title}" akan dihapus dari daftarmu.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.dangerBright,
            ),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      await ref
          .read(reviewRepositoryProvider)
          .deleteUserEntry(
            animeId: entry.animeId,
            reviewId: entry.reviewId,
            userId: userId,
          );
      ref.invalidate(userAnimeListProvider(userId));
      ref.invalidate(userReviewsProvider(userId));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal menghapus: $e')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      color: AppColors.surface,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: entry.imageUrl != null && entry.imageUrl!.isNotEmpty
              ? Image.network(
                  entry.imageUrl!,
                  width: 48,
                  height: 64,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    width: 48,
                    height: 64,
                    color: AppColors.surfaceAlt,
                    child: const Icon(
                      Icons.movie_outlined,
                      size: AppIconSize.lg,
                    ),
                  ),
                )
              : Container(
                  width: 48,
                  height: 64,
                  color: AppColors.surfaceAlt,
                  child: const Icon(
                    Icons.movie_outlined,
                    size: AppIconSize.lg,
                  ),
                ),
        ),
        title: Text(
          entry.title.isNotEmpty ? entry.title : 'Tanpa Judul',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.titleSmall,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: AppSpacing.xs),
            if (entry.watchStatus != null)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: AppColors.accent.withAlpha(46),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text(
                  WatchStatus.label(entry.watchStatus!),
                  style: AppTypography.captionFaint.copyWith(
                    color: AppColors.accentSoft,
                  ),
                ),
              ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              [
                'Ep ${entry.watchedEpisodes}'
                '${entry.totalEpisodes != null ? '/${entry.totalEpisodes}' : ''}',
                if (entry.overallScore > 0)
                  'Skor ${entry.overallScore.toStringAsFixed(1)}',
              ].join(' • '),
              style: AppTypography.caption,
            ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, size: 20),
          onPressed: () => _confirmDelete(context, ref),
        ),
        onTap: () => _goToDetail(context, entry.animeId, entry.title),
      ),
    );
  }
}

// ============================================================
// SHEET SUNTING PROFIL
// ============================================================

class _EditProfileSheet extends ConsumerStatefulWidget {
  final UserProfile profile;

  const _EditProfileSheet({required this.profile});

  @override
  ConsumerState<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends ConsumerState<_EditProfileSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  final _urlCtrl = TextEditingController();
  late int _selectedGradient;
  bool _saving = false;

  XFile? _pickedImage;

  @override
  void initState() {
    super.initState();
    final p = widget.profile;
    _nameCtrl.text = p.displayName;
    _usernameCtrl.text = p.username;
    _bioCtrl.text = p.bio ?? '';
    _urlCtrl.text =
        (p.avatarUrl != null &&
                p.avatarUrl!.isNotEmpty &&
                !p.avatarUrl!.startsWith('grad:'))
            ? p.avatarUrl!
            : '';
    _selectedGradient = p.avatarUrl != null && p.avatarUrl!.startsWith('grad:')
        ? int.tryParse(p.avatarUrl!.split(':')[1]) ??
            gradientIndexFor(p.id)
        : gradientIndexFor(p.id);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _usernameCtrl.dispose();
    _bioCtrl.dispose();
    _urlCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      // Kompres kecil di sumbernya agar muat aman sebagai base64
      // di dokumen Firestore (batas dokumen 1 MB).
      final x = await ImagePicker().pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 70,
      );
      if (!mounted || x == null) return;
      setState(() => _pickedImage = x);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal membuka galeri/kamera')),
        );
      }
    }
  }

  /// Encode foto terpilih menjadi data URI base64 agar bisa disimpan
  /// langsung di dokumen profil Firestore — tanpa Firebase Storage
  /// (Storage tidak tersedia di paket gratis Spark).
  String? _encodeAvatar() {
    final bytes = File(_pickedImage!.path).readAsBytesSync();
    // Batas aman ~700 KB sebelum base64 (base64 membesar ~33%).
    if (bytes.length > 700 * 1024) return null;
    return 'data:image/jpeg;base64,${base64Encode(bytes)}';
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final p = widget.profile;

    // 1. Foto galeri/kamera → data URI base64 (disimpan di Firestore).
    String? encodedAvatar;
    if (_pickedImage != null) {
      encodedAvatar = _encodeAvatar();
      if (encodedAvatar == null) {
        setState(() => _saving = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Foto terlalu besar. Coba pilih foto lain.',
              ),
            ),
          );
        }
        return;
      }
    }

    final bio = _bioCtrl.text.trim();
    final url = _urlCtrl.text.trim();
    final avatarUrl = encodedAvatar ??
        (url.isNotEmpty ? url : 'grad:$_selectedGradient');
    final updated = UserProfile(
      id: p.id,
      username: _usernameCtrl.text.trim(),
      displayName: _nameCtrl.text.trim(),
      bio: bio.isEmpty ? null : bio,
      avatarUrl: avatarUrl,
      bannerUrl: p.bannerUrl,
      birthDate: p.birthDate,
      followersCount: p.followersCount,
      followingCount: p.followingCount,
      animeCompletedCount: p.animeCompletedCount,
      createdAt: p.createdAt,
    );

    try {
      await ref.read(profileRepositoryProvider).updateProfile(updated);
      ref.invalidate(profileProvider(p.id));
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profil berhasil diperbarui')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memperbarui profil: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  InputDecoration _decoration(String label, {IconData? icon}) =>
      InputDecoration(
        labelText: label,
        prefixIcon: icon != null ? Icon(icon, size: AppIconSize.md) : null,
        filled: true,
        fillColor: AppColors.surfaceAlt,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.border),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final bottomPadding = MediaQuery.of(context).viewPadding.bottom;
    return SafeArea(
      top: false,
      bottom: true,
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            20,
            AppSpacing.lg,
            20,
            bottomInset > 0 ? AppSpacing.lg : (AppSpacing.xl + bottomPadding),
          ),
          child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              const Text('Sunting Profil', style: AppTypography.headline),
              const SizedBox(height: AppSpacing.lg),

              // ---- Pratinjau avatar ----
              Center(
                child: _PreviewAvatar(
                  urlText: _urlCtrl.text,
                  localPath: _pickedImage?.path,
                  gradientIndex: _selectedGradient,
                  initial: _nameCtrl.text.isNotEmpty
                      ? _nameCtrl.text[0].toUpperCase()
                      : '?',
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // ---- Ambil foto dari galeri / kamera ----
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _saving
                          ? null
                          : () => _pickImage(ImageSource.gallery),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textPrimary,
                        side: const BorderSide(color: AppColors.border),
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.sm,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                      ),
                      icon: const Icon(
                        Icons.photo_library_outlined,
                        size: AppIconSize.sm,
                      ),
                      label: const Text('Galeri'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _saving
                          ? null
                          : () => _pickImage(ImageSource.camera),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textPrimary,
                        side: const BorderSide(color: AppColors.border),
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.sm,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                      ),
                      icon: const Icon(
                        Icons.photo_camera_outlined,
                        size: AppIconSize.sm,
                      ),
                      label: const Text('Kamera'),
                    ),
                  ),
                ],
              ),
              if (_pickedImage != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Center(
                  child: TextButton.icon(
                    onPressed: _saving
                        ? null
                        : () => setState(() => _pickedImage = null),
                    icon: const Icon(
                      Icons.close,
                      size: AppIconSize.xs,
                      color: AppColors.dangerBright,
                    ),
                    label: Text(
                      'Batalkan foto terpilih',
                      style: AppTypography.captionFaint.copyWith(
                        color: AppColors.dangerBright,
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.md),

              // ---- Pilihan gradien ----
              SizedBox(
                height: 52,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _avatarGradients.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 10),
                  itemBuilder: (context, i) => GestureDetector(
                    onTap: () => setState(() {
                      _selectedGradient = i;
                      // Gradien dipilih → abaikan foto & URL.
                      _pickedImage = null;
                      _urlCtrl.clear();
                    }),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: _avatarGradients[i],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        border: Border.all(
                          color: _selectedGradient == i
                              ? AppColors.textPrimary
                              : Colors.transparent,
                          width: 2.5,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: _selectedGradient == i
                          ? const Icon(
                              Icons.check,
                              size: AppIconSize.md,
                              color: AppColors.textOnAccent,
                            )
                          : null,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),

              TextFormField(
                controller: _nameCtrl,
                decoration:
                    _decoration('Nama Tampilan', icon: Icons.badge_outlined),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null,
              ),
              const SizedBox(height: AppSpacing.md),

              TextFormField(
                controller: _usernameCtrl,
                decoration: _decoration('Username', icon: Icons.alternate_email),
                validator: (v) {
                  final u = v?.trim() ?? '';
                  if (u.isEmpty) return 'Wajib diisi';
                  if (!RegExp(r'^[a-z0-9_]{3,20}$').hasMatch(u)) {
                    return '3–20 huruf kecil, angka, atau garis bawah';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.md),

              TextFormField(
                controller: _bioCtrl,
                decoration: _decoration('Bio', icon: Icons.notes),
                maxLines: 3,
                maxLength: 160,
                style: AppTypography.body,
              ),
              const SizedBox(height: AppSpacing.lg),

              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                  ),
                  icon: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.textOnAccent,
                          ),
                        )
                      : const Icon(Icons.save_outlined, size: AppIconSize.md),
                  label: Text(
                    _saving
                        ? 'Menyimpan...'
                        : _pickedImage != null
                            ? 'Simpan Foto'
                            : 'Simpan Perubahan',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  }
}

class _PreviewAvatar extends StatelessWidget {
  final String urlText;

  /// Path foto lokal hasil galeri/kamera — prioritas tertinggi.
  final String? localPath;
  final int gradientIndex;
  final String initial;

  const _PreviewAvatar({
    required this.urlText,
    this.localPath,
    required this.gradientIndex,
    required this.initial,
  });

  @override
  Widget build(BuildContext context) {
    Widget circle({Widget? child}) => Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: _avatarGradients[gradientIndex],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          alignment: Alignment.center,
          child: child,
        );

    // 1. Foto dari galeri/kamera
    if (localPath != null && localPath!.isNotEmpty) {
      return ClipOval(
        child: Image.file(
          File(localPath!),
          width: 88,
          height: 88,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) =>
              circle(child: Text(initial, style: AppTypography.statNumber)),
        ),
      );
    }
    // 2. URL online
    if (urlText.isEmpty) {
      return circle(
        child: Text(initial, style: AppTypography.statNumber),
      );
    }
    return ClipOval(
      child: Image.network(
        urlText,
        width: 88,
        height: 88,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => circle(
          child: Text(initial, style: AppTypography.statNumber),
        ),
      ),
    );
  }
}

// ============================================================
// EMPTY STATE & HELPERS
// ============================================================

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.surface,
              ),
              child: Icon(icon, size: AppIconSize.hero, color: AppColors.textFaint),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(title, style: AppTypography.title),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: AppTypography.caption.copyWith(height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

void _goToDetail(BuildContext context, int animeId, String title) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => AnimeDetailScreen(animeId: animeId, title: title),
    ),
  );
}

String _monthName(int m) =>
    const ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'][m - 1];

String _formatMonthYear(DateTime d) => '${_monthName(d.month)} ${d.year}';

String _timeAgo(DateTime t) {
  final diff = DateTime.now().difference(t);
  if (diff.inMinutes < 1) return 'baru saja';
  if (diff.inMinutes < 60) return '${diff.inMinutes} menit lalu';
  if (diff.inHours < 24) return '${diff.inHours} jam lalu';
  if (diff.inDays < 7) return '${diff.inDays} hari lalu';
  return '${t.day} ${_monthName(t.month)} ${t.year}';
}
