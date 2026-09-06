import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/config/app_config.dart';
import '../../../core/services/supabase_service.dart';
import '../../anime/data/anime_offline_db.dart';
import '../../anime/presentation/anime_providers.dart';
import '../../auth/presentation/auth_provider.dart';
import '../data/status_repository_impl.dart';
import '../domain/status_update.dart';
import 'package:anitrack/core/theme/app_tokens.dart';

class PostStatusScreen extends ConsumerStatefulWidget {
  const PostStatusScreen({super.key});

  @override
  ConsumerState<PostStatusScreen> createState() => _PostStatusScreenState();
}

class _PostStatusScreenState extends ConsumerState<PostStatusScreen> {
  final _searchCtrl = TextEditingController();
  final _captionCtrl = TextEditingController();
  String _watchStatus = 'completed';
  double? _rating;
  bool _posting = false;
  int _selectedAnimeId = 0;
  String _selectedAnimeTitle = '';
  String _selectedAnimeCoverUrl = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    _captionCtrl.dispose();
    super.dispose();
  }

  void _post() async {
    final user =
        ref.read(authNotifierProvider).value ??
        ref.read(authRepositoryProvider).currentUser;
    if (user == null) return;

    final animeTitle = _selectedAnimeTitle.isNotEmpty
        ? _selectedAnimeTitle
        : _searchCtrl.text.trim();

    if (animeTitle.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih atau masukkan judul anime')),
      );
      return;
    }

    setState(() => _posting = true);

    String coverUrl = _selectedAnimeCoverUrl;
    int animeId = _selectedAnimeId;
    String finalTitle = _selectedAnimeTitle;

    // Jika belum memilih dari list atau cover masih kosong, cari dari database anime lokal otomatis
    if (finalTitle.isEmpty || coverUrl.isEmpty || animeId == 0) {
      final matches = await AnimeOfflineDb.search(animeTitle, limit: 1);
      if (matches.isNotEmpty) {
        finalTitle = matches.first.title;
        coverUrl = matches.first.imageUrl;
        animeId = matches.first.id;
      } else {
        finalTitle = animeTitle;
      }
    }

    String currentUsername = user.username;
    String? currentAvatar = user.avatarUrl;

    // Pastikan mengambil username dan foto asli dari tabel profiles di Supabase jika tersedia
    if (AppConfig.useSupabase && SupabaseService.isInitialized) {
      try {
        final profile = await SupabaseService.client
            ?.from('profiles')
            .select('username, display_name, avatar_url')
            .eq('id', user.id)
            .maybeSingle();
        if (profile != null) {
          final pName = (profile['username'] as String?)?.trim();
          if (pName != null && pName.isNotEmpty) {
            currentUsername = pName;
          }
          final pAvatar = (profile['avatar_url'] as String?)?.trim();
          if (pAvatar != null && pAvatar.isNotEmpty) {
            currentAvatar = pAvatar;
          }
        }
      } catch (_) {}
    }

    final status = StatusUpdate(
      id: 'st_${DateTime.now().millisecondsSinceEpoch}',
      userId: user.id,
      username: currentUsername,
      avatarUrl: currentAvatar,
      animeId: animeId,
      animeTitle: finalTitle,
      animeCoverUrl: coverUrl,
      watchStatus: _watchStatus,
      rating: _rating,
      caption: _captionCtrl.text.trim(),
      createdAt: DateTime.now(),
    );

    try {
      await ref.read(statusRepositoryProvider).postStatus(status);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Status diposting!')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal: $e')));
      }
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final searchQuery = _searchCtrl.text;
    final AsyncValue<List<dynamic>> searchResults = (searchQuery.length >= 2)
        ? ref.watch(searchAnimeProvider(AnimeFilterArgs(query: searchQuery)))
        : const AsyncValue.data([]);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Tulis Status'),
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        top: false,
        bottom: true,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Pilih Anime',
              style: AppTypography.bodyStrong,
            ),
            const SizedBox(height: AppSpacing.sm),

            if (_selectedAnimeTitle.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: AppColors.accent),
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      child: SizedBox(
                        width: 50,
                        height: 72,
                        child: _selectedAnimeCoverUrl.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: _selectedAnimeCoverUrl,
                                fit: BoxFit.cover,
                                placeholder: (_, _) => Container(color: AppColors.surfaceAlt),
                                errorWidget: (_, _, _) => Container(
                                  color: AppColors.surfaceAlt,
                                  child: const Icon(Icons.movie, color: AppColors.textMuted),
                                ),
                              )
                            : Container(
                                color: AppColors.surfaceAlt,
                                child: const Icon(Icons.movie, color: AppColors.textMuted),
                              ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _selectedAnimeTitle,
                            style: AppTypography.titleSmall,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            'Anime terpilih ✓',
                            style: AppTypography.captionFaint.copyWith(color: AppColors.success),
                          ),
                        ],
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _selectedAnimeId = 0;
                          _selectedAnimeTitle = '';
                          _selectedAnimeCoverUrl = '';
                          _searchCtrl.clear();
                        });
                      },
                      icon: const Icon(Icons.refresh, size: AppIconSize.xs),
                      label: const Text('Ganti'),
                    ),
                  ],
                ),
              ),
            ] else ...[
              TextField(
                controller: _searchCtrl,
                decoration: const InputDecoration(
                  hintText: 'Cari judul anime (misal: Attack on Titan)...',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (_) => setState(() {}),
              ),
              if (searchQuery.length >= 2) ...[
                const SizedBox(height: AppSpacing.sm),
                searchResults.when(
                  data: (list) => Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: list
                          .take(4)
                          .map(
                            (anime) => ListTile(
                              leading: ClipRRect(
                                borderRadius: BorderRadius.circular(AppRadius.sm),
                                child: SizedBox(
                                  width: 40,
                                  height: 56,
                                  child: anime.imageUrl.isNotEmpty
                                      ? CachedNetworkImage(
                                          imageUrl: anime.imageUrl,
                                          fit: BoxFit.cover,
                                          errorWidget: (_, _, _) => const Icon(
                                            Icons.movie_outlined,
                                            size: AppIconSize.sm,
                                            color: AppColors.textMuted,
                                          ),
                                        )
                                      : const Icon(
                                          Icons.movie_outlined,
                                          size: AppIconSize.sm,
                                          color: AppColors.textMuted,
                                        ),
                                ),
                              ),
                              title: Text(
                                anime.title,
                                style: AppTypography.bodyStrong,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                anime.genres.join(', '),
                                style: AppTypography.captionFaint,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              onTap: () {
                                setState(() {
                                  _selectedAnimeId = anime.id;
                                  _selectedAnimeTitle = anime.title;
                                  _selectedAnimeCoverUrl = anime.imageUrl;
                                  _searchCtrl.clear();
                                });
                              },
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  loading: () => const Padding(
                    padding: EdgeInsets.all(AppSpacing.md),
                    child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                  ),
                  error: (e, _) => Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Text('Gagal mencari: $e', style: AppTypography.captionFaint),
                  ),
                ),
              ],
            ],
            const SizedBox(height: AppSpacing.xl),
            const Text(
              'Status Menonton',
              style: AppTypography.bodyStrong,
            ),
            DropdownButtonFormField<String>(
              initialValue: _watchStatus,
              items: const [
                DropdownMenuItem(
                  value: 'completed',
                  child: Text('Selesai Ditonton'),
                ),
                DropdownMenuItem(
                  value: 'watching',
                  child: Text('Sedang Ditonton'),
                ),
                DropdownMenuItem(
                  value: 'planned',
                  child: Text('Ingin Ditonton'),
                ),
              ],
              onChanged: (v) => setState(() => _watchStatus = v ?? 'completed'),
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Rating: ${_rating?.toStringAsFixed(1) ?? '-'}',
              style: AppTypography.bodyStrong,
            ),
            Slider(
              value: _rating ?? 8.0,
              min: 1.0,
              max: 10.0,
              divisions: 18,
              label: _rating?.toStringAsFixed(1) ?? '',
              activeColor: AppColors.accent,
              onChanged: (v) => setState(() => _rating = v),
            ),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: _captionCtrl,
              decoration: InputDecoration(
                labelText: 'Caption (opsional, max 280)',
                counterText: '${_captionCtrl.text.length}/280',
                border: const OutlineInputBorder(),
              ),
              maxLength: 280,
              maxLines: 3,
            ),
            const SizedBox(height: AppSpacing.xl),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _posting ? null : _post,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: AppColors.textOnAccent,
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                ),
                child: _posting
                    ? const CircularProgressIndicator(
                        color: AppColors.textOnAccent,
                      )
                    : const Text('Posting'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  }
}
