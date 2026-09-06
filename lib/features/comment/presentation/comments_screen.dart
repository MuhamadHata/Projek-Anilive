import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../auth/presentation/auth_provider.dart';
import '../data/comment_repository_impl.dart';
import '../domain/comment.dart';
import 'package:anitrack/core/theme/app_tokens.dart';

final commentRepositoryProvider = Provider<CommentRepository>((ref) {
  return CommentRepositoryImpl();
});

final animeCommentsProvider = StreamProvider.autoDispose
    .family<List<AnimeComment>, int>((ref, animeId) {
      return ref.watch(commentRepositoryProvider).getComments(animeId);
    });

final commentRepliesProvider = StreamProvider.autoDispose
    .family<List<AnimeComment>, (int, String)>((ref, arg) {
      return ref.watch(commentRepositoryProvider).getReplies(arg.$1, arg.$2);
    });

class CommentsScreen extends ConsumerStatefulWidget {
  final int animeId;
  final String animeTitle;

  const CommentsScreen({
    super.key,
    required this.animeId,
    required this.animeTitle,
  });

  @override
  ConsumerState<CommentsScreen> createState() => _CommentsScreenState();
}

class _CommentsScreenState extends ConsumerState<CommentsScreen> {
  final _inputCtrl = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _inputCtrl.dispose();
    super.dispose();
  }

  void _send() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty) return;

    final user =
        ref.read(authNotifierProvider).value ??
        ref.read(authRepositoryProvider).currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Silakan login terlebih dahulu untuk berkomentar'),
        ),
      );
      return;
    }

    setState(() => _sending = true);
    final comment = AnimeComment(
      id: 'cmt_${DateTime.now().millisecondsSinceEpoch}',
      animeId: widget.animeId,
      userId: user.id,
      username: user.username,
      avatarUrl: user.avatarUrl,
      content: text,
      createdAt: DateTime.now(),
    );

    try {
      await ref.read(commentRepositoryProvider).addComment(comment);
      _inputCtrl.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final commentsAsync = ref.watch(animeCommentsProvider(widget.animeId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Komentar — ${widget.animeTitle}'),
        backgroundColor: Colors.transparent,
      ),
      body: Column(
        children: [
          Expanded(
            child: commentsAsync.when(
              data: (list) => list.isEmpty
                  ? const Center(
                      child: Text('Belum ada komentar. Jadilah yang pertama!'),
                    )
                  : ListView.builder(
                      reverse: true,
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      itemCount: list.length,
                      itemBuilder: (_, i) => _CommentTile(comment: list[i]),
                    ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Gagal memuat komentar: $e')),
            ),
          ),
          _inputBar(),
        ],
      ),
    );
  }

  Widget _inputBar() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      color: AppColors.surfaceDialog,
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _inputCtrl,
                maxLines: null,
                style: AppTypography.body,
                decoration: const InputDecoration(
                  hintText: 'Tulis komentar...',
                  border: InputBorder.none,
                ),
              ),
            ),
            IconButton(
              onPressed: _sending ? null : _send,
              icon: _sending
                  ? const SizedBox(
                      width: AppIconSize.lg,
                      height: AppIconSize.lg,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send, color: AppColors.accent),
            ),
          ],
        ),
      ),
    );
  }
}

class _CommentTile extends ConsumerWidget {
  final AnimeComment comment;

  const _CommentTile({required this.comment});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timeStr = DateFormat('dd MMM yyyy, HH:mm').format(comment.createdAt);

    return Card(
      color: AppColors.surfaceDialog,
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundImage: comment.avatarUrl != null
                      ? NetworkImage(comment.avatarUrl!)
                      : null,
                  child: comment.avatarUrl == null
                      ? const Icon(Icons.person)
                      : null,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(comment.username, style: AppTypography.bodyStrong),
                      Text(timeStr, style: AppTypography.micro),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.favorite_border, size: AppIconSize.lg),
                  onPressed: () => ref
                      .read(commentRepositoryProvider)
                      .toggleLike(comment.animeId, comment.id),
                ),
                Text(
                  '${comment.likeCount}',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(comment.content, style: AppTypography.titleSmall),
          ],
        ),
      ),
    );
  }
}
