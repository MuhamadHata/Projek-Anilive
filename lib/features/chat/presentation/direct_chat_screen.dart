import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_tokens.dart';
import '../../auth/presentation/auth_provider.dart';
import '../../profile/presentation/profile_screen.dart';
import '../data/direct_chat_repository.dart';
import '../domain/direct_message.dart';

class DirectChatScreen extends ConsumerStatefulWidget {
  final String targetUserId;
  final String targetUsername;
  final String? targetAvatarUrl;

  const DirectChatScreen({
    super.key,
    required this.targetUserId,
    required this.targetUsername,
    this.targetAvatarUrl,
  });

  @override
  ConsumerState<DirectChatScreen> createState() => _DirectChatScreenState();
}

class _DirectChatScreenState extends ConsumerState<DirectChatScreen> {
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _isSending = false;

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  String _getInitial(String name) {
    if (name.isNotEmpty && name != 'Pengguna' && name != 'Teman') {
      return name[0].toUpperCase();
    }
    return '?';
  }

  Widget _buildTopAvatar(String? avatarUrl, String name) {
    if (avatarUrl != null &&
        avatarUrl.isNotEmpty &&
        !avatarUrl.startsWith('grad:')) {
      if (avatarUrl.startsWith('data:')) {
        try {
          final bytes = base64Decode(avatarUrl.split(',').last);
          return CircleAvatar(
            radius: AppIconSize.md,
            backgroundColor: AppColors.surfaceAlt,
            backgroundImage: MemoryImage(bytes),
          );
        } catch (_) {}
      } else if (avatarUrl.startsWith('http://') ||
          avatarUrl.startsWith('https://')) {
        return CircleAvatar(
          radius: AppIconSize.md,
          backgroundColor: AppColors.surfaceAlt,
          backgroundImage: CachedNetworkImageProvider(avatarUrl),
          onBackgroundImageError: (_, _) {},
        );
      }
    }

    final initial = _getInitial(name);
    final gradientColors = AppColors.avatarGradient(name.hashCode);
    return Container(
      width: AppIconSize.md * 2,
      height: AppIconSize.md * 2,
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
        style: AppTypography.titleSmall.copyWith(
          color: AppColors.textOnAccent,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  void _scrollToBottom() {
    if (_scrollCtrl.hasClients) {
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent + 80,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _sendMessage() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty || _isSending) return;

    final currentUser =
        ref.read(authNotifierProvider).value ??
        ref.read(authRepositoryProvider).currentUser;

    if (currentUser == null) return;

    setState(() => _isSending = true);
    _inputCtrl.clear();

    final message = DirectMessage(
      id: 'dm_${DateTime.now().millisecondsSinceEpoch}',
      senderId: currentUser.id,
      senderName: currentUser.username,
      senderAvatar: currentUser.avatarUrl,
      receiverId: widget.targetUserId,
      content: text,
      createdAt: DateTime.now(),
    );

    try {
      await ref.read(directChatRepositoryProvider).sendMessage(message);
      Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengirim pesan: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser =
        ref.watch(authNotifierProvider).value ??
        ref.watch(authRepositoryProvider).currentUser;

    final currentUserId = currentUser?.id ?? 'mock_user_123';
    final messagesAsync = ref.watch(
      directMessagesProvider((currentUserId, widget.targetUserId)),
    );

    final targetProfile =
        ref.watch(profileProvider(widget.targetUserId)).value;
    final resolvedUsername = (targetProfile != null &&
            targetProfile.displayName.isNotEmpty &&
            targetProfile.displayName != 'Pengguna')
        ? targetProfile.displayName
        : (targetProfile != null &&
                targetProfile.username.isNotEmpty &&
                targetProfile.username != 'Pengguna')
            ? targetProfile.username
            : (widget.targetUsername.isNotEmpty &&
                    widget.targetUsername != 'Pengguna')
                ? widget.targetUsername
                : 'Teman';
    final resolvedAvatar = (targetProfile?.avatarUrl != null &&
            targetProfile!.avatarUrl!.isNotEmpty &&
            !targetProfile.avatarUrl!.startsWith('grad:'))
        ? targetProfile.avatarUrl
        : (widget.targetAvatarUrl != null &&
                widget.targetAvatarUrl!.isNotEmpty &&
                !widget.targetAvatarUrl!.startsWith('grad:'))
            ? widget.targetAvatarUrl
            : null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        titleSpacing: 0,
        title: Row(
          children: [
            _buildTopAvatar(resolvedAvatar, resolvedUsername),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    resolvedUsername,
                    style: AppTypography.titleSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: AppColors.success,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        'Teman',
                        style: AppTypography.micro.copyWith(
                          color: AppColors.success,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: messagesAsync.when(
                data: (messages) {
                  if (messages.isEmpty) {
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
                            'Belum ada pesan',
                            style: AppTypography.bodyMuted,
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            'Kirim pesan pertama untuk memulai obrolan!',
                            style: AppTypography.captionFaint,
                          ),
                        ],
                      ),
                    );
                  }

                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (_scrollCtrl.hasClients) {
                      _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
                    }
                  });

                  return ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                      vertical: AppSpacing.md,
                    ),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final msg = messages[index];
                      final isMe = msg.senderId == currentUserId;
                      return _MessageBubble(
                        message: msg,
                        isMe: isMe,
                      );
                    },
                  );
                },
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.accent),
                ),
                error: (e, _) => Center(
                  child: Text('Gagal memuat pesan: $e'),
                ),
              ),
            ),
            _buildInputBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: TextField(
                controller: _inputCtrl,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
                style: AppTypography.body,
                decoration: const InputDecoration(
                  hintText: 'Tulis pesan...',
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
              onTap: _isSending ? null : _sendMessage,
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
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final DirectMessage message;
  final bool isMe;

  const _MessageBubble({
    required this.message,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    final timeStr = DateFormat('HH:mm').format(message.createdAt);

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: isMe ? AppColors.accent : AppColors.surface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(AppRadius.md),
            topRight: const Radius.circular(AppRadius.md),
            bottomLeft: Radius.circular(isMe ? AppRadius.md : AppRadius.sm),
            bottomRight: Radius.circular(isMe ? AppRadius.sm : AppRadius.md),
          ),
          border: isMe ? null : Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(
              message.content,
              style: AppTypography.body.copyWith(
                color: isMe ? AppColors.textOnAccent : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              timeStr,
              style: AppTypography.micro.copyWith(
                color: isMe
                    ? AppColors.textOnAccent.withAlpha(180)
                    : AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
