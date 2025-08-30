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
  List<String> mediaUrls;         // Photos from intake
  List<String>? tags;             // AI-generated tags
  
  // Customer Details
  String? address;                // Full service address
  String? zipcode;                // Zip code
  String? city;                   // City
  String? state;                  // State
  String? phoneNumber;            // Contact number
  String? email;                  // Email address
  Map<String, dynamic>? location; // GPS coordinates + formatted address
  Map<String, dynamic>? locationForm;    // Complete location form data
  Map<String, dynamic>? contactForm;     // Complete contact form data
  
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
  bool locationFormRequested;
  bool locationFormCompleted;
  bool contactFormRequested;
  bool contactFormCompleted;
  bool priceEstimationCompleted;

  ConversationState({
    this.requestId,
    this.userId,
    this.serviceCategory,
    this.description,
    List<String>? mediaUrls,
    this.tags,
    this.address,
    this.zipcode,
    this.city, 
    this.state,
    this.phoneNumber,
    this.email,
    this.location,
    this.locationForm,
    this.contactForm,
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
    this.locationFormRequested = false,
    this.locationFormCompleted = false,
    this.contactFormRequested = false,
    this.contactFormCompleted = false,
    this.priceEstimationCompleted = false,
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
  VoidCallback? onLocationFormRequested;
  VoidCallback? onContactFormRequested;
  
  // Enhanced system prompt optimized for Gemini and Magic Home app
  static const String _systemPrompt = '''
You are Magic Home assistant. Help users create service requests efficiently.

CUSTOMER PROFILE: Your customers are often new homeowners with limited knowledge about home construction, repairs, and maintenance. They need guidance and suggestions to properly describe their issues.

CONVERSATION FLOW - FOLLOW STRICTLY:
1. DISCOVER (Step 0-1): What service do you need?
2. DETAILS (Step 2): Get specific problem details WITH GUIDED OPTIONS
3. PHOTOS (Step 3): Guide to photo upload - MAX 2 attempts then proceed
4. SCHEDULE (Step 4): Set availability - MAX 2 attempts then proceed
5. LOCATION (Step 5): Collect location form - address, zipcode, city, state
6. CONTACT (Step 6): Collect contact form - tel, email
7. PRICING (Step 7): Show network-based price estimation
8. CONFIRM (Step 8): Show complete summary

SERVICE CATEGORIES: Cleaning, Plumbing, Electrical, HVAC, Appliance Repair, Handyman, Landscaping, Pest Control, Roofing, Painting

GUIDANCE FOR NEW HOMEOWNERS:
- Always provide 2-3 common issue examples for their service category
- Use simple, non-technical language
- Include location hints (kitchen sink, bathroom, basement, etc.)
- Mention urgency levels (emergency, soon, when convenient)
- Give helpful context about what professionals need to know

RULES:
- ONLY answer HOME SERVICE questions (repairs, maintenance, cleaning, etc.)
- If asked about weather, politics, entertainment, etc. say: "I only help with home services. What do you need fixed?"
- Keep responses SHORT (1 sentence max)
- Ask ONE question at a time
- NEVER repeat the same question
- Progress to step 3 automatically for at most 5 rounds of complete conversations about what's going on (after that, user must explicitly say "done" to move to step 4)
- Step 2: Always provide 2-3 SPECIFIC examples for the service category to guide new homeowners
- Step 3: Say "Photos are helpful! Would you like to upload some?" then TRIGGER photo upload
- Step 4: Say "When works for you?" then TRIGGER calendar
- If user says "skip" or "later" - move to next step immediately

STEP TRIGGERS:
- Step 3: After asking about photos MAX 2 times, automatically call photo upload UI
- Step 4: After asking about schedule MAX 2 times, automatically call calendar UI
- Step 5: After availability set, trigger location form UI
- Step 6: After location form completed, trigger contact form UI
- Step 7: After contact form completed, calculate and show price estimation
- Step 8: Auto-generate complete summary

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
      content: "Hi! I'm here to help you with your home service needs. What can I assist you with today?",
      type: MessageType.ai,
      timestamp: DateTime.now(),
    ));
    
    // Add service options as separate individual boxes
    List<String> services = [
      'Plumbing', 'Electrical', 'HVAC', 'Appliance Repair', 'Cleaning',
      'Handyman', 'Landscaping', 'Pest Control', 'Roofing', 'Painting'
    ];
    
    for (String service in services) {
      _addMessage(ChatMessage(
        content: service,
        type: MessageType.ai,
        timestamp: DateTime.now(),
        metadata: {'isServiceBox': true, 'serviceType': service}, // Individual service box styling
      ));
    }
    
    _addMessage(ChatMessage(
      content: "Select a service above or tell me what's going on!",
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

    // Handle specific user messages for step progression  
    String lowerInput = input.toLowerCase();
    
    // Check if the question is related to home services
    if (!_isHomeServiceRelated(lowerInput)) {
      return "I'm here to help you with home service requests only. Let's focus on getting you connected with the right professional for your home needs. What type of home service do you need help with?";
    }
    
    if (lowerInput.contains('done') && lowerInput.contains('photo')) {
      if (_currentState.conversationStep == 3) {
        _currentState.conversationStep = 4; // Move to availability step
        print('📸 User done with photos, moving to step 4 (availability)');
      }
    }

    // Detect and update service category if not already set
    if (_currentState.serviceCategory == null) {
      _currentState.serviceCategory = _detectServiceCategory(lowerInput);
      if (_currentState.serviceCategory != null) {
        _currentState.description = input;
        // FORCE step advancement to prevent repetition
        _currentState.conversationStep = 1;
        print('🔧 Service category detected: ${_currentState.serviceCategory}, advancing to step 1');
      }
    } else if (_currentState.conversationStep == 0) {
      // If service category already set but still at step 0, force advance
      _currentState.conversationStep = 1;
      print('🔧 Service category already set, forcing advance from step 0 to 1');
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
        contextualMessage += " [Step 1: Get details with GUIDED OPTIONS - provide 2-3 specific examples for ${_currentState.serviceCategory}, attempt $attempts/2]";
        break;
      case 2:
        contextualMessage += " [Step 2: Move to photo upload - be brief]";
        break;
      case 3:
        contextualMessage += " [Step 3: Photo upload - attempt $attempts/2, if >=2 say 'Photos are helpful! Upload some?' and trigger upload]";
        break;
      case 4:
        contextualMessage += " [Step 4: Scheduling - attempt $attempts/2, if >=2 say 'When works?' and trigger calendar]";
        break;
      case 5:
        contextualMessage += " [Step 5: Location form - ask for address, zipcode, city, state]";
        break;
      case 6:
        contextualMessage += " [Step 6: Contact form - ask for tel and email]";
        break;
      case 7:
        contextualMessage += " [Step 7: Show price estimation based on network prices]";
        break;
      case 8:
        contextualMessage += " [Step 8: Show complete summary]";
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
    
    // FORCE progression after 1 attempt to prevent repetition
    switch (_currentState.conversationStep) {
      case 0:
        if (_currentState.serviceCategory != null) {
          _currentState.conversationStep = 1;
        }
        break;
      case 1:
        // Always move to details after first response
      _currentState.conversationStep = 2;
        break;
      case 2:
        // Always move to photo after details
      _currentState.conversationStep = 3;
        _currentState.photoUploadRequested = true;
        break;
      case 3:
        // Only move to scheduling if user explicitly says they're done with photos
        if (lowerResponse.contains('skip') || lowerResponse.contains('later') || 
            lowerResponse.contains('done') || lowerResponse.contains('continue')) {
      _currentState.conversationStep = 4;
          _triggerPhotoUpload();
        }
        // Stay at step 3 to allow multiple photo uploads
        break;
      case 4:
        // Only move to location form if availability is actually set
        if (_currentState.availabilitySet) {
      _currentState.conversationStep = 5;
          _currentState.locationFormRequested = true;
          _triggerLocationForm();
        }
        // If availability not set, stay at step 4 and keep showing calendar
        break;
      case 5:
        // Force move to contact form
        if (_currentState.locationFormCompleted || attempts >= 1) {
          _currentState.conversationStep = 6;
          _currentState.contactFormRequested = true;
          _triggerContactForm();
        }
        break;
      case 6:
        // Force move to pricing
        if (_currentState.contactFormCompleted || attempts >= 1) {
          _currentState.conversationStep = 7;
          _calculateNetworkPrice();
        }
        break;
      case 7:
        // Force move to final summary
        _currentState.conversationStep = 8;
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
    
    // Check if the question is related to home services (only for initial messages)
    if (_currentState.conversationStep == 0 && !_isHomeServiceRelated(lowerInput)) {
      return "I'm here to help you with home service requests only. Let's focus on getting you connected with the right professional for your home needs. What type of home service do you need help with?";
    }
    
    // Handle specific user messages for step progression
    if (lowerInput.contains('done') && lowerInput.contains('photo')) {
      if (_currentState.conversationStep == 3) {
        _currentState.conversationStep = 4; // Move to availability step
        print('📸 User done with photos, moving to step 4 (availability)');
      }
    }
    
    // Use step-based progression when no AI is configured
    if (!ApiConfig.isAnyAiConfigured) {
      return _generateStepBasedResponse(input, lowerInput);
    }
    
    // Enhanced mock responses that mirror Gemini style (when AI is configured but fails)
    if (_currentState.conversationStep == 0) {
        _currentState.serviceCategory = _detectServiceCategory(lowerInput);
        _currentState.serviceDescription = input;
        _currentState.conversationStep = 1;
      return _getServiceSpecificSecondQuestion(_currentState.serviceCategory);
    }
        
    if (_currentState.conversationStep == 1) {
        _currentState.problemDescription = input;
        _currentState.conversationStep = 2;
      return "Great! Photos help professionals provide better estimates. Would you like to upload some?";
    }
    
    // More concise mock flow with attempt tracking
    String stepKey = 'step_${_currentState.conversationStep}_attempts';
    int attempts = _currentState.extractedInfo[stepKey] ?? 0;
    
    if (_currentState.conversationStep == 2) {
      _currentState.photoUploadRequested = true;
      _currentState.conversationStep = 3;
      return "Excellent! Photos help providers give accurate quotes. Ready to upload some?";
    }
    
    if (_currentState.conversationStep == 3) {
      if (lowerInput.contains('skip') || lowerInput.contains('later') || lowerInput.contains('done')) {
      _currentState.conversationStep = 4;
        _triggerPhotoUpload(); // Trigger the actual photo upload UI
        return "When works for you?";
      } else {
        _triggerPhotoUpload();
        return "Photos really help! Would you like to upload some, or should we continue?";
      }
    }
    
    if (_currentState.conversationStep == 4) {
      // Trigger calendar UI first, don't auto-advance until calendar is used
      if (!_currentState.calendarRequested) {
        _triggerCalendar();
      _currentState.calendarRequested = true;
      }
      // Stay at step 4 until availability is actually set
      return "When works best for you? Please select your preferred date and time.";
    }
    
    if (_currentState.conversationStep == 5) {
      // Wait for location form to be completed via UI
      _triggerLocationForm();
      return "Please fill out the location form above.";
    }
    
    if (_currentState.conversationStep == 6) {
      // Wait for contact form to be completed via UI
      _triggerContactForm();
      return "Please fill out the contact form above.";
    }
    
    if (_currentState.conversationStep == 7) {
      // Price calculation step
      _calculateNetworkPrice();
      if (_currentState.priceEstimate != null) {
        _currentState.conversationStep = 8;
        String summary = _generateServiceRequestSummary();
        return "Excellent! Here's your price estimate: ${_formatPriceRange(_currentState.priceEstimate!)}\n\nHere's your complete summary:\n\n$summary";
      } else {
        return "Calculating your price estimate...";
      }
    }
    
    if (_currentState.conversationStep == 8) {
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
        
        // Customize response based on detected service
        return _getServiceSpecificSecondQuestion(_currentState.serviceCategory);
        
      case 1:
        // Step 2: Service Details with Guided Options for New Homeowners
        _currentState.conversationStep = 2;
        return _getGuidedServiceOptions();
        
      case 2:
        // Continue collecting service details
        _currentState.serviceAnswers[_getCurrentQuestionKey()] = input;
        if (_needMoreServiceDetails()) {
          return _getNextServiceQuestion();
        } else {
          _currentState.conversationStep = 3;
          return "Perfect! Photos really help professionals give accurate estimates. Would you like to upload some photos of the issue? It's optional but recommended.";
        }
        
      case 3:
        // Step 3: Visual Assessment - Photo/Video uploads with attempts tracking
        String stepKey = 'step_3_attempts';
        int attempts = _currentState.serviceAnswers[stepKey] != null ? int.parse(_currentState.serviceAnswers[stepKey]!) : 0;
        attempts++;
        _currentState.serviceAnswers[stepKey] = attempts.toString();
        
        _currentState.photoUploadRequested = true;
        if (input.toLowerCase().contains('skip') || input.toLowerCase().contains('later') || input.toLowerCase().contains('done')) {
        _currentState.conversationStep = 4;
          _triggerPhotoUpload();
          return "When works for you?";
        } else {
          _triggerPhotoUpload();
          return "Photos are helpful! Would you like to upload some now?";
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
    // Legacy method for backward compatibility
    return _generateNetworkBasedPriceEstimate();
  }
  
  // Generate network-based price estimation with location factors
  Map<String, dynamic> _generateNetworkBasedPriceEstimate() {
    // Enhanced service-specific pricing structure (in USD)
    Map<String, Map<String, dynamic>> servicePricing = {
      'Cleaning': {
        'hourly_rate': {'min': 25, 'max': 50, 'avg': 35},
        'project_pricing': {
          'Standard House Cleaning': {'min': 80, 'max': 150, 'avg': 115, 'hours': '2-4'},
          'Deep Cleaning': {'min': 150, 'max': 300, 'avg': 225, 'hours': '4-8'},
          'Move-in/Move-out Cleaning': {'min': 200, 'max': 400, 'avg': 300, 'hours': '6-10'},
          'Post-Construction Cleaning': {'min': 300, 'max': 600, 'avg': 450, 'hours': '8-12'},
        },
        'default': {'min': 80, 'max': 200, 'avg': 140}
      },
      'Plumbing': {
        'hourly_rate': {'min': 75, 'max': 150, 'avg': 110},
        'project_pricing': {
          'Faucet Repair/Installation': {'min': 150, 'max': 300, 'avg': 225, 'hours': '1-2'},
          'Toilet Repair/Installation': {'min': 200, 'max': 400, 'avg': 300, 'hours': '2-3'},
          'Pipe Leak Repair': {'min': 250, 'max': 500, 'avg': 375, 'hours': '2-4'},
          'Water Heater Installation': {'min': 800, 'max': 1500, 'avg': 1150, 'hours': '4-6'},
          'Drain Cleaning': {'min': 150, 'max': 350, 'avg': 250, 'hours': '1-3'},
        },
        'default': {'min': 150, 'max': 450, 'avg': 300}
      },
      'Electrical': {
        'hourly_rate': {'min': 80, 'max': 150, 'avg': 115},
        'project_pricing': {
          'Outlet Installation': {'min': 150, 'max': 250, 'avg': 200, 'hours': '1-2'},
          'Light Fixture Installation': {'min': 200, 'max': 400, 'avg': 300, 'hours': '2-3'},
          'Circuit Breaker Replacement': {'min': 300, 'max': 600, 'avg': 450, 'hours': '2-4'},
          'Whole House Rewiring': {'min': 3000, 'max': 8000, 'avg': 5500, 'hours': '20-40'},
          'Panel Upgrade': {'min': 1500, 'max': 3000, 'avg': 2250, 'hours': '6-12'},
        },
        'default': {'min': 200, 'max': 500, 'avg': 350}
      },
      'HVAC': {
        'hourly_rate': {'min': 90, 'max': 175, 'avg': 130},
        'project_pricing': {
          'AC Unit Repair': {'min': 300, 'max': 600, 'avg': 450, 'hours': '2-4'},
          'Furnace Repair': {'min': 400, 'max': 800, 'avg': 600, 'hours': '3-5'},
          'Duct Cleaning': {'min': 300, 'max': 500, 'avg': 400, 'hours': '3-4'},
          'AC Installation': {'min': 3000, 'max': 7000, 'avg': 5000, 'hours': '6-10'},
          'Thermostat Installation': {'min': 200, 'max': 400, 'avg': 300, 'hours': '1-2'},
        },
        'default': {'min': 300, 'max': 800, 'avg': 550}
      },
      'Appliance Repair': {
        'hourly_rate': {'min': 60, 'max': 120, 'avg': 85},
        'project_pricing': {
          'Refrigerator Repair': {'min': 200, 'max': 400, 'avg': 300, 'hours': '2-3'},
          'Washer/Dryer Repair': {'min': 150, 'max': 350, 'avg': 250, 'hours': '1-3'},
          'Dishwasher Repair': {'min': 180, 'max': 300, 'avg': 240, 'hours': '2-3'},
          'Oven/Stove Repair': {'min': 200, 'max': 450, 'avg': 325, 'hours': '2-4'},
          'Garbage Disposal Installation': {'min': 150, 'max': 250, 'avg': 200, 'hours': '1-2'},
        },
        'default': {'min': 120, 'max': 350, 'avg': 235}
      },
      'Landscaping': {
        'hourly_rate': {'min': 35, 'max': 75, 'avg': 55},
        'project_pricing': {
          'Lawn Mowing': {'min': 50, 'max': 150, 'avg': 100, 'hours': '1-3'},
          'Tree Trimming': {'min': 200, 'max': 800, 'avg': 500, 'hours': '3-8'},
          'Garden Design': {'min': 500, 'max': 2000, 'avg': 1250, 'hours': '10-20'},
          'Sprinkler Installation': {'min': 800, 'max': 2500, 'avg': 1650, 'hours': '8-16'},
          'Yard Cleanup': {'min': 150, 'max': 400, 'avg': 275, 'hours': '3-6'},
        },
        'default': {'min': 100, 'max': 300, 'avg': 200}
      },
      'Pest Control': {
        'hourly_rate': {'min': 50, 'max': 100, 'avg': 75},
        'project_pricing': {
          'General Pest Treatment': {'min': 150, 'max': 300, 'avg': 225, 'hours': '2-3'},
          'Termite Treatment': {'min': 500, 'max': 1500, 'avg': 1000, 'hours': '4-8'},
          'Rodent Control': {'min': 200, 'max': 500, 'avg': 350, 'hours': '2-4'},
          'Ant Treatment': {'min': 100, 'max': 250, 'avg': 175, 'hours': '1-2'},
          'Bed Bug Treatment': {'min': 300, 'max': 800, 'avg': 550, 'hours': '3-6'},
        },
        'default': {'min': 150, 'max': 350, 'avg': 250}
      },
      'Roofing': {
        'hourly_rate': {'min': 70, 'max': 120, 'avg': 95},
        'project_pricing': {
          'Roof Inspection': {'min': 200, 'max': 400, 'avg': 300, 'hours': '2-3'},
          'Leak Repair': {'min': 300, 'max': 800, 'avg': 550, 'hours': '3-6'},
          'Shingle Replacement': {'min': 500, 'max': 1500, 'avg': 1000, 'hours': '4-12'},
          'Full Roof Replacement': {'min': 8000, 'max': 25000, 'avg': 16500, 'hours': '40-80'},
          'Gutter Repair': {'min': 200, 'max': 600, 'avg': 400, 'hours': '2-5'},
        },
        'default': {'min': 400, 'max': 1200, 'avg': 800}
      },
      'Painting': {
        'hourly_rate': {'min': 35, 'max': 80, 'avg': 55},
        'project_pricing': {
          'Interior Room Painting': {'min': 300, 'max': 800, 'avg': 550, 'hours': '6-12'},
          'Exterior House Painting': {'min': 2000, 'max': 6000, 'avg': 4000, 'hours': '20-40'},
          'Cabinet Painting': {'min': 500, 'max': 1500, 'avg': 1000, 'hours': '8-16'},
          'Trim/Baseboard Painting': {'min': 200, 'max': 600, 'avg': 400, 'hours': '4-8'},
          'Touch-up Painting': {'min': 150, 'max': 300, 'avg': 225, 'hours': '2-4'},
        },
        'default': {'min': 200, 'max': 600, 'avg': 400}
      },
      'Handyman': {
        'hourly_rate': {'min': 40, 'max': 85, 'avg': 60},
        'project_pricing': {
          'Furniture Assembly': {'min': 80, 'max': 200, 'avg': 140, 'hours': '1-3'},
          'Drywall Repair': {'min': 150, 'max': 400, 'avg': 275, 'hours': '2-5'},
          'Door Installation': {'min': 200, 'max': 500, 'avg': 350, 'hours': '3-6'},
          'Shelf Installation': {'min': 100, 'max': 250, 'avg': 175, 'hours': '1-3'},
          'General Repairs': {'min': 100, 'max': 300, 'avg': 200, 'hours': '2-4'},
        },
        'default': {'min': 80, 'max': 200, 'avg': 140}
      },
    };
    
    String category = _currentState.serviceCategory ?? 'Handyman';
    Map<String, dynamic> categoryPricing = servicePricing[category] ?? servicePricing['Handyman']!;
    
    // Get base price (use default if no specific project type detected)
    Map<String, dynamic> basePrice = _detectSpecificServiceType(category, categoryPricing);
    
    // Location-based adjustments
    double locationMultiplier = _getLocationPriceMultiplier();
    
    // Urgency adjustments
    double urgencyMultiplier = _getUrgencyMultiplier();
    
    // Photo bonus (detailed photos can lead to more accurate quotes)
    double photoBonus = _currentState.mediaUrls.isNotEmpty ? 0.95 : 1.0; // 5% discount for photos
    
    // Get hourly rates
    Map<String, dynamic> hourlyRates = categoryPricing['hourly_rate'];
    
    // Calculate project pricing
    int finalMin = (basePrice['min']! * locationMultiplier * urgencyMultiplier * photoBonus).round();
    int finalMax = (basePrice['max']! * locationMultiplier * urgencyMultiplier * photoBonus).round();
    int finalAvg = (basePrice['avg']! * locationMultiplier * urgencyMultiplier * photoBonus).round();
    
    // Calculate hourly rates
    int hourlyMin = (hourlyRates['min']! * locationMultiplier * urgencyMultiplier).round();
    int hourlyMax = (hourlyRates['max']! * locationMultiplier * urgencyMultiplier).round();
    int hourlyAvg = (hourlyRates['avg']! * locationMultiplier * urgencyMultiplier).round();
    
    return {
      'min': finalMin,
      'max': finalMax,
      'avg': finalAvg,
      'currency': 'USD',
      'service_type': basePrice['service_type'] ?? 'General Service',
      'estimated_hours': basePrice['hours'] ?? 'Variable',
      'hourly_rates': {
        'min': hourlyMin,
        'max': hourlyMax,
        'avg': hourlyAvg,
      },
      'factors': {
        'location_multiplier': locationMultiplier,
        'urgency_multiplier': urgencyMultiplier,
        'photo_bonus': photoBonus,
        'base_category': category,
      },
      'breakdown': {
        'base_min': basePrice['min'],
        'base_max': basePrice['max'],
        'base_avg': basePrice['avg'],
        'base_hourly_min': hourlyRates['min'],
        'base_hourly_max': hourlyRates['max'],
        'base_hourly_avg': hourlyRates['avg'],
      }
    };
  }
  
  // Detect specific service type based on description
  Map<String, dynamic> _detectSpecificServiceType(String category, Map<String, dynamic> categoryPricing) {
    String description = (_currentState.serviceDescription ?? '').toLowerCase();
    Map<String, dynamic> projectPricing = categoryPricing['project_pricing'] ?? {};
    
    // Score each project type based on keyword matches
    String bestMatch = '';
    double bestScore = 0.0;
    
    for (String projectType in projectPricing.keys) {
      double score = _calculateProjectTypeScore(description, projectType);
      if (score > bestScore) {
        bestScore = score;
        bestMatch = projectType;
      }
    }
    
    // Use specific project type if good match found (score > 0.3)
    if (bestScore > 0.3 && projectPricing.containsKey(bestMatch)) {
      Map<String, dynamic> specificPricing = Map<String, dynamic>.from(projectPricing[bestMatch]);
      specificPricing['service_type'] = bestMatch;
      return specificPricing;
    }
    
    // Fall back to default pricing
    Map<String, dynamic> defaultPricing = Map<String, dynamic>.from(categoryPricing['default']);
    defaultPricing['service_type'] = 'General $category Service';
    return defaultPricing;
  }
  
  // Calculate score for project type match
  double _calculateProjectTypeScore(String description, String projectType) {
    String lowerProjectType = projectType.toLowerCase();
    double score = 0.0;
    
    // Extract keywords from project type
    List<String> keywords = lowerProjectType
        .replaceAll(RegExp(r'[/\-]'), ' ')
        .split(' ')
        .where((word) => word.length > 2)
        .toList();
    
    // Score based on keyword matches
    for (String keyword in keywords) {
      if (description.contains(keyword)) {
        score += 1.0 / keywords.length; // Normalize by number of keywords
      }
      
      // Bonus for exact phrase matches
      if (description.contains(keyword) && keyword.length > 4) {
        score += 0.2;
      }
    }
    
    // Specific keyword bonuses
    Map<String, List<String>> bonusKeywords = {
      'faucet': ['tap', 'spigot', 'sink'],
      'toilet': ['bathroom', 'restroom', 'commode'],
      'leak': ['dripping', 'water damage', 'pipe'],
      'cleaning': ['clean', 'dirty', 'sanitize', 'dust'],
      'painting': ['paint', 'color', 'wall', 'ceiling'],
      'repair': ['fix', 'broken', 'not working', 'replace'],
      'installation': ['install', 'setup', 'mount', 'new'],
    };
    
    for (String mainKeyword in bonusKeywords.keys) {
      if (lowerProjectType.contains(mainKeyword)) {
        for (String bonus in bonusKeywords[mainKeyword]!) {
          if (description.contains(bonus)) {
            score += 0.1;
          }
        }
      }
    }
    
    return score;
  }
  
  // Get location-based price multiplier
  double _getLocationPriceMultiplier() {
    String? state = _currentState.state?.toLowerCase() ?? '';
    String? city = _currentState.city?.toLowerCase() ?? '';
    
    // High-cost areas
    if (state.contains('california') || state.contains('new york') || state.contains('massachusetts') ||
        state.contains('ca') || state.contains('ny') || state.contains('ma')) {
      return 1.3; // 30% higher
    }
    
    // Major cities
    if (city.contains('san francisco') || city.contains('new york') || city.contains('los angeles') ||
        city.contains('seattle') || city.contains('chicago') || city.contains('boston') ||
        city.contains('sf') || city.contains('nyc') || city.contains('la')) {
      return 1.25; // 25% higher
    }
    
    // Medium-cost areas
    if (state.contains('texas') || state.contains('florida') || state.contains('washington') ||
        state.contains('tx') || state.contains('fl') || state.contains('wa')) {
      return 1.1; // 10% higher
    }
    
    // Lower-cost areas
    if (state.contains('alabama') || state.contains('mississippi') || state.contains('west virginia') ||
        state.contains('al') || state.contains('ms') || state.contains('wv')) {
      return 0.85; // 15% lower
    }
    
    return 1.0; // Standard pricing
  }
  
  // Get urgency-based price multiplier
  double _getUrgencyMultiplier() {
    int priority = _currentState.priority ?? 3;
    
    switch (priority) {
      case 5: // Emergency
        return 1.5; // 50% higher for emergency
      case 4: // Urgent
        return 1.25; // 25% higher for urgent
      case 3: // Normal
        return 1.0; // Standard pricing
      case 2: // Flexible
        return 0.9; // 10% lower for flexible timing
      case 1: // Very flexible
        return 0.8; // 20% lower for very flexible timing
      default:
        return 1.0;
    }
  }

  String _formatPriceRange(Map<String, dynamic> priceEstimate) {
    String currency = priceEstimate['currency'] ?? 'USD';
    String serviceType = priceEstimate['service_type'] ?? 'Service';
    String estimatedHours = priceEstimate['estimated_hours'] ?? 'Variable';
    
    String result = '**$serviceType**\n';
    
    // Primary focus: Hourly rates only
    if (priceEstimate.containsKey('hourly_rates')) {
      Map<String, dynamic> hourlyRates = priceEstimate['hourly_rates'];
      int hourlyMin = hourlyRates['min'] ?? 0;
      int hourlyMax = hourlyRates['max'] ?? 0;
      int hourlyAvg = hourlyRates['avg'] ?? 0;
      
      result += '💰 **\$${hourlyMin}-\$${hourlyMax}/hour** (avg: \$${hourlyAvg}/hour) $currency\n';
      result += '⏱️ Estimated Duration: $estimatedHours hours';
    } else {
      // Fallback: convert project pricing to hourly rate estimate
      int min = priceEstimate['min'] ?? 0;
      int max = priceEstimate['max'] ?? 0;
      int avg = priceEstimate['avg'] ?? 0;
      
      // Estimate hourly rate based on typical project duration
      String timeRange = estimatedHours.replaceAll(' hours', '');
      if (timeRange.contains('-')) {
        List<String> timeParts = timeRange.split('-');
        if (timeParts.length == 2) {
          try {
            int minHours = int.parse(timeParts[0].trim());
            int maxHours = int.parse(timeParts[1].trim());
            int avgHours = ((minHours + maxHours) / 2).round();
            
            int hourlyRateMin = (min / maxHours).round();
            int hourlyRateMax = (max / minHours).round();
            int hourlyRateAvg = (avg / avgHours).round();
            
            result += '💰 **\$${hourlyRateMin}-\$${hourlyRateMax}/hour** (avg: \$${hourlyRateAvg}/hour) $currency\n';
            result += '⏱️ Estimated Duration: $estimatedHours hours';
          } catch (e) {
            // Simple fallback
            result += '💰 **Estimated Rate: \$${(avg / 2).round()}/hour** $currency\n';
            result += '⏱️ Estimated Duration: $estimatedHours hours';
          }
        }
      } else {
        // Simple hourly rate calculation
        try {
          int hours = int.parse(timeRange.trim());
          int hourlyRate = (avg / hours).round();
          result += '💰 **Estimated Rate: \$${hourlyRate}/hour** $currency\n';
          result += '⏱️ Estimated Duration: $hours hours';
        } catch (e) {
          result += '💰 **Estimated Rate: \$${(avg / 2).round()}/hour** $currency\n';
          result += '⏱️ Estimated Duration: $estimatedHours hours';
        }
      }
    }
    
    return result;
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

  // Generate service-specific second question to engage users better
  String _getServiceSpecificSecondQuestion(String? serviceCategory) {
    switch (serviceCategory) {
      case 'Plumbing':
        return "Great choice! Plumbing issues can be tricky. Is this about a leak, clog, installation, or something not working properly? What's going on with your plumbing?";
      
      case 'Electrical':
        return "Perfect! Electrical work needs the right expertise. Are you dealing with outlets, lighting, circuit issues, or an installation? Tell me what's happening!";
      
      case 'HVAC':
        return "Smart! HVAC systems are complex. Is your heating, cooling, or ventilation not working right? What temperatures or comfort issues are you experiencing?";
      
      case 'Appliance Repair':
        return "Good call! Which appliance is giving you trouble? Is it your refrigerator, washer, dryer, dishwasher, or something else? What's it doing (or not doing)?";
      
      case 'Cleaning':
        return "Excellent! A clean home is a happy home. Are you looking for regular cleaning, deep cleaning, move-in/out, or post-construction cleanup? What areas need attention?";
      
      case 'Handyman':
        return "Perfect! Handyman services cover so much. Are you looking to fix something broken, install something new, or tackle a home improvement project? What needs your attention?";
      
      case 'Landscaping':
        return "Great choice! Your outdoor space deserves care. Is this about lawn maintenance, garden design, tree work, or hardscaping? What's your vision for the space?";
      
      case 'Pest Control':
        return "Smart move! Pest issues need quick attention. Are you seeing specific pests like ants, mice, or insects? Is this for prevention or treating an active problem?";
      
      case 'Roofing':
        return "Important! Your roof protects everything below. Are you noticing leaks, missing shingles, storm damage, or planning maintenance? What's happening up there?";
      
      case 'Painting':
        return "Fantastic! Fresh paint transforms spaces. Are you thinking interior or exterior? Is this for a single room, whole house, or touch-up work? What's your painting project?";
      
      default:
        return "Perfect! I'm here to help with your home service needs. Could you tell me more about what's happening? The more details you share, the better I can connect you with the right professional.";
    }
  }
  
  String _generateFallbackResponse(String input) {
    // More intelligent fallback based on conversation state
    if (_currentState.serviceCategory == null && _currentState.conversationStep == 0) {
      // Force detect service and advance
      _currentState.serviceCategory = _detectServiceCategory(input.toLowerCase());
      _currentState.conversationStep = 1;
      return _getServiceSpecificSecondQuestion(_currentState.serviceCategory);
    } else {
      return "I want to make sure I help you get the best ${_currentState.serviceCategory} service. Could you share a bit more about what you need?";
    }
  }

  // Enhanced callback methods with Gemini integration
  void onPhotoUploaded(String photoUrl) {
    _currentState.mediaUrls.add(photoUrl);
    if (!_currentState.photosUploaded) {
      _currentState.photosUploaded = true;
      // DON'T advance to step 4 yet - wait for user to click "Done"
      // Keep at step 3 until user is done uploading all photos
      
      // Add contextual AI message - more concise
      _addMessage(ChatMessage(
        content: "Photo uploaded! Add more photos or click 'Done' when ready.",
        type: MessageType.ai,
        timestamp: DateTime.now(),
      ));
      
      // Stay at step 3 - calendar will be triggered when user clicks "Done"
    }
  }

  void onAvailabilitySelected(Map<String, dynamic> availability) {
    print('📅 Availability selected: $availability');
    _currentState.userAvailability = availability;
    if (!_currentState.availabilitySet) {
      _currentState.availabilitySet = true;
      _currentState.conversationStep = 5;
      
      // Move to location form
      _addMessage(ChatMessage(
        content: "Perfect! Now I need your service location details.",
        type: MessageType.ai,
        timestamp: DateTime.now(),
      ));
      
      print('📍 Triggering location form from availability selection');
      _triggerLocationForm();
    }
  }
  
  // Handle location form completion
  void onLocationFormCompleted(Map<String, dynamic> locationData) {
    _currentState.locationForm = locationData;
    _currentState.address = locationData['address'];
    _currentState.zipcode = locationData['zipcode'];
    _currentState.city = locationData['city'];
    _currentState.state = locationData['state'];
    _currentState.locationFormCompleted = true;
    _currentState.conversationStep = 6;
    
    _addMessage(ChatMessage(
      content: "Perfect! Now I need your contact information.",
      type: MessageType.ai,
      timestamp: DateTime.now(),
    ));
    
    _triggerContactForm();
  }
  
  // Handle contact form completion
  void onContactFormCompleted(Map<String, dynamic> contactData) {
    _currentState.contactForm = contactData;
    _currentState.phoneNumber = contactData['tel'];
    _currentState.email = contactData['email'];
    _currentState.contactFormCompleted = true;
    _currentState.conversationStep = 7;
    
    // Calculate price estimation
    _calculateNetworkPrice();
    
    _addMessage(ChatMessage(
      content: "Excellent! Here's your price estimate: ${_formatPriceRange(_currentState.priceEstimate!)}",
      type: MessageType.ai,
      timestamp: DateTime.now(),
    ));
    
    // Move to final summary
    _currentState.conversationStep = 8;
    String summary = _generateServiceRequestSummary();
    
    _addMessage(ChatMessage(
      content: "Here's your complete summary:\n\n$summary\n\nReady to connect with professionals!",
      type: MessageType.ai,
      timestamp: DateTime.now(),
    ));
    
    // Trigger conversation completion
    if (isConversationComplete()) {
      _onConversationComplete();
    }
  }

  // Enhanced service request summary
  Map<String, dynamic> getServiceRequestSummary() {
    String conversationDescription = _generateConversationDescription();
    return {
      'serviceCategory': _currentState.serviceCategory ?? 'General Service',
      'serviceDescription': conversationDescription,
      'problemDescription': conversationDescription,
      'mediaUrls': _currentState.mediaUrls,
      'availability': _currentState.userAvailability ?? {},
      'locationForm': {
        'address': _currentState.address ?? '',
        'zipcode': _currentState.zipcode ?? '',
        'city': _currentState.city ?? '',
        'state': _currentState.state ?? '',
      },
      'contactForm': {
        'tel': _currentState.phoneNumber ?? '',
        'email': _currentState.email ?? '',
      },
      'priceEstimate': _currentState.priceEstimate ?? {},
      'customerName': _currentState.customerName ?? '',
      'tags': _currentState.tags,
      'extractedInfo': _currentState.extractedInfo,
      'conversationStep': _currentState.conversationStep,
      'timestamp': DateTime.now().toIso8601String(),
      'isComplete': _isRequestComplete(),
    };
  }
  
  // Check if request is complete with all required information
  bool _isRequestComplete() {
    return _currentState.serviceCategory != null &&
           _currentState.availabilitySet &&
           _currentState.locationFormCompleted &&
           _currentState.contactFormCompleted &&
           _currentState.priceEstimationCompleted;
  }
  
  // Generate formatted summary for display
  String _generateServiceRequestSummary() {
    String summary = "📋 **SERVICE REQUEST SUMMARY**\n\n";
    
    // Service Information
    summary += "🔧 **Service Type:** ${_currentState.serviceCategory ?? 'General Service'}\n";
    
    // Generate description from conversation content
    String conversationDescription = _generateConversationDescription();
    if (conversationDescription.isNotEmpty) {
      summary += "📝 **Description:** $conversationDescription\n";
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
    
    // Location Information
    if (_currentState.locationFormCompleted) {
      summary += "📍 **Location:** ${_currentState.address}\n";
      summary += "🏠 **Address:** ${_currentState.city}, ${_currentState.state} ${_currentState.zipcode}\n";
    }
    
    // Contact Information
    if (_currentState.contactFormCompleted) {
      summary += "📞 **Phone:** ${_currentState.phoneNumber}\n";
      summary += "📧 **Email:** ${_currentState.email}\n";
    }
    
    // Price Estimation - Hourly Rate Focus
    if (_currentState.priceEstimationCompleted && _currentState.priceEstimate != null) {
      summary += "💰 **Hourly Rate:** ${_formatSummaryPriceEstimate(_currentState.priceEstimate!)}\n";
    }
    
    // Customer Information
    if (_currentState.customerName != null && _currentState.customerName!.isNotEmpty) {
      summary += "👤 **Customer:** ${_currentState.customerName}\n";
    }
    
    summary += "\n✅ **Status:** Ready for professional matching";
    
    return summary;
  }
  
  // Generate meaningful description from conversation content
  String _generateConversationDescription() {
    List<String> userInputs = [];
    List<String> problemDescriptions = [];
    
    // Collect all user messages from the conversation
    for (ChatMessage message in _messages) {
      if (message.type == MessageType.user) {
        String content = message.content.trim();
        // Skip service category names and simple responses
        if (content.length > 10 && 
            !_isSimpleServiceCategory(content) &&
            !_isSimpleResponse(content)) {
          
          // Prioritize messages that describe problems
          if (_containsProblemKeywords(content)) {
            problemDescriptions.add(content);
          } else {
            userInputs.add(content);
          }
        }
      }
    }
    
    // Also check stored descriptions
    if (_currentState.problemDescription != null && 
        _currentState.problemDescription!.isNotEmpty &&
        _currentState.problemDescription != _currentState.serviceCategory) {
      problemDescriptions.add(_currentState.problemDescription!);
    }
    
    if (_currentState.serviceDescription != null && 
        _currentState.serviceDescription!.isNotEmpty &&
        _currentState.serviceDescription != _currentState.serviceCategory) {
      userInputs.add(_currentState.serviceDescription!);
    }
    
    // Prioritize problem descriptions
    List<String> allInputs = [...problemDescriptions, ...userInputs];
    List<String> uniqueInputs = allInputs.toSet().toList();
    
    if (uniqueInputs.isEmpty) {
      return "Customer requested ${_currentState.serviceCategory?.toLowerCase() ?? 'home service'} assistance.";
    }
    
    // Return the most detailed description or combine multiple if they're different
    if (uniqueInputs.length == 1) {
      return uniqueInputs.first;
    } else {
      // Find the longest, most detailed description
      uniqueInputs.sort((a, b) => b.length.compareTo(a.length));
      return uniqueInputs.first;
    }
  }
  
  // Check if content contains problem-describing keywords
  bool _containsProblemKeywords(String content) {
    List<String> problemKeywords = [
      'broken', 'not working', 'leaking', 'damaged', 'need', 'help', 'fix', 'repair',
      'problem', 'issue', 'trouble', 'wrong', 'stuck', 'clogged', 'dirty', 'clean',
      'install', 'replace', 'upgrade', 'maintenance', 'service', 'stopped working'
    ];
    
    String lowerContent = content.toLowerCase();
    return problemKeywords.any((keyword) => lowerContent.contains(keyword));
  }
  
  // Check if input is just a service category name
  bool _isSimpleServiceCategory(String input) {
    List<String> categories = [
      'plumbing', 'electrical', 'hvac', 'appliance repair', 'cleaning',
      'handyman', 'landscaping', 'pest control', 'roofing', 'painting'
    ];
    return categories.contains(input.toLowerCase());
  }
  
  // Check if input is a simple response (yes/no/ok/etc)
  bool _isSimpleResponse(String input) {
    List<String> simpleResponses = [
      'yes', 'no', 'ok', 'sure', 'thanks', 'thank you', 'done', 'skip', 'later'
    ];
    return simpleResponses.contains(input.toLowerCase()) || input.length < 5;
  }
  
  // Format price estimate specifically for summary - clean hourly rate focus
  String _formatSummaryPriceEstimate(Map<String, dynamic> priceEstimate) {
    String currency = priceEstimate['currency'] ?? 'USD';
    
    // Primary focus: Clean hourly rate display
    if (priceEstimate.containsKey('hourly_rates')) {
      Map<String, dynamic> hourlyRates = priceEstimate['hourly_rates'];
      int hourlyMin = hourlyRates['min'] ?? 0;
      int hourlyMax = hourlyRates['max'] ?? 0;
      int hourlyAvg = hourlyRates['avg'] ?? 0;
      
      return '\$${hourlyMin}-\$${hourlyMax}/hour (avg: \$${hourlyAvg}/hour)';
    } else {
      // Fallback: convert project pricing to hourly rate estimate
      int min = priceEstimate['min'] ?? 0;
      int max = priceEstimate['max'] ?? 0;
      int avg = priceEstimate['avg'] ?? 0;
      String estimatedHours = priceEstimate['estimated_hours'] ?? '2-4';
      
      // Estimate hourly rate based on typical project duration
      String timeRange = estimatedHours.replaceAll(' hours', '');
      if (timeRange.contains('-')) {
        List<String> timeParts = timeRange.split('-');
        if (timeParts.length == 2) {
          try {
            int minHours = int.parse(timeParts[0].trim());
            int maxHours = int.parse(timeParts[1].trim());
            int avgHours = ((minHours + maxHours) / 2).round();
            
            int hourlyRateMin = (min / maxHours).round();
            int hourlyRateMax = (max / minHours).round();
            int hourlyRateAvg = (avg / avgHours).round();
            
            return '\$${hourlyRateMin}-\$${hourlyRateMax}/hour (avg: \$${hourlyRateAvg}/hour)';
          } catch (e) {
            // Simple fallback
            return '\$${(avg / 3).round()}/hour (estimated)';
          }
        }
      }
      
      // Final fallback
      return '\$${(avg / 3).round()}/hour (estimated)';
    }
  }
  
  // Get guided service options for new homeowners
  String _getGuidedServiceOptions() {
    String category = _currentState.serviceCategory ?? 'Handyman';
    
    Map<String, List<String>> guidedOptions = {
      'Plumbing': [
        'Faucet dripping or not working (kitchen/bathroom)',
        'Toilet running, clogged, or leaking',
        'Low water pressure or no hot water',
        'Pipe leak or water damage'
      ],
      'Electrical': [
        'Outlet not working or sparking',
        'Light switch or fixture not working',
        'Circuit breaker keeps tripping',
        'Need new outlet or light installed'
      ],
      'HVAC': [
        'AC not cooling or heating not working',
        'Strange noises from vents or unit',
        'High energy bills or poor airflow',
        'Thermostat issues or maintenance needed'
      ],
      'Appliance Repair': [
        'Refrigerator not cooling or making noise',
        'Washer/dryer not working properly',
        'Dishwasher not cleaning or draining',
        'Oven, stove, or microwave issues'
      ],
      'Cleaning': [
        'Deep cleaning for move-in/move-out',
        'Regular house cleaning service',
        'Post-construction or renovation cleanup',
        'Carpet or upholstery cleaning'
      ],
      'Handyman': [
        'Furniture assembly or mounting',
        'Drywall holes or paint touch-ups',
        'Door or window not closing properly',
        'Shelving, curtains, or fixtures installation'
      ],
      'Landscaping': [
        'Lawn mowing or yard cleanup',
        'Tree trimming or removal',
        'Garden design or planting',
        'Sprinkler repair or installation'
      ],
      'Pest Control': [
        'Ants, roaches, or other insects',
        'Rodent problem (mice/rats)',
        'Termite inspection or treatment',
        'General pest prevention'
      ],
      'Roofing': [
        'Roof leak or water damage',
        'Missing or damaged shingles',
        'Gutter cleaning or repair',
        'Roof inspection after storm'
      ],
      'Painting': [
        'Interior room painting',
        'Exterior house painting',
        'Touch-ups or small paint jobs',
        'Cabinet or furniture painting'
      ]
    };
    
    List<String> options = guidedOptions[category] ?? [
      'Repair or fix something broken',
      'Install or setup something new',
      'Regular maintenance or cleaning',
      'Emergency or urgent issue'
    ];
    
    String optionsList = '';
    for (int i = 0; i < options.length && i < 3; i++) {
      optionsList += '• ${options[i]}\n';
    }
    
    return "Got it! Here are common $category issues I help with:\n\n$optionsList\nWhich sounds closest to your situation, or describe your specific issue?";
  }
  
  // Check if user input is related to home services
  bool _isHomeServiceRelated(String input) {
    // Always allow if we're in the middle of a service request
    if (_currentState.serviceCategory != null || _currentState.conversationStep > 0) {
      return true;
    }
    
    // Home service categories
    List<String> serviceCategories = [
      'cleaning', 'plumbing', 'electrical', 'hvac', 'appliance', 'handyman', 
      'landscaping', 'pest control', 'roofing', 'painting', 'repair', 'fix', 
      'install', 'maintenance', 'home', 'house'
    ];
    
    // Home-related keywords
    List<String> homeKeywords = [
      'kitchen', 'bathroom', 'bedroom', 'living room', 'garage', 'basement', 
      'attic', 'yard', 'garden', 'driveway', 'roof', 'ceiling', 'floor', 
      'wall', 'door', 'window', 'pipe', 'drain', 'toilet', 'sink', 'faucet',
      'light', 'outlet', 'switch', 'ac', 'heater', 'furnace', 'water heater',
      'dishwasher', 'washer', 'dryer', 'refrigerator', 'oven', 'stove',
      'fence', 'deck', 'patio', 'lawn', 'tree', 'sprinkler'
    ];
    
    // Problem/action keywords
    List<String> actionKeywords = [
      'broken', 'not working', 'leaking', 'clogged', 'stuck', 'damaged',
      'cracked', 'loose', 'noisy', 'slow', 'dirty', 'need', 'want',
      'looking for', 'help with', 'service', 'professional', 'contractor'
    ];
    
    // Check if input contains any relevant keywords
    for (String keyword in [...serviceCategories, ...homeKeywords, ...actionKeywords]) {
      if (input.contains(keyword)) {
        return true;
      }
    }
    
    // Common off-topic patterns to explicitly reject
    List<String> offTopicPatterns = [
      'weather', 'news', 'politics', 'sports', 'entertainment', 'music',
      'movies', 'food', 'restaurant', 'travel', 'vacation', 'school',
      'work', 'job', 'career', 'health', 'medicine', 'doctor', 'hospital',
      'shopping', 'clothes', 'fashion', 'car', 'vehicle', 'transportation',
      'internet', 'computer', 'phone', 'social media', 'game', 'gaming',
      'what is', 'who is', 'when did', 'where is', 'how to cook',
      'recipe', 'stock market', 'investment', 'cryptocurrency', 'bitcoin'
    ];
    
    for (String pattern in offTopicPatterns) {
      if (input.contains(pattern)) {
        return false;
      }
    }
    
    // If unsure, allow the conversation to continue but with a gentle redirect
    return input.length < 100; // Assume short messages might be service-related
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
    } else if (availability.containsKey('dates') && availability['dates'] is List) {
      // Handle multiple dates
      List<String> dates = List<String>.from(availability['dates']);
      if (dates.length == 1) {
        DateTime date = DateTime.parse(dates.first);
        formatted = "Selected date: ${date.day}/${date.month}/${date.year}";
      } else {
        formatted = "Selected ${dates.length} dates";
      }
      
      // Add time preference if available
      if (availability.containsKey('timePreference')) {
        String timePreference = availability['timePreference'];
        if (timePreference != 'Any time') {
          formatted += ", Time: $timePreference";
        }
      }
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
    return _currentState.conversationStep >= 8 && 
           _isRequestComplete();
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
    print('📅 Triggering calendar UI... Step: ${_currentState.conversationStep}');
    _currentState.calendarRequested = true;
    onCalendarRequested?.call();
  }
  
  // Trigger location form UI
  void _triggerLocationForm() {
    print('📍 Triggering location form UI...');
    _currentState.locationFormRequested = true;
    onLocationFormRequested?.call();
  }
  
  // Trigger contact form UI
  void _triggerContactForm() {
    print('📞 Triggering contact form UI...');
    _currentState.contactFormRequested = true;
    onContactFormRequested?.call();
  }
  
  // Calculate network-based price estimation
  void _calculateNetworkPrice() {
    print('💰 Calculating network-based price...');
    try {
      _currentState.priceEstimate = _generateNetworkBasedPriceEstimate();
      _currentState.priceEstimationCompleted = true;
      print('💰 Price calculation completed: ${_currentState.priceEstimate}');
    } catch (e) {
      print('❌ Price calculation error: $e');
      // Fallback price
      _currentState.priceEstimate = {'min': 100, 'max': 300, 'avg': 200, 'currency': 'USD'};
      _currentState.priceEstimationCompleted = true;
    }
  }
  
  // Setup method to connect UI callbacks
  void setupUICallbacks({
    VoidCallback? onPhotoUpload,
    VoidCallback? onCalendar,
    VoidCallback? onLocationForm,
    VoidCallback? onContactForm,
    Function(Map<String, dynamic>)? onComplete,
  }) {
    onPhotoUploadRequested = onPhotoUpload;
    onCalendarRequested = onCalendar;
    onLocationFormRequested = onLocationForm;
    onContactFormRequested = onContactForm;
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
  
  // Force location form UI to show (call this from your UI)
  void showLocationForm() {
    _triggerLocationForm();
  }
  
  // Force contact form UI to show (call this from your UI)
  void showContactForm() {
    _triggerContactForm();
  }
  
  // Manually trigger price calculation
  void calculatePrice() {
    _calculateNetworkPrice();
  }
  
  // Get current conversation step for UI state management
  int get currentStep => _currentState.conversationStep;
  
  // Check if photo upload should be shown
  bool get shouldShowPhotoUpload => _currentState.conversationStep == 3 && _currentState.photoUploadRequested;
  
  // Check if calendar should be shown
  bool get shouldShowCalendar => _currentState.conversationStep == 4 && _currentState.calendarRequested;
  
  // Check if location form should be shown
  bool get shouldShowLocationForm => _currentState.conversationStep == 5 && _currentState.locationFormRequested;
  
  // Check if contact form should be shown
  bool get shouldShowContactForm => _currentState.conversationStep == 6 && _currentState.contactFormRequested;
} 