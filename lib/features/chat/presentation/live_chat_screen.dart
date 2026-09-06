import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../auth/presentation/auth_provider.dart';
import '../data/chat_repository_impl.dart';
import '../domain/chat_models.dart';
import 'package:anitrack/core/theme/app_tokens.dart';

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepositoryImpl();
});

final chatMessagesProvider = StreamProvider.autoDispose
    .family<List<ChatMessage>, int>((ref, animeId) {
      return ref.watch(chatRepositoryProvider).getMessages(animeId);
    });

final onlineUsersProvider = StreamProvider.autoDispose
    .family<List<UserPresence>, int>((ref, animeId) {
      return ref.watch(chatRepositoryProvider).getOnlineUsers(animeId);
    });

class LiveChatScreen extends ConsumerStatefulWidget {
  final int animeId;
  final String animeTitle;

  const LiveChatScreen({
    super.key,
    required this.animeId,
    required this.animeTitle,
  });

  @override
  ConsumerState<LiveChatScreen> createState() => _LiveChatScreenState();
}

class _LiveChatScreenState extends ConsumerState<LiveChatScreen> {
  final _msgCtrl = TextEditingController();
  bool _sending = false;

  ChatRepository? _chatRepo;
  String? _currentUserId;
  String? _currentUsername;

  @override
  void initState() {
    super.initState();
    _chatRepo = ref.read(chatRepositoryProvider);
    final user = ref.read(authNotifierProvider).value ??
        ref.read(authRepositoryProvider).currentUser;
    _currentUserId = user?.id;
    _currentUsername = user?.username;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updatePresence(true);
    });
  }

  @override
  void dispose() {
    if (_chatRepo != null &&
        _currentUserId != null &&
        _currentUsername != null) {
      _chatRepo!.setPresence(
        widget.animeId,
        _currentUserId!,
        _currentUsername!,
        false,
      );
    }
    _msgCtrl.dispose();
    super.dispose();
  }

  void _updatePresence(bool isOnline, {bool isTyping = false}) {
    if (_chatRepo != null &&
        _currentUserId != null &&
        _currentUsername != null) {
      _chatRepo!.setPresence(
        widget.animeId,
        _currentUserId!,
        _currentUsername!,
        isOnline,
        isTyping: isTyping,
      );
    }
  }

  void _send() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;

    final user =
        ref.read(authNotifierProvider).value ??
        ref.read(authRepositoryProvider).currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Silakan login untuk bergabung chat')),
      );
      return;
    }

    setState(() => _sending = true);
    final msg = ChatMessage(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
      animeId: widget.animeId,
      userId: user.id,
      username: user.username,
      avatarUrl: user.avatarUrl,
      content: text,
      createdAt: DateTime.now(),
    );

    try {
      await ref.read(chatRepositoryProvider).sendMessage(msg);
      _msgCtrl.clear();
      _updatePresence(true, isTyping: false);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal mengirim: $e')));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user =
        ref.watch(authNotifierProvider).value ??
        ref.read(authRepositoryProvider).currentUser;
    final currentUserId = user?.id ?? '';
    final messagesAsync = ref.watch(chatMessagesProvider(widget.animeId));
    final onlineAsync = ref.watch(onlineUsersProvider(widget.animeId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.animeTitle, style: AppTypography.title),
            onlineAsync.when(
              data: (users) {
                final typingCount = users.where((u) => u.isTyping).length;
                if (typingCount > 0) {
                  return Text(
                    'Seseorang sedang mengetik...',
                    style: AppTypography.captionFaint.copyWith(
                      color: AppColors.success,
                    ),
                  );
                }
                return Text(
                  '${users.length} online',
                  style: AppTypography.captionFaint.copyWith(
                    color: AppColors.textMuted,
                  ),
                );
              },
              loading: () => const Text(
                'Menghubungkan...',
                style: AppTypography.captionFaint,
              ),
              error: (_, _) => const SizedBox(),
            ),
          ],
        ),
        backgroundColor: AppColors.surfaceDialog,
      ),
      body: Column(
        children: [
          Expanded(
            child: messagesAsync.when(
              data: (msgs) => msgs.isEmpty
                  ? const Center(
                      child: Text('Ruang chat masih sepi. Sapa teman-temanmu!'),
                    )
                  : ListView.builder(
                      reverse: true,
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      itemCount: msgs.length,
                      itemBuilder: (_, i) {
                        final m = msgs[i];
                        final isMe = m.userId == currentUserId;
                        return _MessageBubble(message: m, isMe: isMe);
                      },
                    ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Gagal memuat chat: $e')),
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
                controller: _msgCtrl,
                style: AppTypography.body,
                decoration: const InputDecoration(
                  hintText: 'Ketik pesan...',
                  border: InputBorder.none,
                ),
                onChanged: (text) {
                  _updatePresence(true, isTyping: text.isNotEmpty);
                },
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

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMe;

  const _MessageBubble({required this.message, required this.isMe});

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
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: isMe ? AppColors.accent : AppColors.surfacePressed,
          borderRadius: BorderRadius.circular(AppRadius.lg).copyWith(
            bottomRight: isMe
                ? const Radius.circular(0)
                : const Radius.circular(AppRadius.lg),
            bottomLeft: !isMe
                ? const Radius.circular(0)
                : const Radius.circular(AppRadius.lg),
          ),
        ),
        child: Column(
          crossAxisAlignment: isMe
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            if (!isMe)
              Text(
                message.username,
                style: AppTypography.captionFaint.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.dangerBright,
                ),
              ),
            Text(message.content, style: AppTypography.titleSmall),
            const SizedBox(height: AppSpacing.xs),
            Text(timeStr, style: AppTypography.micro),
          ],
        ),
      ),
    );
  }
}
