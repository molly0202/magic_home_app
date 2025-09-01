import 'package:translator/translator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'dart:developer' as developer;

class TranslationService extends ChangeNotifier {
  static final TranslationService _instance = TranslationService._internal();
  factory TranslationService() => _instance;
  TranslationService._internal();

  final GoogleTranslator _translator = GoogleTranslator();
  String _currentLanguage = 'en';
  bool _isTranslationEnabled = false;
  
  // Supported languages
  static const Map<String, String> supportedLanguages = {
    'en': 'English',
    'zh': 'Chinese',
    'es': 'Spanish',
  };

  // Language codes for Google Translate
  static const Map<String, String> languageCodes = {
    'en': 'en',
    'zh': 'zh-cn',
    'es': 'es',
  };

  String get currentLanguage => _currentLanguage;
  bool get isTranslationEnabled => _isTranslationEnabled;
  
  // Initialize translation service
  Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _currentLanguage = prefs.getString('selected_language') ?? 'en';
      _isTranslationEnabled = prefs.getBool('translation_enabled') ?? false;
      developer.log('Translation service initialized. Language: $_currentLanguage, Enabled: $_isTranslationEnabled');
    } catch (e) {
      developer.log('Error initializing translation service: $e');
    }
  }

  // Set current language
  Future<void> setLanguage(String languageCode) async {
    try {
      _currentLanguage = languageCode;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('selected_language', languageCode);
      developer.log('Language set to: $languageCode');
      notifyListeners(); // Notify all listeners of the change
    } catch (e) {
      developer.log('Error setting language: $e');
    }
  }

  // Toggle translation on/off
  Future<void> toggleTranslation() async {
    try {
      _isTranslationEnabled = !_isTranslationEnabled;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('translation_enabled', _isTranslationEnabled);
      developer.log('Translation toggled: $_isTranslationEnabled');
      notifyListeners(); // Notify all listeners of the change
    } catch (e) {
      developer.log('Error toggling translation: $e');
    }
  }

  // Translate text
  Future<String> translateText(String text, {String? targetLanguage}) async {
    if (!_isTranslationEnabled || text.isEmpty) {
      return text;
    }

    final target = targetLanguage ?? _currentLanguage;
    
    // If target language is English, return original
    if (target == 'en') {
      return text;
    }

    try {
      // Translate to target language (auto-detect source)
      final translation = await _translator.translate(
        text,
        to: languageCodes[target] ?? target,
      );
      
      developer.log('Translated "$text" to ${languageCodes[target]}: "${translation.text}"');
      return translation.text;
    } catch (e) {
      developer.log('Translation error: $e');
      return text; // Return original text if translation fails
    }
  }

  // Batch translate multiple texts
  Future<List<String>> translateTexts(List<String> texts, {String? targetLanguage}) async {
    if (!_isTranslationEnabled) {
      return texts;
    }

    final results = <String>[];
    for (final text in texts) {
      final translated = await translateText(text, targetLanguage: targetLanguage);
      results.add(translated);
    }
    return results;
  }

  // Auto-detect and translate to current language
  Future<String> autoTranslate(String text) async {
    return await translateText(text, targetLanguage: _currentLanguage);
  }

  // Get language display name
  String getLanguageDisplayName(String code) {
    return supportedLanguages[code] ?? code.toUpperCase();
  }

  // Get all supported languages
  List<MapEntry<String, String>> getSupportedLanguages() {
    return supportedLanguages.entries.toList();
  }
}
