import 'package:dio/dio.dart';
import '../../../core/config/app_config.dart';

class LlmSearchService {
  final Dio _dio;

  LlmSearchService({Dio? dio})
    : _dio = dio ??
          Dio(
            BaseOptions(
              baseUrl: AppConfig.llmBaseUrl,
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 15),
              headers: {
                'Authorization': 'Bearer ${AppConfig.llmApiKey}',
                'Content-Type': 'application/json',
              },
            ),
          );

  /// Rewrites a fuzzy/typo user query into the most likely exact anime title
  /// (romaji or English). Returns null on any failure.
  Future<String?> normalizeQuery(String userQuery) async {
    if (AppConfig.llmApiKey.isEmpty) return null;
    if (userQuery.trim().length < 3) return null;
    try {
      final res = await _dio.post('/chat/completions', data: {
        'model': AppConfig.llmModel,
        'messages': [
          {
            'role': 'system',
            'content':
                'You are an anime title resolver. Given a possibly misspelled, '
                'partial, romanized Japanese, Indonesian, or English anime name, '
                'reply with ONLY the most likely official anime title in romaji '
                'or English. No explanation, no quotes, one line only. '
                'If unsure, reply with your best guess.',
          },
          {'role': 'user', 'content': userQuery.trim()},
        ],
        'max_tokens': 60,
        'temperature': 0.2,
      });

      final choices = res.data['choices'] as List<dynamic>?;
      if (choices == null || choices.isEmpty) return null;
      final message = choices[0]['message'] as Map<String, dynamic>?;
      final content = message?['content'] as String?;
      if (content == null) return null;
      final cleaned =
          content.replaceAll(RegExp(r'["\n]'), '').trim();
      if (cleaned.isEmpty || cleaned.length > 100) return null;
      return cleaned;
    } catch (_) {
      return null;
    }
  }
}