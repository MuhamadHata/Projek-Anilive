import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/app_config.dart';

class SupabaseService {
  static bool _initialized = false;
  static bool get isInitialized => _initialized;

  static SupabaseClient? get client {
    if (!_initialized) return null;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  /// Inisialisasi cepat non-blocking Supabase
  static Future<void> initialize() async {
    if (!AppConfig.useSupabase) {
      _initialized = false;
      return;
    }

    final url = AppConfig.supabaseUrl;
    final anonKey = AppConfig.supabaseAnonKey;

    // Jika URL kosong atau masih dummy/placeholder, tetap jalan di mode offline mock yang aman
    if (url.isEmpty || anonKey.isEmpty || url.contains('xyzcompany') || anonKey.startsWith('eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...')) {
      if (kDebugMode) {
        print('Supabase: Running in Fast Offline Fallback Mode (No valid credentials configured).');
      }
      _initialized = false;
      return;
    }

    try {
      await Supabase.initialize(
        url: url,
        // ignore: deprecated_member_use
        anonKey: anonKey,
        debug: kDebugMode,
      );
      _initialized = true;
      if (kDebugMode) {
        print('Supabase: Initialized successfully with project URL: $url');
      }
    } catch (e) {
      _initialized = false;
      if (kDebugMode) {
        print('Supabase init warning (running in safe/fallback mode): $e');
      }
    }
  }
}
