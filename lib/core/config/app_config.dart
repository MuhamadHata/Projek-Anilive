class AppConfig {
  static const bool useSupabase = bool.fromEnvironment(
    'USE_SUPABASE',
    defaultValue: true,
  );

  // Supabase Credentials (disediakan via .env atau --dart-define)
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );

  // Google OAuth Web Client ID
  static const String googleWebClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
    defaultValue: '',
  );

  static const String jikanBaseUrl = 'https://api.jikan.moe/v4';

  // LLM / Semantic Search Configuration (Together AI / OpenAI-compatible API)
  static const String llmBaseUrl = String.fromEnvironment(
    'LLM_BASE_URL',
    defaultValue: 'https://api.together.xyz/v1',
  );
  static const String llmApiKey = String.fromEnvironment(
    'LLM_API_KEY',
    defaultValue: '',
  );
  static const String llmModel = String.fromEnvironment(
    'LLM_MODEL',
    defaultValue: 'meta-llama/Llama-3-8b-chat-hf',
  );

  // Giphy API Configuration
  static const String giphyApiKey = String.fromEnvironment(
    'GIPHY_API_KEY',
    defaultValue: '',
  );
}
