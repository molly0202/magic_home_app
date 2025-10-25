import 'elevenlabs_secrets.dart';

/// ElevenLabs Configuration
/// 
/// This file contains configuration constants for ElevenLabs integration.
/// API credentials are stored in elevenlabs_secrets.dart (gitignored).
class ElevenLabsConfig {
  // API Configuration (from secrets file)
  static String get apiKey => ElevenLabsSecrets.apiKey;
  static String get agentId => ElevenLabsSecrets.agentId;
  
  // WebSocket Configuration  
  static const String baseUrl = 'wss://api.elevenlabs.io/v1/convai/conversation';
  static const int reconnectAttempts = 3;
  static const Duration reconnectDelay = Duration(seconds: 2);
  static const Duration messageTimeout = Duration(seconds: 30);
  
  // Audio Configuration
  static const int sampleRate = 16000;
  static const int channels = 1;
  static const String audioFormat = 'pcm_16000';
  
  // Voice Settings
  static const double stability = 0.5;
  static const double similarityBoost = 0.5;
  static const String voiceId = 'default';
  
  // Conversation Settings
  static const int maxConversationLength = 300; // seconds
  static const int maxRetries = 3;
  static const Duration listeningTimeout = Duration(seconds: 10);
  static const Duration speakingTimeout = Duration(seconds: 30);
  
  // Turn Detection Settings (to prevent agent from talking during silence)
  static const int silenceThresholdMs = 1000; // 800ms of silence before considering turn complete
  static const int maxDurationMs = 180000; // Maximum recording duration (3 minutes)
  
  /// Validate if configuration is properly set
  static bool get isConfigured => ElevenLabsSecrets.isConfigured;
  
  /// Get WebSocket URL with agent ID and turn detection settings
  static String getWebSocketUrl(String? customAgentId) {
    final effectiveAgentId = customAgentId ?? agentId;
    // Add turn detection parameters to prevent agent from talking during silence
    // silence_threshold_ms: How long to wait for silence before considering turn complete
    // max_duration_ms: Maximum duration for a single turn (prevents infinite talking)
    return '$baseUrl?agent_id=$effectiveAgentId&api_key=$apiKey&silence_threshold_ms=$silenceThresholdMs&max_duration_ms=$maxDurationMs';
  }
  
  /// Get HTTP headers for API requests
  static Map<String, String> get headers => {
    'xi-api-key': apiKey,
    'Content-Type': 'application/json',
  };
  
  /// Get voice settings
  static Map<String, dynamic> get voiceSettings => {
    'stability': stability,
    'similarity_boost': similarityBoost,
  };
  
  /// Development configuration
  static bool get isDevConfigured => ElevenLabsSecrets.isDevConfigured;
  static String get devApiKey => ElevenLabsSecrets.devApiKey;
  static String get devAgentId => ElevenLabsSecrets.devAgentId;
}
