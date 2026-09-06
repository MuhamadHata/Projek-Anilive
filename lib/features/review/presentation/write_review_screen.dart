import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/presentation/auth_provider.dart';
import '../data/review_repository_impl.dart';
import '../domain/review.dart';
import 'package:anitrack/core/theme/app_tokens.dart';

final reviewRepositoryProvider = Provider<ReviewRepository>((ref) {
  return ReviewRepositoryImpl();
});

final animeReviewsProvider = StreamProvider.autoDispose
    .family<List<Review>, int>((ref, animeId) {
      return ref.watch(reviewRepositoryProvider).getReviewsForAnime(animeId);
    });

/// Enri bookmark/review milik user yang sedang login untuk satu anime.
final myAnimeEntryProvider =
    StreamProvider.autoDispose.family<Review?, int>((ref, animeId) {
      final user = ref.watch(authNotifierProvider).value ??
          ref.read(authRepositoryProvider).currentUser;
      if (user == null) return Stream.value(null);
      return ref
          .watch(reviewRepositoryProvider)
          .watchUserEntry(animeId, user.id);
    });

/// Daftar anime tersimpan milik satu user (halaman profil).
final userAnimeListProvider =
    StreamProvider.autoDispose.family<List<UserAnimeEntry>, String>(
        (ref, userId) {
  return ref.watch(reviewRepositoryProvider).watchUserList(userId);
});

class WriteReviewScreen extends ConsumerStatefulWidget {
  final int animeId;
  final String animeTitle;
  final String? animeImageUrl;
  final int? totalEpisodes;
  final bool isCompleted;
  final Review? existing;

  const WriteReviewScreen({
    super.key,
    required this.animeId,
    required this.animeTitle,
    this.animeImageUrl,
    this.totalEpisodes,
    this.isCompleted = false,
    this.existing,
  });

  @override
  ConsumerState<WriteReviewScreen> createState() => _WriteReviewScreenState();
}

class _WriteReviewScreenState extends ConsumerState<WriteReviewScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _contentCtrl = TextEditingController();

  int _watchedEpisodes = 0;
  String _status = WatchStatus.watching;
  double _story = 8.0;
  double _animation = 8.0;
  double _sound = 8.0;
  double _character = 8.0;
  double _enjoyment = 8.0;
  bool _isRecommended = true;
  bool _hasSpoiler = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      _titleCtrl.text = existing.title;
      _contentCtrl.text = existing.content;
      _watchedEpisodes = existing.watchedEpisodes ?? 0;
      _status = existing.watchStatus ?? WatchStatus.watching;
      _story = existing.ratings.story;
      _animation = existing.ratings.animation;
      _sound = existing.ratings.sound;
      _character = existing.ratings.character;
      _enjoyment = existing.ratings.enjoyment;
      _isRecommended = existing.isRecommended;
      _hasSpoiler = existing.hasSpoiler;
    } else {
      _watchedEpisodes = _status == WatchStatus.planToWatch ||
              _status == WatchStatus.notInterested
          ? 0
          : (widget.totalEpisodes ?? 1);
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  bool get _isEditing => widget.existing != null;

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final user =
        ref.read(authNotifierProvider).value ??
        ref.read(authRepositoryProvider).currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Silakan login terlebih dahulu untuk menulis review'),
        ),
      );
      return;
    }

    setState(() => _submitting = true);

    final ratings = ReviewRating(
      story: _story,
      animation: _animation,
      sound: _sound,
      character: _character,
      enjoyment: _enjoyment,
    );

    final hasContent =
        _titleCtrl.text.trim().isNotEmpty || _contentCtrl.text.trim().isNotEmpty;
    // Entri tanpa teks = bookmark status saja.
    final overallScore =
        hasContent ? ratings.overall : (_story + _enjoyment) / 2.0;

    final isCompletedAnime =
        widget.totalEpisodes != null &&
        _watchedEpisodes >= widget.totalEpisodes!;

    final review = Review(
      id: _isEditing
          ? widget.existing!.id
          : 'rev_${DateTime.now().millisecondsSinceEpoch}',
      animeId: widget.animeId,
      userId: user.id,
      username: user.username,
      avatarUrl: user.avatarUrl,
      animeTitle: widget.animeTitle,
      animeImageUrl: widget.animeImageUrl,
      watchedEpisodes: _watchedEpisodes,
      totalEpisodes: widget.totalEpisodes,
      isCompleted:
          _status == WatchStatus.completed || isCompletedAnime,
      watchStatus: _status,
      ratings: ratings,
      overallScore: overallScore,
      title: _titleCtrl.text.trim(),
      content: _contentCtrl.text.trim(),
      isRecommended: _isRecommended,
      hasSpoiler: _hasSpoiler,
      createdAt:
          _isEditing ? widget.existing!.createdAt : DateTime.now(),
    );

    try {
      await ref.read(reviewRepositoryProvider).submitReview(review);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isEditing
                  ? 'Perubahan berhasil disimpan!'
                  : 'Berhasil disimpan ke daftarmu!',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final msg = e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menyimpan: $msg')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final overall =
        (_story + _animation + _sound + _character + _enjoyment) / 5.0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          '${_isEditing ? "Edit" : "Tambah"} — ${widget.animeTitle}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        top: false,
        bottom: true,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                color: AppColors.surfaceDialog,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Status Tontonan',
                        style: AppTypography.title,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Berfungsi sebagai bookmark — bisa diubah kapan saja.',
                        style: AppTypography.captionFaint.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      DropdownButtonFormField<String>(
                        initialValue: _status,
                        decoration: InputDecoration(
                          labelText: 'Status',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                          ),
                          filled: true,
                          fillColor: AppColors.surface,
                        ),
                        items: WatchStatus.all
                            .map(
                              (s) => DropdownMenuItem<String>(
                                value: s,
                                child: Row(
                                  children: [
                                    Icon(_statusIcon(s), size: 17),
                                    const SizedBox(width: AppSpacing.sm),
                                    Text(WatchStatus.label(s)),
                                  ],
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (v) {
                          if (v == null) return;
                          setState(() {
                            _status = v;
                            if (v == WatchStatus.completed &&
                                widget.totalEpisodes != null) {
                              _watchedEpisodes = widget.totalEpisodes!;
                            }
                            if (v == WatchStatus.planToWatch ||
                                v == WatchStatus.notInterested) {
                              _watchedEpisodes = 0;
                            }
                          });
                        },
                      ),
                      const Divider(height: AppSpacing.xl),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Progress Menonton',
                            style: AppTypography.titleSmall,
                          ),
                          Text(
                            _watchedEpisodes == 0
                                ? 'Belum Nonton'
                                : 'Episode $_watchedEpisodes ${widget.totalEpisodes != null ? "dari ${widget.totalEpisodes}" : "(Ongoing)"}',
                            style: AppTypography.caption.copyWith(
                              color: AppColors.accentSoft,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),

                      // Tombol Dropdown / Pencarian Episode
                      InkWell(
                        onTap: () => _openEpisodePickerSheet(context),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                            vertical: AppSpacing.md,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.video_library_outlined,
                                size: AppIconSize.md,
                                color: AppColors.accent,
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Text(
                                  _watchedEpisodes == 0
                                      ? 'Pilih Episode (Belum Mulai)'
                                      : 'Episode $_watchedEpisodes',
                                  style: AppTypography.titleSmall,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.sm,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceAlt,
                                  borderRadius:
                                      BorderRadius.circular(AppRadius.sm),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.search,
                                      size: 13,
                                      color: AppColors.textMuted,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Cari & Pilih ▾',
                                      style: AppTypography.captionFaint,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),

                      // Quick Step Buttons (-1, +1, +5, +10, Tamat)
                      Row(
                        children: [
                          _quickStepChip('-1', () {
                            setState(() {
                              _watchedEpisodes =
                                  (_watchedEpisodes - 1).clamp(0, _maxEpisodes);
                            });
                          }),
                          const SizedBox(width: AppSpacing.xs),
                          _quickStepChip('+1', () {
                            setState(() {
                              _watchedEpisodes =
                                  (_watchedEpisodes + 1).clamp(0, _maxEpisodes);
                            });
                          }),
                          const SizedBox(width: AppSpacing.xs),
                          _quickStepChip('+5', () {
                            setState(() {
                              _watchedEpisodes =
                                  (_watchedEpisodes + 5).clamp(0, _maxEpisodes);
                            });
                          }),
                          const SizedBox(width: AppSpacing.xs),
                          _quickStepChip('+10', () {
                            setState(() {
                              _watchedEpisodes =
                                  (_watchedEpisodes + 10).clamp(0, _maxEpisodes);
                            });
                          }),
                          const Spacer(),
                          if (widget.totalEpisodes != null)
                            TextButton.icon(
                              onPressed: () => setState(() {
                                _watchedEpisodes = widget.totalEpisodes!;
                                _status = WatchStatus.completed;
                              }),
                              icon: const Icon(Icons.done_all, size: 16),
                              label: const Text('Tamat'),
                            ),
                        ],
                      ),
                      const Divider(height: AppSpacing.xl),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Skor Keseluruhan',
                            style: AppTypography.bodyStrong,
                          ),
                          Text(
                            '★ ${overall.toStringAsFixed(1)} / 10',
                            style: AppTypography.headline.copyWith(
                              color: AppColors.star,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      _ratingSlider(
                        'Story (Cerita)',
                        _story,
                        (v) => setState(() => _story = v),
                      ),
                      _ratingSlider(
                        'Animation (Visual)',
                        _animation,
                        (v) => setState(() => _animation = v),
                      ),
                      _ratingSlider(
                        'Sound (OST & Voice)',
                        _sound,
                        (v) => setState(() => _sound = v),
                      ),
                      _ratingSlider(
                        'Character (Karakter)',
                        _character,
                        (v) => setState(() => _character = v),
                      ),
                      _ratingSlider(
                        'Enjoyment (Kesenangan)',
                        _enjoyment,
                        (v) => setState(() => _enjoyment = v),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              TextFormField(
                controller: _titleCtrl,
                decoration: const InputDecoration(
                  labelText: 'Judul Review (opsional)',
                  hintText: 'Bebas — boleh dikosongkan',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              TextFormField(
                controller: _contentCtrl,
                maxLines: null,
                minLines: 6,
                keyboardType: TextInputType.multiline,
                maxLength: null,
                decoration: const InputDecoration(
                  labelText: 'Isi Review (opsional)',
                  hintText:
                      'Tulis sepanjang yang kamu mau — 1 kalimat atau ribuan kata',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              SwitchListTile(
                title: const Text('Rekomendasikan anime ini?'),
                value: _isRecommended,
                activeTrackColor: AppColors.success,
                onChanged: (v) => setState(() => _isRecommended = v),
              ),
              SwitchListTile(
                title: const Text('Mengandung Spoiler?'),
                subtitle: const Text(
                  'Teks akan diblur otomatis untuk pengguna lain',
                ),
                value: _hasSpoiler,
                activeTrackColor: AppColors.dangerBright,
                onChanged: (v) => setState(() => _hasSpoiler = v),
              ),
              const SizedBox(height: AppSpacing.xl),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: AppColors.textOnAccent,
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.lg,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                  ),
                  child: _submitting
                      ? const CircularProgressIndicator(
                          color: AppColors.textOnAccent,
                        )
                      : Text(_isEditing ? 'Simpan Perubahan' : 'Simpan'),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  }

  int get _maxEpisodes {
    if (widget.totalEpisodes != null && widget.totalEpisodes! > 0) {
      return widget.totalEpisodes!;
    }
    final title = widget.animeTitle.toLowerCase();
    if (title.contains('one piece')) return 1130;
    if (title.contains('conan')) return 1160;
    if (title.contains('boruto')) return 293;
    if (title.contains('naruto')) return 500;
    if (title.contains('bleach')) return 366;
    if (title.contains('dragon ball')) return 291;
    if (title.contains('gintama')) return 367;
    return 300;
  }

  Widget _quickStepChip(String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm + 2,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: AppColors.border),
        ),
        child: Text(
          label,
          style: AppTypography.caption.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  void _openEpisodePickerSheet(BuildContext context) {
    final max = _maxEpisodes;
    final searchCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          final query = searchCtrl.text.trim();
          final parsedNum = int.tryParse(query);

          // Buat list episode yang relevan
          final List<int> episodes;
          if (query.isEmpty) {
            episodes = List<int>.generate(max, (i) => i + 1);
          } else {
            episodes = List<int>.generate(max, (i) => i + 1)
                .where((ep) => ep.toString().contains(query))
                .toList();
          }

          return SafeArea(
            top: false,
            bottom: true,
            child: Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
              height: MediaQuery.of(context).size.height * 0.75,
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                AppSpacing.lg,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle
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
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Pilih Episode',
                        style: AppTypography.headline,
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),

                  // Search Field
                  TextField(
                    controller: searchCtrl,
                    keyboardType: TextInputType.number,
                    autofocus: false,
                    style: AppTypography.body,
                    decoration: InputDecoration(
                      hintText: 'Ketik nomor episode (contoh: 1071)...',
                      hintStyle: AppTypography.bodyMuted,
                      prefixIcon: const Icon(Icons.search, color: AppColors.textMuted),
                      filled: true,
                      fillColor: AppColors.surfaceAlt,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        borderSide: BorderSide.none,
                      ),
                      suffixIcon: query.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 16),
                              onPressed: () {
                                searchCtrl.clear();
                                setSheetState(() {});
                              },
                            )
                          : null,
                    ),
                    onChanged: (_) => setSheetState(() {}),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Tombol input langsung jika user ketik nomor di luar range standar
                  if (parsedNum != null && parsedNum > 0) ...[
                    InkWell(
                      onTap: () {
                        setState(() => _watchedEpisodes = parsedNum);
                        Navigator.pop(sheetContext);
                      },
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      child: Container(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withAlpha(30),
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          border: Border.all(color: AppColors.accent),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.play_arrow,
                              color: AppColors.accent,
                              size: AppIconSize.md,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text(
                                'Pilih Episode $parsedNum Langsung',
                                style: AppTypography.bodyStrong.copyWith(
                                  color: AppColors.accentSoft,
                                ),
                              ),
                            ),
                            const Icon(
                              Icons.check_circle,
                              color: AppColors.accent,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],

                  // Tombol Reset / Belum Nonton
                  Row(
                    children: [
                      ActionChip(
                        label: const Text('Episode 0 (Belum Mulai)'),
                        backgroundColor: _watchedEpisodes == 0
                            ? AppColors.accent
                            : AppColors.surfaceAlt,
                        labelStyle: AppTypography.caption.copyWith(
                          color: _watchedEpisodes == 0
                              ? AppColors.textOnAccent
                              : AppColors.textMuted,
                        ),
                        onPressed: () {
                          setState(() => _watchedEpisodes = 0);
                          Navigator.pop(sheetContext);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),

                  // Grid / List Episode
                  Expanded(
                    child: episodes.isEmpty
                        ? Center(
                            child: Text(
                              'Episode tidak ditemukan',
                              style: AppTypography.bodyMuted,
                            ),
                          )
                        : GridView.builder(
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 5,
                              crossAxisSpacing: AppSpacing.sm,
                              mainAxisSpacing: AppSpacing.sm,
                              childAspectRatio: 1.3,
                            ),
                            itemCount: episodes.length,
                            itemBuilder: (context, idx) {
                              final ep = episodes[idx];
                              final isSelected = ep == _watchedEpisodes;

                              return InkWell(
                                onTap: () {
                                  setState(() => _watchedEpisodes = ep);
                                  Navigator.pop(sheetContext);
                                },
                                borderRadius:
                                    BorderRadius.circular(AppRadius.sm),
                                child: Container(
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? AppColors.accent
                                        : AppColors.surfaceAlt,
                                    borderRadius:
                                        BorderRadius.circular(AppRadius.sm),
                                    border: Border.all(
                                      color: isSelected
                                          ? AppColors.accent
                                          : AppColors.border,
                                    ),
                                  ),
                                  child: Text(
                                    'Ep $ep',
                                    style: AppTypography.caption.copyWith(
                                      color: isSelected
                                          ? AppColors.textOnAccent
                                          : AppColors.textPrimary,
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        );
        },
      ),
    );
  }

  IconData _statusIcon(String status) => switch (status) {
        WatchStatus.watching => Icons.play_circle_outline,
        WatchStatus.completed => Icons.check_circle_outline,
        WatchStatus.onHold => Icons.pause_circle_outline,
        WatchStatus.dropped => Icons.remove_circle_outline,
        WatchStatus.planToWatch => Icons.bookmark_border,
        WatchStatus.notInterested => Icons.block_outlined,
        _ => Icons.bookmark_border,
      };

  Widget _ratingSlider(
    String label,
    double val,
    ValueChanged<double> onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: AppTypography.bodyMuted,
            ),
            Text(
              '${val.toStringAsFixed(1)} / 10',
              style: AppTypography.bodyStrong,
            ),
          ],
        ),
        Slider(
          value: val,
          min: 1.0,
          max: 10.0,
          divisions: 18,
          activeColor: AppColors.accent,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

