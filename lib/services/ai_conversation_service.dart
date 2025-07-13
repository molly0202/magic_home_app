import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';
import 'dart:convert';
import 'package:http/http.dart' as http;

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
  }) : mediaUrls = mediaUrls ?? <String>[],
       tags = tags ?? <String>[],
       extractedInfo = extractedInfo ?? <String, dynamic>{},
       conversationHistory = conversationHistory ?? <Map<String, String>>[];
}

class AIConversationService {
  static final AIConversationService _instance = AIConversationService._internal();
  factory AIConversationService() => _instance;
  AIConversationService._internal();
  
  // LLM Configuration - For production, add your API key here
  // You can use OpenAI, Google Gemini, or other LLM providers
  static const String _apiKey = 'your-api-key-here';
  static const String _baseUrl = 'https://api.openai.com/v1/chat/completions';
  
  // System prompt that defines the AI's role and knowledge
  static const String _systemPrompt = '''
You are an expert home service AI assistant for Magic Home app. Your role is to:

1. UNDERSTAND user service requests with high accuracy
2. CATEGORIZE services into: HVAC, Plumbing, Electrical, Cleaning, Appliance Repair, Handyman, Landscaping
3. ASK relevant follow-up questions to gather complete information
4. GUIDE users through the service request process
5. PROVIDE helpful and professional responses

Service Categories:
- HVAC: heating, cooling, furnace, AC, air conditioning, thermostat, ductwork, boiler, heat pump
- Plumbing: leak, pipe, drain, toilet, faucet, sink, shower, water, sewer, clog
- Electrical: power, outlet, switch, light, wiring, breaker, circuit, electrical panel
- Cleaning: dirty, messy, clean, dust, vacuum, deep clean, sanitize, maid service
- Appliance: refrigerator, washer, dryer, dishwasher, oven, microwave, broken appliance
- Handyman: repair, fix, install, drywall, painting, door, window, general maintenance
- Landscaping: lawn, garden, yard, tree, grass, outdoor, irrigation, landscaping

Conversation Flow:
1. First, understand what service they need and categorize it
2. Ask relevant follow-up questions to gather details
3. Request photos if helpful for the service type
4. Ask about availability
5. Provide a summary and next steps

Always respond in a helpful, professional tone. Keep responses concise but informative.
If the user says something like "my house is dirty", correctly identify this as a CLEANING service.
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

  List<ChatMessage> get messages => _messages;
  ConversationState get currentState => _currentState;

  void startConversation() {
    _currentState = ConversationState();
    _messages.clear();
    
    _addMessage(ChatMessage(
      content: "Hello! I'm your AI assistant for home services. I'll help you describe your service needs and connect you with the right professionals.\n\nWhat do you need help with?",
      type: MessageType.ai,
      timestamp: DateTime.now(),
    ));
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

    return response;
  }

  Future<String> _generateLLMResponse(String input) async {
    try {
      // Determine conversation context
      String contextPrompt = _buildContextPrompt();
      
      // For development/testing, use a mock LLM response
      if (_apiKey == 'your-api-key-here') {
        return await _generateMockLLMResponse(input);
      }
      
      // Real LLM integration (uncomment when API key is added)
      return await _callLLMAPI(input, contextPrompt);
    } catch (e) {
      print('Error generating LLM response: $e');
      return _generateFallbackResponse(input);
    }
  }

  Future<String> _callLLMAPI(String input, String contextPrompt) async {
    try {
      final messages = [
        {'role': 'system', 'content': '$_systemPrompt\n\n$contextPrompt'},
        ..._currentState.conversationHistory,
      ];

      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({
          'model': 'gpt-3.5-turbo',
          'messages': messages,
          'max_tokens': 300,
          'temperature': 0.7,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        String aiResponse = data['choices'][0]['message']['content'];
        
        // Parse the response to update conversation state
        _updateConversationState(aiResponse, input);
        
        return aiResponse;
      } else {
        throw Exception('LLM API error: ${response.statusCode}');
      }
    } catch (e) {
      print('Error calling LLM API: $e');
      return _generateFallbackResponse(input);
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
    
    // Generate category-specific acknowledgment
    switch (category) {
      case 'cleaning':
        response = "I understand you need cleaning services. ";
        if (input.contains('dirty') || input.contains('messy')) {
          response += "I can help you get your home clean and tidy. ";
        }
        break;
      case 'plumbing':
        response = "I see you have a plumbing issue. ";
        if (input.contains('leak')) {
          response += "Water leaks can be serious, so let's get this addressed quickly. ";
        }
        break;
      case 'electrical':
        response = "I understand you need electrical work. ";
        if (input.contains('power') || input.contains('outlet')) {
          response += "Electrical issues should be handled by professionals for safety. ";
        }
        break;
      case 'hvac':
        response = "I see you need help with your heating or cooling system. ";
        break;
      case 'appliance':
        response = "I understand you have an appliance that needs attention. ";
        break;
      case 'landscaping':
        response = "I see you need help with outdoor/landscaping work. ";
        break;
      default:
        response = "I understand you need some handyman services. ";
    }

    // Add follow-up question
    response += "To help me understand your specific situation better:\n\n";
    response += _getContextualFollowUpQuestion(category, input);
    
    _currentState.conversationStep = 2;
    return response;
  }

  String _getContextualFollowUpQuestion(String category, String input) {
    switch (category) {
      case 'cleaning':
        return "What type of cleaning service are you looking for? (e.g., deep cleaning, regular maintenance, post-construction cleanup)\n\nAre there any specific areas or surfaces you want to focus on?";
      case 'plumbing':
        return "Where exactly is the plumbing issue located, and what symptoms are you experiencing?";
      case 'electrical':
        return "What electrical problem are you experiencing? Is it affecting a specific outlet, room, or your whole home?";
      case 'hvac':
        return "What type of heating/cooling system do you have, and what specific issue are you experiencing?";
      case 'appliance':
        return "Which appliance needs service, and what problem are you experiencing with it?";
      case 'landscaping':
        return "What type of outdoor work do you need? (lawn care, tree trimming, garden maintenance, etc.)";
      default:
        return "What specific work do you need completed around your home?";
    }
  }

  String _generateAcknowledgementAndPhotoRequest(String input) {
    _currentState.problemDescription = (_currentState.problemDescription ?? "") + "\n" + input;
    _currentState.conversationStep = 3;

    String category = _currentState.serviceCategory ?? 'work';
    String response = "Got it. ";
    
    if (category == 'cleaning') {
      response += "That gives us a clear picture of the cleaning you need. ";
    } else {
      response += "Thanks for providing those details. ";
    }
    
    response += "To help our service providers prepare an accurate quote, could you please take a picture of the area that needs service?";
    
    return response;
  }

  String _generatePhotoRequestResponse() {
    _currentState.conversationStep = 4;
    return "Great! Now let's set up your availability. When would be convenient for a service provider to visit?";
  }

  String _generateAvailabilityResponse() {
    _currentState.conversationStep = 5;
    return "Perfect! I now have all the information needed to create your service request. Let me prepare a summary for you.";
  }

  String _generateContinuationResponse(String input) {
    return "Thank you for the additional information. Is there anything else you'd like to add about your service needs?";
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
    // Parse AI response to extract structured information
    // This would be enhanced with better parsing logic
    
    if (_currentState.serviceCategory == null) {
      _currentState.serviceCategory = _intelligentServiceCategorization(userInput.toLowerCase());
      _currentState.serviceDescription = userInput;
    }
    
    // Update conversation step based on response content
    if (aiResponse.contains('picture') || aiResponse.contains('photo')) {
      _currentState.conversationStep = 3;
    } else if (aiResponse.contains('availability') || aiResponse.contains('schedule')) {
      _currentState.conversationStep = 4;
    } else if (aiResponse.contains('summary') || aiResponse.contains('request')) {
      _currentState.conversationStep = 5;
    }
  }

  String _generateFallbackResponse(String input) {
    return "I understand you need help with your home service request. Could you please tell me more about what specific work you need done?";
  }

  void addMediaUrl(String url) {
    _currentState.mediaUrls.add(url);
  }

  void setAvailability(Map<String, dynamic> availability) {
    _currentState.availability = availability;
  }

  Map<String, dynamic> generateServiceRequestSummary() {
    // Generate price estimate based on service type
    Map<String, dynamic> priceEstimate = _generatePriceEstimate();
    
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

  Map<String, dynamic> _generatePriceEstimate() {
    // Simple price estimation based on service category
    Map<String, Map<String, dynamic>> priceRanges = {
      'cleaning': {'min': 80, 'max': 200, 'unit': 'visit'},
      'plumbing': {'min': 150, 'max': 400, 'unit': 'job'},
      'electrical': {'min': 100, 'max': 300, 'unit': 'job'},
      'hvac': {'min': 100, 'max': 500, 'unit': 'service'},
      'appliance': {'min': 80, 'max': 250, 'unit': 'repair'},
      'handyman': {'min': 60, 'max': 200, 'unit': 'hour'},
      'landscaping': {'min': 100, 'max': 300, 'unit': 'job'},
    };

    String category = _currentState.serviceCategory ?? 'handyman';
    Map<String, dynamic> range = priceRanges[category] ?? priceRanges['handyman']!;
    
    return {
      'min': range['min'],
      'max': range['max'],
      'unit': range['unit'],
      'confidence': 0.7,
      'factors': ['Service complexity', 'Materials needed', 'Time required'],
    };
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
} 