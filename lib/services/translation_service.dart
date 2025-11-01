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

  // Custom translation overrides for better accuracy
  static const Map<String, Map<String, String>> customTranslations = {
    'zh': {
      'Earned': '赚得',
      'Bidding Opportunities': '新请求',
      'New Requests': '新请求',
      '🔥 New Requests': '🔥 新请求',
      'No upcoming tasks': '没有即将到来的任务',
      'No Active New Requests': '没有活跃的新请求',
      'URGENT': '紧急',
      'Time Remaining': '剩余时间',
      'BID': '投标',
      'Reply': '回复',
      'Unknown': '未知',
      'Service Opportunity': '服务机会',
      'Cannot Submit Bid': '无法提交报价',
      'Go Back': '返回',
      'Submit Your Bid': '提交您的报价',
      'Your Quote': '您的报价',
      'Provide Direct Quote': '提供直接报价',
      'I can provide a price estimate now': '我现在可以提供价格估算',
      'Need Phone Consultation': '需要电话咨询',
      'I need to discuss details before pricing': '我需要在定价前讨论细节',
      'Need In-Person Consultation': '需要现场咨询',
      'I need to visit the location before pricing': '我需要在定价前实地查看',
    },
    'es': {
      'Earned': 'Ganado',
      'New Requests': 'Nuevas Solicitudes',
      '🔥 New Requests': '🔥 Nuevas Solicitudes',
      'URGENT': 'URGENTE',
      'Time Remaining': 'Tiempo Restante',
      'Reply': 'Responder',
      'Unknown': 'Desconocido',
      'Service Opportunity': 'Oportunidad de Servicio',
      'Cannot Submit Bid': 'No se puede enviar oferta',
      'Go Back': 'Volver',
      'Submit Your Bid': 'Enviar su Oferta',
      'Your Quote': 'Su Cotización',
      'Provide Direct Quote': 'Proporcionar Cotización Directa',
      'Need Phone Consultation': 'Necesito Consulta Telefónica',
      'Need In-Person Consultation': 'Necesito Consulta en Persona',
    },
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

    // Check for custom translations first
    if (customTranslations.containsKey(target) && 
        customTranslations[target]!.containsKey(text)) {
      final customTranslation = customTranslations[target]![text]!;
      developer.log('Using custom translation for "$text" to $target: "$customTranslation"');
      return customTranslation;
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
