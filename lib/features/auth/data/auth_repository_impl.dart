import 'dart:async';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/config/app_config.dart';
import '../../../core/services/supabase_service.dart';
import '../domain/app_user.dart';
import '../domain/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  final SupabaseClient? _injectedClient;

  SupabaseClient? get _supabase =>
      _injectedClient ??
      ((AppConfig.useSupabase && SupabaseService.isInitialized)
          ? SupabaseService.client
          : null);

  // Mock State for Local / Offline Mode
  static AppUser? _mockUser;
  static AppUser? _cachedProfileUser;
  final _mockStateController = StreamController<AppUser?>.broadcast();

  AuthRepositoryImpl({SupabaseClient? client}) : _injectedClient = client {
    if (!AppConfig.useSupabase || !SupabaseService.isInitialized) {
      _mockStateController.add(null);
    }
  }

  @override
  Stream<AppUser?> get onAuthStateChanged {
    if (!AppConfig.useSupabase || !SupabaseService.isInitialized || _supabase == null) {
      return Stream<AppUser?>.multi((controller) {
        controller.add(_mockUser);
        final subscription = _mockStateController.stream.listen(
          controller.add,
          onError: controller.addError,
          onDone: controller.close,
        );
        controller.onCancel = subscription.cancel;
      });
    }

    return _supabase!.auth.onAuthStateChange.asyncMap((data) async {
      final user = data.session?.user;
      if (user == null) {
        _cachedProfileUser = null;
        return null;
      }
      final appUser = await _getUserFromSupabase(user.id, user.email ?? '');
      _cachedProfileUser = appUser;
      return appUser;
    });
  }

  @override
  AppUser? get currentUser {
    if (!AppConfig.useSupabase || !SupabaseService.isInitialized || _supabase == null) {
      return _mockUser;
    }
    final user = _supabase?.auth.currentUser;
    if (user == null) {
      _cachedProfileUser = null;
      return null;
    }
    if (_cachedProfileUser != null && _cachedProfileUser!.id == user.id) {
      return _cachedProfileUser;
    }

    // Trigger async fetch to update _cachedProfileUser in background
    _getUserFromSupabase(user.id, user.email ?? '').then((u) {
      _cachedProfileUser = u;
      _mockStateController.add(u);
    }).catchError((_) {});

    return AppUser(
      id: user.id,
      email: user.email ?? '',
      username: (user.userMetadata?['username'] as String?) ??
          (user.userMetadata?['full_name'] as String?) ??
          user.email?.split('@')[0] ??
          'User',
      displayName: (user.userMetadata?['full_name'] as String?) ??
          (user.userMetadata?['name'] as String?),
      avatarUrl: user.userMetadata?['avatar_url'] as String?,
    );
  }

  Future<AppUser> _getUserFromSupabase(String uid, String email) async {
    if (_supabase != null) {
      try {
        final res = await _supabase!
            .from('profiles')
            .select()
            .eq('id', uid)
            .maybeSingle();

        if (res != null) {
          final birthDateRaw = res['birth_date'];
          final birthDate = birthDateRaw != null
              ? DateTime.tryParse(birthDateRaw.toString())
              : null;
          final user = AppUser(
            id: uid,
            email: email,
            username: res['username'] ?? email.split('@')[0],
            displayName: res['display_name'],
            avatarUrl: res['avatar_url'],
            bio: res['bio'],
            birthDate: birthDate,
          );
          _cachedProfileUser = user;
          return user;
        } else {
          // Profil belum ada (pengguna baru via Google OAuth), buatkan otomatis
          final metadata = _supabase?.auth.currentUser?.userMetadata;
          final googleName = (metadata?['full_name'] as String?) ??
              (metadata?['name'] as String?) ??
              email.split('@')[0];
          final avatarUrl = (metadata?['avatar_url'] as String?);
          final username = email.split('@')[0];

          try {
            await _supabase!.from('profiles').upsert({
              'id': uid,
              'username': username,
              'display_name': googleName,
              if (avatarUrl != null && avatarUrl.isNotEmpty)
                'avatar_url': avatarUrl,
              'updated_at': DateTime.now().toIso8601String(),
            });
          } catch (_) {}

          final user = AppUser(
            id: uid,
            email: email,
            username: username,
            displayName: googleName,
            avatarUrl: avatarUrl,
          );
          _cachedProfileUser = user;
          return user;
        }
      } catch (_) {}
    }
    final fallbackUser = AppUser(id: uid, email: email, username: email.split('@')[0]);
    _cachedProfileUser = fallbackUser;
    return fallbackUser;
  }

  @override
  Future<AppUser?> loginWithEmail(String email, String password) async {
    final sb = _supabase;
    if (!AppConfig.useSupabase || !SupabaseService.isInitialized || sb == null) {
      if (email.contains('error')) throw Exception('Mock login failed');
      _mockUser = AppUser(
        id: 'mock_uid_123',
        email: email,
        username: email.split('@')[0],
      );
      _mockStateController.add(_mockUser);
      return _mockUser;
    }

    final response = await sb.auth.signInWithPassword(
      email: email,
      password: password,
    );
    final user = response.user;
    if (user == null) return null;
    return _getUserFromSupabase(user.id, email);
  }

  @override
  Future<AppUser?> registerWithEmail({
    required String username,
    required String email,
    required String password,
  }) async {
    final sb = _supabase;
    if (!AppConfig.useSupabase || !SupabaseService.isInitialized || sb == null) {
      _mockUser = AppUser(id: 'mock_uid_123', email: email, username: username);
      _mockStateController.add(_mockUser);
      return _mockUser;
    }

    final response = await sb.auth.signUp(
      email: email,
      password: password,
      data: {'username': username, 'display_name': username},
    );
    final user = response.user;
    if (user == null) return null;

    final newUser = AppUser(
      id: user.id,
      email: email,
      username: username,
    );

    try {
      await sb.from('profiles').upsert({
        'id': user.id,
        'username': username,
        'display_name': username,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (_) {}

    return newUser;
  }

  @override
  Future<AppUser?> loginWithGoogle() async {
    final sb = _supabase;
    if (!AppConfig.useSupabase || !SupabaseService.isInitialized || sb == null) {
      _mockUser = const AppUser(
        id: 'mock_google_123',
        email: 'google@gmail.com',
        username: 'GoogleUser',
      );
      _mockStateController.add(_mockUser);
      return _mockUser;
    }

    try {
      // 1. Coba Native Google Sign In via google_sign_in (UX terbaik di Android/iOS)
      final GoogleSignIn googleSignIn = GoogleSignIn(
        serverClientId: AppConfig.googleWebClientId.isNotEmpty
            ? AppConfig.googleWebClientId
            : null,
      );
      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        return null; // Pengguna membatalkan
      }

      final googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;
      final accessToken = googleAuth.accessToken;

      if (idToken != null) {
        final authResponse = await sb.auth.signInWithIdToken(
          provider: OAuthProvider.google,
          idToken: idToken,
          accessToken: accessToken,
        );

        final u = authResponse.user;
        if (u != null) {
          final displayName = googleUser.displayName ??
              u.userMetadata?['full_name'] as String? ??
              u.userMetadata?['name'] as String? ??
              'GoogleUser';
          final avatarUrl = googleUser.photoUrl ??
              u.userMetadata?['avatar_url'] as String? ??
              '';

          try {
            final existing = await _supabase!
                .from('profiles')
                .select('id, username')
                .eq('id', u.id)
                .maybeSingle();

            if (existing == null) {
              await _supabase!.from('profiles').upsert({
                'id': u.id,
                'username': displayName,
                'display_name': displayName,
                if (avatarUrl.isNotEmpty) 'avatar_url': avatarUrl,
                'updated_at': DateTime.now().toIso8601String(),
              });
            } else if (avatarUrl.isNotEmpty) {
              await _supabase!.from('profiles').update({
                'avatar_url': avatarUrl,
                'updated_at': DateTime.now().toIso8601String(),
              }).eq('id', u.id);
            }
          } catch (_) {}

          final appUser = await _getUserFromSupabase(u.id, u.email ?? '');
          _cachedProfileUser = appUser;
          return appUser;
        }
      }
    } catch (_) {
      // 2. Fallback otomatis ke Supabase Browser OAuth dengan Deep Link Callback
      try {
        final success = await _supabase!.auth.signInWithOAuth(
          OAuthProvider.google,
          redirectTo: 'io.supabase.anitrack://login-callback',
        );
        if (success) return currentUser;
      } catch (_) {}
    }

    return currentUser;
  }

  @override
  Future<void> logout() async {
    _cachedProfileUser = null;
    _mockUser = null;
    _mockStateController.add(null);
    if (!AppConfig.useSupabase || !SupabaseService.isInitialized || _supabase == null) {
      return;
    }
    await _supabase?.auth.signOut();
  }

  @override
  Future<void> resetPassword(String email) async {
    if (!AppConfig.useSupabase || !SupabaseService.isInitialized || _supabase == null) return;
    await _supabase?.auth.resetPasswordForEmail(email);
  }
}
