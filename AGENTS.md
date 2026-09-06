# Anilive — Agent Guidelines

Aplikasi Flutter (Android/iOS) review & live-chat anime. Dark-first, Material 3.

## Design System Contract (WAJIB)

Single source of truth: `lib/core/theme/app_tokens.dart`. Tema global sudah terpasang
via `AppTheme.current` di `main.dart` — komponen Material (tombol, input, card, navbar,
tab, dialog, snackbar) otomatis konsisten. Jangan bikin ThemeData sendiri.

### Aturan keras

1. **DILARANG** menulis literal berikut di `lib/features/**` atau layar mana pun:
   - `Color(0xFF...)` → gunakan `AppColors.*`
   - `Colors.white` / `Colors.white70` / `Colors.grey.shadeXXX` → `AppColors.textPrimary` / `textMuted` / `textFaint`
   - `fontSize:` literal → gunakan style token `AppTypography.*` (+ `.copyWith()` bila perlu)
   - Padding/margin/gap nilai acak → skala `AppSpacing`
2. **Skala tipografi hanya 8 gaya**: `display(20b)` `headline(18b)` `title(16b)`
   `titleSmall(14w6)` `body/bodyMuted/bodyStrong(13)` `caption(12)` `captionFaint(11)`
   `micro(10w5)` `statNumber(28b)`. Butuh ukuran lain? Pakai token terdekat.
3. **Radius hanya**: `AppRadius.sm(8)` `md(12)` `lg(16)` `xl(24)` `pill(100)`.
4. **Spacing 4-pt grid**: xs=4, sm=8, md=12, lg=16, xl=24, xxl=32. Nilai off-grid
   (3,5,6,10,14,20) dinormalisasi ke grid saat menyentuh baris tersebut.
5. **Ikon** pakai `AppIconSize` (14/16/18/20/24/32). Target sentuh min 44 (`AppTouch.minTarget`).
6. **Ukuran layout berulang** dari `AppLayout`: pagePadding=16, poster 120x180, thumb 70x100, avatar 32/40/56.
7. Warna semantik: `success`, `warning`, `danger`, `dangerBright` (aksi destruktif), `star` (rating), `accent`/`accentSoft` (brand), `textOnAccent` (teks di atas tombol accent).

### Pola yang benar

```dart
// Teks dengan variasi warna — copyWith, bukan TextStyle baru
Text(time, style: AppTypography.captionFaint.copyWith(color: AppColors.star));

// Kartu standar
Container(
  decoration: BoxDecoration(
    color: AppColors.surface,
    borderRadius: BorderRadius.circular(AppRadius.md),
  ),
  padding: const EdgeInsets.all(AppSpacing.md),
)
```

### Anti-pattern (jangan lakukan)

- `TextStyle(fontSize: 15, fontWeight: FontWeight.bold)` — slop; pakai `AppTypography.title`
- Toggle light mode manual per widget — aplikasi dark-only
- Emoji sebagai ikon UI — pakai `Icons.*` Material
- Hover/press yang mengubah ukuran (layout shift)

## Verifikasi sebelum selesai

```bash
flutter analyze --no-pub
```

Harus 0 error & warning baru. Cek juga tidak ada regex ini yang match di file yang diedit:
`fontSize: \d+|Color\(0xFF|Colors\.white`

## Arsitektur

- Fitur-first clean-ish: `lib/features/<fitur>/{data,domain,presentation}`
- State: Riverpod (`flutter_riverpod`)
- Routing: go_router + IndexedStack bottom-nav di `main.dart`
- Data anime: AniList/Jikan API + cache Firestore + offline JSON assets
