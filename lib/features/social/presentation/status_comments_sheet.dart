import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_tokens.dart';
import '../../auth/presentation/auth_provider.dart';
import '../../profile/presentation/profile_screen.dart';
import '../domain/status_update.dart';
import '../data/status_repository_impl.dart' show statusRepositoryProvider;

final statusCommentsProvider = StreamProvider.autoDispose
    .family<List<StatusComment>, String>((ref, statusId) {
  return ref.watch(statusRepositoryProvider).getComments(statusId);
});

class StatusCommentsSheet extends ConsumerStatefulWidget {
  final StatusUpdate status;

  const StatusCommentsSheet({super.key, required this.status});

  static Future<void> show(BuildContext context, StatusUpdate status) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceDialog,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.xl),
        ),
      ),
      builder: (_) => StatusCommentsSheet(status: status),
    );
  }

  @override
  ConsumerState<StatusCommentsSheet> createState() =>
      _StatusCommentsSheetState();
}

class _StatusCommentsSheetState extends ConsumerState<StatusCommentsSheet> {
  final _inputCtrl = TextEditingController();
  bool _isSending = false;

  @override
  void dispose() {
    _inputCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendComment() async {
    final text = _inputCtrl.text.trim();
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
    _inputCtrl.clear();

    final comment = StatusComment(
      id: 'scmt_${DateTime.now().millisecondsSinceEpoch}',
      statusId: widget.status.id,
      userId: currentUser.id,
      username: currentUser.username,
      avatarUrl: currentUser.avatarUrl,
      content: text,
      createdAt: DateTime.now(),
    );

    try {
      await ref.read(statusRepositoryProvider).addComment(
            comment,
            authorId: widget.status.userId,
            animeTitle: widget.status.animeTitle,
          );
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

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }

  @override
  Widget build(BuildContext context) {
    final commentsAsync = ref.watch(statusCommentsProvider(widget.status.id));

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.xs,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Komentar: ${widget.status.animeTitle}',
                      style: AppTypography.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: AppIconSize.md),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(color: AppColors.border, height: 1),
            // Comments list
            Expanded(
              child: commentsAsync.when(
                data: (comments) {
                  if (comments.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
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
                            'Jadilah orang pertama yang berkomentar!',
                            style: AppTypography.captionFaint,
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    itemCount: comments.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppSpacing.md),
                    itemBuilder: (context, i) {
                      final cmt = comments[i];
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          GestureDetector(
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      ProfileScreen(userId: cmt.userId),
                                ),
                              );
                            },
                            child: CircleAvatar(
                              radius: AppIconSize.sm,
                              backgroundColor: AppColors.surfaceAlt,
                              backgroundImage: cmt.avatarUrl != null &&
                                      cmt.avatarUrl!.isNotEmpty
                                  ? CachedNetworkImageProvider(cmt.avatarUrl!)
                                  : null,
                              onBackgroundImageError: (cmt.avatarUrl != null &&
                                      cmt.avatarUrl!.isNotEmpty)
                                  ? (_, _) {}
                                  : null,
                              child: cmt.avatarUrl == null ||
                                      cmt.avatarUrl!.isEmpty
                                  ? const Icon(
                                      Icons.person,
                                      size: AppIconSize.xs,
                                      color: AppColors.textMuted,
                                    )
                                  : null,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    GestureDetector(
                                      onTap: () {
                                        Navigator.pop(context);
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) => ProfileScreen(
                                              userId: cmt.userId,
                                            ),
                                          ),
                                        );
                                      },
                                      child: Text(
                                        cmt.username,
                                        style: AppTypography.bodyStrong,
                                      ),
                                    ),
                                    const SizedBox(width: AppSpacing.xs),
                                    Text(
                                      '• ${_timeAgo(cmt.createdAt)}',
                                      style: AppTypography.captionFaint,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  cmt.content,
                                  style: AppTypography.body,
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.accent),
                ),
                error: (e, _) => Center(
                  child: Text('Gagal memuat komentar: $e'),
                ),
              ),
            ),
            // Input bar
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceAlt,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                        child: TextField(
                          controller: _inputCtrl,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _sendComment(),
                          style: AppTypography.body,
                          decoration: const InputDecoration(
                            hintText: 'Tulis komentar...',
                            hintStyle: AppTypography.caption,
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(
                              vertical: AppSpacing.sm,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Material(
                      color: AppColors.accent,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        onTap: _isSending ? null : _sendComment,
                        child: SizedBox(
                          width: AppTouch.minTarget,
                          height: AppTouch.minTarget,
                          child: Center(
                            child: _isSending
                                ? const SizedBox(
                                    width: AppIconSize.sm,
                                    height: AppIconSize.sm,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.textOnAccent,
                                    ),
                                  )
                                : const Icon(
                                    Icons.send_rounded,
                                    color: AppColors.textOnAccent,
                                    size: AppIconSize.md,
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
