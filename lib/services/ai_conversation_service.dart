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
  // Core Identifiers
  String? requestId;              // Firestore document ID
  String? userId;                 // Customer's user ID
  
  // Service Information  
  String? serviceCategory;        // AI-categorized service type
  String? description;            // AI-refined description
  List<String> mediaUrls;         // Photos/videos from intake
  List<String>? tags;             // AI-generated tags
  
  // Customer Details
  String? address;                // Full service address
  String? phoneNumber;            // Contact number
  Map<String, dynamic>? location; // GPS coordinates + formatted address
  
  // Availability & Scheduling
  Map<String, dynamic>? userAvailability; // Calendar + time slots
  
  // Preferences & Metadata
  Map<String, dynamic>? preferences; // Budget, quality, timing
  int? priority;                  // 1-5 urgency level
  DateTime? createdAt;            // Creation timestamp
  String? status;                 // Workflow status
  
  // Additional fields for conversation flow
  int conversationStep;
  Map<String, dynamic> extractedInfo;
  List<Map<String, String>> conversationHistory;
  bool photoUploadRequested;
  bool photosUploaded;
  bool calendarRequested;
  bool availabilitySet;
  List<String> serviceQuestions;
  Map<String, String> serviceAnswers;
  String? serviceDescription;
  String? problemDescription;
  String? customerName;
  Map<String, dynamic>? locationDetails;
  Map<String, dynamic>? priceEstimate;

  ConversationState({
    this.requestId,
    this.userId,
    this.serviceCategory,
    this.description,
    List<String>? mediaUrls,
    this.tags,
    this.address,
    this.phoneNumber,
    this.location,
    this.userAvailability,
    this.preferences,
    this.priority,
    this.createdAt,
    this.status,
    this.conversationStep = 0,
    Map<String, dynamic>? extractedInfo,
    List<Map<String, String>>? conversationHistory,
    this.photoUploadRequested = false,
    this.photosUploaded = false,
    this.calendarRequested = false,
    this.availabilitySet = false,
    List<String>? serviceQuestions,
    Map<String, String>? serviceAnswers,
    this.serviceDescription,
    this.problemDescription,
    this.customerName,
    this.locationDetails,
    this.priceEstimate,
  }) : mediaUrls = mediaUrls ?? <String>[],
       extractedInfo = extractedInfo ?? <String, dynamic>{},
       conversationHistory = conversationHistory ?? <Map<String, String>>[],
       serviceQuestions = serviceQuestions ?? <String>[],
       serviceAnswers = serviceAnswers ?? <String, String>{};
}

class AIConversationService {
  static final AIConversationService _instance = AIConversationService._internal();
  factory AIConversationService() => _instance;
  AIConversationService._internal();
  
  // Callbacks for UI interactions
  Function(Map<String, dynamic>)? onServiceRequestComplete;
  VoidCallback? onPhotoUploadRequested;
  VoidCallback? onCalendarRequested;
  
  // Enhanced system prompt optimized for Gemini and Magic Home app
  static const String _systemPrompt = '''
You are Magic Home assistant. Help users create service requests efficiently.

CONVERSATION FLOW - FOLLOW STRICTLY:
1. DISCOVER (Step 0-1): What service do you need?
2. DETAILS (Step 2): Get specific problem details
3. PHOTOS (Step 3): Guide to photo upload - MAX 2 attempts then proceed
4. SCHEDULE (Step 4): Set availability - MAX 2 attempts then proceed  
5. CONFIRM (Step 5): Show summary

SERVICE CATEGORIES: Cleaning, Plumbing, Electrical, HVAC, Appliance Repair, Handyman, Landscaping, Pest Control, Roofing, Painting

RULES:
- Keep responses SHORT (1 sentence max)
- Ask ONE question at a time
- NEVER repeat the same question
- Progress steps automatically after 2 attempts
- Step 3: Say "Photos help! Upload now or we'll continue" then TRIGGER photo upload
- Step 4: Say "When works for you?" then TRIGGER calendar
- If user says "skip" or "later" - move to next step immediately

STEP TRIGGERS:
- Step 3: After asking about photos MAX 2 times, automatically call photo upload UI
- Step 4: After asking about schedule MAX 2 times, automatically call calendar UI
- Step 5: Auto-generate summary

RESPONSE STYLE:
- Concise and direct
- Friendly but brief
- No repetition
- Progress conversation forward

Remember: Be brief, avoid repetition, trigger UI functions, keep moving forward.
''';

  ConversationState _currentState = ConversationState();
  final List<ChatMessage> _messages = [];
  final List<Map<String, dynamic>> _conversationContext = [];

  List<ChatMessage> get messages => _messages;
  ConversationState get currentState => _currentState;

  void   startConversation() {
    _currentState = ConversationState();
    _messages.clear();
    _conversationContext.clear();
    
    // Add system context for Gemini
    _conversationContext.add({
      'role': 'system',
      'content': _systemPrompt,
    });
    
    _addMessage(ChatMessage(
      content: "Hi! What home service do you need?",
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
        _currentState.description = input;
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

    // Check if conversation is complete and trigger summary
    if (isConversationComplete()) {
      _onConversationComplete();
    }

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
    
    // Track attempts for this step
    String stepKey = 'step_${_currentState.conversationStep}_attempts';
    int attempts = _currentState.extractedInfo[stepKey] ?? 0;
    
    // Add concise step context
    switch (_currentState.conversationStep) {
      case 0:
        contextualMessage += " [Step 0: Identify service - be brief]";
        break;
      case 1:
        contextualMessage += " [Step 1: Get details - ask 1 question only, attempt $attempts/2]";
        break;
      case 2:
        contextualMessage += " [Step 2: Move to photos immediately - be brief]";
        break;
      case 3:
        contextualMessage += " [Step 3: Photo upload - attempt $attempts/2, if >=2 say 'Photos help! Upload now or continue?' and trigger upload]";
        break;
      case 4:
        contextualMessage += " [Step 4: Scheduling - attempt $attempts/2, if >=2 say 'When works?' and trigger calendar]";
        break;
      case 5:
        contextualMessage += " [Step 5: Show summary immediately]";
        break;
    }
    
    // Add force progression hints
    if (attempts >= 2) {
      contextualMessage += " [MAX ATTEMPTS REACHED - PROGRESS TO NEXT STEP]";
    }
    
    return contextualMessage;
  }

  void _advanceConversationStep(String response) {
    String lowerResponse = response.toLowerCase();
    
    // Track attempts to prevent repetition
    String stepKey = 'step_${_currentState.conversationStep}_attempts';
    int attempts = _currentState.extractedInfo[stepKey] ?? 0;
    attempts++;
    _currentState.extractedInfo[stepKey] = attempts;
    
    // Force progression after max attempts
    switch (_currentState.conversationStep) {
      case 0:
        if (_currentState.serviceCategory != null) {
          _currentState.conversationStep = 1;
        }
        break;
      case 1:
        if (lowerResponse.contains('tell me more') || lowerResponse.contains('details') || attempts >= 2) {
          _currentState.conversationStep = 2;
        }
        break;
      case 2:
        // Always move to photo after details
        _currentState.conversationStep = 3;
        _currentState.photoUploadRequested = true;
        break;
      case 3:
        // Force move to scheduling after 2 photo attempts OR if user wants to skip
        if (attempts >= 2 || lowerResponse.contains('skip') || lowerResponse.contains('later') || 
            lowerResponse.contains('schedule') || lowerResponse.contains('continue')) {
          _currentState.conversationStep = 4;
          _currentState.calendarRequested = true;
          // Trigger photo upload UI if not triggered yet
          _triggerPhotoUpload();
        }
        break;
      case 4:
        // Force move to summary after 2 scheduling attempts OR if availability is set
        if (attempts >= 2 || _currentState.availabilitySet || lowerResponse.contains('summary')) {
          _currentState.conversationStep = 5;
          // Trigger calendar UI if not triggered yet
          _triggerCalendar();
        }
        break;
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
          
          return "Got it! Photos help with accurate quotes. Upload some?";
        }
    }
    
    // More concise mock flow with attempt tracking
    String stepKey = 'step_${_currentState.conversationStep}_attempts';
    int attempts = _currentState.extractedInfo[stepKey] ?? 0;
    
    if (_currentState.conversationStep == 2) {
      _currentState.photoUploadRequested = true;
      _currentState.conversationStep = 3;
      return "Got it! Photos help providers quote accurately. Upload now?";
    }
    
    if (_currentState.conversationStep == 3) {
      if (attempts >= 2 || lowerInput.contains('skip') || lowerInput.contains('later')) {
        _currentState.conversationStep = 4;
        _currentState.calendarRequested = true;
        _triggerPhotoUpload(); // Trigger the actual photo upload UI
        return "When works for you?";
      } else {
        _triggerPhotoUpload();
        return "Photos help! Upload now or we'll continue.";
      }
    }
    
    if (_currentState.conversationStep == 4) {
      if (attempts >= 2 || _currentState.availabilitySet) {
        _currentState.userAvailability = {'preference': input, 'timestamp': DateTime.now().toIso8601String()};
        _currentState.availabilitySet = true;
        _currentState.conversationStep = 5;
        _triggerCalendar(); // Trigger the actual calendar UI
        String summary = _generateServiceRequestSummary();
        return "Perfect! Here's your summary:\n\n$summary";
      } else {
        _triggerCalendar();
        return "When works best? Morning, afternoon, weekend?";
      }
    }
    
    if (_currentState.conversationStep == 5) {
      return "All set! Ready to connect with professionals.";
    }
    
    return "Thank you for that information! Is there anything else you'd like to add to your service request?";
  }

  String _generateStepBasedResponse(String input, String lowerInput) {
    // 8-step progression for when no AI is configured
    switch (_currentState.conversationStep) {
      case 0:
        // Step 1: Greeting User
        _currentState.serviceCategory = _detectServiceCategory(lowerInput);
        _currentState.description = input;
        _currentState.conversationStep = 1;
        return "Hi! I understand you need ${_currentState.serviceCategory ?? 'home service'} help. What specifically needs to be done?";
        
      case 1:
        // Step 2: Service Details - Category-specific structured questions
        _currentState.conversationStep = 2;
        return _getServiceSpecificQuestions();
        
      case 2:
        // Continue collecting service details
        _currentState.serviceAnswers[_getCurrentQuestionKey()] = input;
        if (_needMoreServiceDetails()) {
          return _getNextServiceQuestion();
        } else {
          _currentState.conversationStep = 3;
          return "Perfect! Now let's do a visual assessment. Would you like to upload photos or a short video (max 30 seconds) to help our professionals better understand your needs? This is optional but highly recommended.";
        }
        
      case 3:
        // Step 3: Visual Assessment - Photo/Video uploads with attempts tracking
        String stepKey = 'step_3_attempts';
        int attempts = _currentState.serviceAnswers[stepKey] != null ? int.parse(_currentState.serviceAnswers[stepKey]!) : 0;
        attempts++;
        _currentState.serviceAnswers[stepKey] = attempts.toString();
        
        _currentState.photoUploadRequested = true;
        if (attempts >= 2 || input.toLowerCase().contains('skip') || input.toLowerCase().contains('later')) {
          _currentState.conversationStep = 4;
          _triggerPhotoUpload();
          return "When works for you?";
        } else {
          _triggerPhotoUpload();
          return "Photos help! Upload now or continue?";
        }
        
      case 4:
        // Step 4: Availability with attempts tracking
        String stepKey4 = 'step_4_attempts';
        int attempts4 = _currentState.serviceAnswers[stepKey4] != null ? int.parse(_currentState.serviceAnswers[stepKey4]!) : 0;
        attempts4++;
        _currentState.serviceAnswers[stepKey4] = attempts4.toString();
        
        if (attempts4 >= 2) {
          _currentState.userAvailability = {'preference': input, 'timestamp': DateTime.now().toIso8601String()};
          _currentState.availabilitySet = true;
          _currentState.conversationStep = 5;
          _triggerCalendar();
          String summary = _generateServiceRequestSummary();
          return "Perfect! Here's your summary:\n\n$summary";
        } else {
          _triggerCalendar();
          return "When works best? Morning, afternoon, or weekend?";
        }
        
      case 5:
        // Step 5: Complete
        _currentState.userAvailability = {'preference': input, 'timestamp': DateTime.now().toIso8601String()};
        _currentState.availabilitySet = true;
        _currentState.conversationStep = 6;
        String summary = _generateServiceRequestSummary();
        return "All set! Here's your summary:\n\n$summary";
        
      case 6:
        // Step 6: Contact Information
        _currentState.address = input;
        _currentState.conversationStep = 7;
        return "Thank you! Finally, I need your contact information for coordination. Please provide: 1) Your full name, 2) Phone number for the service professional to reach you.";
        
      case 7:
        // Step 7: Market Price Range Estimation
        _extractContactInfo(input);
        _currentState.conversationStep = 8;
        _currentState.priceEstimate = _generateMockPriceEstimate();
        return "Excellent! Based on your ${_currentState.serviceCategory} request in your area, the estimated price range is ${_formatPriceRange(_currentState.priceEstimate!)}. Let me prepare a summary of your service request.";
        
      case 8:
        // Step 8: Summary & Confirmation
        _currentState.conversationStep = 9;
        return "Here's your complete service request summary. Please review and confirm if everything looks correct, or let me know what needs to be updated.";
        
      default:
        return "Thank you! Your service request is ready to be submitted. Is there anything else you'd like to modify?";
    }
  }

  String _getServiceSpecificQuestions() {
    // Concise questions for each service category
    switch (_currentState.serviceCategory) {
      case 'Cleaning':
        return "Which areas need cleaning?";
      case 'Plumbing':
        return "What's the plumbing issue?";
      case 'Electrical':
        return "What electrical problem?";
      case 'HVAC':
        return "Heating or cooling issue?";
      case 'Appliance Repair':
        return "Which appliance is broken?";
      case 'Landscaping':
        return "What yard work is needed?";
      case 'Pest Control':
        return "What pest problem?";
      case 'Roofing':
        return "What's the roof issue?";
      case 'Painting':
        return "What needs painting?";
      case 'Handyman':
        return "What needs fixing?";
      default:
        return "What specific service?";
    }
  }

  String _getCurrentQuestionKey() {
    // This method would typically return the key for the current question in serviceAnswers
    // For now, it's a placeholder.
    return 'question_${_currentState.conversationStep}';
  }

  bool _needMoreServiceDetails() {
    // This method would typically check if more details are needed for the current question
    // For now, it's a placeholder.
    return _currentState.serviceAnswers[_getCurrentQuestionKey()] == null || _currentState.serviceAnswers[_getCurrentQuestionKey()]!.isEmpty;
  }

  String _getNextServiceQuestion() {
    // This method would typically return the next question to ask
    // For now, it's a placeholder.
    return _getServiceSpecificQuestions();
  }

  void _extractContactInfo(String input) {
    // This method would typically extract contact information from the user's input
    // For now, it's a placeholder.
    _currentState.phoneNumber = input;
  }

  Map<String, dynamic> _generateMockPriceEstimate() {
    // This method would typically generate a mock price estimate based on service category
    // For now, it's a placeholder.
    switch (_currentState.serviceCategory) {
      case 'Cleaning':
        return {'min': 50, 'max': 150};
      case 'Plumbing':
        return {'min': 100, 'max': 300};
      case 'Electrical':
        return {'min': 150, 'max': 400};
      case 'HVAC':
        return {'min': 200, 'max': 600};
      case 'Appliance Repair':
        return {'min': 100, 'max': 300};
      case 'Landscaping':
        return {'min': 50, 'max': 150};
      case 'Pest Control':
        return {'min': 100, 'max': 250};
      case 'Roofing':
        return {'min': 200, 'max': 800};
      case 'Painting':
        return {'min': 150, 'max': 400};
      case 'Handyman':
        return {'min': 50, 'max': 150};
      default:
        return {'min': 100, 'max': 300};
    }
  }

  String _formatPriceRange(Map<String, dynamic> priceEstimate) {
    // This method would typically format the price range for display
    // For now, it's a placeholder.
    return '\$${priceEstimate['min']}-\$${priceEstimate['max']}';
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
    
    // Enhanced state detection with step-based logic
    if (!_currentState.photoUploadRequested && 
        (lowerResponse.contains('upload') || lowerResponse.contains('photo') || lowerResponse.contains('picture'))) {
      _currentState.photoUploadRequested = true;
    }
    
    if (!_currentState.calendarRequested && 
        (lowerResponse.contains('schedule') || lowerResponse.contains('availability') || 
         lowerResponse.contains('time') || lowerResponse.contains('calendar'))) {
      _currentState.calendarRequested = true;
    }
    
    // Update customer name if provided
    if (_currentState.customerName == null && _detectCustomerName(input) != null) {
      _currentState.customerName = _detectCustomerName(input);
    }
    
    // Update problem description if user provides more details
    if (_currentState.conversationStep >= 1 && _currentState.problemDescription == null && 
        input.length > 10 && !lowerInput.contains('yes') && !lowerInput.contains('no')) {
      _currentState.problemDescription = input;
    }
    
    // Update service description with more context
    if (_currentState.conversationStep >= 2 && input.length > 20 && !lowerInput.contains('yes') && !lowerInput.contains('no')) {
      if (_currentState.serviceDescription == null || _currentState.serviceDescription!.length < input.length) {
        _currentState.serviceDescription = input;
      }
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
      
      // Add contextual AI message - more concise
      _addMessage(ChatMessage(
        content: "Great photo! When works for you?",
        type: MessageType.ai,
        timestamp: DateTime.now(),
      ));
      
      // Trigger calendar after photo upload
      _triggerCalendar();
    }
  }

  void onAvailabilitySelected(Map<String, dynamic> availability) {
    _currentState.userAvailability = availability;
    if (!_currentState.availabilitySet) {
      _currentState.availabilitySet = true;
      _currentState.conversationStep = 5;
      
      // Generate comprehensive summary
      String summary = _generateServiceRequestSummary();
      
      // Add contextual AI message with summary - more concise
      _addMessage(ChatMessage(
        content: "Perfect! Here's your summary:\n\n$summary\n\nReady to connect with professionals!",
        type: MessageType.ai,
        timestamp: DateTime.now(),
      ));
      
      // Trigger conversation completion which calls getServiceRequestSummary()
      if (isConversationComplete()) {
        _onConversationComplete();
      }
    }
  }

  // Enhanced service request summary
  Map<String, dynamic> getServiceRequestSummary() {
    return {
      'serviceCategory': _currentState.serviceCategory ?? 'General Service',
      'serviceDescription': _currentState.serviceDescription ?? '',
      'problemDescription': _currentState.problemDescription ?? '',
      'mediaUrls': _currentState.mediaUrls,
      'availability': _currentState.userAvailability ?? {},
      'location': _currentState.address ?? '',
      'customerName': _currentState.customerName ?? '',
      'tags': _currentState.tags,
      'extractedInfo': _currentState.extractedInfo,
      'conversationStep': _currentState.conversationStep,
      'timestamp': DateTime.now().toIso8601String(),
      'isComplete': _currentState.availabilitySet && _currentState.serviceCategory != null,
    };
  }
  
  // Generate formatted summary for display
  String _generateServiceRequestSummary() {
    String summary = "📋 **SERVICE REQUEST SUMMARY**\n\n";
    
    // Service Information
    summary += "🔧 **Service Type:** ${_currentState.serviceCategory ?? 'General Service'}\n";
    
    if (_currentState.serviceDescription != null && _currentState.serviceDescription!.isNotEmpty) {
      summary += "📝 **Description:** ${_currentState.serviceDescription}\n";
    }
    
    if (_currentState.problemDescription != null && _currentState.problemDescription!.isNotEmpty) {
      summary += "❗ **Details:** ${_currentState.problemDescription}\n";
    }
    
    // Media Information
    if (_currentState.mediaUrls.isNotEmpty) {
      summary += "📸 **Photos:** ${_currentState.mediaUrls.length} photo(s) uploaded\n";
    } else if (_currentState.photoUploadRequested) {
      summary += "📸 **Photos:** Ready for upload\n";
    }
    
    // Availability Information
    if (_currentState.userAvailability != null && _currentState.userAvailability!.isNotEmpty) {
      summary += "📅 **Availability:** ${_formatAvailability(_currentState.userAvailability!)}\n";
    }
    
    // Customer Information
    if (_currentState.customerName != null && _currentState.customerName!.isNotEmpty) {
      summary += "👤 **Customer:** ${_currentState.customerName}\n";
    }
    
    if (_currentState.address != null && _currentState.address!.isNotEmpty) {
      summary += "📍 **Location:** ${_currentState.address}\n";
    }
    
    summary += "\n✅ **Status:** Ready for professional matching";
    
    return summary;
  }
  
  // Helper method to detect customer name from input
  String? _detectCustomerName(String input) {
    String lowerInput = input.toLowerCase();
    
    // Look for patterns like "I'm John", "My name is Sarah", "This is Mike"
    List<RegExp> namePatterns = [
      RegExp(r"i'?m\s+([a-z]+)", caseSensitive: false),
      RegExp(r"my name is\s+([a-z]+)", caseSensitive: false),
      RegExp(r"this is\s+([a-z]+)", caseSensitive: false),
      RegExp(r"call me\s+([a-z]+)", caseSensitive: false),
    ];
    
    for (RegExp pattern in namePatterns) {
      Match? match = pattern.firstMatch(lowerInput);
      if (match != null && match.group(1) != null) {
        String name = match.group(1)!;
        // Capitalize first letter
        return name[0].toUpperCase() + name.substring(1).toLowerCase();
      }
    }
    
    return null;
  }
  
  // Helper method to format availability for display
  String _formatAvailability(Map<String, dynamic> availability) {
    if (availability.isEmpty) return "Not specified";
    
    String formatted = "";
    
    if (availability.containsKey('preference')) {
      formatted = availability['preference'].toString();
    } else if (availability.containsKey('selectedDates')) {
      formatted = "Selected dates provided";
    } else if (availability.containsKey('timeSlots')) {
      formatted = "Time slots selected";
    } else {
      formatted = "Availability preferences set";
    }
    
    return formatted;
  }
  
  // Check if conversation is complete
  bool isConversationComplete() {
    return _currentState.conversationStep >= 5 && 
           _currentState.serviceCategory != null &&
           _currentState.availabilitySet;
  }
  
  // Called when conversation reaches completion
  void _onConversationComplete() {
    print('🎉 Conversation Complete! Generating final summary...');
    
    // Get the structured summary data
    final summaryData = getServiceRequestSummary();
    
    // Log or emit the summary (you can modify this based on your needs)
    print('📋 Final Service Request Summary: $summaryData');
    
    // Optional: Emit event or callback for UI
    onServiceRequestComplete?.call(summaryData);
  }
  
  // Public method to manually trigger completion check and summary generation
  Map<String, dynamic>? tryCompleteConversation() {
    if (isConversationComplete()) {
      _onConversationComplete();
      return getServiceRequestSummary();
    }
    return null;
  }
  
  // Trigger photo upload UI - this should be connected to your photo upload widget
  void _triggerPhotoUpload() {
    print('📷 Triggering photo upload UI...');
    // Set flag that photo upload UI should be shown
    _currentState.photoUploadRequested = true;
    
    // Emit callback for UI to show photo upload
    onPhotoUploadRequested?.call();
  }
  
  // Trigger calendar UI - this should be connected to your calendar widget  
  void _triggerCalendar() {
    print('📅 Triggering calendar UI...');
    // Set flag that calendar UI should be shown
    _currentState.calendarRequested = true;
    
    // Emit callback for UI to show calendar
    onCalendarRequested?.call();
  }
  
  // Setup method to connect UI callbacks
  void setupUICallbacks({
    VoidCallback? onPhotoUpload,
    VoidCallback? onCalendar,
    Function(Map<String, dynamic>)? onComplete,
  }) {
    onPhotoUploadRequested = onPhotoUpload;
    onCalendarRequested = onCalendar;
    onServiceRequestComplete = onComplete;
  }
  
  // Force photo upload UI to show (call this from your UI)
  void showPhotoUpload() {
    _triggerPhotoUpload();
  }
  
  // Force calendar UI to show (call this from your UI)  
  void showCalendar() {
    _triggerCalendar();
  }
  
  // Get current conversation step for UI state management
  int get currentStep => _currentState.conversationStep;
  
  // Check if photo upload should be shown
  bool get shouldShowPhotoUpload => _currentState.conversationStep == 3 && _currentState.photoUploadRequested;
  
  // Check if calendar should be shown
  bool get shouldShowCalendar => _currentState.conversationStep == 4 && _currentState.calendarRequested;
} 