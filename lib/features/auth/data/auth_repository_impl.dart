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

  static String _userBirthDateKey(String uid) => 'anilive_birthdate_$uid';
  static String _emailBirthDateKey(String email) =>
      'anilive_email_birthdate_${email.toLowerCase().trim()}';
  static String _completedKey(String id) => 'anilive_biodata_completed_$id';
  static String _emailCompletedKey(String email) =>
      'anilive_email_completed_${email.toLowerCase().trim()}';

  static final Map<String, String> _birthDateStore = {};
  static final Set<String> _completedStore = {};

  SupabaseClient? get _supabase =>
      _injectedClient ??
      ((AppConfig.useSupabase && SupabaseService.isInitialized)
          ? SupabaseService.client
          : null);

  static AppUser? _mockUser;
  static AppUser? _cachedProfileUser;
  static final _authStateController = StreamController<AppUser?>.broadcast();

  AuthRepositoryImpl({SupabaseClient? client}) : _injectedClient = client {
    _initSession();
  }

  static Future<void> _saveBirthDateLocally(
    String uid,
    String email,
    DateTime date,
  ) async {
    final iso = date.toIso8601String();
    if (uid.isNotEmpty) {
      _birthDateStore[_userBirthDateKey(uid)] = iso;
      _completedStore.add(_completedKey(uid));
    }
    if (email.isNotEmpty) {
      _birthDateStore[_emailBirthDateKey(email)] = iso;
      _completedStore.add(_emailCompletedKey(email));
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      if (uid.isNotEmpty) {
        await prefs.setString(_userBirthDateKey(uid), iso);
        await prefs.setBool(_completedKey(uid), true);
      }
      if (email.isNotEmpty) {
        await prefs.setString(_emailBirthDateKey(email), iso);
        await prefs.setBool(_emailCompletedKey(email), true);
      }
    } catch (_) {}
  }

  static Future<DateTime?> _loadBirthDateLocally(
    String uid,
    String email,
  ) async {
    if (uid.isNotEmpty && _birthDateStore.containsKey(_userBirthDateKey(uid))) {
      final dt = DateTime.tryParse(_birthDateStore[_userBirthDateKey(uid)]!);
      if (dt != null) return dt;
    }
    if (email.isNotEmpty &&
        _birthDateStore.containsKey(_emailBirthDateKey(email))) {
      final dt =
          DateTime.tryParse(_birthDateStore[_emailBirthDateKey(email)]!);
      if (dt != null) return dt;
    }
    if (email.isNotEmpty &&
        _completedStore.contains(_emailCompletedKey(email))) {
      return DateTime(2000, 1, 1);
    }
    if (uid.isNotEmpty && _completedStore.contains(_completedKey(uid))) {
      return DateTime(2000, 1, 1);
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      if (uid.isNotEmpty) {
        final raw = prefs.getString(_userBirthDateKey(uid));
        if (raw != null && raw.isNotEmpty) {
          final dt = DateTime.tryParse(raw);
          if (dt != null) {
            _birthDateStore[_userBirthDateKey(uid)] = raw;
            return dt;
          }
        }
      }
      if (email.isNotEmpty) {
        final raw = prefs.getString(_emailBirthDateKey(email));
        if (raw != null && raw.isNotEmpty) {
          final dt = DateTime.tryParse(raw);
          if (dt != null) {
            _birthDateStore[_emailBirthDateKey(email)] = raw;
            return dt;
          }
        }
        final completed = prefs.getBool(_emailCompletedKey(email));
        if (completed == true) {
          return DateTime(2000, 1, 1);
        }
      }
      if (uid.isNotEmpty) {
        final completed = prefs.getBool(_completedKey(uid));
        if (completed == true) {
          return DateTime(2000, 1, 1);
        }
      }
    } catch (_) {}
    return null;
  }

  static Future<void> _saveLocalUser(AppUser? user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (user == null) {
        await prefs.remove(_cachedUserKey);
      } else {
        await prefs.setString(_cachedUserKey, jsonEncode(user.toMap()));
        if (user.birthDate != null) {
          await _saveBirthDateLocally(user.id, user.email, user.birthDate!);
        }
      }
    } catch (_) {}
  }

  static Future<AppUser?> _loadLocalUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cachedUserKey);
      if (raw != null && raw.isNotEmpty) {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        final user = AppUser.fromMap(map);
        if (user.birthDate == null) {
          final localBirth = await _loadBirthDateLocally(user.id, user.email);
          if (localBirth != null) {
            return user.copyWith(birthDate: localBirth);
          }
        }
        return user;
      }
    } catch (_) {}
    return null;
  }

  Future<void> _initSession() async {
    final sb = _supabase;
    final sbUser = sb?.auth.currentUser;
    final localUser = await _loadLocalUser();

    if (sbUser != null) {
      final uid = sbUser.id;
      final email = sbUser.email ?? '';
      final localBirth = await _loadBirthDateLocally(uid, email);

      AppUser initialUser;
      if (localUser != null && localUser.id == uid) {
        initialUser = localUser.birthDate != null
            ? localUser
            : localUser.copyWith(birthDate: localBirth);
      } else {
        initialUser = AppUser(
          id: uid,
          email: email,
          username: (sbUser.userMetadata?['username'] as String?) ??
              (sbUser.userMetadata?['full_name'] as String?) ??
              (email.isNotEmpty ? email.split('@')[0] : 'User'),
          displayName: (sbUser.userMetadata?['full_name'] as String?) ??
              (sbUser.userMetadata?['name'] as String?),
          avatarUrl: sbUser.userMetadata?['avatar_url'] as String?,
          birthDate: localBirth,
        );
      }
      _cachedProfileUser = initialUser;
      _mockUser = initialUser;
      _authStateController.add(initialUser);

      try {
        final synced = await _getUserFromSupabase(
          uid,
          email,
          isExistingLogin: true,
        ).timeout(const Duration(seconds: 4));

        final resolved = (synced.birthDate == null &&
                localUser?.birthDate != null &&
                localUser?.id == uid)
            ? synced.copyWith(birthDate: localUser!.birthDate)
            : synced;
        _cachedProfileUser = resolved;
        _mockUser = resolved;
        await _saveLocalUser(resolved);
        _authStateController.add(resolved);
      } catch (_) {}
    } else if (localUser != null) {
      _cachedProfileUser = localUser;
      _mockUser = localUser;
      _authStateController.add(localUser);
    } else {
      _authStateController.add(null);
    }

    if (AppConfig.useSupabase && SupabaseService.isInitialized && sb != null) {
      sb.auth.onAuthStateChange.listen((data) async {
        final user = data.session?.user;
        if (user == null) {
          _cachedProfileUser = null;
          _mockUser = null;
          await _saveLocalUser(null);
          _authStateController.add(null);
        } else {
          final appUser = await _getUserFromSupabase(
            user.id,
            user.email ?? '',
            isExistingLogin: true,
          );
          final curLocal = await _loadLocalUser();
          final resolved = (appUser.birthDate == null &&
                  curLocal?.birthDate != null &&
                  curLocal?.id == user.id)
              ? appUser.copyWith(birthDate: curLocal!.birthDate)
              : appUser;
          _cachedProfileUser = resolved;
          _mockUser = resolved;
          await _saveLocalUser(resolved);
          _authStateController.add(resolved);
        }
      });
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
  AppUser? get currentUser {
    final sb = _supabase;
    final sbUser = sb?.auth.currentUser;
    if (sbUser != null) {
      if (_cachedProfileUser != null && _cachedProfileUser!.id == sbUser.id) {
        return _cachedProfileUser;
      }
      return AppUser(
        id: sbUser.id,
        email: sbUser.email ?? '',
        username: (sbUser.userMetadata?['username'] as String?) ??
            (sbUser.userMetadata?['full_name'] as String?) ??
            (sbUser.email?.isNotEmpty == true
                ? sbUser.email!.split('@')[0]
                : 'User'),
        displayName: (sbUser.userMetadata?['full_name'] as String?) ??
            (sbUser.userMetadata?['name'] as String?),
        avatarUrl: sbUser.userMetadata?['avatar_url'] as String?,
        birthDate: _cachedProfileUser?.id == sbUser.id
            ? _cachedProfileUser?.birthDate
            : null,
      );
    }
    return _cachedProfileUser ?? _mockUser;
  }

  Future<AppUser> _getUserFromSupabase(
    String uid,
    String email, {
    bool isExistingLogin = false,
  }) async {
    final sb = _supabase;
    DateTime? localBirthDate = await _loadBirthDateLocally(uid, email);

    if (sb != null) {
      try {
        final res = await sb
            .from('profiles')
            .select()
            .eq('id', uid)
            .maybeSingle()
            .timeout(const Duration(seconds: 4));

        if (res != null) {
          final birthDateRaw = res['birth_date'] ?? res['birthDate'];
          DateTime? birthDate = birthDateRaw != null
              ? DateTime.tryParse(birthDateRaw.toString())
              : null;

          birthDate ??= localBirthDate;

          if (birthDate == null) {
            final metaBirth = sb.auth.currentUser?.userMetadata?['birth_date'];
            if (metaBirth != null) {
              birthDate = DateTime.tryParse(metaBirth.toString());
            }
          }

          // Akun yang sudah terdaftar sebelumnya tidak boleh diminta isi tanggal lahir lagi saat login.
          if (birthDate == null && isExistingLogin) {
            birthDate = DateTime(2000, 1, 1);
            _saveBirthDateLocally(uid, email, birthDate);
            try {
              final birthStr = birthDate.toIso8601String().split('T').first;
              sb.from('profiles').update({'birth_date': birthStr}).eq('id', uid);
            } catch (_) {}
          } else if (birthDate != null) {
            _saveBirthDateLocally(uid, email, birthDate);
          }

          final user = AppUser(
            id: uid,
            email: email,
            username: res['username'] ??
                (email.isNotEmpty ? email.split('@')[0] : 'User'),
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
              (email.isNotEmpty ? email.split('@')[0] : 'User');
          final avatarUrl = (metadata?['avatar_url'] as String?);
          final username = (metadata?['username'] as String?) ??
              (email.isNotEmpty ? email.split('@')[0] : 'User');
          final metaBirth = metadata?['birth_date'];
          DateTime? birthDate = metaBirth != null
              ? DateTime.tryParse(metaBirth.toString())
              : localBirthDate;

          if (birthDate == null && isExistingLogin) {
            birthDate = DateTime(2000, 1, 1);
          }

          try {
            final profileMap = <String, dynamic>{
              'id': uid,
              'username': username,
              'display_name': googleName,
              'updated_at': DateTime.now().toIso8601String(),
            };
            if (avatarUrl != null && avatarUrl.isNotEmpty) {
              profileMap['avatar_url'] = avatarUrl;
            }
            if (birthDate != null) {
              profileMap['birth_date'] =
                  birthDate.toIso8601String().split('T').first;
            }
            await sb
                .from('profiles')
                .upsert(profileMap)
                .timeout(const Duration(seconds: 4));
          } catch (_) {}

          if (birthDate != null) {
            _saveBirthDateLocally(uid, email, birthDate);
          }

          final user = AppUser(
            id: uid,
            email: email,
            username: username,
            displayName: googleName,
            avatarUrl: avatarUrl,
            birthDate: birthDate,
          );
          _cachedProfileUser = user;
          _mockUser = user;
          return user;
        }
      } catch (_) {}
    }

    DateTime? birthDate = localBirthDate;
    if (birthDate == null && isExistingLogin) {
      birthDate = DateTime(2000, 1, 1);
    }
    final fallbackUser = AppUser(
      id: uid,
      email: email,
      username: email.isNotEmpty ? email.split('@')[0] : 'User',
      birthDate: birthDate,
    );
    _cachedProfileUser = fallbackUser;
    _mockUser = fallbackUser;
    return fallbackUser;
  }

  @override
  Future<AppUser?> loginWithEmail(String email, String password) async {
    final cleanEmail = email.trim();
    final sb = _supabase;
    if (!AppConfig.useSupabase || !SupabaseService.isInitialized || sb == null) {
      if (cleanEmail.contains('error')) throw Exception('Mock login failed');
      final local = await _loadLocalUser();
      final localBirth =
          await _loadBirthDateLocally('mock_uid_123', cleanEmail);
      final resolvedBirth = (local != null && local.email == cleanEmail)
          ? (local.birthDate ?? localBirth ?? DateTime(2000, 1, 1))
          : (localBirth ?? DateTime(2000, 1, 1));
      final user = AppUser(
        id: 'mock_uid_123',
        email: cleanEmail,
        username: cleanEmail.split('@')[0],
        birthDate: resolvedBirth,
      );
      _mockUser = user;
      _cachedProfileUser = user;
      await _saveBirthDateLocally(user.id, user.email, resolvedBirth);
      await _saveLocalUser(user);
      _authStateController.add(user);
      return user;
    }

    final response = await sb.auth.signInWithPassword(
      email: cleanEmail,
      password: password,
    );
    final user = response.user;
    if (user == null) return null;
    final appUser = await _getUserFromSupabase(
      user.id,
      cleanEmail,
      isExistingLogin: true,
    );
    _cachedProfileUser = appUser;
    _mockUser = appUser;
    await _saveLocalUser(appUser);
    if (appUser.birthDate != null) {
      await _saveBirthDateLocally(
        appUser.id,
        appUser.email,
        appUser.birthDate!,
      );
    }
    _authStateController.add(appUser);
    return appUser;
  }

  @override
  Future<AppUser?> registerWithEmail({
    required String username,
    required String email,
    required String password,
    DateTime? birthDate,
  }) async {
    final cleanEmail = email.trim();
    final cleanUsername = username.trim();
    final sb = _supabase;

    if (!AppConfig.useSupabase || !SupabaseService.isInitialized || sb == null) {
      final user = AppUser(
        id: 'mock_uid_123',
        email: cleanEmail,
        username: cleanUsername,
        birthDate: birthDate,
      );
      _mockUser = user;
      _cachedProfileUser = user;
      if (birthDate != null) {
        await _saveBirthDateLocally(user.id, user.email, birthDate);
      }
      await _saveLocalUser(user);
      _authStateController.add(user);
      return user;
    }

    final birthDateStr = birthDate?.toIso8601String().split('T').first;
    final authData = <String, dynamic>{
      'username': cleanUsername,
      'display_name': cleanUsername,
    };
    if (birthDateStr != null) {
      authData['birth_date'] = birthDateStr;
    }

    final response = await sb.auth.signUp(
      email: cleanEmail,
      password: password,
      data: authData,
    );
    final user = response.user;
    if (user == null) return null;

    final newUser = AppUser(
      id: user.id,
      email: cleanEmail,
      username: cleanUsername,
      birthDate: birthDate,
    );

    try {
      final profileData = <String, dynamic>{
        'id': user.id,
        'username': cleanUsername,
        'display_name': cleanUsername,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };
      if (birthDateStr != null) {
        profileData['birth_date'] = birthDateStr;
      }
      await sb
          .from('profiles')
          .upsert(profileData)
          .timeout(const Duration(seconds: 4));
    } catch (_) {}

    if (birthDate != null) {
      await _saveBirthDateLocally(user.id, cleanEmail, birthDate);
    }

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
      const email = 'google@gmail.com';
      final localBirth = await _loadBirthDateLocally('mock_google_123', email);
      final user = AppUser(
        id: 'mock_google_123',
        email: email,
        username: 'GoogleUser',
        birthDate: localBirth ?? DateTime(2000, 1, 1),
      );
      _mockUser = user;
      _cachedProfileUser = user;
      await _saveBirthDateLocally(user.id, user.email, user.birthDate!);
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
      // Reset session Google SDK sebelumnya agar dialog pemilihan akun selalu muncul
      try {
        await googleSignIn.signOut();
      } catch (_) {}

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
                .select('id, username, birth_date')
                .eq('id', u.id)
                .maybeSingle()
                .timeout(const Duration(seconds: 4));

            if (existing == null) {
              final googleProfile = <String, dynamic>{
                'id': u.id,
                'username': displayName,
                'display_name': displayName,
                'updated_at': DateTime.now().toIso8601String(),
              };
              if (avatarUrl.isNotEmpty) {
                googleProfile['avatar_url'] = avatarUrl;
              }
              await sb
                  .from('profiles')
                  .upsert(googleProfile)
                  .timeout(const Duration(seconds: 4));
            } else if (avatarUrl.isNotEmpty) {
              await sb.from('profiles').update({
                'avatar_url': avatarUrl,
                'updated_at': DateTime.now().toIso8601String(),
              }).eq('id', u.id).timeout(const Duration(seconds: 4));
            }
          } catch (_) {}

          final appUser = await _getUserFromSupabase(
            u.id,
            u.email ?? '',
            isExistingLogin: true,
          );
          _cachedProfileUser = appUser;
          _mockUser = appUser;
          await _saveLocalUser(appUser);
          if (appUser.birthDate != null) {
            await _saveBirthDateLocally(
              appUser.id,
              appUser.email,
              appUser.birthDate!,
            );
          }
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
    final sb = _supabase;
    final sbUser = sb?.auth.currentUser;
    final uid = sbUser?.id ??
        _cachedProfileUser?.id ??
        _mockUser?.id ??
        'mock_uid_123';
    final email = sbUser?.email ??
        _cachedProfileUser?.email ??
        _mockUser?.email ??
        'user@anilive.app';
    final username = _cachedProfileUser?.username ??
        _mockUser?.username ??
        (sbUser?.userMetadata?['username'] as String?) ??
        (email.isNotEmpty ? email.split('@')[0] : 'User');

    final current = _cachedProfileUser ?? _mockUser;
    final updated = (current ??
            AppUser(
              id: uid,
              email: email,
              username: username,
            ))
        .copyWith(
      id: uid,
      birthDate: birthDate,
    );

    _cachedProfileUser = updated;
    _mockUser = updated;
    await _saveBirthDateLocally(uid, email, birthDate);
    await _saveLocalUser(updated);
    _authStateController.add(updated);

    if (AppConfig.useSupabase && SupabaseService.isInitialized && sb != null) {
      try {
        final birthDateStr = birthDate.toIso8601String().split('T').first;
        await sb.from('profiles').upsert({
          'id': uid,
          'birth_date': birthDateStr,
          'updated_at': DateTime.now().toIso8601String(),
        }).timeout(const Duration(seconds: 4));

        await sb.auth.updateUser(
          UserAttributes(data: {'birth_date': birthDateStr}),
        ).timeout(const Duration(seconds: 4));
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
    if (birthDate != null) {
      await _saveBirthDateLocally(updated.id, updated.email, birthDate);
    }
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
        await sb
            .from('profiles')
            .upsert(map)
            .timeout(const Duration(seconds: 4));
      } catch (_) {}
    }
  }

  @override
  Future<void> logout() async {
    _cachedProfileUser = null;
    _mockUser = null;
    await _saveLocalUser(null);
    _authStateController.add(null);
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn(
        serverClientId: AppConfig.googleWebClientId.isNotEmpty
            ? AppConfig.googleWebClientId
            : null,
      );
      await googleSignIn.signOut();
    } catch (_) {}
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
