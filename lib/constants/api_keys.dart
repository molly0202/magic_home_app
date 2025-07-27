import '../config/secrets.dart';

class APIKeys {
  // Google Maps API Key
  // Get it from: https://console.cloud.google.com/
  // Enable: Geocoding API, Places API
  static String get GOOGLE_MAPS_API_KEY => Secrets.googleMapsApiKey;

  // OpenAI API Key
  // Get it from: https://platform.openai.com/api-keys
  // Required for: GPT-4 conversation, price estimation
  static String get OPENAI_API_KEY => Secrets.openAIApiKey;

  // Optional: Add environment-specific configurations
  static String getOpenAIKey() {
    // You might want to load this from secure storage or environment variables
    const String envKey = String.fromEnvironment('OPENAI_API_KEY');
    return envKey.isNotEmpty ? envKey : OPENAI_API_KEY;
  }

  static String getGoogleMapsKey() {
    const String envKey = String.fromEnvironment('GOOGLE_MAPS_API_KEY');
    return envKey.isNotEmpty ? envKey : GOOGLE_MAPS_API_KEY;
  }
} 