import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'anime_providers.dart';
import '../data/anime_offline_db.dart';
import '../data/anime_repository_impl.dart';
import '../data/jikan_api.dart';
import '../domain/anime.dart';
import '../domain/anime_arcs.dart';
import '../../auth/presentation/auth_provider.dart';
import '../../review/domain/review.dart';
import '../../review/presentation/write_review_screen.dart';
import '../../chat/presentation/live_chat_screen.dart';
import '../../comment/presentation/comments_screen.dart';
import 'package:anitrack/core/theme/app_tokens.dart';

/// 3215701 -> "3.2 jt", 84018 -> "84 rb"
String _compactNum(int n) {
  if (n >= 1000000000) return '${(n / 1e9).toStringAsFixed(1)} M';
  if (n >= 1000000) return '${(n / 1e6).toStringAsFixed(1)} jt';
  if (n >= 1000) return '${(n / 1e3).toStringAsFixed(0)} rb';
  return '$n';
}

class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({super.key});

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen> {
  final _searchCtrl = TextEditingController();
  Timer? _searchDebounceTimer;
  String _debouncedQuery = '';
  bool _searching = false;

  List<int> _genreIds = [];
  String? _status;
  String? _orderBy;

  static const Map<int, String> _availableGenres = {
    1: 'Action',
    2: 'Adventure',
    4: 'Comedy',
    8: 'Drama',
    10: 'Fantasy',
    22: 'Romance',
    24: 'Sci-Fi',
    36: 'Slice of Life',
    37: 'Supernatural',
  };

  static const Map<String, String> _statusOptions = {
    'airing': 'Sedang Tayang',
    'complete': 'Selesai',
    'upcoming': 'Akan Datang',
  };

  static const Map<String, String> _sortOptions = {
    'start_date': 'Terbaru',
    'score': 'Skor Tertinggi',
    'popularity': 'Terpopuler',
  };

  int get _activeFilterCount {
    var c = 0;
    if (_genreIds.isNotEmpty) c++;
    if (_status != null) c++;
    if (_orderBy != null) c++;
    return c;
  }

  bool get _hasActiveFilters =>
      _debouncedQuery.length >= 2 ||
      _genreIds.isNotEmpty ||
      _status != null ||
      _orderBy != null;

  void _openFilterSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      isScrollControlled: true,
      builder: (sheetContext) {
        final tempGenres = List<int>.from(_genreIds);
        var tempStatus = _status;
        var tempOrderBy = _orderBy;
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xxl),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Filter Pencarian',
                          style: AppTypography.headline,
                        ),
                        TextButton(
                          onPressed: () {
                            setSheetState(() {
                              tempGenres.clear();
                              tempStatus = null;
                              tempOrderBy = null;
                            });
                          },
                          child: const Text('Reset'),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Genre',
                      style: AppTypography.titleSmall,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: _availableGenres.entries.map((entry) {
                        final selected = tempGenres.contains(entry.key);
                        return FilterChip(
                          label: Text(entry.value),
                          selected: selected,
                          onSelected: (v) {
                            setSheetState(() {
                              if (v) {
                                tempGenres.add(entry.key);
                              } else {
                                tempGenres.remove(entry.key);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    DropdownButtonFormField<String>(
                      initialValue: tempStatus,
                      decoration: const InputDecoration(labelText: 'Status'),
                      items: [
                        const DropdownMenuItem<String>(
                          value: null,
                          child: Text('Semua Status'),
                        ),
                        ..._statusOptions.entries.map(
                          (e) => DropdownMenuItem<String>(
                            value: e.key,
                            child: Text(e.value),
                          ),
                        ),
                      ],
                      onChanged: (v) => setSheetState(() => tempStatus = v),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    DropdownButtonFormField<String>(
                      initialValue: tempOrderBy,
                      decoration: const InputDecoration(labelText: 'Urutkan'),
                      items: [
                        const DropdownMenuItem<String>(
                          value: null,
                          child: Text('Relevansi'),
                        ),
                        ..._sortOptions.entries.map(
                          (e) => DropdownMenuItem<String>(
                            value: e.key,
                            child: Text(e.value),
                          ),
                        ),
                      ],
                      onChanged: (v) => setSheetState(() => tempOrderBy = v),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          foregroundColor: AppColors.textOnAccent,
                          padding: const EdgeInsets.symmetric(
                            vertical: AppSpacing.md + 2,
                          ),
                        ),
                        onPressed: () {
                          setState(() {
                            _genreIds = tempGenres;
                            _status = tempStatus;
                            _orderBy = tempOrderBy;
                          });
                          Navigator.pop(sheetContext);
                        },
                        child: const Text('Terapkan'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _searchDebounceTimer?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: _searching
            ? TextField(
                controller: _searchCtrl,
                autofocus: true,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Cari anime...',
                  hintStyle: const TextStyle(color: AppColors.textMuted),
                  border: InputBorder.none,
                  suffixIcon: _searchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18, color: AppColors.textMuted),
                          onPressed: () {
                            _searchDebounceTimer?.cancel();
                            _searchCtrl.clear();
                            setState(() => _debouncedQuery = '');
                          },
                        )
                      : null,
                ),
                onChanged: (val) {
                  _searchDebounceTimer?.cancel();
                  _searchDebounceTimer = Timer(const Duration(milliseconds: 300), () {
                    if (mounted) {
                      setState(() {
                        _debouncedQuery = val.trim();
                      });
                    }
                  });
                },
                onSubmitted: (val) {
                  _searchDebounceTimer?.cancel();
                  setState(() => _debouncedQuery = val.trim());
                },
              )
            : const Text('Jelajahi Anime'),
        actions: [
          IconButton(
            onPressed: _openFilterSheet,
            icon: _activeFilterCount > 0
                ? Badge(
                    label: Text('$_activeFilterCount'),
                    child: const Icon(Icons.filter_list),
                  )
                : const Icon(Icons.filter_list),
          ),
          IconButton(
            onPressed: () {
              setState(() {
                _searching = !_searching;
                _searchDebounceTimer?.cancel();
                if (!_searching) {
                  _searchCtrl.clear();
                  _debouncedQuery = '';
                  _genreIds.clear();
                  _status = null;
                  _orderBy = null;
                }
              });
            },
            icon: Icon(_searching ? Icons.close : Icons.search),
          ),
        ],
      ),
      body: _hasActiveFilters
          ? _buildSearchResults(_debouncedQuery)
          : _buildCategories(),
    );
  }

  Widget _buildCategories() {
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(currentSeasonProvider);
        ref.invalidate(trendingProvider);
        ref.invalidate(upcomingSeasonProvider);
        ref.invalidate(topRatedProvider(1));
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle('Sedang Tayang (Musim Ini)'),
            const SizedBox(height: AppSpacing.sm),
            _animeHorizontalList(currentSeasonProvider),
            const SizedBox(height: AppSpacing.xl),
            _sectionTitle('Rekomendasi Terpopuler'),
            const SizedBox(height: AppSpacing.sm),
            _animeHorizontalList(trendingProvider),
            const SizedBox(height: AppSpacing.xl),
            _sectionTitle('Peringkat Teratas (Top Rated)'),
            const SizedBox(height: AppSpacing.sm),
            _animeHorizontalList(topRatedProvider(1)),
            const SizedBox(height: AppSpacing.xl),
            _sectionTitle('Segera Tayang (Upcoming)'),
            const SizedBox(height: AppSpacing.sm),
            _animeHorizontalList(upcomingSeasonProvider),
            const SizedBox(height: AppSpacing.xl),
            _sectionTitle('Film & Movie Terbaik'),
            const SizedBox(height: AppSpacing.sm),
            _animeHorizontalList(topMoviesProvider),
            const SizedBox(height: AppSpacing.xl),
            _sectionTitle('Action Terbaik'),
            const SizedBox(height: AppSpacing.sm),
            _animeHorizontalList(genreAnimeProvider('Action')),
            const SizedBox(height: AppSpacing.xl),
            _sectionTitle('Romance Terbaik'),
            const SizedBox(height: AppSpacing.sm),
            _animeHorizontalList(genreAnimeProvider('Romance')),
            const SizedBox(height: AppSpacing.xl),
            _sectionTitle('Fantasy Terbaik'),
            const SizedBox(height: AppSpacing.sm),
            _animeHorizontalList(genreAnimeProvider('Fantasy')),
            const SizedBox(height: AppSpacing.xl),
            _sectionTitle('Comedy Terbaik'),
            const SizedBox(height: AppSpacing.sm),
            _animeHorizontalList(genreAnimeProvider('Comedy')),
            const SizedBox(height: AppSpacing.xl),
            _sectionTitle('Drama Terbaik'),
            const SizedBox(height: AppSpacing.sm),
            _animeHorizontalList(genreAnimeProvider('Drama')),
            const SizedBox(height: AppSpacing.xl),
            _sectionTitle('Sci-Fi Terbaik'),
            const SizedBox(height: AppSpacing.sm),
            _animeHorizontalList(genreAnimeProvider('Sci-Fi')),
            const SizedBox(height: AppSpacing.xxl),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) => Text(
    title,
    style: Theme.of(
      context,
    ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
  );

  Widget _animeHorizontalList(AutoDisposeFutureProvider<List<Anime>> provider) {
    final async = ref.watch(provider);
    return async.when(
      data: (items) => SizedBox(
        height: 260,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.md),
          itemBuilder: (_, i) => _AnimeCard(anime: items[i]),
        ),
      ),
      loading: () => SizedBox(
        height: 260,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: 5,
          separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.md),
          itemBuilder: (_, _) => Container(
            width: AppLayout.posterW,
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
          ),
        ),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Text(
          'Gagal memuat: $e',
          style: const TextStyle(color: AppColors.dangerBright),
        ),
      ),
    );
  }

  Widget _buildSearchResults(String query) {
    final currentUser =
        ref.watch(authNotifierProvider).value ??
        ref.read(authRepositoryProvider).currentUser;
    final allowAdult = currentUser?.isAdult ?? false;

    final args = AnimeFilterArgs(
      query: query,
      genres: _genreIds.isEmpty ? null : _genreIds,
      status: _status,
      orderBy: _orderBy,
      allowAdult: allowAdult,
    );
    final async = ref.watch(searchAnimeProvider(args));
    return Column(
      children: [
        // Banner peringatan usia jika query mengandung kata adult tapi user belum terverifikasi
        if (!allowAdult && _isAdultQuery(query))
          Container(
            margin: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.sm,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: AppColors.warning.withAlpha(30),
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.warning.withAlpha(80)),
            ),
            child: Row(
              children: [
                const Icon(Icons.lock_outline, color: AppColors.warning, size: AppIconSize.md),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Konten 20+ hanya untuk pengguna yang sudah memverifikasi usia. Lengkapi biodata di Profil.',
                    style: AppTypography.caption.copyWith(color: AppColors.warning),
                  ),
                ),
              ],
            ),
          ),
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.xs),
            children: [
              _statusChip(null, 'Semua'),
              ..._statusOptions.entries.map(
                (e) => _statusChip(e.key, e.value),
              ),
            ],
          ),
        ),
        if (query.split(RegExp(r'\s+')).length >= 2)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.xs,
            ),
            child: Row(
              children: [
                const Icon(Icons.auto_awesome, size: 14, color: AppColors.accent),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  'Pencarian Cerdas RAG Aktif (Pencocokan Deskripsi & Alur Cerita)',
                  style: AppTypography.micro.copyWith(color: AppColors.accent),
                ),
              ],
            ),
          ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async => ref.refresh(searchAnimeProvider(args)),
            child: async.when(
              data: (items) => items.isEmpty
                  ? SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: Container(
                        height: MediaQuery.of(context).size.height * 0.5,
                        alignment: Alignment.center,
                        child: const Text('Anime tidak ditemukan'),
                      ),
                    )
                  : ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
                      itemBuilder: (_, i) => _AnimeSearchListItem(anime: items[i]),
                    ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Container(
                  height: MediaQuery.of(context).size.height * 0.5,
                  alignment: Alignment.center,
                  child: Text('Error: $e'),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  static const Set<String> _adultKeywords = {
    'hentai', 'ecchi', 'yosuga', 'overflow', 'erotica', 'h anime', 'adult anime', 'porn'
  };

  bool _isAdultQuery(String q) {
    final lower = q.toLowerCase();
    return _adultKeywords.any((kw) => lower.contains(kw));
  }


  Widget _statusChip(String? value, String label) {
    final selected = _status == value;
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.sm),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        selectedColor: AppColors.accent,
        labelStyle: TextStyle(
            color: selected ? AppColors.textOnAccent : AppColors.textMuted),
        backgroundColor: AppColors.surfaceAlt,
        onSelected: (_) => setState(() => _status = value),
      ),
    );
  }
}

class _AnimeSearchListItem extends StatelessWidget {
  final Anime anime;

  const _AnimeSearchListItem({required this.anime});

  @override
  Widget build(BuildContext context) {
    final fmt = (anime.format ?? '').toUpperCase();
    final typeText = fmt.isNotEmpty
        ? (fmt == 'MOVIE' ? 'Movie' : fmt == 'TV' ? 'TV' : fmt)
        : (anime.source ?? 'Anime');
    final yearText = anime.year != null ? ' • ${anime.year}' : '';

    return Card(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => AnimeDetailScreen(
                animeId: anime.id,
                title: anime.title,
                initialAnime: anime,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                child: SizedBox(
                  width: AppLayout.thumbW,
                  height: AppLayout.thumbH,
                  child: anime.imageUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: anime.imageUrl,
                          fit: BoxFit.cover,
                          placeholder: (_, _) =>
                              Container(color: AppColors.surfaceDialog),
                          errorWidget: (_, _, _) => Container(
                            color: AppColors.surfaceDialog,
                            child: const Icon(Icons.movie, color: AppColors.textMuted),
                          ),
                        )
                      : Container(
                          color: AppColors.surfaceDialog,
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
                      anime.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.title,
                    ),
                    if (anime.titleEnglish != null &&
                        anime.titleEnglish!.isNotEmpty &&
                        anime.titleEnglish!.toLowerCase() != anime.title.toLowerCase()) ...[
                      const SizedBox(height: 2),
                      Text(
                        anime.titleEnglish!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.captionFaint.copyWith(
                          color: AppColors.accentSoft,
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      '$typeText$yearText',
                      style: AppTypography.caption,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        if (anime.score != null) ...[
                          const Icon(Icons.star, size: 15, color: AppColors.star),
                          const SizedBox(width: AppSpacing.xs),
                          Text(
                            anime.score!.toStringAsFixed(1),
                            style: AppTypography.bodyStrong,
                          ),
                          const SizedBox(width: AppSpacing.md),
                        ],
                        if (anime.episodes != null) ...[
                          const Icon(Icons.movie_outlined, size: 14, color: AppColors.textMuted),
                          const SizedBox(width: AppSpacing.xs),
                          Text(
                            '${anime.episodes} ep',
                            style: AppTypography.caption,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(AppSpacing.xs),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: const Icon(Icons.add, size: 18, color: AppColors.textPrimary),
                ),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => WriteReviewScreen(
                        animeId: anime.id,
                        animeTitle: anime.title,
                        animeImageUrl: anime.imageUrl,
                        totalEpisodes: anime.episodes,
                        isCompleted: anime.status == 'Finished Airing',
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnimeCard extends StatelessWidget {
  final Anime anime;

  const _AnimeCard({required this.anime});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => AnimeDetailScreen(
              animeId: anime.id,
              title: anime.title,
              initialAnime: anime,
            ),
          ),
        );
      },
      child: SizedBox(
        width: AppLayout.posterW,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: SizedBox(
                height: AppLayout.posterH,
                width: AppLayout.posterW,
                child: anime.imageUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: anime.imageUrl,
                        fit: BoxFit.cover,
                        placeholder: (_, _) =>
                            Container(color: AppColors.surfaceDialog),
                        errorWidget: (_, _, _) => Container(
                          color: AppColors.surfaceDialog,
                          child: const Center(
                            child: Icon(Icons.movie, color: AppColors.textMuted),
                          ),
                        ),
                      )
                    : Container(
                        color: AppColors.surfaceDialog,
                        child: const Center(
                          child: Icon(Icons.movie, color: AppColors.textMuted),
                        ),
                      ),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              anime.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.caption.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            if (anime.score != null)
              Row(
                children: [
                  const Icon(Icons.star, size: 14, color: AppColors.star),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    anime.score!.toStringAsFixed(1),
                    style: AppTypography.captionFaint
                        .copyWith(color: AppColors.textMuted),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class AnimeDetailScreen extends ConsumerWidget {
  final int animeId;
  final String title;
  final Anime? initialAnime;

  const AnimeDetailScreen({
    super.key,
    required this.animeId,
    required this.title,
    this.initialAnime,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (initialAnime != null) {
      AnimeRepositoryImpl.cacheDetail(initialAnime!);
    }
    final async = ref.watch(animeDetailProvider(animeId));
    final anime = async.value ?? initialAnime ?? AnimeOfflineDb.getByIdSync(animeId);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(title, style: AppTypography.title),
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        top: false,
        bottom: true,
        child: anime != null
            ? SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
              // 1. Compact Header (Poster + Key Metadata)
              _AnimeDetailHeader(anime: anime),
              const SizedBox(height: AppSpacing.lg),

              // 2. High-impact Stat Grid (Rating, Episodes, Favorites, Rank)
              _AnimeStatHighlights(anime: anime),
              const SizedBox(height: AppSpacing.md),

              // 3. Expandable Secondary Metadata ("Selengkapnya" / "Tutup")
              _AnimeExpandableInfoCard(anime: anime),
              const SizedBox(height: AppSpacing.lg),

              // 4. Consistent Trailer Action Button
              _AnimeTrailerButton(anime: anime),
              const SizedBox(height: AppSpacing.md),

              // 5. Main Action Buttons (Review & Chat)
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => WriteReviewScreen(
                              animeId: anime.id,
                              animeTitle: anime.title,
                              animeImageUrl: anime.imageUrl,
                              totalEpisodes: anime.episodes,
                              isCompleted: anime.status == 'Finished Airing' || anime.status == 'FINISHED',
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.rate_review_outlined),
                      label: const Text('Tulis Review'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: AppColors.textOnAccent,
                        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => LiveChatScreen(
                              animeId: anime.id,
                              animeTitle: anime.title,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.chat_bubble_outline),
                      label: const Text('Live Chat'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => CommentsScreen(
                          animeId: anime.id,
                          animeTitle: anime.title,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.forum_outlined),
                  label: const Text('Diskusi / Komentar Realtime'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // 6. User Watchlist / Status Tracker
              _MyListSection(anime: anime),
              const SizedBox(height: AppSpacing.xl),

              // 7. Synopsis with Expandable Toggle
              _SynopsisSection(synopsis: anime.synopsis),
              const SizedBox(height: AppSpacing.xl),

              // 8. Episodes List Section
              _EpisodeSection(anime: anime),

              // 9. Opening & Ending Theme Songs
              if (anime.openingThemes.isNotEmpty || anime.endingThemes.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    childrenPadding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    title: Text(
                      'Lagu Opening & Ending',
                      style: AppTypography.title,
                    ),
                    subtitle: Text(
                      '${anime.openingThemes.length} OP • ${anime.endingThemes.length} ED',
                      style: AppTypography.captionFaint.copyWith(color: AppColors.textMuted),
                    ),
                    children: [
                      ...anime.openingThemes.map(
                        (t) => ListTile(
                          dense: true,
                          leading: Text(
                            'OP',
                            style: AppTypography.titleSmall.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.accent,
                            ),
                          ),
                          title: Text(t, style: AppTypography.body),
                        ),
                      ),
                      ...anime.endingThemes.map(
                        (t) => ListTile(
                          dense: true,
                          leading: Text(
                            'ED',
                            style: AppTypography.titleSmall.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.success,
                            ),
                          ),
                          title: Text(t, style: AppTypography.body),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // 10. Characters Section
              if (anime.characters.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xl),
                Text(
                  'Karakter Utama',
                  style: AppTypography.title,
                ),
                const SizedBox(height: AppSpacing.sm),
                SizedBox(
                  height: 175,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: anime.characters.length.clamp(0, 10),
                    separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.md),
                    itemBuilder: (context, index) {
                      final c = anime.characters[index];
                      return Column(
                        children: [
                          CircleAvatar(
                            radius: 40,
                            backgroundColor: AppColors.surfaceDialog,
                            backgroundImage: c.imageUrl != null && c.imageUrl!.isNotEmpty
                                ? CachedNetworkImageProvider(c.imageUrl!)
                                : null,
                            onBackgroundImageError: (c.imageUrl != null && c.imageUrl!.isNotEmpty)
                                ? (_, _) {}
                                : null,
                            child: c.imageUrl == null || c.imageUrl!.isEmpty
                                ? const Icon(Icons.person, color: AppColors.textMuted)
                                : null,
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          SizedBox(
                            width: 80,
                            child: Text(
                              c.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: AppTypography.captionFaint.copyWith(color: AppColors.textPrimary),
                            ),
                          ),
                          Text(
                            c.role,
                            style: AppTypography.micro,
                          ),
                          if (c.voiceActorName != null)
                            SizedBox(
                              width: 80,
                              child: Text(
                                'CV. ${c.voiceActorName}',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: AppTypography.micro.copyWith(
                                  fontStyle: FontStyle.italic,
                                  color: AppColors.accent,
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ],

              // 11. Recommendations
              _RecommendationsSection(animeId: anime.id),
              const SizedBox(height: AppSpacing.xl),

              // 12. Reviews
              Text(
                'Review Komunitas',
                style: AppTypography.title,
              ),
              const SizedBox(height: AppSpacing.sm),
              _ReviewSection(animeId: anime.id),
            ],
          ),
        )
      : async.when(
          data: (_) => const SizedBox.shrink(),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
        ),
      ),
    );
  }
}

/// Compact header displaying poster on left and key identity on right.
class _AnimeDetailHeader extends StatelessWidget {
  final Anime anime;

  const _AnimeDetailHeader({required this.anime});

  @override
  Widget build(BuildContext context) {
    final fmt = (anime.format ?? '').toUpperCase();
    final typeText = fmt.isNotEmpty
        ? (fmt == 'MOVIE' ? 'Movie' : fmt == 'TV' ? 'TV' : fmt)
        : (anime.source ?? 'Anime');
    final yearText = anime.year != null ? ' • ${anime.year}' : '';
    final statusRaw = (anime.status ?? '').trim();
    final statusLower = statusRaw.toLowerCase();
    final isFinished = statusLower.contains('finished') ||
        statusLower.contains('completed') ||
        statusLower == 'finished airing' ||
        statusLower == 'finished' ||
        statusLower == 'completed';
    final isAiring = !isFinished &&
        (statusLower.contains('currently airing') ||
            statusLower.contains('releasing') ||
            statusLower == 'airing');
    final statusLabel = isAiring
        ? 'Sedang Tayang'
        : isFinished
            ? 'Selesai'
            : statusRaw.isNotEmpty
                ? statusRaw
                : 'Info';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: anime.imageUrl.isNotEmpty
              ? CachedNetworkImage(
                  imageUrl: anime.imageUrl,
                  width: AppLayout.posterW,
                  height: AppLayout.posterH,
                  fit: BoxFit.cover,
                  errorWidget: (_, _, _) => Container(
                    width: AppLayout.posterW,
                    height: AppLayout.posterH,
                    color: AppColors.surfaceDialog,
                    child: const Icon(Icons.movie, color: AppColors.textMuted),
                  ),
                )
              : Container(
                  width: AppLayout.posterW,
                  height: AppLayout.posterH,
                  color: AppColors.surfaceDialog,
                  child: const Icon(Icons.movie, color: AppColors.textMuted),
                ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                anime.title,
                style: AppTypography.headline.copyWith(color: AppColors.textPrimary),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              if (anime.titleJapanese != null || anime.titleEnglish != null) ...[
                const SizedBox(height: 2),
                Text(
                  anime.titleJapanese ?? anime.titleEnglish!,
                  style: AppTypography.captionFaint.copyWith(color: AppColors.textMuted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 3),
                    decoration: BoxDecoration(
                      color: isAiring ? AppColors.accent.withAlpha(40) : AppColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: isAiring ? AppColors.accent : AppColors.textMuted,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          statusLabel,
                          style: AppTypography.captionFaint.copyWith(
                            color: isAiring ? AppColors.accent : AppColors.textMuted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Text(
                      '$typeText$yearText',
                      style: AppTypography.captionFaint.copyWith(color: AppColors.textMuted),
                    ),
                  ),
                ],
              ),
              if (anime.studios.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    const Icon(Icons.business_outlined, size: 14, color: AppColors.textMuted),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        anime.studios.first,
                        style: AppTypography.captionFaint.copyWith(color: AppColors.textMuted),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
              if (anime.genres.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xs),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: anime.genres.take(4).map(
                    (g) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceDialog,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      child: Text(
                        g,
                        style: AppTypography.micro.copyWith(color: AppColors.textMuted),
                      ),
                    ),
                  ).toList(),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Highlight bar containing 4 primary metric badges (Score, Episodes, Favorites, Rank)
class _AnimeStatHighlights extends StatelessWidget {
  final Anime anime;

  const _AnimeStatHighlights({required this.anime});

  @override
  Widget build(BuildContext context) {
    final rankText = anime.rank != null ? '#${anime.rank}' : (anime.popularity != null ? '#${anime.popularity}' : '-');
    final favText = (anime.favoritesCount != null && anime.favoritesCount! > 0)
        ? _compactNum(anime.favoritesCount!)
        : '-';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.surfaceAlt),
      ),
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md, horizontal: AppSpacing.xs),
      child: Row(
        children: [
          Expanded(
            child: _statItem(
              icon: Icons.star_rounded,
              iconColor: AppColors.star,
              value: anime.score != null ? anime.score!.toStringAsFixed(1) : '-',
              label: 'Rating',
            ),
          ),
          _divider(),
          Expanded(
            child: _statItem(
              icon: Icons.movie_outlined,
              iconColor: AppColors.accent,
              value: anime.episodes != null ? '${anime.episodes} Ep' : '? Ep',
              label: 'Episode',
            ),
          ),
          _divider(),
          Expanded(
            child: _statItem(
              icon: Icons.favorite_rounded,
              iconColor: AppColors.dangerBright,
              value: favText,
              label: 'Favorit',
            ),
          ),
          _divider(),
          Expanded(
            child: _statItem(
              icon: Icons.emoji_events_outlined,
              iconColor: AppColors.warning,
              value: rankText,
              label: 'Peringkat',
            ),
          ),
        ],
      ),
    );
  }

  Widget _statItem({
    required IconData icon,
    required Color iconColor,
    required String value,
    required String label,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: iconColor),
            const SizedBox(width: 2),
            Flexible(
              child: Text(
                value,
                style: AppTypography.titleSmall.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: AppTypography.micro.copyWith(color: AppColors.textMuted),
        ),
      ],
    );
  }

  Widget _divider() {
    return Container(
      width: 1,
      height: 28,
      color: AppColors.surfaceAlt,
    );
  }
}

/// Expandable card that houses all secondary information behind a "Selengkapnya" toggle.
class _AnimeExpandableInfoCard extends StatefulWidget {
  final Anime anime;

  const _AnimeExpandableInfoCard({required this.anime});

  @override
  State<_AnimeExpandableInfoCard> createState() => _AnimeExpandableInfoCardState();
}

class _AnimeExpandableInfoCardState extends State<_AnimeExpandableInfoCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final anime = widget.anime;
    final duration = anime.durationText ??
        (anime.episodeDurationMinutes != null ? '${anime.episodeDurationMinutes} menit / episode' : null);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.surfaceAlt),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(AppRadius.md),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 18, color: AppColors.accent),
                  const SizedBox(width: AppSpacing.sm),
                  Text('Informasi Lengkap', style: AppTypography.titleSmall),
                  const Spacer(),
                  Row(
                    children: [
                      Text(
                        _expanded ? 'Tutup' : 'Selengkapnya',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.accent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(
                        _expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                        size: 18,
                        color: AppColors.accent,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            const Divider(height: 1, color: AppColors.surfaceAlt),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                children: [
                  _infoRow(Icons.shield_outlined, 'Rating Usia', anime.ratingAge ?? 'Semua Umur'),
                  if (duration != null)
                    _infoRow(Icons.schedule, 'Durasi per Episode', duration),
                  if (anime.airedString != null)
                    _infoRow(Icons.calendar_month_outlined, 'Tanggal Rilis', anime.airedString!),
                  if (anime.source != null)
                    _infoRow(Icons.auto_fix_high, 'Sumber Cerita', anime.source!),
                  if ((anime.members ?? 0) > 0)
                    _infoRow(Icons.group_outlined, 'Total Penonton', '${_compactNum(anime.members!)} penonton'),
                  if ((anime.popularity ?? 0) > 0)
                    _infoRow(Icons.trending_up, 'Popularitas', 'Peringkat #${anime.popularity}'),
                  if (anime.genres.isNotEmpty)
                    _infoRow(Icons.category_outlined, 'Semua Genre', anime.genres.join(', ')),
                  if (anime.studios.isNotEmpty)
                    _infoRow(Icons.apartment_outlined, 'Studio Produksi', anime.studios.join(', ')),
                  if (anime.streamingPlatforms.isNotEmpty)
                    _infoRow(Icons.play_circle_outline, 'Platform Streaming', anime.streamingPlatforms.join(' • ')),
                  if (anime.synonyms.isNotEmpty)
                    _infoRow(Icons.translate, 'Sinonim / Judul Lain', anime.synonyms.join(' • ')),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.textMuted),
          const SizedBox(width: AppSpacing.sm),
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: AppTypography.captionFaint.copyWith(color: AppColors.textMuted),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              value,
              style: AppTypography.body.copyWith(color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

/// Consistent Trailer Action Button that opens direct trailer URL or falls back to YouTube search.
class _AnimeTrailerButton extends StatelessWidget {
  final Anime anime;

  const _AnimeTrailerButton({required this.anime});

  @override
  Widget build(BuildContext context) {
    final hasTrailer = anime.trailerUrl != null && anime.trailerUrl!.isNotEmpty;
    final trailerTarget = hasTrailer
        ? anime.trailerUrl!
        : 'https://www.youtube.com/results?search_query=${Uri.encodeComponent('${anime.title} official trailer')}';

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () async {
          final uri = Uri.parse(trailerTarget);
          try {
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            }
          } catch (_) {}
        },
        icon: const Icon(Icons.play_circle_fill, color: AppColors.dangerBright),
        label: Text(
          hasTrailer ? 'Tonton Trailer Resmi' : 'Cari Trailer di YouTube',
          style: AppTypography.titleSmall.copyWith(color: AppColors.textPrimary),
        ),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          side: const BorderSide(color: AppColors.dangerBright),
        ),
      ),
    );
  }
}

/// Synopsis section with clean "Baca Selengkapnya / Ringkas" expandable toggle.
class _SynopsisSection extends StatefulWidget {
  final String? synopsis;

  const _SynopsisSection({required this.synopsis});

  @override
  State<_SynopsisSection> createState() => _SynopsisSectionState();
}

class _SynopsisSectionState extends State<_SynopsisSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final text = widget.synopsis ?? 'Tidak ada sinopsis.';
    final isLong = text.length > 220;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Sinopsis',
          style: AppTypography.title,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          text,
          maxLines: _expanded ? null : (isLong ? 4 : null),
          overflow: _expanded ? null : (isLong ? TextOverflow.ellipsis : null),
          style: AppTypography.bodyMuted.copyWith(height: 1.5),
        ),
        if (isLong) ...[
          const SizedBox(height: AppSpacing.xs),
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Text(
              _expanded ? 'Tutup Sinopsis ⌃' : 'Baca Selengkapnya ⌄',
              style: AppTypography.caption.copyWith(
                color: AppColors.accent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Bookmark / status tontonan user untuk anime ini.
/// Bisa diubah langsung lewat dropdown, atau diedit lengkap di layar review.
class _MyListSection extends ConsumerWidget {
  final Anime anime;

  const _MyListSection({required this.anime});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entry = ref.watch(myAnimeEntryProvider(anime.id));

    return entry.when(
      data: (review) {
        final loggedIn =
            ref.watch(authNotifierProvider).value != null ||
            ref.read(authRepositoryProvider).currentUser != null;

        if (!loggedIn) {
          return const SizedBox.shrink();
        }

        if (review == null) {
          return SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => WriteReviewScreen(
                    animeId: anime.id,
                    animeTitle: anime.title,
                    animeImageUrl: anime.imageUrl,
                    totalEpisodes: anime.episodes,
                  ),
                ),
              ),
              icon: const Icon(Icons.bookmark_add_outlined),
              label: const Text('Tambah ke Daftar Saya'),
            ),
          );
        }

        final status = review.watchStatus;
        return Card(
          color: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.bookmark, size: 18, color: AppColors.accent),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      'Daftar Saya',
                      style: AppTypography.titleSmall,
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => WriteReviewScreen(
                            animeId: anime.id,
                            animeTitle: anime.title,
                            animeImageUrl: anime.imageUrl,
                            totalEpisodes: anime.episodes,
                            existing: review,
                          ),
                        ),
                      ),
                      icon: const Icon(Icons.edit_outlined, size: 16),
                      label: const Text('Edit'),
                    ),
                  ],
                ),
                DropdownButtonFormField<String>(
                  initialValue: status,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    filled: true,
                    fillColor: AppColors.surfaceAlt,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                  ),
                  items: WatchStatus.all
                      .map((s) => DropdownMenuItem<String>(
                            value: s,
                            child: Text(WatchStatus.label(s)),
                          ))
                      .toList(),
                  onChanged: status == null
                      ? null
                      : (v) async {
                          if (v == null || v == status) return;
                          final total = anime.episodes;
                          int? watched = review.watchedEpisodes ?? 0;
                          bool completed = review.isCompleted;
                          if (v == WatchStatus.completed && total != null) {
                            watched = total;
                            completed = true;
                          } else if (v == WatchStatus.planToWatch ||
                              v == WatchStatus.notInterested) {
                            watched = 0;
                            completed = false;
                          }
                          try {
                            await ref.read(reviewRepositoryProvider).updateWatchStatus(
                                  animeId: anime.id,
                                  reviewId: review.id,
                                  userId: review.userId,
                                  watchStatus: v,
                                  watchedEpisodes: watched,
                                  isCompleted: completed,
                                );
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content:
                                      Text('Status diubah: ${WatchStatus.label(v)}'),
                                  backgroundColor: AppColors.accent,
                                  duration: const Duration(seconds: 1),
                                ),
                              );
                            }
                          } catch (_) {}
                        },
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Progress: Episode ${review.watchedEpisodes ?? 0}'
                  '${anime.episodes != null ? ' dari ${anime.episodes}' : ''}',
                  style: AppTypography.caption,
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}

/// Anime serupa berdasarkan rekomendasi komunitas MAL.
class _RecommendationsSection extends ConsumerWidget {
  final int animeId;

  const _RecommendationsSection({required this.animeId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(animeRecommendationsProvider(animeId));

    return async.when(
      data: (items) {
        if (items.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: AppSpacing.xl),
            Text(
              'Rekomendasi Serupa',
              style: AppTypography.title,
            ),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              height: 260,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.md),
                itemBuilder: (_, i) => _AnimeCard(anime: items[i]),
              ),
            ),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}

class _EpisodeSection extends ConsumerStatefulWidget {
  final Anime anime;

  const _EpisodeSection({required this.anime});

  @override
  ConsumerState<_EpisodeSection> createState() => _EpisodeSectionState();
}

/// Cache judul episode per halaman (100 ep/halaman) — dibagi antar widget
/// agar tidak refetch.
final Map<String, List<JikanEpisode>> _episodePageCache = {};

class _EpisodeSectionState extends ConsumerState<_EpisodeSection> {
  int? _selected;
  bool _showAll = false;
  final Map<int, JikanEpisode?> _epInfoCache = {};

  List<AnimeArc>? get _arcs => AnimeArcDb.find(widget.anime.title);

  int get _totalEpisodes =>
      widget.anime.episodes ?? _arcs?.last.endEpisode ?? 0;

  Future<JikanEpisode?> _loadEpisodeInfo(int episode) async {
    if (_epInfoCache.containsKey(episode)) return _epInfoCache[episode];
    final page = ((episode - 1) ~/ 100) + 1;
    final key = '${widget.anime.id}_$page';
    var list = _episodePageCache[key];
    list ??= await ref.read(jikanApiProvider).getEpisodes(
          widget.anime.id,
          page: page,
        );
    JikanEpisode? found;
    for (final e in list) {
      if (e.number == episode) {
        found = e;
        break;
      }
    }
    _epInfoCache[episode] = found;
    return found;
  }

  void _select(int episode) {
    setState(() => _selected = episode);
    final arcs = _arcs;
    final arc =
        arcs != null ? AnimeArcDb.arcForEpisode(arcs, episode) : null;
    final minutes = widget.anime.episodeDurationMinutes;

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
              decoration: BoxDecoration(
                color: AppColors.accent,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Text(
                'EP $episode',
                style: AppTypography.bodyStrong.copyWith(
                  color: AppColors.textOnAccent,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                arc?.name ?? 'Episode',
                style: AppTypography.titleSmall,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FutureBuilder<JikanEpisode?>(
              future: _loadEpisodeInfo(episode),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  );
                }
                final info = snap.data;
                if (info == null ||
                    ((info.title ?? '').isEmpty &&
                        info.titleJapanese == null)) {
                  return Text(
                    'Judul episode belum tersedia.',
                    style: TextStyle(color: AppColors.textFaint),
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      info.title?.isNotEmpty == true
                          ? info.title!
                          : (info.titleRomanji ?? 'Tanpa Judul'),
                      style: AppTypography.title,
                    ),
                    if (info.titleJapanese != null &&
                        info.titleJapanese!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.xs),
                        child: Text(
                          info.titleJapanese!,
                          style: AppTypography.caption,
                        ),
                      ),
                    if (info.filler || info.recap)
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.xs),
                        child: Wrap(
                          spacing: AppSpacing.xs,
                          children: [
                            if (info.filler)
                              Chip(
                                label: const Text('Filler'),
                                backgroundColor: AppColors.warning,
                                labelStyle: AppTypography.captionFaint
                                    .copyWith(color: AppColors.textMuted),
                                visualDensity: VisualDensity.compact,
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                              ),
                            if (info.recap)
                              Chip(
                                label: const Text('Recap'),
                                backgroundColor: AppColors.surfaceAlt,
                                labelStyle: AppTypography.captionFaint
                                    .copyWith(color: AppColors.textMuted),
                                visualDensity: VisualDensity.compact,
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                              ),
                          ],
                        ),
                      ),
                  ],
                );
              },
            ),
            const Divider(height: 20),
            Row(
              children: [
                const Icon(Icons.schedule, size: 16, color: AppColors.textMuted),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  minutes != null
                      ? 'Durasi ±$minutes menit'
                      : (widget.anime.durationText ?? 'Durasi ±24 menit'),
                  style: AppTypography.bodyMuted,
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Tutup'),
          ),
          FilledButton.icon(
            onPressed: () async {
              Navigator.pop(dialogContext);
              final user = ref.read(authNotifierProvider).value ??
                  ref.read(authRepositoryProvider).currentUser;
              if (user == null) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Login dulu untuk menyimpan progress.'),
                  ),
                );
                return;
              }
              final entry =
                  ref.read(myAnimeEntryProvider(widget.anime.id)).value;
              try {
                if (entry != null) {
                  await ref.read(reviewRepositoryProvider).updateWatchStatus(
                        animeId: widget.anime.id,
                        reviewId: entry.id,
                        userId: user.id,
                        watchStatus: WatchStatus.watching,
                        watchedEpisodes: episode,
                      );
                } else {
                  // Buat entri baru otomatis sebagai Currently Watching.
                  await ref.read(reviewRepositoryProvider).submitReview(
                        Review(
                          id:
                              'rev_${DateTime.now().millisecondsSinceEpoch}',
                          animeId: widget.anime.id,
                          userId: user.id,
                          username: user.username,
                          avatarUrl: user.avatarUrl,
                          animeTitle: widget.anime.title,
                          animeImageUrl: widget.anime.imageUrl,
                          watchedEpisodes: episode,
                          totalEpisodes: widget.anime.episodes,
                          watchStatus: WatchStatus.watching,
                          ratings: const ReviewRating(),
                          overallScore: 8.0,
                          title: '',
                          content: '',
                          isRecommended: true,
                          hasSpoiler: false,
                          createdAt: DateTime.now(),
                        ),
                      );
                }
                ref.invalidate(myAnimeEntryProvider(widget.anime.id));
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                        'Progress disimpan — Episode $episode ditonton'),
                    backgroundColor: AppColors.accent,
                  ),
                );
              } catch (_) {}
            },
            icon: const Icon(Icons.check, size: 18),
            label: const Text('Sudah Ditonton'),
          ),
        ],
      ),
    );
  }

  Widget _episodeChip(int episode) {
    final selected = _selected == episode;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xs),
      child: InkWell(
        onTap: () => _select(episode),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Container(
          width: 52,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppColors.accent : AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(
              color: selected ? AppColors.accent : Colors.transparent,
            ),
          ),
          child: Text(
            '$episode',
            style: selected
                ? AppTypography.bodyStrong.copyWith(
                    color: AppColors.textOnAccent,
                  )
                : AppTypography.body.copyWith(
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w500,
                  ),
          ),
        ),
      ),
    );
  }

  Widget _episodeGrid(int start, int end) {
    final episodes = <int>[
      for (var i = start; i <= end; i++) i,
    ];
    return Wrap(
      children: episodes.map(_episodeChip).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final arcs = _arcs;
    final total = _totalEpisodes;
    if (total <= 0) return const SizedBox.shrink();

    final hasArcs = arcs != null && arcs.first.startEpisode == 1;
    final lastArcEnd =
        hasArcs ? arcs.last.endEpisode.clamp(0, total).toInt() : 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Daftar Episode',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            if (_selected != null)
              Chip(
                label: Text('Ep $_selected'),
                backgroundColor: AppColors.accent,
                labelStyle: AppTypography.caption.copyWith(
                  color: AppColors.textOnAccent,
                ),
                padding: EdgeInsets.zero,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          () {
            final s = (widget.anime.status ?? '').toLowerCase();
            final finished = s.contains('finished') || s.contains('completed');
            final airing = !finished &&
                (s.contains('currently airing') ||
                    s.contains('releasing') ||
                    s == 'airing');
            return airing
                ? 'Sedang tayang • $total episode terdata'
                : '$total episode';
          }(),
          style: AppTypography.caption,
        ),
        const SizedBox(height: AppSpacing.sm),

        // Anime panjang dikelompokkan per arc
        if (hasArcs) ...[
          ...arcs.where((a) => a.startEpisode <= total).map((arc) {
            final end = arc.endEpisode > total ? total : arc.endEpisode;
            final containsSelected =
                _selected != null &&
                _selected! >= arc.startEpisode &&
                _selected! <= end;
            return Theme(
              data: Theme.of(context)
                  .copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                childrenPadding: const EdgeInsets.fromLTRB(AppSpacing.sm, 0, AppSpacing.sm, AppSpacing.sm),
                initiallyExpanded: containsSelected,
                collapsedBackgroundColor: AppColors.surface,
                backgroundColor: AppColors.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                title: Text(
                  arc.name,
                  style: AppTypography.titleSmall,
                ),
                subtitle: Text(
                  'Episode ${arc.startEpisode}–$end',
                  style: AppTypography.captionFaint
                      .copyWith(color: AppColors.textMuted),
                ),
                children: [_episodeGrid(arc.startEpisode, end)],
              ),
            );
          }),
          // Episode di luar cakupan arc (anime masih tayang / data arc belum update)
          if (lastArcEnd < total) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Episode Terbaru (${lastArcEnd + 1}–$total)',
              style: AppTypography.titleSmall,
            ),
            const SizedBox(height: AppSpacing.xs),
            _episodeGrid(lastArcEnd + 1, total),
          ],
        ] else ...[
          // Tanpa arc: grid biasa, batasi awalnya 50 agar tidak berat
          if (!_showAll && total > 50) ...[
            _episodeGrid(1, 50),
            const SizedBox(height: AppSpacing.sm),
            Center(
              child: OutlinedButton.icon(
                onPressed: () => setState(() => _showAll = true),
                icon: const Icon(Icons.expand_more, size: 18),
                label: Text('Tampilkan semua ($total episode)'),
              ),
            ),
          ] else
            _episodeGrid(1, total),
        ],
      ],
    );
  }
}

class _ReviewSection extends StatefulWidget {
  final int animeId;

  const _ReviewSection({required this.animeId});

  @override
  State<_ReviewSection> createState() => _ReviewSectionState();
}

class _ReviewSectionState extends State<_ReviewSection> {
  final _reviewCtrl = TextEditingController();
  final List<String> _localReviews = [];

  void _submitReview() {
    final text = _reviewCtrl.text.trim();
    if (text.isNotEmpty) {
      setState(() {
        _localReviews.insert(0, text);
        _reviewCtrl.clear();
      });
    }
  }

  @override
  void dispose() {
    _reviewCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _reviewCtrl,
                decoration: const InputDecoration(
                  hintText: 'Tulis review kamu...',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                ),
                maxLines: 2,
                minLines: 1,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            IconButton(
              icon: const Icon(Icons.send, color: AppColors.accent),
              onPressed: _submitReview,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        if (_localReviews.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: Text('Belum ada review. Jadilah yang pertama!', style: TextStyle(color: AppColors.textMuted)),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _localReviews.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (_, i) => Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.surfaceDialog,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Text(_localReviews[i]),
            ),
          ),
      ],
    );
  }
}
