import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/services/supabase_service.dart';
import 'core/theme/app_tokens.dart';
import 'core/theme/theme_provider.dart';
import 'features/anime/data/anime_offline_db.dart';
import 'features/anime/presentation/explore_screen.dart';
import 'features/auth/presentation/auth_provider.dart';
import 'features/auth/presentation/biodata_screen.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/profile/presentation/profile_screen.dart';
import 'features/social/presentation/home_feed_screen.dart';
import 'features/notification/data/notification_repository.dart';
import 'features/notification/presentation/notifications_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Pastikan status bar dan navigation bar sistem menyatu rapi dengan tema gelap Anilive
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
      systemNavigationBarColor: AppColors.surface,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    if (kDebugMode) {
      print('Uncaught Platform Error: $error');
    }
    return true;
  };

  await SupabaseService.initialize();
  // Warm up database offline lokal agar Explore Screen & Search tampil instan (0 ms)
  unawaited(AnimeOfflineDb.ensureLoaded());
  runApp(const ProviderScope(child: AniliveApp()));
}

class AniliveApp extends ConsumerWidget {
  const AniliveApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      title: 'Anilive',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: AppTheme.current,
      darkTheme: AppTheme.current,
      home: const _AuthGate(),
    );
  }
}

/// Alias kompatibilitas untuk test dan legacy reference
typedef AniTrackApp = AniliveApp;

class _AuthGate extends ConsumerWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    return authState.when(
      data: (user) {
        if (user == null) return const LoginScreen();
        // Jika belum mengisi biodata (tanggal lahir), tampilkan onboarding dulu.
        if (user.needsBiodataSetup) {
          return BiodataScreen(
            userId: user.id,
            onComplete: () {
              // Invalidate auth state agar AppUser ter-refresh dengan birthDate baru.
              ref.invalidate(authStateProvider);
            },
          );
        }
        return const HomeScreen();
      },
      loading: () {
        final current = ref.read(authRepositoryProvider).currentUser;
        if (current != null) {
          if (current.needsBiodataSetup) {
            return BiodataScreen(
              userId: current.id,
              onComplete: () {
                ref.invalidate(authStateProvider);
              },
            );
          }
          return const HomeScreen();
        }
        return const Scaffold(
          backgroundColor: AppColors.background,
          body: Center(child: CircularProgressIndicator(color: AppColors.accent)),
        );
      },
      error: (_, _) => const LoginScreen(),
    );
  }
}

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final user =
        ref.watch(authNotifierProvider).value ??
        ref.watch(authRepositoryProvider).currentUser;
    final currentUserId = user?.id ?? 'mock_user_123';
    final unreadCount =
        ref.watch(unreadNotificationsCountProvider(currentUserId));

    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: const [
          HomeFeedScreen(),
          ExploreScreen(),
          NotificationsScreen(),
          _ProfileTabWrapper(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) =>
            setState(() => _selectedIndex = index),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          const NavigationDestination(
            icon: Icon(Icons.explore_outlined),
            selectedIcon: Icon(Icons.explore),
            label: 'Explore',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: unreadCount > 0,
              label: Text(unreadCount > 9 ? '9+' : unreadCount.toString()),
              backgroundColor: AppColors.dangerBright,
              child: const Icon(Icons.notifications_outlined),
            ),
            selectedIcon: Badge(
              isLabelVisible: unreadCount > 0,
              label: Text(unreadCount > 9 ? '9+' : unreadCount.toString()),
              backgroundColor: AppColors.dangerBright,
              child: const Icon(Icons.notifications),
            ),
            label: 'Notifikasi',
          ),
          const NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}

class _ProfileTabWrapper extends ConsumerWidget {
  const _ProfileTabWrapper();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user =
        ref.watch(authNotifierProvider).value ??
        ref.read(authRepositoryProvider).currentUser;
    return ProfileScreen(
      userId: user?.id ?? 'mock_uid_123',
      embedded: false,
    );
  }
}

