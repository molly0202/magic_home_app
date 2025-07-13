import 'dart:convert';
import 'package:http/http.dart' as http;

// EXAMPLE: Real AI/LLM Integration for Production Use
// This shows how to integrate with actual AI services for much better understanding

class LLMAIService {
  // Configuration - Add your API keys here
  static const String _openAIApiKey = 'your-openai-api-key-here';
  static const String _openAIBaseUrl = 'https://api.openai.com/v1/chat/completions';
  
  // Alternative: Google Gemini API
  static const String _geminiApiKey = 'your-gemini-api-key-here';
  static const String _geminiBaseUrl = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent';
  
  // Alternative: Anthropic Claude API
  static const String _claudeApiKey = 'your-claude-api-key-here';
  static const String _claudeBaseUrl = 'https://api.anthropic.com/v1/messages';

  // System prompt that defines the AI's role and knowledge
  static const String _systemPrompt = '''
You are an expert home service AI assistant for Magic Home app. Your role is to:

1. UNDERSTAND user service requests with high accuracy
2. CATEGORIZE services into: HVAC, Plumbing, Electrical, Cleaning, Appliance Repair, Handyman, Landscaping
3. ASK relevant follow-up questions to gather complete information
4. GUIDE users through photo upload and availability selection
5. ESTIMATE fair market prices based on service details

Service Categories and Keywords:
- HVAC: heating, cooling, furnace, AC, air conditioning, thermostat, ductwork, boiler, heat pump
- Plumbing: leak, pipe, drain, toilet, faucet, sink, shower, water, sewer, clog
- Electrical: power, outlet, switch, light, wiring, breaker, circuit, electrical panel
- Cleaning: dirty, messy, clean, dust, vacuum, deep clean, sanitize, maid service
- Appliance: refrigerator, washer, dryer, dishwasher, oven, microwave, broken appliance
- Handyman: repair, fix, install, drywall, painting, door, window, general maintenance
- Landscaping: lawn, garden, yard, tree, grass, outdoor, irrigation, landscaping

Always respond in a helpful, professional tone. Keep responses concise but informative.
''';

  // OpenAI GPT Integration
  static Future<String> generateResponseWithOpenAI(String userMessage, List<Map<String, String>> conversationHistory) async {
    try {
      final messages = [
        {'role': 'system', 'content': _systemPrompt},
        ...conversationHistory,
        {'role': 'user', 'content': userMessage},
      ];

      final response = await http.post(
        Uri.parse(_openAIBaseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_openAIApiKey',
        },
        body: jsonEncode({
          'model': 'gpt-3.5-turbo', // or 'gpt-4' for better results
          'messages': messages,
          'max_tokens': 300,
          'temperature': 0.7,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['choices'][0]['message']['content'];
      } else {
        throw Exception('OpenAI API error: ${response.statusCode}');
      }
    } catch (e) {
      print('Error calling OpenAI API: $e');
      return 'I apologize, but I\'m having trouble processing your request right now. Please try again.';
    }
  }

  // Google Gemini Integration
  static Future<String> generateResponseWithGemini(String userMessage) async {
    try {
      final prompt = '$_systemPrompt\n\nUser: $userMessage\nAssistant:';
      
      final response = await http.post(
        Uri.parse('$_geminiBaseUrl?key=$_geminiApiKey'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'contents': [{
            'parts': [{'text': prompt}]
          }],
          'generationConfig': {
            'temperature': 0.7,
            'maxOutputTokens': 300,
          }
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['candidates'][0]['content']['parts'][0]['text'];
      } else {
        throw Exception('Gemini API error: ${response.statusCode}');
      }
    } catch (e) {
      print('Error calling Gemini API: $e');
      return 'I apologize, but I\'m having trouble processing your request right now. Please try again.';
    }
  }

  // Anthropic Claude Integration
  static Future<String> generateResponseWithClaude(String userMessage) async {
    try {
      final response = await http.post(
        Uri.parse(_claudeBaseUrl),
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': _claudeApiKey,
          'anthropic-version': '2023-06-01',
        },
        body: jsonEncode({
          'model': 'claude-3-sonnet-20240229',
          'max_tokens': 300,
          'system': _systemPrompt,
          'messages': [
            {'role': 'user', 'content': userMessage}
          ],
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['content'][0]['text'];
      } else {
        throw Exception('Claude API error: ${response.statusCode}');
      }
    } catch (e) {
      print('Error calling Claude API: $e');
      return 'I apologize, but I\'m having trouble processing your request right now. Please try again.';
    }
  }

  // Service categorization using AI
  static Future<String> categorizeServiceWithAI(String userMessage) async {
    const prompt = '''
Based on this user message, identify the most appropriate service category.
Return ONLY the category name: HVAC, Plumbing, Electrical, Cleaning, Appliance, Handyman, or Landscaping.

User message: "$userMessage"

Category:''';

    try {
      // Use your preferred AI service here
      final response = await generateResponseWithOpenAI(prompt, []);
      return response.trim().toLowerCase();
    } catch (e) {
      print('Error categorizing with AI: $e');
      return 'handyman'; // fallback
    }
  }

  // Price estimation using AI
  static Future<Map<String, dynamic>> estimatePriceWithAI(String serviceDescription, String category, List<String> tags) async {
    final prompt = '''
Estimate a fair market price range for this home service:
- Service: $serviceDescription
- Category: $category
- Tags: ${tags.join(', ')}

Provide a JSON response with min, max, average prices in USD, and confidence level (low/medium/high).
Example: {"min": 100, "max": 300, "average": 200, "confidence": "medium", "factors": ["complexity", "time required"]}
''';

    try {
      final response = await generateResponseWithOpenAI(prompt, []);
      // Parse AI response to extract price data
      return jsonDecode(response);
    } catch (e) {
      print('Error estimating price with AI: $e');
      return {
        'min': 50,
        'max': 200,
        'average': 100,
        'confidence': 'low',
        'factors': ['Unable to analyze with AI']
      };
    }
  }
}

// USAGE INSTRUCTIONS:
/*
1. Add dependencies to pubspec.yaml:
   dependencies:
     http: ^1.1.0

2. Get API keys:
   - OpenAI: https://platform.openai.com/api-keys
   - Google Gemini: https://ai.google.dev/
   - Anthropic Claude: https://www.anthropic.com/api

3. Replace the AI service calls in AIConversationService:
   
   Future<String> _generateResponse(String input) async {
     // Replace rule-based logic with:
     return await LLMAIService.generateResponseWithOpenAI(input, _conversationHistory);
   }

4. Handle conversation context:
   - Maintain conversation history for better context
   - Pass previous messages to the AI for continuity

5. Add error handling and fallbacks:
   - Network connectivity checks
   - Rate limiting
   - Fallback to rule-based system if AI fails

6. Consider costs:
   - OpenAI: ~$0.002 per 1K tokens
   - Gemini: Free tier available
   - Monitor usage and implement caching
*/ 