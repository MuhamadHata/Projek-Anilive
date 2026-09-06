import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:anitrack/core/theme/app_tokens.dart';
import '../../../core/config/app_config.dart';
import '../../../core/services/supabase_service.dart';

const _giphyBase = 'https://api.giphy.com/v1/gifs';

/// Sheet untuk mengganti banner profil.
/// Dua opsi: upload dari galeri (foto/GIF) atau cari GIF dari Giphy.
class BannerPickerSheet extends ConsumerStatefulWidget {
  final String userId;
  final void Function(String bannerUrl) onBannerSelected;

  const BannerPickerSheet({
    super.key,
    required this.userId,
    required this.onBannerSelected,
  });

  @override
  ConsumerState<BannerPickerSheet> createState() => _BannerPickerSheetState();
}

class _BannerPickerSheetState extends ConsumerState<BannerPickerSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;
  final _searchCtrl = TextEditingController();

  bool _uploading = false;
  double _uploadProgress = 0;
  String? _uploadError;

  List<_GifItem> _giphyResults = [];
  bool _giphyLoading = false;
  String? _giphyError;

  final Dio _dio = Dio();

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _searchGiphy('anime'); // default trending anime GIFs
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _searchCtrl.dispose();
    _dio.close();
    super.dispose();
  }

  // ── GALERI ──────────────────────────────────────────────────────────────────

  Future<void> _pickFromGallery() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery);
    if (file == null) return;
    await _uploadFile(File(file.path));
  }

  Future<void> _pickVideoGif() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery);
    if (file == null) return;
    await _uploadFile(File(file.path));
  }

  Future<void> _uploadFile(File file) async {
    setState(() {
      _uploading = true;
      _uploadProgress = 0.3;
      _uploadError = null;
    });
    try {
      String url;
      final bytes = await file.readAsBytes();
      final ext = file.path.split('.').last.toLowerCase();

      if (SupabaseService.isInitialized && SupabaseService.client != null) {
        final fileName = 'banners/${widget.userId}_${DateTime.now().millisecondsSinceEpoch}.$ext';
        setState(() => _uploadProgress = 0.7);
        try {
          await SupabaseService.client!.storage.from('banners').uploadBinary(
            fileName,
            bytes,
          );
          url = SupabaseService.client!.storage.from('banners').getPublicUrl(fileName);
        } catch (_) {
          url = 'data:image/$ext;base64,${base64Encode(bytes)}';
        }
      } else {
        url = 'data:image/$ext;base64,${base64Encode(bytes)}';
      }
      if (mounted) {
        Navigator.pop(context);
        widget.onBannerSelected(url);
      }
    } catch (e) {
      setState(() {
        _uploading = false;
        _uploadError = 'Upload gagal: $e';
      });
    }
  }

  // ── GIPHY ───────────────────────────────────────────────────────────────────

  Future<void> _searchGiphy(String query) async {
    if (AppConfig.giphyApiKey.isEmpty) {
      setState(() {
        _giphyLoading = false;
        _giphyError = 'Giphy API key belum dikonfigurasi di .env';
      });
      return;
    }

    setState(() {
      _giphyLoading = true;
      _giphyError = null;
    });
    try {
      final endpoint = query.isEmpty ? '$_giphyBase/trending' : '$_giphyBase/search';
      final resp = await _dio.get<Map<String, dynamic>>(
        endpoint,
        queryParameters: {
          'api_key': AppConfig.giphyApiKey,
          'q': query,
          'limit': 24,
          'rating': 'pg-13',
        },
      );
      final data = resp.data?['data'] as List<dynamic>? ?? [];
      setState(() {
        _giphyResults = data
            .whereType<Map<String, dynamic>>()
            .map((item) {
              final images = item['images'] as Map<String, dynamic>?;
              final preview = images?['fixed_height_small'] as Map<String, dynamic>?;
              final original = images?['original'] as Map<String, dynamic>?;
              return _GifItem(
                previewUrl: preview?['url'] as String? ?? '',
                originalUrl: original?['url'] as String? ?? '',
                title: item['title'] as String? ?? '',
              );
            })
            .where((g) => g.previewUrl.isNotEmpty && g.originalUrl.isNotEmpty)
            .toList();
        _giphyLoading = false;
      });
    } catch (e) {
      setState(() {
        _giphyLoading = false;
        _giphyError = 'Gagal memuat Giphy: $e';
      });
    }
  }

  void _selectGiphyGif(_GifItem gif) {
    Navigator.pop(context);
    widget.onBannerSelected(gif.originalUrl);
  }

  // ── BUILD ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      bottom: true,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        ),
        child: Column(
        children: [
          // Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: AppSpacing.md),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0,
            ),
            child: Row(
              children: [
                Text('Ganti Banner', style: AppTypography.headline),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          // TabBar
          TabBar(
            controller: _tabCtrl,
            indicatorColor: AppColors.accent,
            indicatorSize: TabBarIndicatorSize.label,
            labelColor: AppColors.textPrimary,
            unselectedLabelColor: AppColors.textMuted,
            labelStyle: AppTypography.bodyStrong,
            dividerColor: AppColors.border,
            tabs: const [
              Tab(icon: Icon(Icons.photo_library_outlined), text: 'Galeri'),
              Tab(icon: Icon(Icons.gif_box_outlined), text: 'Giphy'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              children: [
                _buildGalleryTab(),
                _buildGiphyTab(),
              ],
            ),
          ),
        ],
      ),
    ),
  );
  }

  Widget _buildGalleryTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_uploading) ...[
            const SizedBox(height: AppSpacing.lg),
            Text('Mengupload...', style: AppTypography.body, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.md),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.pill),
              child: LinearProgressIndicator(
                value: _uploadProgress,
                backgroundColor: AppColors.surfaceAlt,
                valueColor: const AlwaysStoppedAnimation(AppColors.accent),
                minHeight: 8,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              '${(_uploadProgress * 100).toInt()}%',
              style: AppTypography.captionFaint,
              textAlign: TextAlign.center,
            ),
          ] else ...[
            _galleryOption(
              icon: Icons.image_outlined,
              label: 'Upload Foto',
              subtitle: 'JPEG, PNG dari galeri',
              onTap: () => _pickFromGallery(),
            ),
            const SizedBox(height: AppSpacing.md),
            _galleryOption(
              icon: Icons.gif_outlined,
              label: 'Upload GIF',
              subtitle: 'GIF animasi dari galeri',
              onTap: () => _pickVideoGif(),
            ),
            if (_uploadError != null) ...[
              const SizedBox(height: AppSpacing.md),
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.danger.withAlpha(25),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: AppColors.danger.withAlpha(80)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: AppColors.dangerBright,
                      size: AppIconSize.md,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        _uploadError!,
                        style: AppTypography.caption.copyWith(
                          color: AppColors.dangerBright,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.xl),
            // Remove banner option
            OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                // Pass empty string to reset banner to gradient
                widget.onBannerSelected('');
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.dangerBright,
                side: const BorderSide(color: AppColors.danger),
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
              ),
              icon: const Icon(Icons.delete_outline),
              label: const Text('Hapus Banner'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _galleryOption({
    required IconData icon,
    required String label,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.accent, AppColors.accentDeep],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Icon(icon, color: AppColors.textOnAccent, size: AppIconSize.lg),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: AppTypography.title),
                  Text(subtitle, style: AppTypography.captionFaint),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }

  Widget _buildGiphyTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.sm,
          ),
          child: TextField(
            controller: _searchCtrl,
            style: AppTypography.body,
            decoration: InputDecoration(
              hintText: 'Cari GIF anime...',
              hintStyle: AppTypography.bodyMuted,
              prefixIcon: const Icon(Icons.search, color: AppColors.textMuted),
              filled: true,
              fillColor: AppColors.surfaceAlt,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.pill),
                borderSide: BorderSide.none,
              ),
              suffixIcon: _searchCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: AppColors.textMuted),
                      onPressed: () {
                        _searchCtrl.clear();
                        _searchGiphy('anime');
                      },
                    )
                  : null,
            ),
            textInputAction: TextInputAction.search,
            onSubmitted: (q) => _searchGiphy(q.trim()),
            onChanged: (_) => setState(() {}),
          ),
        ),
        Expanded(
          child: _giphyLoading
              ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
              : _giphyError != null
                  ? Center(
                      child: Text(
                        _giphyError!,
                        style: AppTypography.body.copyWith(color: AppColors.dangerBright),
                        textAlign: TextAlign.center,
                      ),
                    )
                  : _giphyResults.isEmpty
                      ? Center(
                          child: Text(
                            'Tidak ada hasil',
                            style: AppTypography.bodyMuted,
                          ),
                        )
                      : GridView.builder(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.lg,
                            vertical: AppSpacing.sm,
                          ),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: AppSpacing.sm,
                            mainAxisSpacing: AppSpacing.sm,
                            childAspectRatio: 16 / 9,
                          ),
                          itemCount: _giphyResults.length,
                          itemBuilder: (_, i) {
                            final gif = _giphyResults[i];
                            return GestureDetector(
                              onTap: () => _selectGiphyGif(gif),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(AppRadius.md),
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    CachedNetworkImage(
                                      imageUrl: gif.previewUrl,
                                      fit: BoxFit.cover,
                                      placeholder: (_, p1) => Container(
                                        color: AppColors.surfaceAlt,
                                      ),
                                      errorWidget: (_, p1, p2) => Container(
                                        color: AppColors.surfaceAlt,
                                        child: const Icon(
                                          Icons.broken_image_outlined,
                                          color: AppColors.textMuted,
                                        ),
                                      ),
                                    ),
                                    // GIF badge
                                    Positioned(
                                      top: 4,
                                      left: 4,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 5,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.surface.withAlpha(200),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          'GIF',
                                          style: AppTypography.micro.copyWith(
                                            color: AppColors.accent,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
        ),
        // Powered by Giphy attribution (required by Giphy ToS)
        Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Powered by ',
                style: AppTypography.micro.copyWith(color: AppColors.textMuted),
              ),
              Text(
                'GIPHY',
                style: AppTypography.micro.copyWith(
                  color: AppColors.accent,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _GifItem {
  final String previewUrl;
  final String originalUrl;
  final String title;

  const _GifItem({
    required this.previewUrl,
    required this.originalUrl,
    required this.title,
  });
}
