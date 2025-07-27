import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants/api_keys.dart';
import 'dart:async';

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

class ServiceCategory {
  final String id;
  final String name;
  final String description;
  final List<String> keywords;
  final List<String> followUpQuestions;
  final Map<String, dynamic> priceRange;
  final String icon;
  final Color color;

  ServiceCategory({
    required this.id,
    required this.name,
    required this.description,
    required this.keywords,
    required this.followUpQuestions,
    required this.priceRange,
    required this.icon,
    required this.color,
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
  
  // Enhanced pricing and location data
  String? userLocation;
  String? marketArea;
  Map<String, dynamic>? serviceDetails;
  Map<String, dynamic>? marketPricing;
  bool locationRequested = false;
  bool contactRequested = false;
  bool photoRequested = false;
  bool availabilityRequested = false;
  bool summaryReady = false;

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
    this.userLocation,
    this.marketArea,
    this.serviceDetails,
    this.marketPricing,
    this.locationRequested = false,
    this.contactRequested = false,
    this.photoRequested = false,
    this.availabilityRequested = false,
    this.summaryReady = false,
  }) : mediaUrls = mediaUrls ?? <String>[],
       tags = tags ?? <String>[],
       extractedInfo = extractedInfo ?? <String, dynamic>{},
       conversationHistory = conversationHistory ?? <Map<String, String>>[];
}

class AIConversationService {
  static final AIConversationService _instance = AIConversationService._internal();
  factory AIConversationService() => _instance;
  AIConversationService._internal();
  
  // LLM Configuration
  static const String _openaiBaseUrl = 'https://api.openai.com/v1/chat/completions';
  static const String _anthropicBaseUrl = 'https://api.anthropic.com/v1/messages';
  
  // API Provider selection (can be changed based on availability)
  static const String _preferredProvider = 'openai'; // 'openai', 'anthropic', 'fallback'
  
  // System prompt that defines the AI's role and knowledge
  static const String _systemPrompt = '''
You are an EXPERT home service AI assistant for Magic Home app. You are a professional service coordinator with deep knowledge of home services. Your role is to:

**CORE RESPONSIBILITIES:**
1. **EXPERT CATEGORIZATION**: Accurately identify and categorize service requests
2. **NATURAL CONVERSATION**: Guide users through information gathering in a natural, conversational way
3. **PROFESSIONAL GUIDANCE**: Provide expert advice and recommendations
4. **COMPLETE INFORMATION GATHERING**: Ensure all necessary details are collected
5. **CONTEXT-AWARE RESPONSES**: Adapt your questions based on what information is already available

**SERVICE EXPERTISE AREAS:**
- HVAC: heating, cooling, furnace, AC, air conditioning, thermostat, ductwork, boiler, heat pump, air filter, refrigerant, compressor
- Plumbing: leak, pipe, drain, toilet, faucet, sink, shower, water, sewer, clog, water heater, sump pump, backflow prevention
- Electrical: power, outlet, switch, light, wiring, breaker, circuit, electrical panel, GFCI, surge protection, lighting installation
- Cleaning: deep cleaning, regular maintenance, specialized cleaning, carpet, window, move-in/out cleaning, post-construction
- Appliance: refrigerator, washer, dryer, dishwasher, oven, microwave, garbage disposal, range hood, ice maker
- Handyman: repairs, installations, maintenance, drywall, painting, door/window work, shelving, general carpentry
- Landscaping: lawn care, gardening, tree services, irrigation, hardscaping, seasonal maintenance, pest control

**CONVERSATION APPROACH:**
- **ASK ONE QUESTION AT A TIME**: Never ask for multiple pieces of information simultaneously
- **NATURAL FLOW**: Don't follow rigid steps - adapt to the conversation naturally
- **CONTEXT AWARENESS**: Check what information is already available before asking
- **PROGRESSIVE GATHERING**: Build on information as the conversation progresses
- **FLEXIBLE ORDERING**: Ask for information in the order that makes sense for each user
- **EXPERT INSIGHTS**: Provide professional recommendations and tips throughout

**INFORMATION GATHERING PRIORITIES:**
1. **Service Details**: What service is needed, specific problems, requirements
2. **Location Information**: Where the service will be performed
3. **Contact Information**: Phone number for coordination
4. **Visual Assessment**: Photos/videos for better understanding (optional but recommended)
5. **Availability**: When the service can be performed
6. **Summary**: Review all information and provide next steps

**CONTACT INFORMATION HANDLING:**
- Always request phone number for service provider coordination
- Ask for primary contact number in format: "(555) 123-4567" or "555-123-4567"
- Explain why contact info is needed: "for service provider coordination"
- Request contact info after service details but before or with location
- Be clear about the purpose: "so service providers can contact you directly"

**RESPONSE GUIDELINES:**
- Use numbered options when appropriate: "1. Option A, 2. Option B, 3. Option C"
- Provide clear, professional explanations
- Include expert tips and recommendations
- Use bullet points for key information
- Always maintain professional, helpful tone
- Adapt your approach based on the user's communication style
- Don't ask for information that's already been provided

**SPECIAL INSTRUCTIONS:**
- **ASK ONE QUESTION AT A TIME**: Never ask for multiple pieces of information simultaneously
- If service category is unclear, ask clarifying questions
- If contact information is missing, request phone number for coordination
- If location is missing, request it naturally in the conversation
- If photos/videos would help, suggest them but don't force them
- If availability is needed, ask when would be convenient
- Always provide context for why you're asking for specific information
- Be conversational and professional, not robotic or scripted
- Provide market-based pricing estimates when appropriate

**UI TRIGGER INSTRUCTIONS:**
- When asking for photos/videos, include keywords: "photo", "picture", or "video" to trigger photo upload UI
- When asking for availability/scheduling, include keywords: "availability", "schedule", or "calendar" to trigger calendar UI
- When ready for summary, include keywords: "summary", "review", or "confirm" to trigger summary UI
- When asking for location, request complete address format: "Street address, City, State, ZIP code"
- When asking for contact info, request phone number format: "(555) 123-4567"

**CONVERSATION FLOW GUIDELINES:**
1. **ASK ONE QUESTION AT A TIME**: Never ask for multiple pieces of information simultaneously
2. **Service Details First**: Always gather service information before asking for contact/location
3. **Contact Request**: Ask for phone number for service provider coordination
4. **Location Request**: Ask for complete address when service details are clear
5. **Photo Request**: Suggest photos/videos after location is confirmed (optional but helpful)
6. **Availability Request**: Ask for scheduling preferences when all other info is collected
7. **Summary**: Provide comprehensive summary when all information is gathered

**RESPONSE FORMAT EXAMPLES:**
- For contact request: "I'll need your contact number so service providers can coordinate with you directly. Please provide your phone number in format: (555) 123-4567"
- For location request: "I'll need your service address to provide accurate pricing and match you with nearby providers. Please provide your complete address: Street, City, State, ZIP code."
- For photo request: "To help our service providers better understand your situation, could you please take a photo or video of the area that needs service?"
- For availability request: "Now let's schedule your service appointment. When would be convenient for a professional to visit your home?"
- For summary: "Perfect! I now have all the information needed. Let me provide you with a comprehensive summary of your service request."
''';

  final List<ServiceCategory> _serviceCategories = [
    ServiceCategory(
      id: 'hvac',
      name: 'HVAC & Heating',
      description: 'Heating, ventilation, air conditioning, and furnace services',
      keywords: ['furnace', 'heating', 'ac', 'air conditioning', 'hvac', 'ventilation', 'boiler', 'heat pump', 'thermostat', 'duct'],
      followUpQuestions: [
        'What type of HVAC system do you have?',
        'When did you first notice the problem?',
        'What sounds is the system making?',
        'Is the system not heating/cooling at all, or is it working poorly?',
        'Have you checked the air filter recently?',
      ],
      priceRange: {'min': 100, 'max': 800, 'average': 300},
      icon: 'ac_unit',
      color: Colors.blue,
    ),
    ServiceCategory(
      id: 'plumbing',
      name: 'Plumbing',
      description: 'Pipe repairs, leak fixes, drain cleaning, and plumbing installations',
      keywords: ['plumbing', 'pipe', 'leak', 'drain', 'toilet', 'faucet', 'sink', 'shower', 'water', 'sewer'],
      followUpQuestions: [
        'Where exactly is the plumbing issue located?',
        'Is there active water damage or flooding?',
        'When did the leak/problem start?',
        'What type of pipes do you have (copper, PVC, etc.)?',
        'Have you tried any temporary fixes?',
      ],
      priceRange: {'min': 80, 'max': 500, 'average': 200},
      icon: 'plumbing',
      color: Colors.teal,
    ),
    ServiceCategory(
      id: 'electrical',
      name: 'Electrical',
      description: 'Electrical repairs, installations, and troubleshooting',
      keywords: ['electrical', 'electric', 'outlet', 'switch', 'light', 'wiring', 'power', 'breaker', 'fuse', 'circuit'],
      followUpQuestions: [
        'What electrical component is having issues?',
        'Are you experiencing complete power loss or partial issues?',
        'When did the electrical problem start?',
        'Have you checked your circuit breaker?',
        'Is this a safety concern or emergency?',
      ],
      priceRange: {'min': 120, 'max': 600, 'average': 250},
      icon: 'electrical_services',
      color: Colors.amber,
    ),
    ServiceCategory(
      id: 'cleaning',
      name: 'Cleaning',
      description: 'Deep cleaning, regular maintenance, and specialized cleaning services',
      keywords: ['clean', 'cleaning', 'vacuum', 'deep clean', 'maid', 'housekeeping', 'sanitize', 'carpet', 'window', 'dirty', 'messy', 'dust', 'dusty', 'spotless', 'tidy', 'mess', 'scrub', 'wash', 'wipe'],
      followUpQuestions: [
        'What type of cleaning service do you need?',
        'How large is the area to be cleaned?',
        'Do you have any specific cleaning requirements?',
        'Are there any areas that need special attention?',
        'Do you need a one-time or recurring service?',
      ],
      priceRange: {'min': 80, 'max': 300, 'average': 150},
      icon: 'cleaning_services',
      color: Colors.green,
    ),
    ServiceCategory(
      id: 'appliance',
      name: 'Appliance Repair',
      description: 'Repair and maintenance of household appliances',
      keywords: ['appliance', 'refrigerator', 'washer', 'dryer', 'dishwasher', 'oven', 'microwave', 'garbage disposal'],
      followUpQuestions: [
        'What type of appliance needs repair?',
        'What brand and model is the appliance?',
        'What specific problem are you experiencing?',
        'How old is the appliance?',
        'Is the appliance still under warranty?',
      ],
      priceRange: {'min': 100, 'max': 400, 'average': 200},
      icon: 'home_repair_service',
      color: Colors.orange,
    ),
    ServiceCategory(
      id: 'handyman',
      name: 'Handyman',
      description: 'General repairs, installations, and home maintenance',
      keywords: ['handyman', 'repair', 'fix', 'install', 'maintenance', 'drywall', 'painting', 'door', 'window', 'shelf'],
      followUpQuestions: [
        'What type of repair or installation do you need?',
        'Can you describe the current condition?',
        'Do you have the materials or need them provided?',
        'Is this an urgent repair?',
        'Are there any specific requirements or preferences?',
      ],
      priceRange: {'min': 60, 'max': 300, 'average': 120},
      icon: 'handyman',
      color: Colors.brown,
    ),
    ServiceCategory(
      id: 'landscaping',
      name: 'Landscaping',
      description: 'Lawn care, gardening, and outdoor maintenance',
      keywords: ['landscaping', 'lawn', 'garden', 'yard', 'grass', 'tree', 'shrub', 'mulch', 'irrigation', 'outdoor'],
      followUpQuestions: [
        'What type of landscaping service do you need?',
        'What is the size of your yard or garden?',
        'Do you have any specific plants or materials in mind?',
        'What is the current condition of your outdoor space?',
        'Do you need ongoing maintenance or a one-time service?',
      ],
      priceRange: {'min': 100, 'max': 500, 'average': 250},
      icon: 'grass',
      color: Colors.lightGreen,
    ),
  ];

  ConversationState _currentState = ConversationState();
  final List<ChatMessage> _messages = [];
  
  // Conversation persistence
  static const String _conversationKey = 'ai_conversation_state';
  static const String _messagesKey = 'ai_conversation_messages';

  List<ChatMessage> get messages => _messages;
  ConversationState get currentState => _currentState;

  void startConversation() {
    _currentState = ConversationState();
    _messages.clear();
    
    _addMessage(ChatMessage(
      content: "**🏠 Welcome to Magic Home Services!**\n\nI'm your **Expert Home Service Assistant** - here to help you get the professional service you need quickly and efficiently.\n\n**How I can help you:**\n• Identify the right service category\n• Gather essential details for accurate quotes\n• Connect you with qualified professionals\n• Ensure your service request is complete\n\n**Available Services:**\n1. **HVAC & Climate Control** ❄️🔥\n2. **Plumbing** 🔧\n3. **Electrical** ⚡\n4. **Cleaning** 🧹\n5. **Appliance Repair** 🏠\n6. **Handyman** 🔨\n7. **Landscaping** 🌳\n\n**What do you need help with today?**\n\n*Simply describe your issue, and I'll guide you through the process with expert questions to ensure you get the best service possible.*",
      type: MessageType.ai,
      timestamp: DateTime.now(),
    ));
    
    // Save initial state
    _saveConversationState();
  }

  void resetConversation() {
    _currentState = ConversationState();
    _messages.clear();
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

    // Add user message to conversation history
    _currentState.conversationHistory.add({
      'role': 'user',
      'content': input,
    });

    String response = await _generateLLMResponse(input);
    
    _addMessage(ChatMessage(
      content: response,
      type: MessageType.ai,
      timestamp: DateTime.now(),
    ));

    // Add AI response to conversation history
    _currentState.conversationHistory.add({
      'role': 'assistant',
      'content': response,
    });

    // Save conversation state after each interaction
    _saveConversationState();

    return response;
  }

  Future<String> _generateLLMResponse(String input) async {
    try {
      // Build comprehensive context for LLM
      String contextPrompt = _buildLLMContextPrompt();
      
      // Use real LLM integration with full conversation context
      return await _callLLMAPI(input, contextPrompt);
    } catch (e) {
      print('Error generating LLM response: $e');
      return _generateFallbackResponse(input);
    }
  }

  String _buildLLMContextPrompt() {
    String context = "**Current Conversation Context:**\n\n";
    
    // Service information
    if (_currentState.serviceCategory != null) {
      context += "Service Category: ${_currentState.serviceCategory}\n";
    }
    if (_currentState.serviceDescription != null) {
      context += "Service Description: ${_currentState.serviceDescription}\n";
    }
    if (_currentState.problemDescription != null) {
      context += "Problem Details: ${_currentState.problemDescription}\n";
    }
    
    // Location information
    if (_currentState.userLocation != null) {
      context += "Location: ${_currentState.userLocation}\n";
    }
    
    // Media attachments
    if (_currentState.mediaUrls.isNotEmpty) {
      context += "Media Attachments: ${_currentState.mediaUrls.length} files\n";
    }
    
    // Service details
    if (_currentState.serviceDetails != null && _currentState.serviceDetails!.isNotEmpty) {
      context += "Service Details: ${_currentState.serviceDetails}\n";
    }
    
    // Availability
    if (_currentState.availability != null) {
      context += "Availability: ${_currentState.availability}\n";
    }
    
    // Tags
    if (_currentState.tags.isNotEmpty) {
      context += "Tags: ${_currentState.tags.join(', ')}\n";
    }
    
    // Missing information analysis - prioritize one at a time
    context += "\n**Next Priority Information Needed:**\n";
    
    // Determine the next most important missing information
    if (_currentState.serviceCategory == null) {
      context += "- Service category not identified (ask for service details first)\n";
    } else if (_currentState.serviceDescription == null || _currentState.serviceDescription!.length < 20) {
      context += "- Service description incomplete (ask for more specific details about the problem)\n";
    } else if (_currentState.extractedInfo['phoneNumber'] == null) {
      context += "- Contact information needed (ask for phone number for coordination)\n";
    } else if (_currentState.userLocation == null) {
      context += "- Location information needed (ask for complete address: Street, City, State, ZIP)\n";
    } else if (_currentState.mediaUrls.isEmpty) {
      context += "- Visual assessment recommended (suggest photos/videos to trigger UI)\n";
    } else if (_currentState.availability == null) {
      context += "- Availability/scheduling information needed (ask for scheduling preferences to trigger calendar UI)\n";
    } else {
      context += "- All information collected (provide comprehensive summary)\n";
    }
    
    // UI trigger guidance
    context += "\n**UI Trigger Guidance:**\n";
    context += "- To show photo upload UI: Include 'photo', 'picture', or 'video' in your response\n";
    context += "- To show calendar UI: Include 'availability', 'schedule', or 'calendar' in your response\n";
    context += "- To show summary UI: Include 'summary', 'review', or 'confirm' in your response\n";
    context += "- For contact request: Ask for phone number format: (555) 123-4567\n";
    context += "- For location request: Ask for complete address format: Street, City, State, ZIP\n";
    
    context += "\n**Conversation History:**\n";
    for (int i = 0; i < _currentState.conversationHistory.length; i++) {
      final entry = _currentState.conversationHistory[i];
      if (entry.containsKey('user')) {
        context += "User: ${entry['user']}\n";
      } else if (entry.containsKey('ai')) {
        context += "Assistant: ${entry['ai']}\n";
      }
    }
    
    return context;
  }

  Future<String> _callLLMAPI(String input, String contextPrompt) async {
    try {
      final messages = [
        {'role': 'system', 'content': '$_systemPrompt\n\n$contextPrompt'},
        ..._currentState.conversationHistory,
      ];

      print('Calling LLM API with messages: $messages');
      print('API Key: ${APIKeys.getOpenAIKey().substring(0, 10)}...');

      // Try OpenAI first
      try {
        final response = await http.post(
          Uri.parse(_openaiBaseUrl),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${APIKeys.getOpenAIKey()}',
          },
          body: jsonEncode({
            'model': 'gpt-3.5-turbo',
            'messages': messages,
            'max_tokens': 300,
            'temperature': 0.7,
          }),
        );

        print('OpenAI API response status: ${response.statusCode}');
        
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          String aiResponse = data['choices'][0]['message']['content'];
          
          // Parse the response to update conversation state
          _updateConversationState(aiResponse, input);
          
          return aiResponse;
        } else if (response.statusCode == 429) {
          print('⚠️ OPENAI QUOTA EXCEEDED: Rate limit hit');
          print('Switching to intelligent fallback...');
          return await _generateIntelligentMockResponse(input);
        } else {
          print('OpenAI API error: ${response.statusCode} - ${response.body}');
          throw Exception('OpenAI API error: ${response.statusCode}');
        }
      } catch (e) {
        print('OpenAI API failed: $e');
        print('Falling back to intelligent response...');
        return await _generateIntelligentMockResponse(input);
      }
    } catch (e) {
      print('Error in LLM API call: $e');
      return await _generateIntelligentMockResponse(input);
    }
  }

  Future<String> _generateIntelligentMockResponse(String input) async {
    // Simulate API delay
    await Future.delayed(const Duration(milliseconds: 300));
    
    String lowerInput = input.toLowerCase();
    
    // Handle greetings and general responses
    if (input.toLowerCase().contains('hello') || input.toLowerCase().contains('hi') || input.toLowerCase().contains('hey')) {
      return "**Hello! 👋**\n\nI'm your **Expert Home Service Assistant** - ready to help you get the professional service you need!\n\n**Available Services:**\n1. **HVAC & Climate Control** ❄️🔥\n2. **Plumbing** 🔧\n3. **Electrical** ⚡\n4. **Cleaning** 🧹\n5. **Appliance Repair** 🏠\n6. **Handyman** 🔨\n7. **Landscaping** 🌳\n\n**What type of service do you need today?**\n\n*Simply describe your issue, and I'll guide you through the process with expert questions to ensure you get the best service possible.*";
    }
    
    // Advanced service categorization using multiple indicators
    if (_currentState.serviceCategory == null) {
      _currentState.serviceCategory = _intelligentServiceCategorization(lowerInput);
      _currentState.serviceDescription = input;
      _currentState.conversationStep = 1;
    }
    
    // Generate contextual response based on conversation step
    switch (_currentState.conversationStep) {
      case 1:
        return _generateInitialResponse(lowerInput);
      case 2:
        return _generateServiceQuestionsResponse(lowerInput);
      case 3:
        return _generateAcknowledgementAndPhotoRequest(lowerInput);
      case 4:
        return _generatePhotoRequestResponse();
      case 5:
        return _generateContactAndLocationRequest(lowerInput);
      case 6:
        if (_currentState.locationRequested && _currentState.userLocation == null) {
          // Check if we have address validation result waiting for confirmation
          if (_currentState.extractedInfo['addressValidation'] != null) {
            return _handleAddressConfirmation(lowerInput);
          } else {
            return _generateLocationResponse(lowerInput);
          }
        } else {
          return _generateAvailabilityRequest(lowerInput);
        }
      case 7:
        return _generateAvailabilityResponse();
      default:
        return _generateContinuationResponse(lowerInput);
    }
  }

  Future<String> _generateMockLLMResponse(String input) async {
    // Simulate API delay
    await Future.delayed(const Duration(milliseconds: 500));
    
    String lowerInput = input.toLowerCase();
    
    // Advanced service categorization using multiple indicators
    if (_currentState.serviceCategory == null) {
      _currentState.serviceCategory = _intelligentServiceCategorization(lowerInput);
      _currentState.serviceDescription = input;
      _currentState.conversationStep = 1;
    }
    
    // Generate contextual response based on conversation step
    switch (_currentState.conversationStep) {
      case 1:
        return _generateInitialResponse(lowerInput);
      case 2:
        return _generateAcknowledgementAndPhotoRequest(lowerInput);
      case 3:
        return _generatePhotoRequestResponse();
      case 4:
        return _generateAvailabilityResponse();
      default:
        return _generateContinuationResponse(lowerInput);
    }
  }

  String _intelligentServiceCategorization(String input) {
    // Enhanced categorization using context and semantic understanding
    Map<String, double> categoryScores = {
      'cleaning': 0.0,
      'plumbing': 0.0,
      'electrical': 0.0,
      'hvac': 0.0,
      'appliance': 0.0,
      'handyman': 0.0,
      'landscaping': 0.0,
    };

    // Cleaning indicators
    if (input.contains('dirty') || input.contains('messy') || input.contains('clean') || 
        input.contains('dust') || input.contains('vacuum') || input.contains('maid') ||
        input.contains('sanitize') || input.contains('scrub') || input.contains('wash') ||
        input.contains('wipe') || input.contains('spotless') || input.contains('deep clean')) {
      categoryScores['cleaning'] = categoryScores['cleaning']! + 10.0;
    }

    // Plumbing indicators
    if (input.contains('leak') || input.contains('pipe') || input.contains('drain') ||
        input.contains('toilet') || input.contains('faucet') || input.contains('sink') ||
        input.contains('shower') || input.contains('water') || input.contains('plumb')) {
      categoryScores['plumbing'] = categoryScores['plumbing']! + 10.0;
    }

    // Electrical indicators
    if (input.contains('power') || input.contains('outlet') || input.contains('switch') ||
        input.contains('light') || input.contains('wiring') || input.contains('electric') ||
        input.contains('breaker') || input.contains('circuit')) {
      categoryScores['electrical'] = categoryScores['electrical']! + 10.0;
    }

    // HVAC indicators
    if (input.contains('heating') || input.contains('cooling') || input.contains('furnace') ||
        input.contains('air conditioning') || input.contains('hvac') || input.contains('thermostat') ||
        input.contains('ac ') || input.contains('heat pump') || input.contains('boiler')) {
      categoryScores['hvac'] = categoryScores['hvac']! + 10.0;
    }

    // Appliance indicators
    if (input.contains('refrigerator') || input.contains('washer') || input.contains('dryer') ||
        input.contains('dishwasher') || input.contains('oven') || input.contains('microwave') ||
        input.contains('appliance') || input.contains('fridge')) {
      categoryScores['appliance'] = categoryScores['appliance']! + 10.0;
    }

    // Landscaping indicators
    if (input.contains('lawn') || input.contains('garden') || input.contains('yard') ||
        input.contains('tree') || input.contains('grass') || input.contains('outdoor') ||
        input.contains('landscape') || input.contains('irrigation')) {
      categoryScores['landscaping'] = categoryScores['landscaping']! + 10.0;
    }

    // Find the category with highest score
    String bestCategory = 'handyman';
    double bestScore = 0.0;
    
    categoryScores.forEach((category, score) {
      if (score > bestScore) {
        bestScore = score;
        bestCategory = category;
      }
    });

    return bestCategory;
  }

  String _generateInitialResponse(String input) {
    String category = _currentState.serviceCategory!;
    String response = "";
    
    // Generate expert category-specific acknowledgment
    switch (category) {
      case 'cleaning':
        response = "**Professional Cleaning Services** 🧹\n\nI understand you need cleaning services. ";
        if (input.contains('dirty') || input.contains('messy')) {
          response += "I can help you get your home clean and tidy with professional cleaning solutions. ";
        }
        break;
      case 'plumbing':
        response = "**Expert Plumbing Services** 🔧\n\nI see you have a plumbing issue. ";
        if (input.contains('leak')) {
          response += "Water leaks can cause serious damage, so let's get this addressed quickly by a licensed plumber. ";
        }
        break;
      case 'electrical':
        response = "**Licensed Electrical Services** ⚡\n\nI understand you need electrical work. ";
        if (input.contains('power') || input.contains('outlet')) {
          response += "Electrical issues should always be handled by licensed professionals for your safety. ";
        }
        break;
      case 'hvac':
        response = "**HVAC & Climate Control Services** ❄️🔥\n\nI see you need help with your heating or cooling system. ";
        break;
      case 'appliance':
        response = "**Appliance Repair Services** 🏠\n\nI understand you have an appliance that needs professional attention. ";
        break;
      case 'landscaping':
        response = "**Landscaping & Outdoor Services** 🌳\n\nI see you need help with outdoor/landscaping work. ";
        break;
      default:
        response = "**Handyman Services** 🔨\n\nI understand you need some handyman services. ";
    }

    // Ask for service details first
    response += "\n\n**🔍 Service Details Required**\n\nTo provide you with the most accurate pricing and match you with the right service providers, I need to gather some specific details about your service needs.\n\n";
    response += _getStructuredFollowUpQuestions(category, input);
    
    _currentState.conversationStep = 2;
    return response;
  }

  String _getStructuredFollowUpQuestions(String category, String input) {
    switch (category) {
      case 'cleaning':
        return '''**1. What type of cleaning service do you need?**
1. Deep cleaning (thorough, detailed cleaning)
2. Regular maintenance cleaning
3. Move-in/out cleaning
4. Post-construction cleanup
5. Specialized cleaning (carpet, window, etc.)

**2. What areas need cleaning?**
1. Kitchen only
2. Bathrooms only
3. Living areas only
4. Bedrooms only
5. All areas

**3. How large is your home?**
1. Studio/1 bedroom
2. 2-3 bedrooms
3. 4+ bedrooms
4. Large home (2000+ sq ft)
5. Commercial property

**4. Any special requirements?**
• Pet-friendly cleaning products
• Eco-friendly options
• Specific areas needing extra attention
• Time constraints

**5. Preferred frequency?**
1. One-time service
2. Weekly
3. Bi-weekly
4. Monthly

*Please respond with the number(s) that best describe your needs, or provide additional details.*''';

      case 'plumbing':
        return '''**1. Where is the plumbing issue located?**
1. Kitchen
2. Bathroom
3. Basement
4. Outdoor
5. Multiple areas

**2. What type of problem are you experiencing?**
1. Leak (water dripping/flowing)
2. Clog (slow drain/backup)
3. Low water pressure
4. No hot water
5. Running toilet
6. Other

**3. Is there active water damage?**
• Visible water damage
• Mold/mildew
• Ceiling/wall damage
• Floor damage

**4. When did the issue start?**
• Just started
• A few days ago
• A week or more
• Ongoing issue

**5. Have you tried any DIY fixes?**
• Plunger
• Drain cleaner
• Turned off water
• Other attempts

*Please respond with the number(s) that best describe your situation, or provide additional details.*''';

      case 'electrical':
        return '''**1. What electrical component is affected?**
1. Outlet
2. Switch
3. Light fixture
4. Circuit breaker
5. Electrical panel
6. Multiple components

**2. What's the specific issue?**
1. No power (complete loss)
2. Intermittent power
3. Sparks/smoking
4. Tripping breaker
5. Flickering lights
6. Other

**3. Is this a safety concern?**
• Burning smell
• Sparks
• Hot outlets
• Exposed wiring
• Emergency situation

**4. When did the problem start?**
• Just started
• A few days ago
• Ongoing issue
• After recent work

**5. Have you checked the circuit breaker?**
• Yes, breaker is fine
• Yes, breaker keeps tripping
• No, haven't checked
• Don't know how

*Please respond with the number(s) that best describe your situation, or provide additional details.*''';

      case 'hvac':
        return '''**1. What type of HVAC system do you have?**
1. Central AC/Furnace
2. Heat Pump
3. Mini-split system
4. Boiler
5. Other

**2. What specific issue are you experiencing?**
1. Not heating/cooling at all
2. Poor performance (weak airflow)
3. Strange noises
4. High energy bills
5. Thermostat issues
6. Other

**3. When did the problem start?**
• Just started
• A few days ago
• A week or more
• Seasonal issue

**4. Have you checked/changed the air filter recently?**
• Yes, filter is clean
• No, haven't checked
• Don't know how
• Filter is dirty

**5. Is this an emergency situation?**
• No heat in winter
• No AC in summer
• System completely down
• Can wait for service

*Please respond with the number(s) that best describe your situation, or provide additional details.*''';

      case 'appliance':
        return '''**1. What appliance needs repair?**
1. Refrigerator
2. Washer/Dryer
3. Dishwasher
4. Oven/Range
5. Microwave
6. Other

**2. What's the problem?**
1. Not working at all
2. Making strange noises
3. Leaking water
4. Poor performance
5. Error codes
6. Other

**3. Brand and approximate age?**
• Brand: (e.g., Samsung, LG, Whirlpool)
• Age: (e.g., 2 years, 5 years, 10+ years)

**4. Is it still under warranty?**
• Yes, still under warranty
• No, warranty expired
• Don't know
• Extended warranty

**5. When did the issue start?**
• Just started
• A few days ago
• Gradual decline
• After power outage

*Please respond with the number(s) that best describe your situation, or provide additional details.*''';

      case 'landscaping':
        return '''**1. What landscaping service do you need?**
1. Lawn care (mowing, edging, maintenance)
2. Tree services (trimming, removal)
3. Garden maintenance
4. Irrigation system
5. Hardscaping (patios, walkways)
6. Other

**2. What is the size of your property?**
1. Small yard (< 0.25 acres)
2. Medium yard (0.25-0.5 acres)
3. Large yard (0.5+ acres)
4. Commercial property

**3. What is the current condition?**
1. Well-maintained
2. Needs attention
3. Overgrown
4. New construction
5. Neglected

**4. Any specific requirements?**
• Native plants
• Drought-resistant
• Low maintenance
• Seasonal work
• Specific design preferences

**5. Do you need ongoing or one-time service?**
1. One-time service
2. Weekly maintenance
3. Bi-weekly maintenance
4. Monthly maintenance
5. Seasonal service

*Please respond with the number(s) that best describe your needs, or provide additional details.*''';

      default:
        return '''**1. What type of work do you need?**
1. Repairs
2. Installation
3. Assembly
4. Painting
5. General maintenance
6. Other

**2. What specific project?**
1. Drywall repair
2. Door/window work
3. Shelving/Storage
4. Painting
5. Other

**3. Do you have materials or need them provided?**
1. Have materials
2. Need materials provided
3. Need recommendations
4. Don't know yet

**4. Timeline preference?**
1. ASAP (urgent)
2. This week
3. Flexible timing
4. Scheduled appointment

**5. Any specific requirements?**
• Professional finish
• Matching existing work
• Specific materials
• Time constraints

*Please respond with the number(s) that best describe your needs, or provide additional details.*''';
    }
  }

  String _generateAcknowledgementAndPhotoRequest(String input) {
    _currentState.problemDescription = (_currentState.problemDescription ?? "") + "\n" + input;
    _currentState.conversationStep = 3;

    String category = _currentState.serviceCategory ?? 'work';
    String response = "**Excellent! Thank you for the detailed information.** ✅\n\n";
    
    if (category == 'cleaning') {
      response += "I now have a clear understanding of your cleaning requirements. ";
    } else {
      response += "I have all the essential details about your service needs. ";
    }
    
    // Add market-based pricing information
    Map<String, dynamic> pricing = _getMarketBasedPricing();
    response += "\n\n**💰 Market Price Estimate**\n\nBased on your service details and location, here's what you can expect:\n\n";
    response += "**Price Range:** \$${pricing['min']} - \$${pricing['max']}\n";
    response += "**Average:** \$${pricing['average']}\n";
    response += "**Market Area:** ${pricing['marketArea']}\n";
    response += "**Confidence Level:** ${(pricing['confidence'] * 100).round()}%\n\n";
    
    if (pricing['locationAdjustment'] != 1.0) {
      String adjustment = pricing['locationAdjustment'] > 1.0 ? 'higher' : 'lower';
      response += "*Note: Pricing reflects ${adjustment} market rates in your area.*\n\n";
    }
    
    response += "**📸 Visual Assessment Required**\n\nTo ensure our service providers can give you the most accurate quote and prepare properly, I need you to take a photo or record a short video (under 30 seconds) of the area that needs service.\n\n**Why this helps:**\n• More accurate pricing\n• Right tools and materials\n• Better preparation\n• Faster service completion\n\n**What to capture:**\n• The main problem area\n• Overall context\n• Any specific details mentioned\n\n*You can skip this step if you prefer, but it helps us provide better service.*";
    
    return response;
  }

  String _generatePhotoRequestResponse() {
    _currentState.conversationStep = 5;
    return "**Perfect! 📸**\n\nNow I need to get your contact information and service location to match you with the right service provider.\n\n**📞 Contact & Location Details**\n\nPlease provide:\n\n**1. Your contact number** (for service provider coordination)\n**2. Your service address** (where the work needs to be done)\n\n*This information helps us find qualified providers in your area and coordinate the service.*";
  }

  String _generateAvailabilityRequest(String input) {
    _currentState.conversationStep = 7;
    return "**Perfect! 📍**\n\nNow let's schedule your service appointment.\n\n**📅 Availability Planning**\n\nWhen would be convenient for a professional service provider to visit your home?\n\n**Please select your preferred dates and time slots using the calendar below.**\n\n*This helps us match you with the best available service provider.*";
  }

  String _generateAvailabilityResponse() {
    _currentState.conversationStep = 8;
    return "**Excellent! 🎯**\n\nI now have all the essential information needed to create your professional service request.\n\n**📋 Preparing Your Service Summary**\n\nLet me compile everything into a comprehensive summary for you to review before we submit your request to our network of qualified service providers.\n\n*This ensures accuracy and helps us match you with the best professional for your specific needs.*";
  }

  String _generateContinuationResponse(String input) {
    if (_currentState.conversationStep >= 2 && _currentState.problemDescription != null) {
      return "**Thank you for the additional information! ✅**\n\n**📸 Visual Assessment Required**\n\nTo help our service providers prepare an accurate quote and better understand your situation, could you please take a photo or record a short video (under 30 seconds) of the area that needs service?\n\n**Why this helps:**\n• More accurate pricing\n• Right tools and materials\n• Better preparation\n• Faster service completion\n\n*You can skip this step if you prefer, but it helps us provide better service.*";
    }
    return "**Thank you for the additional information! ✅**\n\nIs there anything else you'd like to add about your service needs to help us provide the best possible service?";
  }

  String _buildContextPrompt() {
    String context = "Current conversation step: ${_currentState.conversationStep}\n";
    if (_currentState.serviceCategory != null) {
      context += "Service category: ${_currentState.serviceCategory}\n";
    }
    if (_currentState.serviceDescription != null) {
      context += "Service description: ${_currentState.serviceDescription}\n";
    }
    if (_currentState.problemDescription != null) {
      context += "Problem details: ${_currentState.problemDescription}\n";
    }
    
    return context;
  }

  void _updateConversationState(String aiResponse, String userInput) {
    // Extract information from user input
    _extractServiceInformation(userInput);
    
    // Analyze AI response to determine what information was requested
    _analyzeAIResponse(aiResponse);
    
    // Update conversation state based on what information is still needed
    _updateMissingInformation();
  }

  void _extractServiceInformation(String userInput) {
    // Extract service category if not already set
    if (_currentState.serviceCategory == null) {
      _currentState.serviceCategory = _intelligentServiceCategorization(userInput.toLowerCase());
      _currentState.serviceDescription = userInput;
    }
    
    // Extract location information
    _extractLocationFromInput(userInput);
    
    // Extract service details
    _extractServiceDetailsFromInput(userInput);
    
    // Extract contact information if present
    String? phoneNumber = _extractPhoneNumber(userInput);
    if (phoneNumber != null) {
      _currentState.extractedInfo['phoneNumber'] = phoneNumber;
    }
  }

  void _analyzeAIResponse(String aiResponse) {
    String lowerResponse = aiResponse.toLowerCase();
    
    // Detect what type of information the AI is requesting
    if (lowerResponse.contains('photo') || lowerResponse.contains('picture') || lowerResponse.contains('video')) {
      _currentState.photoRequested = true;
    }
    
    if (lowerResponse.contains('location') || lowerResponse.contains('address') || lowerResponse.contains('where')) {
      _currentState.locationRequested = true;
    }
    
    if (lowerResponse.contains('contact') || lowerResponse.contains('phone') || lowerResponse.contains('number')) {
      _currentState.contactRequested = true;
    }
    
    if (lowerResponse.contains('availability') || lowerResponse.contains('schedule') || lowerResponse.contains('when')) {
      _currentState.availabilityRequested = true;
    }
    
    if (lowerResponse.contains('summary') || lowerResponse.contains('review') || lowerResponse.contains('confirm')) {
      _currentState.summaryReady = true;
    }
  }

  void _updateMissingInformation() {
    // Determine what information is still needed based on current state
    List<String> missingInfo = [];
    
    if (_currentState.serviceCategory == null) {
      missingInfo.add('service_category');
    }
    
    if (_currentState.serviceDescription == null) {
      missingInfo.add('service_description');
    }
    
    if (_currentState.extractedInfo['phoneNumber'] == null) {
      missingInfo.add('contact');
    }
    
    if (_currentState.userLocation == null) {
      missingInfo.add('location');
    }
    
    if (_currentState.mediaUrls.isEmpty) {
      missingInfo.add('visual_assessment');
    }
    
    if (_currentState.availability == null) {
      missingInfo.add('availability');
    }
    
    // Update conversation step based on missing information
    if (missingInfo.contains('service_category') || missingInfo.contains('service_description')) {
      _currentState.conversationStep = 1; // Service identification
    } else if (missingInfo.contains('contact')) {
      _currentState.conversationStep = 2; // Contact request
    } else if (missingInfo.contains('location')) {
      _currentState.conversationStep = 3; // Location request
    } else if (missingInfo.contains('visual_assessment')) {
      _currentState.conversationStep = 4; // Photo request
    } else if (missingInfo.contains('availability')) {
      _currentState.conversationStep = 5; // Availability request
    } else {
      _currentState.conversationStep = 6; // Summary ready
    }
  }

  void _extractLocationFromInput(String input) {
    if (_currentState.userLocation != null) return; // Already set
    
    String lowerInput = input.toLowerCase();
    
    // Extract location keywords
    Map<String, String> locationKeywords = {
      'new york': 'new_york',
      'nyc': 'new_york',
      'manhattan': 'new_york',
      'brooklyn': 'new_york',
      'los angeles': 'los_angeles',
      'la': 'los_angeles',
      'san francisco': 'san_francisco',
      'sf': 'san_francisco',
      'bay area': 'san_francisco',
      'washington dc': 'washington_dc',
      'dc': 'washington_dc',
      'boston': 'boston',
      'seattle': 'seattle',
      'chicago': 'chicago',
      'denver': 'denver',
      'atlanta': 'atlanta',
      'dallas': 'dallas',
      'houston': 'houston',
      'phoenix': 'phoenix',
      'miami': 'miami',
      'orlando': 'orlando',
      'las vegas': 'las_vegas',
      'austin': 'austin',
      'suburban': 'suburban',
      'rural': 'rural',
    };
    
    locationKeywords.forEach((keyword, location) {
      if (lowerInput.contains(keyword)) {
        _currentState.userLocation = location;
        _currentState.marketArea = _getMarketArea(location);
      }
    });
  }

  void _extractServiceDetailsFromInput(String input) {
    if (_currentState.serviceDetails == null) {
      _currentState.serviceDetails = {};
    }
    
    String lowerInput = input.toLowerCase();
    String category = _currentState.serviceCategory ?? '';
    
    // Extract service-specific details based on category
    switch (category) {
      case 'cleaning':
        if (lowerInput.contains('deep clean')) _currentState.serviceDetails!['deep_cleaning'] = true;
        if (lowerInput.contains('move in') || lowerInput.contains('move out')) _currentState.serviceDetails!['move_in_out'] = true;
        if (lowerInput.contains('post construction')) _currentState.serviceDetails!['post_construction'] = true;
        if (lowerInput.contains('large') || lowerInput.contains('big')) _currentState.serviceDetails!['large_home'] = true;
        if (lowerInput.contains('commercial')) _currentState.serviceDetails!['commercial'] = true;
        break;
        
      case 'plumbing':
        if (lowerInput.contains('emergency') || lowerInput.contains('urgent')) _currentState.serviceDetails!['emergency'] = true;
        if (lowerInput.contains('leak')) _currentState.serviceDetails!['leak_repair'] = true;
        if (lowerInput.contains('drain')) _currentState.serviceDetails!['drain_cleaning'] = true;
        if (lowerInput.contains('water heater')) _currentState.serviceDetails!['water_heater'] = true;
        if (lowerInput.contains('pipe')) _currentState.serviceDetails!['pipe_replacement'] = true;
        break;
        
      case 'electrical':
        if (lowerInput.contains('emergency') || lowerInput.contains('urgent')) _currentState.serviceDetails!['emergency'] = true;
        if (lowerInput.contains('panel')) _currentState.serviceDetails!['panel_work'] = true;
        if (lowerInput.contains('outlet')) _currentState.serviceDetails!['outlet_installation'] = true;
        if (lowerInput.contains('light')) _currentState.serviceDetails!['lighting'] = true;
        if (lowerInput.contains('wiring')) _currentState.serviceDetails!['wiring'] = true;
        if (lowerInput.contains('safety')) _currentState.serviceDetails!['safety_issue'] = true;
        break;
        
      case 'hvac':
        if (lowerInput.contains('emergency') || lowerInput.contains('urgent')) _currentState.serviceDetails!['emergency'] = true;
        if (lowerInput.contains('repair')) _currentState.serviceDetails!['system_repair'] = true;
        if (lowerInput.contains('maintenance')) _currentState.serviceDetails!['maintenance'] = true;
        if (lowerInput.contains('thermostat')) _currentState.serviceDetails!['thermostat'] = true;
        if (lowerInput.contains('duct')) _currentState.serviceDetails!['ductwork'] = true;
        break;
        
      case 'appliance':
        if (lowerInput.contains('refrigerator') || lowerInput.contains('fridge')) _currentState.serviceDetails!['refrigerator'] = true;
        if (lowerInput.contains('washer') || lowerInput.contains('dryer')) _currentState.serviceDetails!['washer_dryer'] = true;
        if (lowerInput.contains('dishwasher')) _currentState.serviceDetails!['dishwasher'] = true;
        if (lowerInput.contains('oven') || lowerInput.contains('range')) _currentState.serviceDetails!['oven_range'] = true;
        if (lowerInput.contains('microwave')) _currentState.serviceDetails!['microwave'] = true;
        if (lowerInput.contains('warranty')) _currentState.serviceDetails!['warranty_work'] = true;
        break;
        
      case 'handyman':
        if (lowerInput.contains('repair')) _currentState.serviceDetails!['repairs'] = true;
        if (lowerInput.contains('install')) _currentState.serviceDetails!['installation'] = true;
        if (lowerInput.contains('assemble')) _currentState.serviceDetails!['assembly'] = true;
        if (lowerInput.contains('paint')) _currentState.serviceDetails!['painting'] = true;
        if (lowerInput.contains('drywall')) _currentState.serviceDetails!['drywall'] = true;
        if (lowerInput.contains('urgent') || lowerInput.contains('asap')) _currentState.serviceDetails!['urgent'] = true;
        break;
        
      case 'landscaping':
        if (lowerInput.contains('lawn')) _currentState.serviceDetails!['lawn_care'] = true;
        if (lowerInput.contains('tree')) _currentState.serviceDetails!['tree_services'] = true;
        if (lowerInput.contains('garden')) _currentState.serviceDetails!['garden_maintenance'] = true;
        if (lowerInput.contains('irrigation')) _currentState.serviceDetails!['irrigation'] = true;
        if (lowerInput.contains('hardscape') || lowerInput.contains('patio')) _currentState.serviceDetails!['hardscaping'] = true;
        if (lowerInput.contains('large') || lowerInput.contains('big')) _currentState.serviceDetails!['large_property'] = true;
        break;
    }
  }

  String _generateFallbackResponse(String input) {
    if (_currentState.conversationStep >= 2) {
      return "**Thank you for the information! ✅**\n\n**📸 Visual Assessment Required**\n\nTo help our service providers better understand your situation and provide an accurate quote, could you please take a photo or record a short video (under 30 seconds) of the area that needs service?\n\n**Why this helps:**\n• More accurate pricing\n• Right tools and materials\n• Better preparation\n• Faster service completion\n\n*You can skip this step if you prefer, but it helps us provide better service.*";
    }
    return "**I understand you need help with your home service request! 🏠**\n\nCould you please tell me more about what specific work you need done? I'm here to help you get the right professional service.\n\n**Available Services:**\n1. **HVAC & Climate Control** ❄️🔥\n2. **Plumbing** 🔧\n3. **Electrical** ⚡\n4. **Cleaning** 🧹\n5. **Appliance Repair** 🏠\n6. **Handyman** 🔨\n7. **Landscaping** 🌳";
  }

  void addMediaUrl(String url) {
    _currentState.mediaUrls.add(url);
  }

  void setAvailability(Map<String, dynamic> availability) {
    _currentState.availability = availability;
  }

  void setUserLocation(String location) {
    _currentState.userLocation = location;
    _currentState.marketArea = _getMarketArea(location);
  }

  void setServiceDetails(Map<String, dynamic> details) {
    _currentState.serviceDetails = details;
  }

  Map<String, dynamic> getMarketPricing() {
    return _getMarketBasedPricing();
  }

  void setValidatedAddress(Map<String, dynamic> addressData) {
    _currentState.location = addressData['formattedAddress'];
    _currentState.userLocation = addressData['marketArea'];
    _currentState.marketArea = addressData['marketArea'];
    _currentState.locationRequested = true;
  }

  Future<Map<String, dynamic>> generateServiceRequestSummary() async {
    // Generate price estimate using LLM analysis
    Map<String, dynamic> priceEstimate = await _generatePriceEstimate();
    
    return {
      'description': _currentState.serviceDescription ?? 'Service request',
      'details': _currentState.problemDescription ?? 'Additional details provided',
      'category': _currentState.serviceCategory ?? 'general',
      'serviceType': _currentState.serviceCategory ?? 'general',
      'tags': _currentState.tags,
      'mediaUrls': _currentState.mediaUrls,
      'availability': _currentState.availability,
      'priceEstimate': priceEstimate,
      'priority': _currentState.tags.contains('Emergency') ? 'high' : 'medium',
    };
  }

  Future<Map<String, dynamic>> _generatePriceEstimate() async {
    try {
      // Prepare comprehensive context for LLM analysis
      String context = _buildPricingContext();
      
      // Create pricing analysis prompt
      String prompt = '''
You are an expert pricing analyst for home services. Analyze the following service request and provide a detailed price estimate.

**Service Request Context:**
$context

**Your Task:**
Provide a JSON response with the following structure:
{
  "min": <minimum_price_in_dollars>,
  "max": <maximum_price_in_dollars>, 
  "average": <average_price_in_dollars>,
  "unit": "<pricing_unit>",
  "confidence": <confidence_level_0_to_1>,
  "factors": ["factor1", "factor2", "factor3"],
  "reasoning": "<detailed_explanation_of_pricing_logic>",
  "marketArea": "<market_area>",
  "complexity": "<low/medium/high>",
  "urgency": "<low/medium/high>",
  "estimatedHours": <estimated_hours_if_applicable>
}

**Pricing Guidelines:**
- Consider location-based market rates
- Factor in service complexity and urgency
- Account for materials and labor costs
- Include travel time for the service area
- Consider seasonal factors if relevant
- Base estimates on current market conditions

**Response Format:**
Return ONLY the JSON object, no additional text.
''';

      // Call LLM API for pricing analysis
      String response = await _callLLMAPI(prompt, '');
      
      // Parse JSON response
      Map<String, dynamic> pricingData = json.decode(response);
      
      // Validate and sanitize the response
      return _validatePricingResponse(pricingData);
      
    } catch (e) {
      print('Error generating LLM price estimate: $e');
      // Fallback to basic estimation if LLM fails
      return _generateFallbackPriceEstimate();
    }
  }

  String _buildPricingContext() {
    String context = '';
    
    // Service details
    context += 'Service Category: ${_currentState.serviceCategory ?? 'Unknown'}\n';
    context += 'Service Description: ${_currentState.serviceDescription ?? 'No description'}\n';
    context += 'Problem Details: ${_currentState.problemDescription ?? 'No details'}\n';
    
    // Location information
    context += 'Location: ${_currentState.userLocation ?? 'Unknown'}\n';
    context += 'Market Area: ${_getMarketArea(_currentState.userLocation ?? 'default')}\n';
    
    // Service details and complexity
    if (_currentState.serviceDetails != null && _currentState.serviceDetails!.isNotEmpty) {
      context += 'Service Details: ${_currentState.serviceDetails}\n';
    }
    
    // Media attachments
    if (_currentState.mediaUrls.isNotEmpty) {
      context += 'Media Attachments: ${_currentState.mediaUrls.length} files provided\n';
    }
    
    // Tags and priority indicators
    if (_currentState.tags.isNotEmpty) {
      context += 'Tags: ${_currentState.tags.join(', ')}\n';
    }
    
    // Availability information
    if (_currentState.availability != null) {
      context += 'Availability: ${_currentState.availability}\n';
    }
    
    return context;
  }

  Map<String, dynamic> _validatePricingResponse(Map<String, dynamic> data) {
    // Ensure all required fields are present and valid
    return {
      'min': _validatePrice(data['min'] ?? 100),
      'max': _validatePrice(data['max'] ?? 300),
      'average': _validatePrice(data['average'] ?? 200),
      'unit': data['unit'] ?? 'service',
      'confidence': _validateConfidence(data['confidence'] ?? 0.7),
      'factors': _validateFactors(data['factors'] ?? ['standard_service']),
      'reasoning': data['reasoning'] ?? 'Price estimate based on service analysis',
      'marketArea': data['marketArea'] ?? _getMarketArea(_currentState.userLocation ?? 'default'),
      'complexity': data['complexity'] ?? 'medium',
      'urgency': data['urgency'] ?? 'medium',
      'estimatedHours': _validateHours(data['estimatedHours'] ?? 2),
    };
  }

  int _validatePrice(dynamic price) {
    if (price is int) return price;
    if (price is double) return price.round();
    if (price is String) {
      int? parsed = int.tryParse(price.replaceAll(RegExp(r'[^\d]'), ''));
      return parsed ?? 100;
    }
    return 100;
  }

  double _validateConfidence(dynamic confidence) {
    if (confidence is double) return confidence.clamp(0.0, 1.0);
    if (confidence is int) return (confidence / 100).clamp(0.0, 1.0);
    if (confidence is String) {
      double? parsed = double.tryParse(confidence);
      return parsed?.clamp(0.0, 1.0) ?? 0.7;
    }
    return 0.7;
  }

  List<String> _validateFactors(dynamic factors) {
    if (factors is List) {
      return factors.map((f) => f.toString()).toList();
    }
    return ['standard_service'];
  }

  int _validateHours(dynamic hours) {
    if (hours is int) return hours;
    if (hours is double) return hours.round();
    if (hours is String) {
      int? parsed = int.tryParse(hours);
      return parsed ?? 2;
    }
    return 2;
  }

  Map<String, dynamic> _generateFallbackPriceEstimate() {
    // Fallback pricing when LLM fails
    String category = _currentState.serviceCategory ?? 'handyman';
    Map<String, dynamic> basePricing = _getBasePricingByCategory(category);
    
    return {
      'min': basePricing['min'] ?? 100,
      'max': basePricing['max'] ?? 300,
      'average': basePricing['average'] ?? 200,
      'unit': basePricing['unit'] ?? 'service',
      'confidence': 0.5,
      'factors': ['fallback_estimation'],
      'reasoning': 'Fallback pricing used due to analysis error',
      'marketArea': _getMarketArea(_currentState.userLocation ?? 'default'),
      'complexity': 'medium',
      'urgency': 'medium',
      'estimatedHours': 2,
    };
  }

  Map<String, dynamic> _getMarketBasedPricing() {
    String category = _currentState.serviceCategory ?? 'handyman';
    String location = _currentState.userLocation ?? 'default';
    Map<String, dynamic> serviceDetails = _currentState.serviceDetails ?? {};
    
    // Base pricing by service category and complexity
    Map<String, dynamic> basePricing = _getBasePricingByCategory(category);
    
    // Location-based adjustments
    Map<String, double> locationMultipliers = _getLocationMultipliers(location);
    double locationMultiplier = locationMultipliers[location] ?? 1.0;
    
    // Service complexity adjustments
    Map<String, dynamic> complexityAdjustments = _getComplexityAdjustments(category, serviceDetails);
    double complexityMultiplier = complexityAdjustments['multiplier'] ?? 1.0;
    
    // Calculate adjusted pricing
    int baseMin = (basePricing['min'] as int?) ?? 100;
    int baseMax = (basePricing['max'] as int?) ?? 300;
    int baseAverage = (basePricing['average'] as int?) ?? 200;
    
    int adjustedMin = (baseMin * locationMultiplier * complexityMultiplier).round();
    int adjustedMax = (baseMax * locationMultiplier * complexityMultiplier).round();
    int adjustedAverage = (baseAverage * locationMultiplier * complexityMultiplier).round();
    
    // Determine confidence level based on available information
    double confidence = _calculatePricingConfidence();
    
    return {
      'min': adjustedMin,
      'max': adjustedMax,
      'average': adjustedAverage,
      'unit': basePricing['unit'] ?? 'service',
      'confidence': confidence,
      'factors': _getPricingFactors(category, serviceDetails, location),
      'marketArea': _getMarketArea(location),
      'locationAdjustment': locationMultiplier,
      'serviceComplexity': complexityMultiplier,
      'basePricing': basePricing,
    };
  }

  Map<String, dynamic> _getBasePricingByCategory(String category) {
    Map<String, Map<String, dynamic>> pricing = {
      'cleaning': {
        'min': 80, 'max': 200, 'average': 140, 'unit': 'visit',
        'complexity_factors': {
          'deep_cleaning': 1.3,
          'move_in_out': 1.5,
          'post_construction': 1.8,
          'specialized': 1.4,
          'large_home': 1.6,
          'commercial': 2.0,
        }
      },
      'plumbing': {
        'min': 150, 'max': 400, 'average': 275, 'unit': 'job',
        'complexity_factors': {
          'emergency': 1.5,
          'leak_repair': 1.2,
          'drain_cleaning': 1.1,
          'water_heater': 1.4,
          'pipe_replacement': 1.6,
          'multiple_locations': 1.3,
        }
      },
      'electrical': {
        'min': 100, 'max': 300, 'average': 200, 'unit': 'job',
        'complexity_factors': {
          'emergency': 1.6,
          'panel_work': 1.5,
          'outlet_installation': 1.1,
          'lighting': 1.2,
          'wiring': 1.4,
          'safety_issue': 1.3,
        }
      },
      'hvac': {
        'min': 100, 'max': 500, 'average': 300, 'unit': 'service',
        'complexity_factors': {
          'emergency': 1.5,
          'system_repair': 1.3,
          'maintenance': 1.1,
          'thermostat': 1.2,
          'ductwork': 1.4,
          'replacement_parts': 1.6,
        }
      },
      'appliance': {
        'min': 80, 'max': 250, 'average': 165, 'unit': 'repair',
        'complexity_factors': {
          'refrigerator': 1.2,
          'washer_dryer': 1.1,
          'dishwasher': 1.0,
          'oven_range': 1.3,
          'microwave': 0.8,
          'warranty_work': 0.9,
        }
      },
      'handyman': {
        'min': 60, 'max': 200, 'average': 130, 'unit': 'hour',
        'complexity_factors': {
          'repairs': 1.0,
          'installation': 1.2,
          'assembly': 0.9,
          'painting': 1.1,
          'drywall': 1.3,
          'urgent': 1.4,
        }
      },
      'landscaping': {
        'min': 100, 'max': 300, 'average': 200, 'unit': 'job',
        'complexity_factors': {
          'lawn_care': 1.0,
          'tree_services': 1.4,
          'garden_maintenance': 1.2,
          'irrigation': 1.5,
          'hardscaping': 1.8,
          'large_property': 1.6,
        }
      },
    };
    
    return pricing[category] ?? pricing['handyman']! as Map<String, dynamic>;
  }

  Map<String, double> _getLocationMultipliers(String location) {
    // Location-based pricing multipliers based on market data
    Map<String, double> multipliers = {
      // Major metropolitan areas (high cost of living)
      'new_york': 1.8,
      'los_angeles': 1.7,
      'san_francisco': 1.9,
      'washington_dc': 1.6,
      'boston': 1.5,
      'seattle': 1.4,
      'chicago': 1.3,
      'denver': 1.2,
      
      // Mid-tier cities
      'atlanta': 1.1,
      'dallas': 1.0,
      'houston': 1.0,
      'phoenix': 0.95,
      'miami': 1.1,
      'orlando': 1.0,
      'las_vegas': 1.0,
      'austin': 1.1,
      
      // Smaller cities and suburbs
      'suburban': 0.9,
      'rural': 0.8,
      'default': 1.0,
    };
    
    return multipliers;
  }

  Map<String, dynamic> _getComplexityAdjustments(String category, Map<String, dynamic> serviceDetails) {
    Map<String, dynamic> basePricing = _getBasePricingByCategory(category);
    Map<String, double> complexityFactors = Map<String, double>.from(basePricing['complexity_factors'] ?? {});
    
    double multiplier = 1.0;
    List<String> appliedFactors = [];
    
    // Analyze service details to determine complexity
    if (serviceDetails.isNotEmpty) {
      String details = serviceDetails.toString().toLowerCase();
      
      // Apply complexity factors based on service details
      complexityFactors.forEach((factor, factorMultiplier) {
        if (details.contains(factor.replaceAll('_', ' '))) {
          multiplier *= factorMultiplier;
          appliedFactors.add(factor);
        }
      });
    }
    
    return {
      'multiplier': multiplier,
      'applied_factors': appliedFactors,
    };
  }

  double _calculatePricingConfidence() {
    double confidence = 0.5; // Base confidence
    
    // Increase confidence based on available information
    if (_currentState.serviceCategory != null) confidence += 0.2;
    if (_currentState.serviceDetails != null && _currentState.serviceDetails!.isNotEmpty) confidence += 0.2;
    if (_currentState.userLocation != null) confidence += 0.1;
    if (_currentState.problemDescription != null && _currentState.problemDescription!.length > 20) confidence += 0.1;
    
    return confidence.clamp(0.0, 1.0);
  }

  List<String> _getPricingFactors(String category, Map<String, dynamic> serviceDetails, String location) {
    List<String> factors = ['Service complexity', 'Materials needed', 'Time required'];
    
    // Add location-specific factors
    if (location != 'default') {
      factors.add('Market rates in ${_getMarketArea(location)}');
    }
    
    // Add category-specific factors
    switch (category) {
      case 'cleaning':
        factors.addAll(['Home size', 'Cleaning type', 'Frequency']);
        break;
      case 'plumbing':
        factors.addAll(['Issue complexity', 'Parts needed', 'Emergency service']);
        break;
      case 'electrical':
        factors.addAll(['Safety requirements', 'Code compliance', 'Licensing']);
        break;
      case 'hvac':
        factors.addAll(['System type', 'Seasonal demand', 'Parts availability']);
        break;
      case 'appliance':
        factors.addAll(['Appliance age', 'Warranty status', 'Parts cost']);
        break;
      case 'handyman':
        factors.addAll(['Project scope', 'Materials provided', 'Timeline']);
        break;
      case 'landscaping':
        factors.addAll(['Property size', 'Seasonal factors', 'Equipment needed']);
        break;
    }
    
    return factors;
  }

  String _getMarketArea(String location) {
    Map<String, String> marketAreas = {
      'new_york': 'New York Metro Area',
      'los_angeles': 'Los Angeles Metro Area',
      'san_francisco': 'San Francisco Bay Area',
      'washington_dc': 'Washington DC Metro Area',
      'boston': 'Boston Metro Area',
      'seattle': 'Seattle Metro Area',
      'chicago': 'Chicago Metro Area',
      'denver': 'Denver Metro Area',
      'atlanta': 'Atlanta Metro Area',
      'dallas': 'Dallas-Fort Worth Metro Area',
      'houston': 'Houston Metro Area',
      'phoenix': 'Phoenix Metro Area',
      'miami': 'Miami Metro Area',
      'orlando': 'Orlando Metro Area',
      'las_vegas': 'Las Vegas Metro Area',
      'austin': 'Austin Metro Area',
      'suburban': 'Suburban Area',
      'rural': 'Rural Area',
      'default': 'Local Market',
    };
    
    return marketAreas[location] ?? 'Local Market';
  }

  ServiceCategory _getServiceCategory(String id) {
    // Return service category by ID - simplified version
    Map<String, ServiceCategory> categories = {
      'cleaning': ServiceCategory(
        id: 'cleaning',
        name: 'Cleaning Services',
        description: 'Professional cleaning for your home',
        keywords: ['clean', 'dirty', 'messy'],
        followUpQuestions: [],
        priceRange: {},
        icon: 'cleaning_services',
        color: Colors.blue,
      ),
      'plumbing': ServiceCategory(
        id: 'plumbing',
        name: 'Plumbing',
        description: 'Water, pipes, and drainage services',
        keywords: ['leak', 'pipe', 'water'],
        followUpQuestions: [],
        priceRange: {},
        icon: 'plumbing',
        color: Colors.blue,
      ),
      // Add other categories as needed
    };
    
    return categories[id] ?? categories['cleaning']!;
  }

  String _getRandomFollowUpQuestion(ServiceCategory category) {
    List<String> questions = [
      "What specific work do you need done?",
      "Can you describe the current situation?",
      "What are the main issues you're experiencing?",
    ];
    
    return questions[Random().nextInt(questions.length)];
  }

  // Conversation persistence methods
  void _saveConversationState() {
    try {
      // Save conversation state
      final stateData = {
        'serviceCategory': _currentState.serviceCategory,
        'serviceDescription': _currentState.serviceDescription,
        'problemDescription': _currentState.problemDescription,
        'mediaUrls': _currentState.mediaUrls,
        'availability': _currentState.availability,
        'location': _currentState.location,
        'priceEstimate': _currentState.priceEstimate,
        'tags': _currentState.tags,
        'conversationStep': _currentState.conversationStep,
        'extractedInfo': _currentState.extractedInfo,
        'conversationHistory': _currentState.conversationHistory,
        'userLocation': _currentState.userLocation,
        'marketArea': _currentState.marketArea,
        'serviceDetails': _currentState.serviceDetails,
        'marketPricing': _currentState.marketPricing,
        'locationRequested': _currentState.locationRequested,
      };
      
      // Save messages
      final messagesData = _messages.map((msg) => {
        'content': msg.content,
        'type': msg.type.index,
        'timestamp': msg.timestamp.toIso8601String(),
        'imageUrl': msg.imageUrl,
        'metadata': msg.metadata,
      }).toList();
      
      print('Saving conversation state: $stateData');
      print('Saving messages: ${messagesData.length} messages');
      
      // In a real app, you'd save to SharedPreferences or local storage
      // For now, we'll just print for debugging
    } catch (e) {
      print('Error saving conversation state: $e');
    }
  }

  void loadConversationState() {
    try {
      // In a real app, you'd load from SharedPreferences or local storage
      // For now, we'll just check if there's existing state
      if (_messages.isNotEmpty) {
        print('Loading existing conversation with ${_messages.length} messages');
        return;
      }
      
      print('No saved conversation found, starting fresh');
    } catch (e) {
      print('Error loading conversation state: $e');
    }
  }

  void clearConversation() {
    _currentState = ConversationState();
    _messages.clear();
    print('Conversation cleared after service request submission');
    
    // Clear any saved conversation data
    try {
      // In a real app, you'd clear from SharedPreferences or local storage
      print('Cleared saved conversation data');
    } catch (e) {
      print('Error clearing conversation data: $e');
    }
  }

  // Address validation and geocoding methods
  Future<Map<String, dynamic>> validateAddress(String address) async {
    try {
      final apiKey = APIKeys.getGoogleMapsKey();
      final encodedAddress = Uri.encodeComponent(address);
      final url = 'https://maps.googleapis.com/maps/api/geocode/json?address=$encodedAddress&key=$apiKey';
      
      print('Validating address: $address');
      print('Google Geocoding API URL: $url');
      
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['status'] == 'OK' && data['results'].isNotEmpty) {
          final result = data['results'][0];
          final formattedAddress = result['formatted_address'];
          final location = result['geometry']['location'];
          final addressComponents = result['address_components'];
          
          // Extract location details
          String city = '';
          String state = '';
          String zipCode = '';
          String country = '';
          
          for (var component in addressComponents) {
            final types = List<String>.from(component['types']);
            if (types.contains('locality')) {
              city = component['long_name'];
            } else if (types.contains('administrative_area_level_1')) {
              state = component['short_name'];
            } else if (types.contains('postal_code')) {
              zipCode = component['long_name'];
            } else if (types.contains('country')) {
              country = component['short_name'];
            }
          }
          
          // Determine market area based on city/state
          String marketArea = _determineMarketArea(city, state);
          
          return {
            'valid': true,
            'formattedAddress': formattedAddress,
            'latitude': location['lat'],
            'longitude': location['lng'],
            'city': city,
            'state': state,
            'zipCode': zipCode,
            'country': country,
            'marketArea': marketArea,
            'confidence': 'high',
          };
        } else {
          return {
            'valid': false,
            'error': 'Address not found or invalid',
            'confidence': 'low',
          };
        }
      } else {
        return {
          'valid': false,
          'error': 'Failed to validate address',
          'confidence': 'low',
        };
      }
    } catch (e) {
      print('Error validating address: $e');
      return {
        'valid': false,
        'error': 'Error validating address: $e',
        'confidence': 'low',
      };
    }
  }

  String _determineMarketArea(String city, String state) {
    String locationKey = 'default';
    
    // Major metropolitan areas
    if (city.toLowerCase().contains('new york') || state == 'NY') {
      locationKey = 'new_york';
    } else if (city.toLowerCase().contains('los angeles') || state == 'CA') {
      locationKey = 'los_angeles';
    } else if (city.toLowerCase().contains('san francisco') || city.toLowerCase().contains('oakland') || city.toLowerCase().contains('san jose')) {
      locationKey = 'san_francisco';
    } else if (city.toLowerCase().contains('washington') || state == 'DC') {
      locationKey = 'washington_dc';
    } else if (city.toLowerCase().contains('boston') || state == 'MA') {
      locationKey = 'boston';
    } else if (city.toLowerCase().contains('seattle') || state == 'WA') {
      locationKey = 'seattle';
    } else if (city.toLowerCase().contains('chicago') || state == 'IL') {
      locationKey = 'chicago';
    } else if (city.toLowerCase().contains('denver') || state == 'CO') {
      locationKey = 'denver';
    } else if (city.toLowerCase().contains('atlanta') || state == 'GA') {
      locationKey = 'atlanta';
    } else if (city.toLowerCase().contains('dallas') || city.toLowerCase().contains('fort worth')) {
      locationKey = 'dallas';
    } else if (city.toLowerCase().contains('houston') || state == 'TX') {
      locationKey = 'houston';
    } else if (city.toLowerCase().contains('phoenix') || state == 'AZ') {
      locationKey = 'phoenix';
    } else if (city.toLowerCase().contains('miami') || state == 'FL') {
      locationKey = 'miami';
    } else if (city.toLowerCase().contains('orlando') || state == 'FL') {
      locationKey = 'orlando';
    } else if (city.toLowerCase().contains('las vegas') || state == 'NV') {
      locationKey = 'las_vegas';
    } else if (city.toLowerCase().contains('austin') || state == 'TX') {
      locationKey = 'austin';
    }
    
    return _getMarketArea(locationKey);
  }

  String _getLocationRequestOptions() {
    return '''**📍 Please provide your service address:**

To ensure accurate pricing and match you with the right service providers, I need your complete home address.

**Please enter your full address:**
• Street address
• City, State, ZIP code
• Example: "123 Main Street, New York, NY 10001"

**Why we need your address:**
• Accurate pricing based on your exact location
• Matching with nearby service providers
• Faster response times
• Better service coordination
• Emergency service routing if needed

*Please provide your complete address so we can validate it and provide the most accurate service.*''';
  }

  String _generateLocationResponse(String input) {
    // This will be called when user provides address
    return _processAddressInput(input);
  }

  String _processAddressInput(String address) {
    // Validate address asynchronously
    validateAddress(address).then((validationResult) {
      if (validationResult['valid']) {
        // Store validation result for confirmation
        _currentState.extractedInfo['addressValidation'] = validationResult;
        
        print('Address validated successfully: ${validationResult['formattedAddress']}');
        print('Market area: ${validationResult['marketArea']}');
      } else {
        print('Address validation failed: ${validationResult['error']}');
        _currentState.extractedInfo['addressValidation'] = validationResult;
      }
    });
    
    return "**📍 Address Received**\n\nThank you for providing your address. I'm validating it now to ensure we have the correct location for accurate pricing and service provider matching.\n\n*Please wait while I verify your address...*";
  }

  String _generateServiceQuestionsResponse(String input) {
    // Store service details from user input
    _currentState.extractedInfo['serviceDetails'] = input;
    
    String response = "**✅ Service Details Received!**\n\n";
    response += "**Service Type:** ${_currentState.serviceCategory}\n";
    response += "**Service Description:** ${_currentState.serviceDescription}\n";
    response += "**Additional Details:** $input\n\n";
    
    // Move to contact and location collection
    _currentState.conversationStep = 3;
    return response;
  }

  String _generateContactAndLocationRequest(String input) {
    // Check if user provided contact and location info
    if (_currentState.contactRequested && _currentState.locationRequested) {
      return _processContactAndLocationInput(input);
    }
    
    String response = "**📞 Contact & Location Information**\n\n";
    response += "Great! Now I need your contact information and service location to provide accurate pricing and match you with nearby service providers.\n\n";
    
    response += "**Please provide your contact information:**\n\n";
    response += "**1. Phone Number:**\n";
    response += "• Your primary contact number\n";
    response += "• Format: (555) 123-4567 or 555-123-4567\n\n";
    
    response += "**2. Service Address:**\n";
    response += "• Complete street address\n";
    response += "• City, State, ZIP code\n";
    response += "• Example: \"123 Main Street, New York, NY 10001\"\n\n";
    
    response += "**Please provide both your phone number and complete address in your response.**\n\n";
    response += "*I'll validate your address and provide market-based pricing based on your location.*";
    
    _currentState.contactRequested = true;
    _currentState.locationRequested = true;
    _currentState.conversationStep = 4;
    return response;
  }

  String _processContactAndLocationInput(String input) {
    // Extract phone number and address from user input
    String? phoneNumber = _extractPhoneNumber(input);
    String? address = _extractAddress(input);
    
    if (phoneNumber != null && address != null) {
      // Store contact information
      _currentState.extractedInfo['phoneNumber'] = phoneNumber;
      
      // Validate address asynchronously
      validateAddress(address).then((validationResult) {
        if (validationResult['valid']) {
          _currentState.extractedInfo['addressValidation'] = validationResult;
          print('Address validated successfully: ${validationResult['formattedAddress']}');
          print('Market area: ${validationResult['marketArea']}');
        } else {
          print('Address validation failed: ${validationResult['error']}');
          _currentState.extractedInfo['addressValidation'] = validationResult;
        }
      });
      
      String response = "**✅ Contact & Location Information Received**\n\n";
      response += "**📞 Phone Number:** $phoneNumber\n";
      response += "**📍 Address:** $address\n\n";
      response += "I'm validating your address now to ensure we have the correct location for accurate pricing and service provider matching.\n\n*Please wait while I verify your address...*";
      
      return response;
      
    } else {
      String response = "**❌ Missing Information**\n\n";
      
      if (phoneNumber == null) {
        response += "**Phone Number:** Please provide a valid phone number\n";
        response += "• Format: (555) 123-4567 or 555-123-4567\n\n";
      }
      
      if (address == null) {
        response += "**Address:** Please provide a complete address\n";
        response += "• Format: Street address, City, State, ZIP code\n";
        response += "• Example: \"123 Main Street, New York, NY 10001\"\n\n";
      }
      
      response += "*Please provide both your phone number and complete address.*";
      return response;
    }
  }

  String? _extractPhoneNumber(String input) {
    // Phone number regex patterns
    RegExp phonePattern1 = RegExp(r'\(?\d{3}\)?[\s.-]?\d{3}[\s.-]?\d{4}');
    RegExp phonePattern2 = RegExp(r'\d{10}');
    
    Match? match = phonePattern1.firstMatch(input);
    if (match != null) {
      return match.group(0);
    }
    
    match = phonePattern2.firstMatch(input);
    if (match != null) {
      String number = match.group(0)!;
      return '(${number.substring(0, 3)}) ${number.substring(3, 6)}-${number.substring(6)}';
    }
    
    return null;
  }

  String? _extractAddress(String input) {
    // Look for address patterns
    // This is a simplified extraction - in production, you might want more sophisticated parsing
    List<String> lines = input.split('\n');
    
    for (String line in lines) {
      line = line.trim();
      if (line.contains(',') && 
          (line.contains('street') || line.contains('avenue') || line.contains('road') || 
           line.contains('drive') || line.contains('lane') || line.contains('way') ||
           line.contains('blvd') || line.contains('st') || line.contains('ave') ||
           line.contains('rd') || line.contains('dr') || line.contains('ln'))) {
        return line;
      }
    }
    
    // Fallback: look for ZIP code pattern
    RegExp zipPattern = RegExp(r'\d{5}(-\d{4})?');
    Match? zipMatch = zipPattern.firstMatch(input);
    if (zipMatch != null) {
      // Try to extract the line containing the ZIP code
      for (String line in lines) {
        if (line.contains(zipMatch.group(0)!)) {
          return line.trim();
        }
      }
    }
    
    return null;
  }

  String _generateAddressConfirmationResponse(String input) {
    Map<String, dynamic>? validationResult = _currentState.extractedInfo['addressValidation'];
    
    if (validationResult == null) {
      return "**⏳ Address Validation in Progress**\n\nI'm still validating your address. Please wait a moment...";
    }
    
    if (validationResult['valid'] == true) {
      String formattedAddress = validationResult['formattedAddress'];
      String marketArea = validationResult['marketArea'];
      String city = validationResult['city'];
      String state = validationResult['state'];
      String zipCode = validationResult['zipCode'];
      
      return '''**✅ Address Validated Successfully!**

**📍 Confirmed Service Address:**
$formattedAddress

**📊 Location Details:**
• City: $city
• State: $state
• ZIP Code: $zipCode
• Market Area: $marketArea

**Is this address correct?**

1. **Yes, this is correct** - Proceed with service details
2. **No, I need to correct it** - Please provide the correct address
3. **This is close but needs adjustment** - Please specify what needs to be changed

*Please confirm this is your correct service address so we can provide accurate pricing and match you with nearby service providers.*''';
    } else {
      return '''**❌ Address Validation Failed**

**Error:** ${validationResult['error']}

**Please try again with a more complete address:**

**Required format:**
• Street address
• City, State, ZIP code
• Example: "123 Main Street, New York, NY 10001"

**Common issues:**
• Missing street number
• Incomplete city name
• Missing state abbreviation
• Invalid ZIP code

*Please provide your complete address again.*''';
    }
  }

  String _handleAddressConfirmation(String input) {
    String lowerInput = input.toLowerCase();
    
    if (lowerInput.contains('yes') || lowerInput.contains('correct') || lowerInput.contains('1')) {
      // User confirmed address
      Map<String, dynamic> validationResult = _currentState.extractedInfo['addressValidation'];
      
      _currentState.location = validationResult['formattedAddress'];
      _currentState.userLocation = validationResult['marketArea'];
      _currentState.marketArea = validationResult['marketArea'];
      _currentState.locationRequested = true;
      
      // Proceed to photo request
      _currentState.conversationStep = 5;
      
      String response = "**✅ Address Confirmed!**\n\n";
      response += "**Service Location:** ${_currentState.location}\n";
      response += "**Market Area:** ${_currentState.marketArea}\n\n";
      response += "**📸 Visual Assessment**\n\n";
      response += "To provide you with the most accurate pricing and help service providers understand your specific needs, I'd like to see photos of the area that needs service.\n\n";
      response += "**Please upload photos showing:**\n";
      response += "• The specific area or item that needs service\n";
      response += "• Any damage or issues you're experiencing\n";
      response += "• The overall context of the work area\n\n";
      response += "*Photos help us provide more accurate estimates and ensure service providers are fully prepared.*";
      
      return response;
      
    } else if (lowerInput.contains('no') || lowerInput.contains('incorrect') || lowerInput.contains('2')) {
      // User needs to correct address
      _currentState.locationRequested = false;
      _currentState.conversationStep = 2;
      
      return '''**📍 Please provide the correct address:**

I understand the previous address wasn't correct. Please provide your complete and accurate service address.

**Please enter your full address:**
• Street address
• City, State, ZIP code
• Example: "123 Main Street, New York, NY 10001"

*I'll validate the new address for you.*''';
      
    } else if (lowerInput.contains('adjustment') || lowerInput.contains('change') || lowerInput.contains('3')) {
      // User wants to make adjustments
      _currentState.locationRequested = false;
      _currentState.conversationStep = 2;
      
      return '''**📍 Please specify what needs to be adjusted:**

I understand the address needs some adjustments. Please provide the corrected address or specify what needs to be changed.

**Current address:** ${_currentState.extractedInfo['addressValidation']['formattedAddress']}

**Please provide:**
• The complete corrected address, OR
• Specific changes needed (e.g., "wrong street number", "different city", etc.)

*I'll validate the corrected address for you.*''';
      
    } else {
      // User provided a new address
      return _processAddressInput(input);
    }
  }
} 