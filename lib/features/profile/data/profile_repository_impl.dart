import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/config/app_config.dart';
import '../../../core/services/supabase_service.dart';
import '../domain/user_profile.dart';

abstract class ProfileRepository {
  Stream<UserProfile?> watchProfile(String userId);
  Future<void> updateProfile(UserProfile profile);
  Future<void> follow(String userId, String targetUserId);
  Future<void> unfollow(String userId, String targetUserId);
  Future<bool> isFollowing(String userId, String targetUserId);
}

class ProfileRepositoryImpl implements ProfileRepository {
  final SupabaseClient? _supabase;
  static final Map<String, UserProfile> _mockProfiles = {};
  static final Set<String> _mockFollows = {};
  static final _mockController =
      StreamController<Map<String, UserProfile>>.broadcast();

  ProfileRepositoryImpl({SupabaseClient? client})
      : _supabase = (AppConfig.useSupabase && SupabaseService.isInitialized)
            ? (client ?? SupabaseService.client)
            : null;

  @override
  Stream<UserProfile?> watchProfile(String userId) {
    return Stream<UserProfile?>.multi((controller) {
      // 1. Dapatkan profil dari cache atau inisialisasi dari user aktif
      final existing = _mockProfiles[userId];
      if (existing != null) {
        controller.add(existing);
      } else {
        final sb = _supabase;
        final sbUser = (sb?.auth.currentUser?.id == userId) ? sb?.auth.currentUser : null;
        final email = sbUser?.email ?? '';
        final initial = UserProfile(
          id: userId,
          username: (sbUser?.userMetadata?['username'] as String?) ??
              (sbUser?.userMetadata?['full_name'] as String?) ??
              (email.isNotEmpty ? email.split('@')[0] : 'user_${userId.length > 5 ? userId.substring(0, 5) : userId}'),
          displayName: (sbUser?.userMetadata?['full_name'] as String?) ??
              (sbUser?.userMetadata?['name'] as String?) ??
              'Pengguna Anilive',
          bio: null,
          avatarUrl: sbUser?.userMetadata?['avatar_url'] as String?,
          followersCount: 0,
          followingCount: 0,
          animeCompletedCount: 0,
          createdAt: DateTime.now(),
        );
        _mockProfiles[userId] = initial;
        controller.add(initial);
      }

      // 2. Dengarkan broadcast controller untuk update lokal instan
      final sub = _mockController.stream.listen((profiles) {
        if (profiles.containsKey(userId)) {
          controller.add(profiles[userId]);
        }
      });
      controller.onCancel = sub.cancel;

      // 3. Jika Supabase terhubung, sinkronkan data profil di latar belakang
      final sb = _supabase;
      if (sb != null) {
        _fetchAndSyncSupabaseProfile(userId, controller);
      }
    });
  }

  Future<void> _fetchAndSyncSupabaseProfile(
    String userId,
    MultiStreamController<UserProfile?> controller,
  ) async {
    final sb = _supabase;
    if (sb == null) return;
    try {
      final res = await sb
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle()
          .timeout(const Duration(seconds: 4));

      if (res != null) {
        final profile = UserProfile.fromMap(res, userId);
        _mockProfiles[userId] = profile;
        if (!controller.isClosed) {
          controller.add(profile);
        }
      } else {
        await _ensureProfileExists(userId);
      }
    } catch (_) {}
  }

  Future<void> _ensureProfileExists(String userId) async {
    final sb = _supabase;
    if (sb == null) return;
    try {
      final existing = await sb
          .from('profiles')
          .select('id')
          .eq('id', userId)
          .maybeSingle()
          .timeout(const Duration(seconds: 4));

      if (existing == null) {
        await sb.from('profiles').upsert({
          'id': userId,
          'username': 'user_${userId.substring(0, 5.clamp(0, userId.length))}',
          'display_name': 'Pengguna Anilive',
          'followers_count': 0,
          'following_count': 0,
          'anime_completed_count': 0,
          'created_at': DateTime.now().toIso8601String(),
        }).timeout(const Duration(seconds: 4));
      }
    } catch (_) {}
  }

  @override
  Future<void> updateProfile(UserProfile profile) async {
    _mockProfiles[profile.id] = profile;
    _mockController.add(_mockProfiles);

    final sb = _supabase;
    if (sb != null) {
      try {
        await sb
            .from('profiles')
            .upsert(profile.toSupabaseMap())
            .timeout(const Duration(seconds: 4));
      } catch (_) {}
    }
  }

  @override
  Future<void> follow(String userId, String targetUserId) async {
    _mockFollows.add('${userId}_$targetUserId');
    if (_mockProfiles.containsKey(targetUserId)) {
      final p = _mockProfiles[targetUserId]!;
      _mockProfiles[targetUserId] =
          p.copyWith(followersCount: p.followersCount + 1);
    }
    if (_mockProfiles.containsKey(userId)) {
      final p = _mockProfiles[userId]!;
      _mockProfiles[userId] = p.copyWith(followingCount: p.followingCount + 1);
    }
    _mockController.add(_mockProfiles);

    final sb = _supabase;
    if (sb != null) {
      try {
        await sb.from('follows').upsert({
          'follower_id': userId,
          'following_id': targetUserId,
          'created_at': DateTime.now().toIso8601String(),
        }).timeout(const Duration(seconds: 4));
      } catch (_) {}

      try {
        final targetData = await sb
            .from('profiles')
            .select('followers_count')
            .eq('id', targetUserId)
            .maybeSingle()
            .timeout(const Duration(seconds: 4));
        final currentFollowers =
            ((targetData?['followers_count'] as num?)?.toInt() ?? 0) + 1;
        await sb.from('profiles').update({
          'followers_count': currentFollowers,
        }).eq('id', targetUserId).timeout(const Duration(seconds: 4));
      } catch (_) {}

      try {
        final myData = await sb
            .from('profiles')
            .select('following_count')
            .eq('id', userId)
            .maybeSingle()
            .timeout(const Duration(seconds: 4));
        final currentFollowing =
            ((myData?['following_count'] as num?)?.toInt() ?? 0) + 1;
        await sb.from('profiles').update({
          'following_count': currentFollowing,
        }).eq('id', userId).timeout(const Duration(seconds: 4));
      } catch (_) {}
    }
  }

  @override
  Future<void> unfollow(String userId, String targetUserId) async {
    _mockFollows.remove('${userId}_$targetUserId');
    if (_mockProfiles.containsKey(targetUserId)) {
      final p = _mockProfiles[targetUserId]!;
      _mockProfiles[targetUserId] =
          p.copyWith(followersCount: (p.followersCount - 1).clamp(0, 999999));
    }
    if (_mockProfiles.containsKey(userId)) {
      final p = _mockProfiles[userId]!;
      _mockProfiles[userId] =
          p.copyWith(followingCount: (p.followingCount - 1).clamp(0, 999999));
    }
    _mockController.add(_mockProfiles);

    final sb = _supabase;
    if (sb != null) {
      try {
        await sb
            .from('follows')
            .delete()
            .eq('follower_id', userId)
            .eq('following_id', targetUserId)
            .timeout(const Duration(seconds: 4));
      } catch (_) {}

      try {
        final targetData = await sb
            .from('profiles')
            .select('followers_count')
            .eq('id', targetUserId)
            .maybeSingle()
            .timeout(const Duration(seconds: 4));
        final currentFollowers =
            (((targetData?['followers_count'] as num?)?.toInt() ?? 1) - 1)
                .clamp(0, 999999);
        await sb.from('profiles').update({
          'followers_count': currentFollowers,
        }).eq('id', targetUserId).timeout(const Duration(seconds: 4));
      } catch (_) {}

      try {
        final myData = await sb
            .from('profiles')
            .select('following_count')
            .eq('id', userId)
            .maybeSingle()
            .timeout(const Duration(seconds: 4));
        final currentFollowing =
            (((myData?['following_count'] as num?)?.toInt() ?? 1) - 1)
                .clamp(0, 999999);
        await sb.from('profiles').update({
          'following_count': currentFollowing,
        }).eq('id', userId).timeout(const Duration(seconds: 4));
      } catch (_) {}
    }
  }

  @override
  Future<bool> isFollowing(String userId, String targetUserId) async {
    if (_mockFollows.contains('${userId}_$targetUserId')) return true;

    final sb = _supabase;
    if (sb != null) {
      try {
        final res = await sb
            .from('follows')
            .select('id')
            .eq('follower_id', userId)
            .eq('following_id', targetUserId)
            .maybeSingle()
            .timeout(const Duration(seconds: 4));
        if (res != null) {
          _mockFollows.add('${userId}_$targetUserId');
          return true;
        }
      } catch (_) {}
    }
    return false;
  }
}
