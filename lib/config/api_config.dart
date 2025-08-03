class ApiConfig {
  // Gemini API Configuration
  static const String geminiApiKey = 'YOUR_GEMINI_API_KEY';  // Temporarily disabled for testing
  static const String geminiBaseUrl = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent';
  
  // Other API configurations can be added here
  static const String openAiApiKey = 'YOUR_OPENAI_API_KEY';
  static const String openAiBaseUrl = 'https://api.openai.com/v1/chat/completions';
  
  // Environment check
  static bool get isGeminiConfigured => geminiApiKey != 'YOUR_GEMINI_API_KEY' && geminiApiKey.isNotEmpty;
  static bool get isOpenAiConfigured => openAiApiKey != 'YOUR_OPENAI_API_KEY' && openAiApiKey.isNotEmpty;
  
  // Check if any AI service is configured
  static bool get isAnyAiConfigured => isGeminiConfigured || isOpenAiConfigured;
  
  // API timeouts and limits
  static const Duration apiTimeout = Duration(seconds: 30);
  static const int maxRetries = 3;
  static const int maxTokens = 300;
} 