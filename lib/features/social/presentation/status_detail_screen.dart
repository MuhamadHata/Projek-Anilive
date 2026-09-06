import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_tokens.dart';
import '../../auth/presentation/auth_provider.dart';
import '../../profile/presentation/profile_screen.dart';
import '../data/status_repository_impl.dart';
import '../domain/status_update.dart';

class StatusDetailScreen extends ConsumerStatefulWidget {
  final String statusId;

  const StatusDetailScreen({super.key, required this.statusId});

  @override
  ConsumerState<StatusDetailScreen> createState() => _StatusDetailScreenState();
}

class _StatusDetailScreenState extends ConsumerState<StatusDetailScreen> {
  final _commentCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _isSending = false;

  @override
  void dispose() {
    _commentCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.isNegative || diff.inMinutes < 1) return 'Baru saja';
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

  Widget _buildAvatar(String? avatarUrl, {double radius = AppIconSize.md}) {
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
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.surfaceAlt,
      child: const Icon(
        Icons.person,
        size: AppIconSize.sm,
        color: AppColors.textMuted,
      ),
    );
  }

  Future<void> _sendComment(StatusUpdate status) async {
    final text = _commentCtrl.text.trim();
    if (text.isEmpty || _isSending) return;

    final currentUser =
        ref.read(authNotifierProvider).value ??
        ref.read(authRepositoryProvider).currentUser;

    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Silakan login untuk berkomentar')),
      );
      return;
    }

    setState(() => _isSending = true);
    _commentCtrl.clear();

    final comment = StatusComment(
      id: 'scmt_${DateTime.now().millisecondsSinceEpoch}',
      statusId: status.id,
      userId: currentUser.id,
      username: currentUser.username,
      avatarUrl: currentUser.avatarUrl,
      content: text,
      createdAt: DateTime.now(),
    );

    try {
      await ref.read(statusRepositoryProvider).addComment(
            comment,
            authorId: status.userId,
            animeTitle: status.animeTitle,
          );
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent + 60,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengirim komentar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final feed = ref.watch(feedProvider).value ?? [];
    final feedMatch = feed.where((s) => s.id == widget.statusId).firstOrNull;
    final singleStatusAsync = ref.watch(singleStatusProvider(widget.statusId));
    final status = feedMatch ?? singleStatusAsync.value;

    final currentUser =
        ref.watch(authNotifierProvider).value ??
        ref.watch(authRepositoryProvider).currentUser;
    final currentUserId = currentUser?.id ?? 'mock_user_123';
    final commentsAsync = ref.watch(statusCommentsProvider(widget.statusId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Status Anime'),
        actions: [
          IconButton(
            tooltip: 'Segarkan',
            icon: const Icon(Icons.refresh, size: AppIconSize.md),
            onPressed: () {
              ref.invalidate(singleStatusProvider(widget.statusId));
              ref.invalidate(statusCommentsProvider(widget.statusId));
            },
          ),
        ],
      ),
      body: status == null
          ? (singleStatusAsync.isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.accent),
                )
              : Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: AppIconSize.hero,
                        color: AppColors.textFaint,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text('Status tidak ditemukan',
                          style: AppTypography.bodyMuted),
                    ],
                  ),
                ))
          : Column(
              children: [
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () async {
                      ref.invalidate(singleStatusProvider(widget.statusId));
                      ref.invalidate(statusCommentsProvider(widget.statusId));
                    },
                    child: ListView(
                      controller: _scrollCtrl,
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      children: [
                        // ---- Kartu Status Utama ----
                        Card(
                          color: AppColors.surfaceDialog,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Author Header
                                GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => ProfileScreen(
                                          userId: status.userId,
                                        ),
                                      ),
                                    );
                                  },
                                  child: Row(
                                    children: [
                                      _buildAvatar(status.avatarUrl),
                                      const SizedBox(width: AppSpacing.sm),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              status.username,
                                              style: AppTypography.bodyStrong,
                                            ),
                                            Text(
                                              _timeAgo(status.createdAt),
                                              style: AppTypography.captionFaint
                                                  .copyWith(
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
                                Text(
                                  _statusLabel(status.watchStatus),
                                  style: AppTypography.bodyMuted,
                                ),
                                const SizedBox(height: AppSpacing.sm),

                                // Anime Content
                                Container(
                                  padding: const EdgeInsets.all(AppSpacing.sm),
                                  decoration: BoxDecoration(
                                    color: AppColors.surface,
                                    borderRadius:
                                        BorderRadius.circular(AppRadius.md),
                                    border: Border.all(color: AppColors.border),
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Anime Poster
                                      ClipRRect(
                                        borderRadius:
                                            BorderRadius.circular(AppRadius.sm),
                                        child: SizedBox(
                                          width: 80,
                                          height: 114,
                                          child: status
                                                  .animeCoverUrl.isNotEmpty
                                              ? CachedNetworkImage(
                                                  imageUrl:
                                                      status.animeCoverUrl,
                                                  fit: BoxFit.cover,
                                                  placeholder: (_, _) =>
                                                      Container(
                                                    color: AppColors.surfaceAlt,
                                                    child: const Center(
                                                      child:
                                                          CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                        color: AppColors.accent,
                                                      ),
                                                    ),
                                                  ),
                                                  errorWidget: (_, _, _) =>
                                                      Container(
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
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              status.animeTitle,
                                              style: AppTypography.title,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            if (status.rating != null) ...[
                                              const SizedBox(
                                                  height: AppSpacing.xs),
                                              Row(
                                                children: [
                                                  const Icon(
                                                    Icons.star_rounded,
                                                    size: AppIconSize.sm,
                                                    color: AppColors.star,
                                                  ),
                                                  const SizedBox(
                                                      width: AppSpacing.xs),
                                                  Text(
                                                    '${status.rating!.toStringAsFixed(1)} / 10',
                                                    style: AppTypography
                                                        .bodyStrong
                                                        .copyWith(
                                                      color: AppColors.star,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                            if (status.caption.isNotEmpty) ...[
                                              const SizedBox(
                                                  height: AppSpacing.xs),
                                              Text(
                                                status.caption,
                                                style: AppTypography.body,
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.md),

                                // Actions (Love & Comment count)
                                Row(
                                  children: [
                                    InkWell(
                                      borderRadius:
                                          BorderRadius.circular(AppRadius.sm),
                                      onTap: () {
                                        ref
                                            .read(statusRepositoryProvider)
                                            .toggleLike(
                                              status.id,
                                              currentUserId,
                                              authorId: status.userId,
                                              currentUsername:
                                                  currentUser?.username,
                                              currentAvatarUrl:
                                                  currentUser?.avatarUrl,
                                              animeTitle: status.animeTitle,
                                            );
                                      },
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: AppSpacing.sm,
                                          vertical: AppSpacing.xs,
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              status.likedBy
                                                      .contains(currentUserId)
                                                  ? Icons.favorite
                                                  : Icons.favorite_border,
                                              size: AppIconSize.md,
                                              color: status.likedBy
                                                      .contains(currentUserId)
                                                  ? AppColors.dangerBright
                                                  : AppColors.textMuted,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              '${status.likeCount}',
                                              style: AppTypography.caption
                                                  .copyWith(
                                                color: status.likedBy
                                                        .contains(currentUserId)
                                                    ? AppColors.dangerBright
                                                    : AppColors.textMuted,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: AppSpacing.md),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: AppSpacing.sm,
                                        vertical: AppSpacing.xs,
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.chat_bubble_outline,
                                            size: AppIconSize.md,
                                            color: AppColors.textMuted,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            '${status.commentCount}',
                                            style: AppTypography.caption
                                                .copyWith(
                                              color: AppColors.textMuted,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: AppSpacing.lg),

                        // Section Komentar
                        Text(
                          'Komentar',
                          style: AppTypography.titleSmall,
                        ),
                        const SizedBox(height: AppSpacing.sm),

                        // List Komentar
                        commentsAsync.when(
                          data: (comments) {
                            if (comments.isEmpty) {
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: AppSpacing.xl,
                                ),
                                alignment: Alignment.center,
                                child: Column(
                                  children: [
                                    const Icon(
                                      Icons.chat_bubble_outline,
                                      size: AppIconSize.hero,
                                      color: AppColors.textFaint,
                                    ),
                                    const SizedBox(height: AppSpacing.sm),
                                    Text(
                                      'Belum ada komentar',
                                      style: AppTypography.bodyMuted,
                                    ),
                                    const SizedBox(height: AppSpacing.xs),
                                    Text(
                                      'Jadilah yang pertama mengomentari status ini!',
                                      style: AppTypography.captionFaint,
                                    ),
                                  ],
                                ),
                              );
                            }

                            return ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: comments.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: AppSpacing.sm),
                              itemBuilder: (context, i) {
                                final c = comments[i];
                                return Container(
                                  padding: const EdgeInsets.all(AppSpacing.md),
                                  decoration: BoxDecoration(
                                    color: AppColors.surface,
                                    borderRadius:
                                        BorderRadius.circular(AppRadius.md),
                                    border: Border.all(color: AppColors.border),
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      GestureDetector(
                                        onTap: () {
                                          Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (_) => ProfileScreen(
                                                userId: c.userId,
                                              ),
                                            ),
                                          );
                                        },
                                        child: _buildAvatar(c.avatarUrl,
                                            radius: AppIconSize.sm),
                                      ),
                                      const SizedBox(width: AppSpacing.sm),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    c.username,
                                                    style: AppTypography
                                                        .bodyStrong,
                                                  ),
                                                ),
                                                Text(
                                                  _timeAgo(c.createdAt),
                                                  style: AppTypography.micro
                                                      .copyWith(
                                                    color: AppColors.textFaint,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              c.content,
                                              style: AppTypography.body,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            );
                          },
                          loading: () => const Padding(
                            padding: EdgeInsets.all(AppSpacing.lg),
                            child: Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.accent,
                              ),
                            ),
                          ),
                          error: (e, _) => Center(
                            child: Text(
                              'Gagal memuat komentar: $e',
                              style: AppTypography.captionFaint,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Bottom Comment Input Field
                Container(
                  padding: EdgeInsets.only(
                    left: AppSpacing.lg,
                    right: AppSpacing.lg,
                    top: AppSpacing.sm,
                    bottom: MediaQuery.of(context).viewInsets.bottom +
                        AppSpacing.sm,
                  ),
                  decoration: const BoxDecoration(
                    color: AppColors.surface,
                    border: Border(
                      top: BorderSide(color: AppColors.border),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _commentCtrl,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _sendComment(status),
                          style: AppTypography.body,
                          decoration: InputDecoration(
                            hintText: 'Tulis komentar...',
                            hintStyle: AppTypography.bodyMuted,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                              vertical: AppSpacing.sm,
                            ),
                            border: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(AppRadius.pill),
                              borderSide:
                                  const BorderSide(color: AppColors.border),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(AppRadius.pill),
                              borderSide:
                                  const BorderSide(color: AppColors.border),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(AppRadius.pill),
                              borderSide:
                                  const BorderSide(color: AppColors.accent),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      IconButton(
                        onPressed:
                            _isSending ? null : () => _sendComment(status),
                        icon: _isSending
                            ? const SizedBox(
                                width: AppIconSize.sm,
                                height: AppIconSize.sm,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.accent,
                                ),
                              )
                            : const Icon(
                                Icons.send_rounded,
                                color: AppColors.accent,
                                size: AppIconSize.md,
                              ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
