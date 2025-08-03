import 'package:flutter_test/flutter_test.dart';
import 'package:magic_home_app/services/ai_conversation_service.dart';
import 'package:magic_home_app/config/api_config.dart';

void main() {
  group('AIConversationService Functional Tests', () {
    late AIConversationService aiService;

    setUp(() {
      aiService = AIConversationService();
    });

    tearDown(() {
      aiService.resetConversation();
    });

    test('should initialize with empty state', () {
      expect(aiService.messages.length, 0);
      expect(aiService.currentState.conversationStep, 0);
      expect(aiService.currentState.serviceCategory, null);
    });

    test('should start conversation with greeting message', () {
      aiService.startConversation();
      
      expect(aiService.messages.length, 1);
      expect(aiService.messages.first.type, MessageType.ai);
      expect(aiService.messages.first.content, contains('Magic Home assistant'));
    });

    test('should handle conversation flow with responses', () async {
      // Start conversation
      aiService.startConversation();
      
      // Step 1: Service request - just check response is not empty and no error
      final response1 = await aiService.processUserInput('I need cleaning service');
      expect(response1, isNotEmpty);
      expect(response1, isA<String>());
      expect(response1.toLowerCase(), isNot(contains('error')));
      
      // Check that conversation progressed
      expect(aiService.currentState.conversationStep, greaterThan(0));
      
      // Step 2: Details - just check successful response
      final response2 = await aiService.processUserInput('Deep cleaning of my house');
      expect(response2, isNotEmpty);
      expect(response2, isA<String>());
      expect(response2.toLowerCase(), isNot(contains('error')));
      
      // Step 3: Photo request - just check successful response
      final response3 = await aiService.processUserInput('yes, I want to upload photos');
      expect(response3, isNotEmpty);
      expect(response3, isA<String>());
      expect(response3.toLowerCase(), isNot(contains('error')));
    });

    test('should handle photo upload callback', () {
      const testUrl = 'https://example.com/test.jpg';
      
      aiService.onPhotoUploaded(testUrl);
      
      expect(aiService.currentState.mediaUrls.contains(testUrl), true);
      expect(aiService.currentState.photosUploaded, true);
    });

    test('should handle availability selection callback', () {
      final testAvailability = {
        'selectedDates': ['2024-01-15', '2024-01-16'],
        'preferredTime': 'morning',
      };
      
      aiService.onAvailabilitySelected(testAvailability);
      
      expect(aiService.currentState.availability, testAvailability);
      expect(aiService.currentState.availabilitySet, true);
    });

    test('should generate service request summary', () {
      // Set up conversation state
      aiService.currentState.serviceCategory = 'cleaning';
      aiService.currentState.serviceDescription = 'House cleaning';
      aiService.currentState.problemDescription = 'Deep cleaning needed';
      aiService.currentState.mediaUrls.add('https://example.com/photo.jpg');
      
      final summary = aiService.getServiceRequestSummary();
      
      expect(summary['serviceCategory'], 'cleaning');
      expect(summary['serviceDescription'], 'House cleaning');
      expect(summary['problemDescription'], 'Deep cleaning needed');
      expect(summary['mediaUrls'], contains('https://example.com/photo.jpg'));
    });

    test('should handle service requests successfully', () async {
      aiService.startConversation();
      
      // Test cleaning detection - just check response is successful
      final cleaningResponse = await aiService.processUserInput('I need cleaning service');
      expect(cleaningResponse, isNotEmpty);
      expect(cleaningResponse, isA<String>());
      expect(cleaningResponse.toLowerCase(), isNot(contains('error')));
      
      // Reset and test plumbing
      aiService.resetConversation();
      aiService.startConversation();
      final plumbingResponse = await aiService.processUserInput('My pipe is leaking');
      expect(plumbingResponse, isNotEmpty);
      expect(plumbingResponse, isA<String>());
      expect(plumbingResponse.toLowerCase(), isNot(contains('error')));
      
      // Reset and test electrical
      aiService.resetConversation();
      aiService.startConversation();
      final electricalResponse = await aiService.processUserInput('Electrical outlet not working');
      expect(electricalResponse, isNotEmpty);
      expect(electricalResponse, isA<String>());
      expect(electricalResponse.toLowerCase(), isNot(contains('error')));
    });
  });

  group('Gemini API Functional Tests', () {
    test('should test Gemini connection - returns boolean result', () async {
      print('Testing Gemini API connection...');
      print('API Key configured: ${ApiConfig.isGeminiConfigured}');
      print('Base URL: ${ApiConfig.geminiBaseUrl}');
      
      final result = await AIConversationService.testGeminiConnection();
      
      expect(result, isA<bool>());
      
      if (ApiConfig.isGeminiConfigured) {
        print('Result with configured API: $result');
        // If API is configured, we expect either true (success) or false (failure)
        // But it should not throw an exception
      } else {
        print('Result with unconfigured API: $result');
        // Should return false when API key is not configured
        expect(result, false);
      }
    });

    test('should handle real conversation with Gemini or mock', () async {
      print('Testing conversation flow...');
      
      final aiService = AIConversationService();
      aiService.startConversation();
      
      // Test a simple cleaning request - just verify we get a response without error
      final response = await aiService.processUserInput('I need house cleaning');
      
      // Should get some response
      expect(response, isNotEmpty);
      expect(response, isA<String>());
      expect(response.toLowerCase(), isNot(contains('error')));
      
      print('Input: "I need house cleaning"');
      print('Response: "$response"');
      
      // Should be in a valid conversation state
      expect(aiService.currentState.conversationStep, greaterThanOrEqualTo(0));
    });

    test('should handle multiple conversation turns', () async {
      print('Testing multi-turn conversation...');
      
      final aiService = AIConversationService();
      aiService.startConversation();
      
      // Turn 1: Initial request
      final response1 = await aiService.processUserInput('I need plumbing help');
      expect(response1, isNotEmpty);
      expect(response1, isA<String>());
      expect(response1.toLowerCase(), isNot(contains('error')));
      
      print('Turn 1 - Input: "I need plumbing help"');
      print('Turn 1 - Response: "$response1"');
      
      // Turn 2: Provide details
      final response2 = await aiService.processUserInput('My kitchen sink is clogged');
      expect(response2, isNotEmpty);
      expect(response2, isA<String>());
      expect(response2.toLowerCase(), isNot(contains('error')));
      
      print('Turn 2 - Input: "My kitchen sink is clogged"');
      print('Turn 2 - Response: "$response2"');
      
      // Turn 3: Agree to photos
      final response3 = await aiService.processUserInput('yes, I can take photos');
      expect(response3, isNotEmpty);
      expect(response3, isA<String>());
      expect(response3.toLowerCase(), isNot(contains('error')));
      
      print('Turn 3 - Input: "yes, I can take photos"');
      print('Turn 3 - Response: "$response3"');
      
      // Verify conversation is progressing
      expect(aiService.currentState.conversationStep, greaterThan(0));
    });
  });

  group('Configuration Tests', () {
    test('should have correct API configuration', () {
      expect(ApiConfig.geminiBaseUrl, isNotEmpty);
      expect(ApiConfig.apiTimeout, const Duration(seconds: 30));
      expect(ApiConfig.maxRetries, 3);
      expect(ApiConfig.maxTokens, 300);
    });

    test('should detect if Gemini is configured correctly', () {
      final isConfigured = ApiConfig.isGeminiConfigured;
      expect(isConfigured, isA<bool>());
      
      print('Gemini configured: $isConfigured');
      print('API Key: ${isConfigured ? "Present" : "Not configured"}');
      
      // API key should not be the placeholder value if configured
      if (isConfigured) {
        expect(ApiConfig.geminiApiKey, isNot('YOUR_GEMINI_API_KEY'));
        expect(ApiConfig.geminiApiKey, isNotEmpty);
      } else {
        expect(ApiConfig.geminiApiKey, 'YOUR_GEMINI_API_KEY');
      }
    });
  });
} 