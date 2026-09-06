import 'package:flutter/material.dart';

/// ============================================================
/// TOKEN DESAIN ANIMELIVE
/// Sumber tunggal (single source of truth) untuk warna, tipografi,
/// spacing, radius, ikon, dan layout aplikasi.
///
/// ATURAN WAJIB:
/// 1. DILARANG menulis `Color(0xFF...)`, `Colors.white`, atau
///    `fontSize:` literal di dalam layar/widget. Selalu impor file ini.
/// 2. Aplikasi DARK-FIRST: satu palet dipakai di Android & iOS.
/// 3. Skala tipografi hanya 10/11/12/13/14/16/18/20/28 pt.
///    Jika butuh ukuran lain -> pilih token terdekat, jangan bikin baru.
/// ============================================================

class AppColors {
  AppColors._();

  // ---- Dasar permukaan ----
  static const Color background = Color(0xFF0D0D1A);
  static const Color surface = Color(0xFF16162B); // kartu & baris
  static const Color surfaceAlt = Color(0xFF24243D); // input, chip, thumb
  static const Color surfaceDialog = Color(0xFF1A1A30); // dialog & sheet
  static const Color surfacePressed = Color(0xFF252538); // state ditekan
  static const Color border = Color(0xFF3A3A5C);

  // ---- Aksen / brand ----
  static const Color accent = Color(0xFF6C63FF);
  static const Color accentDeep = Color(0xFF3B3790);
  static const Color accentSoft = Color(0xFFB3AEFF); // teks di atas tint

  // ---- Teks ----
  static const Color textPrimary = Colors.white;
  static const Color textOnAccent = Colors.white; // teks di atas accent
  static const Color textMuted = Color(0xFF9E9EBF);
  static const Color textFaint = Color(0xFF6E6E92);

  // ---- Semantik ----
  static const Color success = Color(0xFF66BB6A);
  static const Color warning = Color(0xFFFFB300);
  static const Color danger = Color(0xFFEF5350);
  static const Color dangerBright = Color(0xFFFF6B6B); // aksi destruktif
  static const Color star = Color(0xFFFFC107); // ikon bintang rating

  // ---- Gradien avatar preset (palet dekoratif) ----
  static const List<List<Color>> avatarGradients = [
    [Color(0xFF6C63FF), Color(0xFF3F3D9E)],
    [Color(0xFFFF6B9D), Color(0xFFB23A6B)],
    [Color(0xFF00C9A7), Color(0xFF007D68)],
    [Color(0xFFFFB300), Color(0xFFC77C02)],
    [Color(0xFF4FC3F7), Color(0xFF0277BD)],
    [Color(0xFFAB47BC), Color(0xFF6A1B9A)],
    [Color(0xFFFF7043), Color(0xFFBF360C)],
    [Color(0xFF66BB6A), Color(0xFF2E7D32)],
  ];

  static List<Color> avatarGradient(int index) =>
      avatarGradients[index % avatarGradients.length];
}

/// Skala tipografi — HANYA 8 gaya dasar. Gunakan .copyWith() bila perlu
/// variasi warna, bukan mendefinisikan TextStyle baru.
class AppTypography {
  AppTypography._();

  /// Judul layar utama / hero. 20pt bold.
  static const TextStyle display = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
    height: 1.3,
  );

  /// Header section di dalam halaman. 18pt bold.
  static const TextStyle headline = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
    height: 1.3,
  );

  /// Angka statistik besar (followers, rating count). 28pt bold.
  static const TextStyle statNumber = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
    height: 1.15,
  );

  /// Judul kartu / item list. 16pt bold.
  static const TextStyle title = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
    height: 1.35,
  );

  /// Subjudul kartu / nama field. 14pt semi-bold.
  static const TextStyle titleSmall = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    height: 1.35,
  );

  /// Teks isi standar. 13pt regular.
  static const TextStyle body = TextStyle(
    fontSize: 13,
    color: AppColors.textPrimary,
    height: 1.5,
  );

  /// Teks isi dengan penekanan (nama user inline, label penting).
  static const TextStyle bodyStrong = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    height: 1.5,
  );

  static const TextStyle bodyMuted = TextStyle(
    fontSize: 13,
    color: AppColors.textMuted,
    height: 1.5,
  );

  /// Label sekunder, chip, tab kecil. 12pt.
  static const TextStyle caption = TextStyle(
    fontSize: 12,
    color: AppColors.textMuted,
    height: 1.4,
  );

  /// Timestamp, meta kecil. 11pt.
  static const TextStyle captionFaint = TextStyle(
    fontSize: 11,
    color: AppColors.textFaint,
    height: 1.4,
  );

  /// Badge, indikator mini (batas bawah keterbacaan). 10pt medium.
  static const TextStyle micro = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w500,
    color: AppColors.textMuted,
    height: 1.3,
  );
}

/// Spacing 4-pt grid — DILARANG nilai di luar skala ini.
class AppSpacing {
  AppSpacing._();
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

/// Radius sudut seragam. Nilai liar (6,10,14,20) dinormalisasi ke skala ini.
class AppRadius {
  AppRadius._();
  static const double sm = 8; // thumbnail kecil, elemen mini
  static const double md = 12; // kartu, input, tombol (DEFAULT)
  static const double lg = 16; // kartu besar, bubble chat
  static const double xl = 24; // dialog, bottom sheet
  static const double pill = 100; // chip, tombol pil
}

/// Ukuran ikon standar (jangan pakai ukuran acak).
class AppIconSize {
  AppIconSize._();
  static const double xs = 14;
  static const double sm = 16;
  static const double md = 18;
  static const double lg = 20;
  static const double xl = 24;
  static const double hero = 32; // empty state
}

/// Target sentuh minimum (pedoman aksesibilitas 44–48px).
class AppTouch {
  AppTouch._();
  static const double minTarget = 44;
  static const double navBarHeight = 68;
}

/// Dimensi layout — ukuran komponen berulang wajib dari sini.
class AppLayout {
  AppLayout._();
  static const double pagePadding = 16; // padding horizontal layar
  static const double cardGap = 12; // gap vertikal antar kartu/list item
  static const double sectionGap = 24; // gap antar section besar
  static const double avatarSm = 32; // avatar chat/komentar
  static const double avatarMd = 40; // avatar feed
  static const double avatarLg = 56; // avatar profil
  static const double posterW = 120; // poster grid explore
  static const double posterH = 180; // poster grid explore (rasio 2:3)
  static const double thumbW = 70; // thumbnail horizontal list
  static const double thumbH = 100;
}

/// Tema aplikasi — komponen Material otomatis mengikuti token di atas,
/// sehingga Android & iOS tampil identik tanpa styling manual per layar.
class AppTheme {
  AppTheme._();

  /// Anilive dark-first: hanya satu tema resmi.
  static ThemeData get current => dark();

  static ThemeData dark() => _build();

  static ThemeData _build() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.accent,
      brightness: Brightness.dark,
      primary: AppColors.accent,
      secondary: AppColors.accentSoft,
      surface: AppColors.surface,
      error: AppColors.dangerBright,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.background,
      splashFactory: InkSparkle.splashFactory,

      // ---- Tipografi global ----
      textTheme: const TextTheme(
        displaySmall: AppTypography.statNumber,
        headlineMedium: AppTypography.display,
        headlineSmall: AppTypography.headline,
        titleLarge: AppTypography.title,
        titleMedium: AppTypography.titleSmall,
        bodyLarge: AppTypography.titleSmall,
        bodyMedium: AppTypography.body,
        bodySmall: AppTypography.caption,
        labelLarge: AppTypography.bodyStrong,
        labelSmall: AppTypography.micro,
      ),

      // ---- AppBar ----
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        foregroundColor: AppColors.textPrimary,
        titleTextStyle: AppTypography.display,
        iconTheme: IconThemeData(color: AppColors.textPrimary, size: AppIconSize.xl),
      ),

      // ---- Kartu ----
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),

      // ---- Navigasi bawah ----
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.accent.withAlpha(60),
        height: AppTouch.navBarHeight,
        elevation: 0,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: AppIconSize.xl,
            color: states.contains(WidgetState.selected)
                ? AppColors.accentSoft
                : AppColors.textMuted,
          ),
        ),
        labelTextStyle: const WidgetStatePropertyAll(AppTypography.micro),
      ),

      // ---- Input ----
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceAlt,
        hintStyle: AppTypography.bodyMuted,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
        ),
      ),

      // ---- Tombol ----
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: AppColors.textOnAccent,
          textStyle: AppTypography.titleSmall,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.md + 2,
          ),
          minimumSize: const Size(64, AppTouch.minTarget),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.accentSoft,
          side: const BorderSide(color: AppColors.accent),
          textStyle: AppTypography.titleSmall,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.md + 2,
          ),
          minimumSize: const Size(64, AppTouch.minTarget),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.accentSoft,
          textStyle: AppTypography.titleSmall,
          minimumSize: const Size(44, AppTouch.minTarget),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surfaceAlt,
        selectedColor: AppColors.accent.withAlpha(90),
        labelStyle: AppTypography.caption,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        side: BorderSide.none,
      ),

      // ---- Dialog & sheet ----
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surfaceDialog,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        titleTextStyle: AppTypography.title,
        contentTextStyle: AppTypography.bodyMuted,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surfaceDialog,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        ),
        showDragHandle: true,
      ),

      // ---- Tab ----
      tabBarTheme: const TabBarThemeData(
        indicatorColor: AppColors.accent,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: Colors.transparent,
        labelColor: AppColors.textPrimary,
        unselectedLabelColor: AppColors.textMuted,
        labelStyle: AppTypography.bodyStrong,
        unselectedLabelStyle: AppTypography.body,
      ),

      // ---- Lain-lain ----
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.surfaceAlt,
        contentTextStyle: AppTypography.body,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
      dividerTheme: const DividerThemeData(color: AppColors.border, thickness: 1),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.accent,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.accent
              : AppColors.textMuted,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.accent.withAlpha(90)
              : AppColors.surfaceAlt,
        ),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: AppColors.textMuted,
        titleTextStyle: AppTypography.titleSmall,
        subtitleTextStyle: AppTypography.caption,
      ),
      badgeTheme: const BadgeThemeData(
        backgroundColor: AppColors.danger,
        textStyle: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: AppColors.textOnAccent),
      ),
    );
  }
}
