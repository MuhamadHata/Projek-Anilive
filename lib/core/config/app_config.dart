class AppConfig {
  static const bool useSupabase = bool.fromEnvironment(
    'USE_SUPABASE',
    defaultValue: true,
  );

  // Supabase Credentials (default ke kredensial proyek Supabase Anilive)
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://tihkckfzshynedtalxsr.supabase.co',
  );
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_4b5PDmIEx8ec71kFixy8EQ_YH01pwj0',
  );

  // Google OAuth Web Client ID
  static const String googleWebClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
    defaultValue:
        '685061689158-edj18sj1ddntd93fs171o9js4hb56rq0.apps.googleusercontent.com',
  );

  static const String jikanBaseUrl = 'https://api.jikan.moe/v4';

  // LLM / Semantic Search Configuration (Together AI / OpenAI-compatible API)
  static const String llmBaseUrl = String.fromEnvironment(
    'LLM_BASE_URL',
    defaultValue: 'https://api.together.xyz/v1',
  );
  static const String llmApiKey = String.fromEnvironment(
    'LLM_API_KEY',
    defaultValue: '8700b4128e7e435a9fa3b4f3772b62af.2oB3TmwCjmmm2DdNc0Zu-sKo',
  );
  static const String llmModel = String.fromEnvironment(
    'LLM_MODEL',
    defaultValue: 'meta-llama/Llama-3-8b-chat-hf',
  );

  // Giphy API Configuration
  static const String giphyApiKey = String.fromEnvironment(
    'GIPHY_API_KEY',
    defaultValue: 'QtBRcbxBKJbdEHBqPd9XEyXb4R8YH05R',
  );
}
