import '../../core/config/app_config.dart';
import '../services/supabase_service.dart';

class ModerationService {
  static final List<String> _bannedWords = [
    'kasar',
    'anjing',
    'babi',
    'kontol',
    'memek',
    'bangsat',
    'spam',
  ];

  static bool containsProfanity(String text) {
    final lower = text.toLowerCase();
    for (final word in _bannedWords) {
      if (lower.contains(word)) return true;
    }
    return false;
  }

  static String sanitize(String text) {
    String res = text;
    for (final word in _bannedWords) {
      res = res.replaceAll(RegExp(word, caseSensitive: false), '***');
    }
    return res;
  }

  static Future<void> reportContent({
    required String contentType, // 'review' | 'comment' | 'chat'
    required String contentId,
    required String reason,
    required String reportedByUserId,
  }) async {
    if (!AppConfig.useSupabase || !SupabaseService.isInitialized) return;

    try {
      await SupabaseService.client?.from('reports').insert({
        'content_type': contentType,
        'content_id': contentId,
        'reason': reason,
        'reported_by': reportedByUserId,
        'status': 'pending',
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (_) {}
  }
}
