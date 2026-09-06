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
    if (!AppConfig.useSupabase || !SupabaseService.isInitialized || _supabase == null) {
      _mockProfiles.putIfAbsent(
        userId,
        () => UserProfile(
          id: userId,
          username: 'anime_user',
          displayName: 'Anime User',
          bio: 'Penggemar anime dan reviewer komunitas.',
          followersCount: 12,
          followingCount: 8,
          animeCompletedCount: 42,
          createdAt: DateTime.now().subtract(const Duration(days: 90)),
        ),
      );
      _mockController.add(_mockProfiles);
      return _mockController.stream
          .map((profiles) => profiles[userId])
          .asBroadcastStream();
    }

    // Auto-create profil jika belum ada
    _ensureProfileExists(userId);

    return _supabase
        .from('profiles')
        .stream(primaryKey: ['id'])
        .eq('id', userId)
        .map((data) {
          if (data.isEmpty) {
            return _mockProfiles[userId];
          }
          return UserProfile.fromMap(data.first, userId);
        })
        .handleError((_) => _mockProfiles[userId]);
  }

  Future<void> _ensureProfileExists(String userId) async {
    if (_supabase == null) return;
    try {
      final existing = await _supabase
          .from('profiles')
          .select('id')
          .eq('id', userId)
          .maybeSingle();

      if (existing == null) {
        await _supabase.from('profiles').upsert({
          'id': userId,
          'username': 'user_${userId.substring(0, 5.clamp(0, userId.length))}',
          'display_name': 'Pengguna Anilive',
          'followers_count': 0,
          'following_count': 0,
          'anime_completed_count': 0,
          'created_at': DateTime.now().toIso8601String(),
        });
      }
    } catch (_) {}
  }

  @override
  Future<void> updateProfile(UserProfile profile) async {
    _mockProfiles[profile.id] = profile;
    _mockController.add(_mockProfiles);

    if (_supabase != null) {
      try {
        await _supabase.from('profiles').upsert(profile.toSupabaseMap());
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

    if (_supabase != null) {
      // 1. Catat relasi follow ke tabel follows
      try {
        await _supabase.from('follows').upsert({
          'follower_id': userId,
          'following_id': targetUserId,
          'created_at': DateTime.now().toIso8601String(),
        });
      } catch (_) {}

      // 2. Tambah followers_count pada target profile secara realtime
      try {
        final targetData = await _supabase
            .from('profiles')
            .select('followers_count')
            .eq('id', targetUserId)
            .maybeSingle();
        final currentFollowers =
            ((targetData?['followers_count'] as num?)?.toInt() ?? 0) + 1;
        await _supabase.from('profiles').update({
          'followers_count': currentFollowers,
        }).eq('id', targetUserId);
      } catch (_) {}

      // 3. Tambah following_count pada current user profile secara realtime
      try {
        final myData = await _supabase
            .from('profiles')
            .select('following_count')
            .eq('id', userId)
            .maybeSingle();
        final currentFollowing =
            ((myData?['following_count'] as num?)?.toInt() ?? 0) + 1;
        await _supabase.from('profiles').update({
          'following_count': currentFollowing,
        }).eq('id', userId);
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

    if (_supabase != null) {
      // 1. Hapus relasi dari tabel follows
      try {
        await _supabase
            .from('follows')
            .delete()
            .eq('follower_id', userId)
            .eq('following_id', targetUserId);
      } catch (_) {}

      // 2. Kurangi followers_count pada target profile
      try {
        final targetData = await _supabase
            .from('profiles')
            .select('followers_count')
            .eq('id', targetUserId)
            .maybeSingle();
        final currentFollowers =
            (((targetData?['followers_count'] as num?)?.toInt() ?? 1) - 1)
                .clamp(0, 999999);
        await _supabase.from('profiles').update({
          'followers_count': currentFollowers,
        }).eq('id', targetUserId);
      } catch (_) {}

      // 3. Kurangi following_count pada current user profile
      try {
        final myData = await _supabase
            .from('profiles')
            .select('following_count')
            .eq('id', userId)
            .maybeSingle();
        final currentFollowing =
            (((myData?['following_count'] as num?)?.toInt() ?? 1) - 1)
                .clamp(0, 999999);
        await _supabase.from('profiles').update({
          'following_count': currentFollowing,
        }).eq('id', userId);
      } catch (_) {}
    }
  }

  @override
  Future<bool> isFollowing(String userId, String targetUserId) async {
    if (_mockFollows.contains('${userId}_$targetUserId')) return true;

    if (_supabase != null) {
      try {
        final res = await _supabase
            .from('follows')
            .select('id')
            .eq('follower_id', userId)
            .eq('following_id', targetUserId)
            .maybeSingle();
        if (res != null) {
          _mockFollows.add('${userId}_$targetUserId');
          return true;
        }
      } catch (_) {}
    }
    return false;
  }
}
