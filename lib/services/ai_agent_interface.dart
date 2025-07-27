import '../models/service_request.dart';

/// Abstract interface for AI Agent functionality
/// This allows parallel development of features that depend on AI output
abstract class AIAgentInterface {
  /// Generate a service request from user input
  Future<ServiceRequest> generateServiceRequest(String userInput);
  
  /// Get service recommendations based on user needs
  Future<Map<String, dynamic>> getServiceRecommendations();
  
  /// Process user conversation and return AI response
  Future<String> processUserConversation(String input);
  
  /// Get pricing estimates for a service
  Future<Map<String, dynamic>> getPricingEstimate(String serviceCategory, Map<String, dynamic> details);
  
  /// Validate and format user address
  Future<Map<String, dynamic>> validateAddress(String address);
  
  /// Extract contact information from user input
  String? extractContactInfo(String input);
  
  /// Get conversation state
  Map<String, dynamic> getConversationState();
  
  /// Reset conversation
  void resetConversation();
} 