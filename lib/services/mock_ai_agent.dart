import 'ai_agent_interface.dart';
import '../models/service_request.dart';

/// Mock implementation of AI Agent for development
/// This allows development of dependent features without waiting for the real AI agent
class MockAIAgent implements AIAgentInterface {
  Map<String, dynamic> _conversationState = {};
  
  @override
  Future<ServiceRequest> generateServiceRequest(String userInput) async {
    // Simulate processing delay
    await Future.delayed(const Duration(milliseconds: 500));
    
    // Generate mock service request based on input
    String category = _determineCategory(userInput);
    Map<String, dynamic> details = _extractDetails(userInput);
    
    return ServiceRequest(
      category: category,
      description: userInput,
      details: details,
      mediaUrls: [],
      location: '123 Main Street, New York, NY 10001',
      contactInfo: '(555) 123-4567',
      pricing: _generateMockPricing(category),
      availability: {'preferredTime': 'Any time this week'},
      tags: _generateTags(category, details),
      priority: _determinePriority(details),
      userId: 'mock_user_123',
      requestId: 'mock_request_${DateTime.now().millisecondsSinceEpoch}',
    );
  }
  
  @override
  Future<Map<String, dynamic>> getServiceRecommendations() async {
    await Future.delayed(const Duration(milliseconds: 300));
    
    return {
      'recommendations': [
        {
          'serviceType': 'plumbing',
          'confidence': 0.85,
          'reasoning': 'Based on your description of water issues',
          'estimatedCost': {'min': 150, 'max': 400, 'average': 275},
        },
        {
          'serviceType': 'electrical',
          'confidence': 0.65,
          'reasoning': 'Possible electrical component involvement',
          'estimatedCost': {'min': 100, 'max': 300, 'average': 200},
        }
      ],
      'marketArea': 'New York Metro Area',
      'responseTime': '2-4 hours',
    };
  }
  
  @override
  Future<String> processUserConversation(String input) async {
    await Future.delayed(const Duration(milliseconds: 400));
    
    String lowerInput = input.toLowerCase();
    
    if (lowerInput.contains('hello') || lowerInput.contains('hi')) {
      return "**Hello! 👋**\n\nI'm your **Expert Home Service Assistant** - ready to help you get the professional service you need!\n\n**Available Services:**\n1. **HVAC & Climate Control** ❄️🔥\n2. **Plumbing** 🔧\n3. **Electrical** ⚡\n4. **Cleaning** 🧹\n5. **Appliance Repair** 🏠\n6. **Handyman** 🔨\n7. **Landscaping** 🌳\n\n**What type of service do you need today?**";
    }
    
    if (lowerInput.contains('leak') || lowerInput.contains('water') || lowerInput.contains('pipe')) {
      return "**Expert Plumbing Services** 🔧\n\nI understand you have a plumbing issue. Water leaks can cause serious damage, so let's get this addressed quickly by a licensed plumber.\n\n**🔍 Service Details Required**\n\nTo provide you with the most accurate pricing and match you with the right service providers, I need to gather some specific details about your service needs.\n\n**1. Where is the plumbing issue located?**\n1. Kitchen\n2. Bathroom\n3. Basement\n4. Outdoor\n5. Multiple areas\n\n*Please respond with the number that best describes your situation, or provide additional details.*";
    }
    
    if (lowerInput.contains('clean') || lowerInput.contains('dirty') || lowerInput.contains('messy')) {
      return "**Professional Cleaning Services** 🧹\n\nI understand you need cleaning services. I can help you get your home clean and tidy with professional cleaning solutions.\n\n**🔍 Service Details Required**\n\n**1. What type of cleaning service do you need?**\n1. Deep cleaning (thorough, detailed cleaning)\n2. Regular maintenance cleaning\n3. Move-in/out cleaning\n4. Post-construction cleanup\n5. Specialized cleaning (carpet, window, etc.)\n\n*Please respond with the number that best describes your needs, or provide additional details.*";
    }
    
    return "**Thank you for your message! ✅**\n\nI understand you need help with your home service request. To provide you with the best possible service, I need to gather some specific details.\n\n**Could you please tell me more about:**\n• What type of service you need\n• The specific problem or issue\n• When you need the service\n• Any urgency or special requirements\n\n*This helps me match you with the right professionals and provide accurate pricing.*";
  }
  
  @override
  Future<Map<String, dynamic>> getPricingEstimate(String serviceCategory, Map<String, dynamic> details) async {
    await Future.delayed(const Duration(milliseconds: 200));
    
    return _generateMockPricing(serviceCategory);
  }
  
  @override
  Future<Map<String, dynamic>> validateAddress(String address) async {
    await Future.delayed(const Duration(milliseconds: 300));
    
    return {
      'valid': true,
      'formattedAddress': address,
      'latitude': 40.7128,
      'longitude': -74.0060,
      'city': 'New York',
      'state': 'NY',
      'zipCode': '10001',
      'country': 'US',
      'marketArea': 'New York Metro Area',
      'confidence': 'high',
    };
  }
  
  @override
  String? extractContactInfo(String input) {
    RegExp phonePattern = RegExp(r'\(?\d{3}\)?[\s.-]?\d{3}[\s.-]?\d{4}');
    Match? match = phonePattern.firstMatch(input);
    return match?.group(0);
  }
  
  @override
  Map<String, dynamic> getConversationState() {
    return _conversationState;
  }
  
  @override
  void resetConversation() {
    _conversationState = {};
  }
  
  // Helper methods for mock data generation
  String _determineCategory(String input) {
    String lowerInput = input.toLowerCase();
    
    if (lowerInput.contains('leak') || lowerInput.contains('pipe') || lowerInput.contains('water')) {
      return 'plumbing';
    } else if (lowerInput.contains('clean') || lowerInput.contains('dirty') || lowerInput.contains('messy')) {
      return 'cleaning';
    } else if (lowerInput.contains('power') || lowerInput.contains('electrical') || lowerInput.contains('outlet')) {
      return 'electrical';
    } else if (lowerInput.contains('heating') || lowerInput.contains('cooling') || lowerInput.contains('hvac')) {
      return 'hvac';
    } else if (lowerInput.contains('appliance') || lowerInput.contains('refrigerator') || lowerInput.contains('washer')) {
      return 'appliance';
    } else if (lowerInput.contains('lawn') || lowerInput.contains('garden') || lowerInput.contains('landscape')) {
      return 'landscaping';
    } else {
      return 'handyman';
    }
  }
  
  Map<String, dynamic> _extractDetails(String input) {
    String lowerInput = input.toLowerCase();
    Map<String, dynamic> details = {};
    
    if (lowerInput.contains('emergency') || lowerInput.contains('urgent')) {
      details['urgency'] = 'high';
    } else {
      details['urgency'] = 'medium';
    }
    
    if (lowerInput.contains('kitchen')) {
      details['location'] = 'kitchen';
    } else if (lowerInput.contains('bathroom')) {
      details['location'] = 'bathroom';
    } else if (lowerInput.contains('basement')) {
      details['location'] = 'basement';
    }
    
    return details;
  }
  
  Map<String, dynamic> _generateMockPricing(String category) {
    Map<String, Map<String, dynamic>> pricing = {
      'plumbing': {'min': 150, 'max': 400, 'average': 275, 'unit': 'job'},
      'cleaning': {'min': 80, 'max': 200, 'average': 140, 'unit': 'visit'},
      'electrical': {'min': 100, 'max': 300, 'average': 200, 'unit': 'job'},
      'hvac': {'min': 100, 'max': 500, 'average': 300, 'unit': 'service'},
      'appliance': {'min': 80, 'max': 250, 'average': 165, 'unit': 'repair'},
      'landscaping': {'min': 100, 'max': 300, 'average': 200, 'unit': 'job'},
      'handyman': {'min': 60, 'max': 200, 'average': 130, 'unit': 'hour'},
    };
    
    return pricing[category] ?? pricing['handyman']!;
  }
  
  List<String> _generateTags(String category, Map<String, dynamic> details) {
    List<String> tags = [category];
    
    if (details['urgency'] == 'high') {
      tags.add('emergency');
    }
    
    if (details['location'] != null) {
      tags.add(details['location']);
    }
    
    return tags;
  }
  
  String _determinePriority(Map<String, dynamic> details) {
    if (details['urgency'] == 'high') {
      return 'high';
    }
    return 'medium';
  }
} 