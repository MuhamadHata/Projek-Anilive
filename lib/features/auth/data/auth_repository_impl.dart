import 'dart:async';
import 'dart:convert';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/config/app_config.dart';
import '../../../core/services/supabase_service.dart';
import '../domain/app_user.dart';
import '../domain/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  final SupabaseClient? _injectedClient;
  static const String _cachedUserKey = 'anilive_cached_auth_user';

  SupabaseClient? get _supabase =>
      _injectedClient ??
      ((AppConfig.useSupabase && SupabaseService.isInitialized)
          ? SupabaseService.client
          : null);

  static AppUser? _mockUser;
  static AppUser? _cachedProfileUser;
  static final _authStateController = StreamController<AppUser?>.broadcast();
  static bool _sessionInitialized = false;

  AuthRepositoryImpl({SupabaseClient? client}) : _injectedClient = client {
    if (!_sessionInitialized) {
      _sessionInitialized = true;
      _initSession();
    }
  }

  static Future<void> _saveLocalUser(AppUser? user) async {
    try {
      final prefs = SharedPreferencesAsync();
      if (user == null) {
        await prefs.remove(_cachedUserKey);
      } else {
        await prefs.setString(_cachedUserKey, jsonEncode(user.toMap()));
      }
    } catch (_) {}
  }

  static Future<AppUser?> _loadLocalUser() async {
    try {
      final prefs = SharedPreferencesAsync();
      final raw = await prefs.getString(_cachedUserKey);
      if (raw != null && raw.isNotEmpty) {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        return AppUser.fromMap(map);
      }
    } catch (_) {}
    return null;
  }

  Future<void> _initSession() async {
    final localUser = await _loadLocalUser();
    if (localUser != null) {
      _cachedProfileUser = localUser;
      _mockUser = localUser;
      _authStateController.add(localUser);
    }

    final sb = _supabase;
    if (AppConfig.useSupabase && SupabaseService.isInitialized && sb != null) {
      sb.auth.onAuthStateChange.listen((data) async {
        final user = data.session?.user;
        if (user == null) {
          _cachedProfileUser = null;
          _mockUser = null;
          await _saveLocalUser(null);
          _authStateController.add(null);
        } else {
          final appUser = await _getUserFromSupabase(user.id, user.email ?? '');
          final currentLocal = await _loadLocalUser();
          final resolvedUser = (appUser.birthDate == null &&
                  currentLocal?.birthDate != null &&
                  currentLocal?.id == user.id)
              ? appUser.copyWith(birthDate: currentLocal!.birthDate)
              : appUser;
          _cachedProfileUser = resolvedUser;
          _mockUser = resolvedUser;
          await _saveLocalUser(resolvedUser);
          _authStateController.add(resolvedUser);
        }
      });

      final currentSbUser = sb.auth.currentUser;
      if (currentSbUser != null) {
        try {
          final appUser = await _getUserFromSupabase(
            currentSbUser.id,
            currentSbUser.email ?? '',
          ).timeout(const Duration(seconds: 4));
          final resolvedUser = (appUser.birthDate == null &&
                  localUser?.birthDate != null &&
                  localUser?.id == currentSbUser.id)
              ? appUser.copyWith(birthDate: localUser!.birthDate)
              : appUser;
          _cachedProfileUser = resolvedUser;
          _mockUser = resolvedUser;
          await _saveLocalUser(resolvedUser);
          _authStateController.add(resolvedUser);
        } catch (_) {
          if (localUser != null) {
            _authStateController.add(localUser);
          }
        }
      } else if (localUser == null) {
        _authStateController.add(null);
      }
    } else {
      if (localUser != null) {
        _authStateController.add(localUser);
      } else if (_mockUser != null) {
        _authStateController.add(_mockUser);
      } else {
        _authStateController.add(null);
      }
    }
  }

  @override
  Stream<AppUser?> get onAuthStateChanged {
    return Stream<AppUser?>.multi((controller) {
      final current = currentUser;
      if (current != null) {
        controller.add(current);
      }
      final sub = _authStateController.stream.listen(
        controller.add,
        onError: controller.addError,
        onDone: controller.close,
      );
      controller.onCancel = sub.cancel;
    });
  }

  @override
  AppUser? get currentUser => _cachedProfileUser ?? _mockUser;

  Future<AppUser> _getUserFromSupabase(String uid, String email) async {
    final sb = _supabase;
    if (sb != null) {
      try {
        final res = await sb
            .from('profiles')
            .select()
            .eq('id', uid)
            .maybeSingle()
            .timeout(const Duration(seconds: 4));

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
          _mockUser = user;
          return user;
        } else {
          final metadata = sb.auth.currentUser?.userMetadata;
          final googleName = (metadata?['full_name'] as String?) ??
              (metadata?['name'] as String?) ??
              email.split('@')[0];
          final avatarUrl = (metadata?['avatar_url'] as String?);
          final username = email.split('@')[0];

          try {
            await sb.from('profiles').upsert({
              'id': uid,
              'username': username,
              'display_name': googleName,
              if (avatarUrl != null && avatarUrl.isNotEmpty)
                'avatar_url': avatarUrl,
              'updated_at': DateTime.now().toIso8601String(),
            }).timeout(const Duration(seconds: 4));
          } catch (_) {}

          final user = AppUser(
            id: uid,
            email: email,
            username: username,
            displayName: googleName,
            avatarUrl: avatarUrl,
          );
          _cachedProfileUser = user;
          _mockUser = user;
          return user;
        }
      } catch (_) {}
    }
    final fallbackUser = AppUser(
      id: uid,
      email: email,
      username: email.split('@')[0],
    );
    _cachedProfileUser = fallbackUser;
    _mockUser = fallbackUser;
    return fallbackUser;
  }

  @override
  Future<AppUser?> loginWithEmail(String email, String password) async {
    final sb = _supabase;
    if (!AppConfig.useSupabase || !SupabaseService.isInitialized || sb == null) {
      if (email.contains('error')) throw Exception('Mock login failed');
      final local = await _loadLocalUser();
      final user = (local != null && local.email == email)
          ? local
          : AppUser(
              id: 'mock_uid_123',
              email: email,
              username: email.split('@')[0],
            );
      _mockUser = user;
      _cachedProfileUser = user;
      await _saveLocalUser(user);
      _authStateController.add(user);
      return user;
    }

    final response = await sb.auth.signInWithPassword(
      email: email,
      password: password,
    );
    final user = response.user;
    if (user == null) return null;
    final appUser = await _getUserFromSupabase(user.id, email);
    _cachedProfileUser = appUser;
    _mockUser = appUser;
    await _saveLocalUser(appUser);
    _authStateController.add(appUser);
    return appUser;
  }

  @override
  Future<AppUser?> registerWithEmail({
    required String username,
    required String email,
    required String password,
  }) async {
    final sb = _supabase;
    if (!AppConfig.useSupabase || !SupabaseService.isInitialized || sb == null) {
      final user = AppUser(
        id: 'mock_uid_123',
        email: email,
        username: username,
      );
      _mockUser = user;
      _cachedProfileUser = user;
      await _saveLocalUser(user);
      _authStateController.add(user);
      return user;
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
      }).timeout(const Duration(seconds: 4));
    } catch (_) {}

    _cachedProfileUser = newUser;
    _mockUser = newUser;
    await _saveLocalUser(newUser);
    _authStateController.add(newUser);

    return newUser;
  }

  @override
  Future<AppUser?> loginWithGoogle() async {
    final sb = _supabase;
    if (!AppConfig.useSupabase || !SupabaseService.isInitialized || sb == null) {
      const user = AppUser(
        id: 'mock_google_123',
        email: 'google@gmail.com',
        username: 'GoogleUser',
      );
      _mockUser = user;
      _cachedProfileUser = user;
      await _saveLocalUser(user);
      _authStateController.add(user);
      return user;
    }

    try {
      final GoogleSignIn googleSignIn = GoogleSignIn(
        serverClientId: AppConfig.googleWebClientId.isNotEmpty
            ? AppConfig.googleWebClientId
            : null,
      );
      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        return null;
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
            final existing = await sb
                .from('profiles')
                .select('id, username')
                .eq('id', u.id)
                .maybeSingle()
                .timeout(const Duration(seconds: 4));

            if (existing == null) {
              await sb.from('profiles').upsert({
                'id': u.id,
                'username': displayName,
                'display_name': displayName,
                if (avatarUrl.isNotEmpty) 'avatar_url': avatarUrl,
                'updated_at': DateTime.now().toIso8601String(),
              }).timeout(const Duration(seconds: 4));
            } else if (avatarUrl.isNotEmpty) {
              await sb.from('profiles').update({
                'avatar_url': avatarUrl,
                'updated_at': DateTime.now().toIso8601String(),
              }).eq('id', u.id).timeout(const Duration(seconds: 4));
            }
          } catch (_) {}

          final appUser = await _getUserFromSupabase(u.id, u.email ?? '');
          _cachedProfileUser = appUser;
          _mockUser = appUser;
          await _saveLocalUser(appUser);
          _authStateController.add(appUser);
          return appUser;
        }
      }
    } catch (_) {
      try {
        final success = await sb.auth.signInWithOAuth(
          OAuthProvider.google,
          redirectTo: 'io.supabase.anitrack://login-callback',
        );
        if (success) return currentUser;
      } catch (_) {}
    }

    return currentUser;
  }

  @override
  Future<void> updateBirthDate(DateTime birthDate) async {
    final current = currentUser;
    final uid = current?.id ??
        _supabase?.auth.currentUser?.id ??
        'mock_uid_123';
    final email = current?.email ??
        _supabase?.auth.currentUser?.email ??
        'user@anilive.app';
    final username = current?.username ?? email.split('@')[0];

    final updated = (current ??
            AppUser(
              id: uid,
              email: email,
              username: username,
            ))
        .copyWith(birthDate: birthDate);

    _cachedProfileUser = updated;
    _mockUser = updated;
    await _saveLocalUser(updated);
    _authStateController.add(updated);

    final sb = _supabase;
    if (AppConfig.useSupabase && SupabaseService.isInitialized && sb != null) {
      try {
        final birthDateStr = birthDate.toIso8601String().split('T').first;
        await sb.from('profiles').upsert({
          'id': uid,
          'birth_date': birthDateStr,
          'updated_at': DateTime.now().toIso8601String(),
        }).timeout(const Duration(seconds: 4));
      } catch (_) {}
    }
  }

  @override
  Future<void> updateProfile({
    String? username,
    String? displayName,
    String? avatarUrl,
    String? bio,
    DateTime? birthDate,
  }) async {
    final current = currentUser;
    if (current == null) return;

    final updated = current.copyWith(
      username: username,
      displayName: displayName,
      avatarUrl: avatarUrl,
      bio: bio,
      birthDate: birthDate,
    );

    _cachedProfileUser = updated;
    _mockUser = updated;
    await _saveLocalUser(updated);
    _authStateController.add(updated);

    final sb = _supabase;
    if (AppConfig.useSupabase && SupabaseService.isInitialized && sb != null) {
      try {
        final map = <String, dynamic>{
          'id': updated.id,
          'updated_at': DateTime.now().toIso8601String(),
        };
        if (username != null) map['username'] = username;
        if (displayName != null) map['display_name'] = displayName;
        if (avatarUrl != null) map['avatar_url'] = avatarUrl;
        if (bio != null) map['bio'] = bio;
        if (birthDate != null) {
          map['birth_date'] = birthDate.toIso8601String().split('T').first;
        }
        await sb.from('profiles').upsert(map).timeout(const Duration(seconds: 4));
      } catch (_) {}
    }
  }

  @override
  Future<void> logout() async {
    _cachedProfileUser = null;
    _mockUser = null;
    await _saveLocalUser(null);
    _authStateController.add(null);
    final sb = _supabase;
    if (!AppConfig.useSupabase || !SupabaseService.isInitialized || sb == null) {
      return;
    }
    try {
      await sb.auth.signOut();
    } catch (_) {}
  }

  @override
  Future<void> resetPassword(String email) async {
    final sb = _supabase;
    if (!AppConfig.useSupabase || !SupabaseService.isInitialized || sb == null) {
      return;
    }
    try {
      await sb.auth.resetPasswordForEmail(email);
    } catch (_) {}
  }
}
