import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/config/app_config.dart';
import '../../../core/services/supabase_service.dart';
import '../domain/notification_model.dart';

abstract class NotificationRepository {
  Stream<List<AppNotification>> watchNotifications(String userId);
  Future<void> sendNotification(AppNotification notification);
  Future<void> markAsRead(String notificationId);
  Future<void> markAllAsRead(String userId);
  Future<void> deleteNotification(String notificationId);
}

class NotificationRepositoryImpl implements NotificationRepository {
  final SupabaseClient? _supabase;
  static final List<AppNotification> _mockNotifications = [];

  static final _mockStreamController =
      StreamController<List<AppNotification>>.broadcast();

  NotificationRepositoryImpl({SupabaseClient? client})
      : _supabase = (AppConfig.useSupabase && SupabaseService.isInitialized)
            ? (client ?? SupabaseService.client)
            : null;

  @override
  Stream<List<AppNotification>> watchNotifications(String userId) {
    if (!AppConfig.useSupabase || !SupabaseService.isInitialized || _supabase == null) {
      final initial = _mockNotifications
          .where((n) => n.recipientUserId == userId)
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      return _mockStreamController.stream
          .map((all) {
            final list = all.where((n) => n.recipientUserId == userId).toList();
            list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
            return list;
          })
          .asBroadcastStream()
          .transform(
            StreamTransformer<List<AppNotification>, List<AppNotification>>.fromHandlers(
              handleData: (data, sink) => sink.add(data),
            ),
          )
          .startWith(initial);
    }

    return _supabase
        .from('notifications')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .map((data) {
          final list = data
              .where((n) => n['recipient_user_id'] == userId)
              .map((n) => AppNotification.fromMap(n, n['id']?.toString() ?? ''))
              .toList();

          return list;
        })
        .handleError((_) => <AppNotification>[]);
  }

  @override
  Future<void> sendNotification(AppNotification notification) async {
    _mockNotifications.removeWhere((n) => n.id == notification.id);
    _mockNotifications.insert(0, notification);
    _mockStreamController.add(List.from(_mockNotifications));

    if (_supabase != null) {
      try {
        await _supabase.from('notifications').insert(notification.toSupabaseMap());
      } catch (_) {}
    }
  }

  @override
  Future<void> markAsRead(String notificationId) async {
    final index =
        _mockNotifications.indexWhere((n) => n.id == notificationId);
    if (index != -1) {
      _mockNotifications[index] =
          _mockNotifications[index].copyWith(isRead: true);
      _mockStreamController.add(List.from(_mockNotifications));
    }

    if (_supabase != null) {
      try {
        await _supabase
            .from('notifications')
            .update({'is_read': true})
            .eq('id', notificationId);
      } catch (_) {}
    }
  }

  @override
  Future<void> markAllAsRead(String userId) async {
    for (var i = 0; i < _mockNotifications.length; i++) {
      if (_mockNotifications[i].recipientUserId == userId ||
          _mockNotifications[i].recipientUserId == 'mock_user_123') {
        _mockNotifications[i] =
            _mockNotifications[i].copyWith(isRead: true);
      }
    }
    _mockStreamController.add(List.from(_mockNotifications));

    if (_supabase != null) {
      try {
        await _supabase
            .from('notifications')
            .update({'is_read': true})
            .eq('recipient_user_id', userId);
      } catch (_) {}
    }
  }

  @override
  Future<void> deleteNotification(String notificationId) async {
    _mockNotifications.removeWhere((n) => n.id == notificationId);
    _mockStreamController.add(List.from(_mockNotifications));

    if (_supabase != null) {
      try {
        await _supabase
            .from('notifications')
            .delete()
            .eq('id', notificationId);
      } catch (_) {}
    }
  }
}

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepositoryImpl();
});

final userNotificationsProvider = StreamProvider.autoDispose
    .family<List<AppNotification>, String>((ref, userId) {
  return ref.watch(notificationRepositoryProvider).watchNotifications(userId);
});

final unreadNotificationsCountProvider = Provider.autoDispose
    .family<int, String>((ref, userId) {
  final notifs = ref.watch(userNotificationsProvider(userId)).value ?? [];
  return notifs.where((n) => !n.isRead).length;
});

extension _StreamExtensions<T> on Stream<T> {
  Stream<T> startWith(T initial) async* {
    yield initial;
    yield* this;
  }
}
