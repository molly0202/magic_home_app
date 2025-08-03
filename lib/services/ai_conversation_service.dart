import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math' as math;
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

enum MessageType { user, ai, system }

class ChatMessage {
  final String content;
  final MessageType type;
  final DateTime timestamp;
  final String? imageUrl;
  final Map<String, dynamic>? metadata;

  ChatMessage({
    required this.content,
    required this.type,
    required this.timestamp,
    this.imageUrl,
    this.metadata,
  });
}

class ConversationState {
  String? serviceCategory;
  String? serviceDescription;
  String? problemDescription;
  List<String> mediaUrls;
  Map<String, dynamic>? availability;
  String? location;
  Map<String, dynamic>? priceEstimate;
  List<String> tags;
  int conversationStep;
  Map<String, dynamic> extractedInfo;
  List<Map<String, String>> conversationHistory;
  bool photoUploadRequested;
  bool photosUploaded;
  bool calendarRequested;
  bool availabilitySet;

  ConversationState({
    this.serviceCategory,
    this.serviceDescription,
    this.problemDescription,
    List<String>? mediaUrls,
    this.availability,
    this.location,
    this.priceEstimate,
    List<String>? tags,
    this.conversationStep = 0,
    Map<String, dynamic>? extractedInfo,
    List<Map<String, String>>? conversationHistory,
    this.photoUploadRequested = false,
    this.photosUploaded = false,
    this.calendarRequested = false,
    this.availabilitySet = false,
  }) : mediaUrls = mediaUrls ?? <String>[],
       tags = tags ?? <String>[],
       extractedInfo = extractedInfo ?? <String, dynamic>{},
       conversationHistory = conversationHistory ?? <Map<String, String>>[];
}

class AIConversationService {
  static final AIConversationService _instance = AIConversationService._internal();
  factory AIConversationService() => _instance;
  AIConversationService._internal();
  
  // Enhanced system prompt optimized for Gemini and Magic Home app
  static const String _systemPrompt = '''
You are Gemini, the AI assistant for Magic Home - a premium home services platform. Your role is to help users create detailed service requests through natural conversation.

CONVERSATION FLOW:
1. GREETING & DISCOVERY (Steps 0-1): Understand what home service they need
2. DETAILS GATHERING (Step 2): Get specific details about their problem
3. VISUAL DOCUMENTATION (Step 3): Encourage photo uploads for better quotes
4. SCHEDULING (Step 4): Help them set availability preferences
5. SUMMARY & CONFIRMATION (Step 5): Present complete service request

SERVICE CATEGORIES: Cleaning, Plumbing, Electrical, HVAC, Appliance Repair, Handyman, Landscaping, Pest Control, Roofing, Painting

CONVERSATION GUIDELINES:
- Be conversational, helpful, and professional
- Ask ONE focused question at a time
- Use the user's name when provided
- For photo uploads: "Great! You can upload photos now to help providers give accurate quotes."
- For scheduling: "Perfect! Let's set up your availability. You can select preferred dates and times."
- Keep responses under 2 sentences for mobile users
- Use encouraging language like "Perfect!", "Great!", "Excellent!"

CONTEXT AWARENESS:
- Track conversation step and adapt responses accordingly
- Reference previous information shared by the user
- Maintain context across the entire conversation
- If user mentions urgency, acknowledge it in responses

RESPONSE STYLE:
- Professional yet friendly tone
- Mobile-optimized (concise but complete)
- Action-oriented when appropriate
- Empathetic to user's service needs

Remember: You're helping create a service request that will connect them with qualified professionals. Focus on gathering the essential information to ensure they get the best possible service experience.
''';

  ConversationState _currentState = ConversationState();
  final List<ChatMessage> _messages = [];
  final List<Map<String, dynamic>> _conversationContext = [];

  List<ChatMessage> get messages => _messages;
  ConversationState get currentState => _currentState;

  void startConversation() {
    _currentState = ConversationState();
    _messages.clear();
    _conversationContext.clear();
    
    // Add system context for Gemini
    _conversationContext.add({
      'role': 'system',
      'content': _systemPrompt,
    });
    
    _addMessage(ChatMessage(
      content: "Hi! I'm your Magic Home assistant. I'm here to help you connect with the perfect service professional. What kind of home service do you need today?",
      type: MessageType.ai,
      timestamp: DateTime.now(),
    ));
  }

  void resetConversation() {
    _currentState = ConversationState();
    _messages.clear();
    _conversationContext.clear();
  }

  void _addMessage(ChatMessage message) {
    _messages.add(message);
  }

  Future<String> processUserInput(String input) async {
    _addMessage(ChatMessage(
      content: input,
      type: MessageType.user,
      timestamp: DateTime.now(),
    ));

    // Add user message to conversation context
    _conversationContext.add({
      'role': 'user',
      'content': input,
    });

    // Detect and update service category if not already set
    if (_currentState.serviceCategory == null) {
      String lowerInput = input.toLowerCase();
      _currentState.serviceCategory = _detectServiceCategory(lowerInput);
      if (_currentState.serviceCategory != null) {
        _currentState.serviceDescription = input;
        // Don't advance step here - let _generateStepBasedResponse handle step progression
      }
    }

    String response = await _generateGeminiResponse(input);
    
    _addMessage(ChatMessage(
      content: response,
      type: MessageType.ai,
      timestamp: DateTime.now(),
    ));

    // Add AI response to conversation context
    _conversationContext.add({
      'role': 'assistant',
      'content': response,
    });

    // Update conversation state based on response content
    _updateConversationState(input, response);

    return response;
  }

  Future<String> _generateGeminiResponse(String input) async {
    try {
      // Check if ANY AI is configured, not just Gemini
      if (!ApiConfig.isAnyAiConfigured) {
        return await _generateMockResponse(input);
      }
      
      // If Gemini is specifically configured, use it
      if (ApiConfig.isGeminiConfigured) {
        return await _callGeminiAPI(input);
      }
      
      // If other AI is configured but not Gemini, fall back to mock
      return await _generateMockResponse(input);
    } catch (e) {
      print('Error generating Gemini response: $e');
      return _generateFallbackResponse(input);
    }
  }

  Future<String> _callGeminiAPI(String input) async {
    int retryCount = 0;
    
    while (retryCount < ApiConfig.maxRetries) {
      try {
        // Build comprehensive conversation context
        final conversationContext = _buildEnhancedConversationContext();
        final userMessage = _buildContextualUserMessage(input);
        
        final messages = [
          {
            "role": "user",
            "parts": [{"text": "$_systemPrompt\n\n$conversationContext\n\nUser: $userMessage"}]
          }
        ];

        final response = await http.post(
          Uri.parse('${ApiConfig.geminiBaseUrl}?key=${ApiConfig.geminiApiKey}'),
          headers: {
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'contents': messages,
            'generationConfig': {
              'temperature': 0.7,
              'topK': 40,
              'topP': 0.95,
              'maxOutputTokens': ApiConfig.maxTokens,
              'stopSequences': [],
            },
            'safetySettings': [
              {
                'category': 'HARM_CATEGORY_HARASSMENT',
                'threshold': 'BLOCK_MEDIUM_AND_ABOVE'
              },
              {
                'category': 'HARM_CATEGORY_HATE_SPEECH',
                'threshold': 'BLOCK_MEDIUM_AND_ABOVE'
              }
            ],
          }),
        ).timeout(ApiConfig.apiTimeout);

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data['candidates'] != null && data['candidates'].isNotEmpty) {
            final responseText = data['candidates'][0]['content']['parts'][0]['text'];
            print('Gemini API call successful');
            
            // Advance conversation step based on response content
            _advanceConversationStep(responseText);
            
            return responseText.trim();
          }
        }
        
        throw Exception('Gemini API error: ${response.statusCode} - ${response.body}');
        
      } catch (e) {
        retryCount++;
        print('Gemini API call attempt $retryCount failed: $e');
        
        if (retryCount >= ApiConfig.maxRetries) {
          print('Max retries reached, falling back to mock response');
          return _generateFallbackResponse(input);
        }
        
        // Wait before retry with exponential backoff
        await Future.delayed(Duration(seconds: retryCount * 2));
      }
    }
    
    return _generateFallbackResponse(input);
  }

  String _buildEnhancedConversationContext() {
    String context = "CURRENT CONVERSATION STATE:\n";
    context += "- Step: ${_currentState.conversationStep}\n";
    
    if (_currentState.serviceCategory != null) {
      context += "- Service Category: ${_currentState.serviceCategory}\n";
    }
    if (_currentState.serviceDescription != null) {
      context += "- Service Description: ${_currentState.serviceDescription}\n";
    }
    if (_currentState.problemDescription != null) {
      context += "- Problem Details: ${_currentState.problemDescription}\n";
    }
    
    context += "- Photo Upload Requested: ${_currentState.photoUploadRequested}\n";
    context += "- Photos Uploaded: ${_currentState.photosUploaded}\n";
    context += "- Calendar Requested: ${_currentState.calendarRequested}\n";
    context += "- Availability Set: ${_currentState.availabilitySet}\n";
    
    if (_currentState.mediaUrls.isNotEmpty) {
      context += "- Photos: ${_currentState.mediaUrls.length} uploaded\n";
    }
    
    // Add recent conversation history (last 3 exchanges)
    if (_conversationContext.length > 1) {
      context += "\nRECENT CONVERSATION:\n";
      final recentMessages = _conversationContext.take(_conversationContext.length).toList();
      for (var i = math.max(0, recentMessages.length - 6); i < recentMessages.length; i++) {
        final message = recentMessages[i];
        if (message['role'] != 'system') {
          context += "${message['role']}: ${message['content']}\n";
        }
      }
    }
    
    return context;
  }

  String _buildContextualUserMessage(String input) {
    String contextualMessage = input;
    
    // Add step context for Gemini to understand flow
    switch (_currentState.conversationStep) {
      case 0:
        contextualMessage += " [User is starting conversation - needs service discovery]";
        break;
      case 1:
        contextualMessage += " [User has described service need - gather more details]";
        break;
      case 2:
        contextualMessage += " [User provided details - suggest photo upload]";
        break;
      case 3:
        contextualMessage += " [User responding about photos - may need scheduling next]";
        break;
      case 4:
        contextualMessage += " [User discussing scheduling - prepare for summary]";
        break;
      default:
        contextualMessage += " [Continue conversation naturally]";
    }
    
    return contextualMessage;
  }

  void _advanceConversationStep(String response) {
    String lowerResponse = response.toLowerCase();
    
    // Advance step based on response content
    if (_currentState.conversationStep < 2 && 
        (lowerResponse.contains('tell me more') || lowerResponse.contains('details') || lowerResponse.contains('specific'))) {
      _currentState.conversationStep = 2;
    } else if (_currentState.conversationStep < 3 && 
               (lowerResponse.contains('photo') || lowerResponse.contains('upload') || lowerResponse.contains('picture'))) {
      _currentState.conversationStep = 3;
    } else if (_currentState.conversationStep < 4 && 
               (lowerResponse.contains('schedule') || lowerResponse.contains('availability') || lowerResponse.contains('time'))) {
      _currentState.conversationStep = 4;
    } else if (_currentState.conversationStep < 5 && 
               (lowerResponse.contains('summary') || lowerResponse.contains('request'))) {
      _currentState.conversationStep = 5;
    }
  }

  // Test method for Gemini API connectivity with enhanced testing
  static Future<bool> testGeminiConnection() async {
    if (!ApiConfig.isGeminiConfigured) {
      print('Gemini API not configured');
      return false;
    }
    
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.geminiBaseUrl}?key=${ApiConfig.geminiApiKey}'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'contents': [
            {
              "role": "user",
              "parts": [{"text": "Hello Gemini, this is a connection test for Magic Home app. Please respond with 'Test successful' to confirm you're working."}]
            }
          ],
          'generationConfig': {
            'temperature': 0.1,
            'maxOutputTokens': 20,
          },
        }),
      ).timeout(ApiConfig.apiTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['candidates'] != null && data['candidates'].isNotEmpty) {
          final responseText = data['candidates'][0]['content']['parts'][0]['text'];
          print('Gemini test response: $responseText');
          return true;
        }
      }
      
      print('Gemini test failed with status: ${response.statusCode}');
      print('Response body: ${response.body}');
      return false;
      
    } catch (e) {
      print('Gemini test connection error: $e');
      return false;
    }
  }

  Future<String> _generateMockResponse(String input) async {
    await Future.delayed(const Duration(milliseconds: 500));
    
    String lowerInput = input.toLowerCase();
    
    // Use step-based progression when no AI is configured
    if (!ApiConfig.isAnyAiConfigured) {
      return _generateStepBasedResponse(input, lowerInput);
    }
    
    // Enhanced mock responses that mirror Gemini style (when AI is configured but fails)
    if (_currentState.conversationStep < 2) {
      if (_currentState.serviceCategory == null) {
        _currentState.serviceCategory = _detectServiceCategory(lowerInput);
        _currentState.serviceDescription = input;
        _currentState.conversationStep = 1;
        
        return "Perfect! I understand you need ${_currentState.serviceCategory} service. Could you tell me more details about what specifically needs to be done?";
      } else {
        _currentState.problemDescription = input;
        _currentState.conversationStep = 2;
        
        return "Got it! That gives me a clear picture. Would you like to upload some photos? They really help our service providers give you the most accurate quote.";
      }
    }
    
    // Continue with existing mock flow
    if (_currentState.conversationStep == 2) {
      // Always show photo upload, regardless of user response
      _currentState.photoUploadRequested = true;
      _currentState.conversationStep = 3;
      return "Great! You can upload photos now to help providers give accurate quotes.";
    }
    
    if (_currentState.conversationStep == 3) {
      _currentState.photosUploaded = true;
      _currentState.conversationStep = 4;
      return "Excellent photos! Now let's set up your availability. When works best for you?";
    }
    
    if (_currentState.conversationStep == 4) {
      _currentState.calendarRequested = true;
      _currentState.conversationStep = 5;
      return "Perfect! Please select your preferred dates and times. You can choose multiple options for flexibility.";
    }
    
    if (_currentState.conversationStep == 5) {
      _currentState.availabilitySet = true;
      _currentState.conversationStep = 6;
      return "Excellent! I have all the information needed. Here's your complete service request summary.";
    }
    
    return "Thank you for that information! Is there anything else you'd like to add to your service request?";
  }

  String _generateStepBasedResponse(String input, String lowerInput) {
    // Step-based progression for when no AI is configured
    switch (_currentState.conversationStep) {
      case 0:
        // Initial service discovery
        _currentState.serviceCategory = _detectServiceCategory(lowerInput);
        _currentState.serviceDescription = input;
        _currentState.conversationStep = 1;
        return "Thank you! I understand you need ${_currentState.serviceCategory ?? 'home service'} help. Could you provide more details about what specifically needs to be done?";
        
      case 1:
        // Gathering details
        _currentState.problemDescription = input;
        _currentState.conversationStep = 2;
        return "Got it! Now I have a better understanding of your needs. Would you like to upload some photos to help our service providers?";
        
      case 2:
        // Photo upload - always show regardless of user response
        _currentState.conversationStep = 3;
        return "Great! Please upload your photos. This will help providers give you accurate quotes.";
        
      case 3:
        // After photo upload (this will be triggered by UI, but we need a response)
        _currentState.conversationStep = 4;
        return "Perfect! Your photos have been uploaded. Now let's schedule your service. When would work best for you?";
        
      case 4:
        // After calendar selection
        _currentState.conversationStep = 5;
        return "Excellent! I have your availability preferences. Let me prepare a summary of your service request.";
        
      case 5:
        // Summary phase
        _currentState.conversationStep = 6;
        return "Your service request is complete! Here's a summary of everything we discussed.";
        
      default:
        return "Thank you! Is there anything else you'd like to add or modify in your service request?";
    }
  }

  String _detectServiceCategory(String input) {
    // Use scoring system for better category detection
    final categoryScores = _calculateCategoryScores(input);
    
    // Find the category with the highest score
    String? bestCategory;
    double highestScore = 0.0;
    
    categoryScores.forEach((category, score) {
      if (score > highestScore) {
        highestScore = score;
        bestCategory = category;
      }
    });
    
    // Return best category if confidence is high enough, otherwise default to Handyman
    return (highestScore > 0.3) ? bestCategory! : 'Handyman';
  }

  Map<String, double> _calculateCategoryScores(String input) {
    String lowerInput = input.toLowerCase();
    Map<String, double> scores = {};
    
    // Define keywords and their weights for each category
    Map<String, Map<String, double>> categoryKeywords = {
      'Cleaning': {
        'clean': 1.0, 'dirty': 0.8, 'dust': 0.7, 'vacuum': 0.9, 'maid': 1.0, 'tidy': 0.8,
        'sanitize': 0.9, 'scrub': 0.8, 'sweep': 0.7, 'mop': 0.8, 'disinfect': 0.9,
        'housekeeping': 1.0, 'spotless': 0.8, 'polish': 0.7, 'organize': 0.6
      },
      'Plumbing': {
        'leak': 1.0, 'pipe': 0.9, 'drain': 0.9, 'toilet': 0.8, 'faucet': 0.8, 'plumb': 1.0,
        'water': 0.6, 'sink': 0.7, 'shower': 0.8, 'bathtub': 0.8, 'clog': 0.9,
        'pressure': 0.7, 'hot water': 0.8, 'cold water': 0.7, 'sewer': 0.9
      },
      'Electrical': {
        'electric': 1.0, 'power': 0.8, 'outlet': 0.9, 'light': 0.7, 'wiring': 1.0, 'switch': 0.8,
        'circuit': 0.9, 'breaker': 0.9, 'voltage': 0.8, 'amperage': 0.8, 'shock': 0.7,
        'electrician': 1.0, 'generator': 0.8, 'panel': 0.8, 'meter': 0.7
      },
      'HVAC': {
        'heat': 0.8, 'cool': 0.8, 'hvac': 1.0, 'furnace': 0.9, 'air conditioning': 1.0, 'ac': 0.8,
        'temperature': 0.7, 'thermostat': 0.9, 'duct': 0.8, 'ventilation': 0.9,
        'filter': 0.7, 'humidity': 0.7, 'refrigerant': 0.9, 'compressor': 0.8
      },
      'Appliance Repair': {
        'appliance': 1.0, 'refrigerator': 0.9, 'washer': 0.9, 'dryer': 0.9, 'dishwasher': 0.9, 'oven': 0.8,
        'microwave': 0.8, 'stove': 0.8, 'freezer': 0.8, 'garbage disposal': 0.9,
        'repair': 0.7, 'broken': 0.6, 'not working': 0.7, 'malfunctioning': 0.8
      },
      'Landscaping': {
        'lawn': 0.9, 'garden': 0.9, 'yard': 0.8, 'tree': 0.7, 'landscape': 1.0, 'grass': 0.8,
        'mowing': 0.9, 'trimming': 0.8, 'pruning': 0.8, 'weeds': 0.7, 'mulch': 0.7,
        'irrigation': 0.8, 'sprinkler': 0.8, 'hedge': 0.7, 'bushes': 0.7
      },
      'Pest Control': {
        'pest': 1.0, 'bug': 0.8, 'ant': 0.8, 'roach': 0.9, 'exterminate': 1.0,
        'insect': 0.8, 'mice': 0.9, 'rat': 0.9, 'termite': 0.9, 'spider': 0.7,
        'cockroach': 0.9, 'infestation': 1.0, 'fumigation': 1.0, 'poison': 0.7
      },
      'Roofing': {
        'roof': 1.0, 'gutter': 0.8, 'shingle': 0.9, 'leak': 0.7, 'tile': 0.7,
        'rafter': 0.8, 'chimney': 0.7, 'flashing': 0.8, 'eaves': 0.7, 'downspout': 0.8
      },
      'Painting': {
        'paint': 1.0, 'wall': 0.7, 'color': 0.6, 'brush': 0.8, 'roller': 0.8,
        'primer': 0.9, 'ceiling': 0.7, 'trim': 0.7, 'exterior': 0.8, 'interior': 0.8
      },
      'Handyman': {
        'fix': 0.8, 'repair': 0.7, 'install': 0.8, 'replace': 0.7, 'maintenance': 0.8,
        'broken': 0.6, 'assembly': 0.7, 'mounting': 0.7, 'general': 0.6
      }
    };
    
    // Initialize all category scores to 0
    categoryKeywords.keys.forEach((category) {
      scores[category] = 0.0;
    });
    
    // Calculate scores based on keyword matches
    categoryKeywords.forEach((category, keywords) {
      keywords.forEach((keyword, weight) {
        if (lowerInput.contains(keyword)) {
          scores[category] = scores[category]! + weight;
          
          // Bonus for exact word matches (not just substring)
          List<String> words = lowerInput.split(' ');
          if (words.contains(keyword)) {
            scores[category] = scores[category]! + (weight * 0.5);
          }
        }
      });
      
      // Normalize score by number of keywords to prevent bias toward categories with more keywords
      if (keywords.isNotEmpty) {
        scores[category] = scores[category]! / keywords.length;
      }
    });
    
    // Apply category-specific rules and bonuses
    _applyCategoryRules(lowerInput, scores);
    
    return scores;
  }

  void _applyCategoryRules(String lowerInput, Map<String, double> scores) {
    // Specific rules to improve detection accuracy
    
    // Water-related issues could be plumbing
    if (lowerInput.contains('water') && (lowerInput.contains('leak') || lowerInput.contains('drip') || lowerInput.contains('flow'))) {
      scores['Plumbing'] = scores['Plumbing']! + 0.5;
    }
    
    // Electrical safety keywords
    if (lowerInput.contains('spark') || lowerInput.contains('shock') || lowerInput.contains('burn')) {
      scores['Electrical'] = scores['Electrical']! + 0.3;
    }
    
    // HVAC temperature issues
    if ((lowerInput.contains('hot') || lowerInput.contains('cold')) && 
        (lowerInput.contains('house') || lowerInput.contains('room') || lowerInput.contains('temperature'))) {
      scores['HVAC'] = scores['HVAC']! + 0.4;
    }
    
    // Outdoor work likely landscaping
    if (lowerInput.contains('outdoor') || lowerInput.contains('outside') || lowerInput.contains('backyard') || lowerInput.contains('front yard')) {
      scores['Landscaping'] = scores['Landscaping']! + 0.3;
    }
    
    // Kitchen appliances
    if (lowerInput.contains('kitchen') && 
        (lowerInput.contains('appliance') || lowerInput.contains('not working') || lowerInput.contains('broken'))) {
      scores['Appliance Repair'] = scores['Appliance Repair']! + 0.4;
    }
    
    // General maintenance tasks default to handyman
    if (lowerInput.contains('small') || lowerInput.contains('minor') || lowerInput.contains('quick')) {
      scores['Handyman'] = scores['Handyman']! + 0.2;
    }
  }

  // Method to get category scores for debugging or display
  Map<String, double> getCategoryScores(String input) {
    return _calculateCategoryScores(input);
  }

  void _updateConversationState(String input, String response) {
    String lowerResponse = response.toLowerCase();
    String lowerInput = input.toLowerCase();
    
    // Enhanced state detection
    if (!_currentState.photoUploadRequested && 
        (lowerResponse.contains('upload') || lowerResponse.contains('photo') || lowerResponse.contains('picture'))) {
      _currentState.photoUploadRequested = true;
    }
    
    if (!_currentState.calendarRequested && 
        (lowerResponse.contains('schedule') || lowerResponse.contains('availability') || 
         lowerResponse.contains('time') || lowerResponse.contains('calendar'))) {
      _currentState.calendarRequested = true;
    }
    
    if (!_currentState.availabilitySet && 
        (lowerResponse.contains('summary') || lowerResponse.contains('complete') ||
         lowerResponse.contains('all the information'))) {
      _currentState.availabilitySet = true;
    }
    
    // Update problem description if user provides more details
    if (_currentState.conversationStep >= 1 && _currentState.problemDescription == null && 
        input.length > 10 && !lowerInput.contains('yes') && !lowerInput.contains('no')) {
      _currentState.problemDescription = input;
    }
  }

  String _generateFallbackResponse(String input) {
    // More intelligent fallback based on conversation state
    if (_currentState.serviceCategory == null) {
      return "I'd love to help you with your home service needs! Could you tell me what type of service you're looking for?";
    } else {
      return "I want to make sure I help you get the best ${_currentState.serviceCategory} service. Could you share a bit more about what you need?";
    }
  }

  // Enhanced callback methods with Gemini integration
  void onPhotoUploaded(String photoUrl) {
    _currentState.mediaUrls.add(photoUrl);
    if (!_currentState.photosUploaded) {
      _currentState.photosUploaded = true;
      _currentState.conversationStep = 4;
      
      // Add contextual AI message
      _addMessage(ChatMessage(
        content: "Perfect! I can see your photo. This will really help our service providers understand your needs. Now let's set up your availability!",
        type: MessageType.ai,
        timestamp: DateTime.now(),
      ));
    }
  }

  void onAvailabilitySelected(Map<String, dynamic> availability) {
    _currentState.availability = availability;
    if (!_currentState.availabilitySet) {
      _currentState.availabilitySet = true;
      _currentState.conversationStep = 5;
      
      // Add contextual AI message
      _addMessage(ChatMessage(
        content: "Excellent! I have your availability preferences. You're all set! Here's your complete service request summary.",
        type: MessageType.ai,
        timestamp: DateTime.now(),
      ));
    }
  }

  // Enhanced service request summary
  Map<String, dynamic> getServiceRequestSummary() {
    return {
      'serviceCategory': _currentState.serviceCategory ?? 'General Service',
      'serviceDescription': _currentState.serviceDescription ?? '',
      'problemDescription': _currentState.problemDescription ?? '',
      'mediaUrls': _currentState.mediaUrls,
      'availability': _currentState.availability ?? {},
      'location': _currentState.location ?? '',
      'tags': _currentState.tags,
      'extractedInfo': _currentState.extractedInfo,
      'conversationStep': _currentState.conversationStep,
      'timestamp': DateTime.now().toIso8601String(),
      'isComplete': _currentState.availabilitySet && _currentState.serviceCategory != null,
    };
  }
} 