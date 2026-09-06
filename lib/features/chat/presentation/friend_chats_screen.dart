import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_tokens.dart';
import '../../auth/presentation/auth_provider.dart';
import '../../profile/presentation/profile_screen.dart';
import '../../social/data/friendship_repository.dart';
import '../../social/domain/friendship_model.dart';
import '../data/direct_chat_repository.dart';
import '../domain/direct_message.dart';
import 'direct_chat_screen.dart';

class FriendChatsScreen extends ConsumerStatefulWidget {
  const FriendChatsScreen({super.key});

  @override
  ConsumerState<FriendChatsScreen> createState() => _FriendChatsScreenState();
}

class _FriendChatsScreenState extends ConsumerState<FriendChatsScreen> {
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.isNegative || diff.inMinutes < 1) return 'Baru saja';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}j';
    if (diff.inDays < 7) return '${diff.inDays}h';
    return '${dt.day}/${dt.month}';
  }

  static Widget buildAvatar(String? avatarUrl, String name, {double radius = 24}) {
    if (avatarUrl != null &&
        avatarUrl.isNotEmpty &&
        !avatarUrl.startsWith('grad:')) {
      if (avatarUrl.startsWith('data:')) {
        try {
          final bytes = base64Decode(avatarUrl.split(',').last);
          return CircleAvatar(
            radius: radius,
            backgroundColor: AppColors.surfaceAlt,
            backgroundImage: MemoryImage(bytes),
          );
        } catch (_) {}
      } else if (avatarUrl.startsWith('http://') ||
          avatarUrl.startsWith('https://')) {
        return CircleAvatar(
          radius: radius,
          backgroundColor: AppColors.surfaceAlt,
          backgroundImage: CachedNetworkImageProvider(avatarUrl),
          onBackgroundImageError: (_, _) {},
        );
      }
    }

    final initial = name.isNotEmpty && name != 'Pengguna'
        ? name[0].toUpperCase()
        : (name == 'Pengguna' ? 'P' : '?');
    final gradientColors = AppColors.avatarGradient(name.hashCode);
    return Container(
      width: radius * 2,
      height: radius * 2,
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
        style: (radius > 20 ? AppTypography.title : AppTypography.caption).copyWith(
          color: AppColors.textOnAccent,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  void _openChat(String friendId, String username, String? avatarUrl) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DirectChatScreen(
          targetUserId: friendId,
          targetUsername: username,
          targetAvatarUrl: avatarUrl,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser =
        ref.watch(authNotifierProvider).value ??
        ref.watch(authRepositoryProvider).currentUser;
    final currentUserId = currentUser?.id ?? 'mock_user_123';

    final friendsAsync = ref.watch(userFriendsProvider(currentUserId));
    final allMessagesAsync = ref.watch(userAllMessagesProvider(currentUserId));
    final allMessages = allMessagesAsync.value ?? [];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Row(
          children: [
            const Icon(
              Icons.forum_outlined,
              size: AppIconSize.md,
              color: AppColors.accent,
            ),
            const SizedBox(width: AppSpacing.sm),
            const Text('Pesan & Teman'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Segarkan',
            icon: const Icon(Icons.refresh, size: AppIconSize.md),
            onPressed: () {
              ref.invalidate(userFriendsProvider(currentUserId));
              ref.invalidate(userAllMessagesProvider(currentUserId));
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(userFriendsProvider(currentUserId));
          ref.invalidate(userAllMessagesProvider(currentUserId));
        },
        child: friendsAsync.when(
          data: (friends) {
            final filteredFriends = _searchQuery.isEmpty
                ? friends
                : friends.where((f) {
                    final q = _searchQuery.toLowerCase();
                    return f.displayName.toLowerCase().contains(q) ||
                        f.username.toLowerCase().contains(q);
                  }).toList();

            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                // ---- Search Box ----
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.sm,
                  ),
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (val) =>
                        setState(() => _searchQuery = val.trim()),
                    style: AppTypography.body,
                    decoration: InputDecoration(
                      hintText: 'Cari teman atau pesan...',
                      hintStyle: AppTypography.bodyMuted,
                      prefixIcon: const Icon(
                        Icons.search,
                        size: AppIconSize.md,
                        color: AppColors.textMuted,
                      ),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(
                                Icons.clear,
                                size: AppIconSize.sm,
                                color: AppColors.textMuted,
                              ),
                              onPressed: () {
                                _searchCtrl.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: AppColors.surface,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),

                // ---- Active Friends Stories / Row ----
                if (friends.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.sm,
                      AppSpacing.lg,
                      AppSpacing.xs,
                    ),
                    child: Text(
                      'Teman Aktif',
                      style: AppTypography.captionFaint.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                  SizedBox(
                    height: 94,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                      ),
                      scrollDirection: Axis.horizontal,
                      itemCount: friends.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(width: AppSpacing.md),
                      itemBuilder: (context, i) {
                        final friend = friends[i];
                        return _ActiveFriendItem(
                          friend: friend,
                          onOpenChat: _openChat,
                        );
                      },
                    ),
                  ),
                  const Divider(color: AppColors.border, height: 1),
                ],

                // ---- Chat List / Friends List ----
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.md,
                    AppSpacing.lg,
                    AppSpacing.xs,
                  ),
                  child: Text(
                    'Obrolan',
                    style: AppTypography.titleSmall,
                  ),
                ),

                if (filteredFriends.isEmpty) ...[
                  Container(
                    height: 260,
                    alignment: Alignment.center,
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.people_outline,
                          size: AppIconSize.hero,
                          color: AppColors.textFaint,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          _searchQuery.isEmpty
                              ? 'Belum ada teman'
                              : 'Tidak ada teman yang cocok',
                          style: AppTypography.bodyMuted,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          _searchQuery.isEmpty
                              ? 'Kirim permintaan pertemanan dari profil pengguna lain untuk mulai mengobrol!'
                              : 'Coba kata kunci pencarian yang lain.',
                          textAlign: TextAlign.center,
                          style: AppTypography.captionFaint,
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding:
                        const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                    itemCount: filteredFriends.length,
                    separatorBuilder: (_, _) => const Divider(
                      color: AppColors.border,
                      height: 1,
                      indent: 72,
                    ),
                    itemBuilder: (context, i) {
                      final friend = filteredFriends[i];

                      // Cari percakapan terakhir dengan teman ini
                      final friendMessages = allMessages.where((m) =>
                          (m.senderId == friend.id &&
                              m.receiverId == currentUserId) ||
                          (m.senderId == currentUserId &&
                              m.receiverId == friend.id));
                      final lastMessage = friendMessages.isNotEmpty
                          ? friendMessages.first
                          : null;

                      final timeString = lastMessage != null
                          ? _timeAgo(lastMessage.createdAt)
                          : '';

                      return _ChatFriendTile(
                        friend: friend,
                        currentUserId: currentUserId,
                        lastMessage: lastMessage,
                        timeString: timeString,
                        onOpenChat: _openChat,
                      );
                    },
                  ),
                ],
              ],
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
                'Gagal memuat teman: $e',
                style: AppTypography.bodyMuted,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ActiveFriendItem extends ConsumerWidget {
  final FriendUser friend;
  final Function(String friendId, String name, String? avatar) onOpenChat;

  const _ActiveFriendItem({
    required this.friend,
    required this.onOpenChat,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider(friend.id)).value;
    final resolvedUsername = (profile != null &&
            profile.displayName.isNotEmpty &&
            profile.displayName != 'Pengguna')
        ? profile.displayName
        : (profile != null &&
                profile.username.isNotEmpty &&
                profile.username != 'Pengguna')
            ? profile.username
            : (friend.displayName.isNotEmpty && friend.displayName != 'Pengguna')
                ? friend.displayName
                : (friend.username.isNotEmpty && friend.username != 'Pengguna')
                    ? friend.username
                    : 'Teman';
    final avatarUrl = (profile?.avatarUrl != null &&
            profile!.avatarUrl!.isNotEmpty &&
            !profile.avatarUrl!.startsWith('grad:'))
        ? profile.avatarUrl
        : (friend.avatarUrl != null &&
                friend.avatarUrl!.isNotEmpty &&
                !friend.avatarUrl!.startsWith('grad:'))
            ? friend.avatarUrl
            : null;

    return GestureDetector(
      onTap: () => onOpenChat(friend.id, resolvedUsername, avatarUrl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            children: [
              _FriendChatsScreenState.buildAvatar(
                avatarUrl,
                resolvedUsername,
                radius: 26,
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 13,
                  height: 13,
                  decoration: BoxDecoration(
                    color: AppColors.success,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.background,
                      width: 2,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          SizedBox(
            width: 62,
            child: Text(
              resolvedUsername,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: AppTypography.micro,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatFriendTile extends ConsumerWidget {
  final FriendUser friend;
  final String currentUserId;
  final DirectMessage? lastMessage;
  final String timeString;
  final Function(String friendId, String name, String? avatar) onOpenChat;

  const _ChatFriendTile({
    required this.friend,
    required this.currentUserId,
    required this.lastMessage,
    required this.timeString,
    required this.onOpenChat,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider(friend.id)).value;
    final resolvedUsername = (profile != null &&
            profile.displayName.isNotEmpty &&
            profile.displayName != 'Pengguna')
        ? profile.displayName
        : (profile != null &&
                profile.username.isNotEmpty &&
                profile.username != 'Pengguna')
            ? profile.username
            : (friend.displayName.isNotEmpty && friend.displayName != 'Pengguna')
                ? friend.displayName
                : (friend.username.isNotEmpty && friend.username != 'Pengguna')
                    ? friend.username
                    : 'Teman';
    final avatarUrl = (profile?.avatarUrl != null &&
            profile!.avatarUrl!.isNotEmpty &&
            !profile.avatarUrl!.startsWith('grad:'))
        ? profile.avatarUrl
        : (friend.avatarUrl != null &&
                friend.avatarUrl!.isNotEmpty &&
                !friend.avatarUrl!.startsWith('grad:'))
            ? friend.avatarUrl
            : null;

    final previewText = lastMessage != null
        ? (lastMessage!.senderId == currentUserId
            ? 'Anda: ${lastMessage!.content}'
            : lastMessage!.content)
        : 'Ketuk untuk mengobrol';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onOpenChat(friend.id, resolvedUsername, avatarUrl),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: Row(
            children: [
              Stack(
                children: [
                  _FriendChatsScreenState.buildAvatar(
                    avatarUrl,
                    resolvedUsername,
                    radius: 26,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: AppColors.success,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.surface,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            resolvedUsername,
                            style: AppTypography.bodyStrong,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (timeString.isNotEmpty)
                          Text(
                            timeString,
                            style: AppTypography.micro.copyWith(
                              color: AppColors.textFaint,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      previewText,
                      style: AppTypography.caption.copyWith(
                        color: lastMessage != null
                            ? AppColors.textMuted
                            : AppColors.accentSoft,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              const Icon(
                Icons.chevron_right,
                size: AppIconSize.sm,
                color: AppColors.textFaint,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
