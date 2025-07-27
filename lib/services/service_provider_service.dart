import 'package:cloud_firestore/cloud_firestore.dart';
import 'ai_agent_interface.dart';
import '../models/service_request.dart';

/// Service for managing service provider interactions
/// Uses AI agent interface to generate and send service requests
class ServiceProviderService {
  final AIAgentInterface aiAgent;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  ServiceProviderService({required this.aiAgent});
  
  /// Send a service request to providers using AI-generated data
  Future<Map<String, dynamic>> sendServiceRequest(String userInput) async {
    try {
      // Use AI agent to generate structured service request
      ServiceRequest request = await aiAgent.generateServiceRequest(userInput);
      
      // Get service recommendations from AI
      Map<String, dynamic> recommendations = await aiAgent.getServiceRecommendations();
      
      // Find matching service providers
      List<Map<String, dynamic>> providers = await _findMatchingProviders(request);
      
      // Send request to providers
      List<String> sentToProviders = await _sendToProviders(request, providers);
      
      // Store request in database
      String requestId = await _storeServiceRequest(request);
      
      return {
        'success': true,
        'requestId': requestId,
        'request': request.toJson(),
        'providersContacted': sentToProviders.length,
        'estimatedResponseTime': recommendations['responseTime'] ?? '2-4 hours',
        'pricing': request.pricing,
        'recommendations': recommendations,
      };
      
    } catch (e) {
      print('Error sending service request: $e');
      return {
        'success': false,
        'error': 'Failed to send service request: $e',
      };
    }
  }
  
  /// Find service providers that match the request criteria
  Future<List<Map<String, dynamic>>> _findMatchingProviders(ServiceRequest request) async {
    try {
      // Query providers based on service category and location
      QuerySnapshot providersSnapshot = await _firestore
          .collection('service_providers')
          .where('service_categories', arrayContains: request.category)
          .where('service_areas', arrayContains: request.location?.split(',').last.trim() ?? 'New York')
          .where('is_active', isEqualTo: true)
          .limit(10)
          .get();
      
      List<Map<String, dynamic>> providers = [];
      
      for (var doc in providersSnapshot.docs) {
        Map<String, dynamic> providerData = doc.data() as Map<String, dynamic>;
        providerData['id'] = doc.id;
        
        // Add provider rating and availability
        providerData['rating'] = await _getProviderRating(doc.id);
        providerData['availability'] = await _checkProviderAvailability(doc.id, request.availability);
        
        providers.add(providerData);
      }
      
      // Sort by rating and availability
      providers.sort((a, b) {
        double ratingA = (a['rating'] ?? 0.0).toDouble();
        double ratingB = (b['rating'] ?? 0.0).toDouble();
        bool availableA = a['availability'] ?? false;
        bool availableB = b['availability'] ?? false;
        
        if (availableA != availableB) {
          return availableA ? -1 : 1;
        }
        return ratingB.compareTo(ratingA);
      });
      
      return providers;
      
    } catch (e) {
      print('Error finding matching providers: $e');
      return [];
    }
  }
  
  /// Send service request to selected providers
  Future<List<String>> _sendToProviders(ServiceRequest request, List<Map<String, dynamic>> providers) async {
    List<String> sentToProviders = [];
    
    for (var provider in providers.take(5)) { // Send to top 5 providers
      try {
        await _firestore
            .collection('service_requests')
            .add({
          'provider_id': provider['id'],
          'customer_request': request.toJson(),
          'status': 'pending',
          'created_at': FieldValue.serverTimestamp(),
          'priority': request.priority ?? 'medium',
          'estimated_cost': request.pricing,
          'customer_contact': request.contactInfo,
          'service_location': request.location,
          'service_category': request.category,
          'media_urls': request.mediaUrls,
          'availability': request.availability,
        });
        
        sentToProviders.add(provider['id']);
        
        // Send notification to provider (if notification service is available)
        await _sendProviderNotification(provider['id'], request);
        
      } catch (e) {
        print('Error sending request to provider ${provider['id']}: $e');
      }
    }
    
    return sentToProviders;
  }
  
  /// Store the service request in customer's history
  Future<String> _storeServiceRequest(ServiceRequest request) async {
    try {
      DocumentReference docRef = await _firestore
          .collection('customer_requests')
          .add({
        'user_id': request.userId ?? 'anonymous',
        'request_data': request.toJson(),
        'status': 'sent_to_providers',
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      });
      
      return docRef.id;
      
    } catch (e) {
      print('Error storing service request: $e');
      return 'error_${DateTime.now().millisecondsSinceEpoch}';
    }
  }
  
  /// Get provider rating
  Future<double> _getProviderRating(String providerId) async {
    try {
      QuerySnapshot ratingsSnapshot = await _firestore
          .collection('provider_ratings')
          .where('provider_id', isEqualTo: providerId)
          .get();
      
      if (ratingsSnapshot.docs.isEmpty) {
        return 4.0; // Default rating
      }
      
      double totalRating = 0;
      int count = 0;
      
      for (var doc in ratingsSnapshot.docs) {
        Map<String, dynamic> ratingData = doc.data() as Map<String, dynamic>;
        totalRating += (ratingData['rating'] ?? 4.0).toDouble();
        count++;
      }
      
      return count > 0 ? totalRating / count : 4.0;
      
    } catch (e) {
      print('Error getting provider rating: $e');
      return 4.0;
    }
  }
  
  /// Check if provider is available for the requested time
  Future<bool> _checkProviderAvailability(String providerId, Map<String, dynamic>? availability) async {
    try {
      // This is a simplified check - in a real app, you'd check against provider's calendar
      DocumentSnapshot providerDoc = await _firestore
          .collection('service_providers')
          .doc(providerId)
          .get();
      
      if (!providerDoc.exists) return false;
      
      Map<String, dynamic> providerData = providerDoc.data() as Map<String, dynamic>;
      
      // Check if provider is currently accepting requests
      bool isAcceptingRequests = providerData['is_accepting_requests'] ?? true;
      int currentLoad = providerData['current_load'] ?? 0;
      int maxLoad = providerData['max_load'] ?? 10;
      
      return isAcceptingRequests && currentLoad < maxLoad;
      
    } catch (e) {
      print('Error checking provider availability: $e');
      return true; // Assume available if check fails
    }
  }
  
  /// Send notification to provider
  Future<void> _sendProviderNotification(String providerId, ServiceRequest request) async {
    try {
      await _firestore
          .collection('provider_notifications')
          .add({
        'provider_id': providerId,
        'type': 'new_service_request',
        'title': 'New Service Request',
        'message': 'You have a new ${request.category} service request',
        'request_data': request.toJson(),
        'created_at': FieldValue.serverTimestamp(),
        'read': false,
      });
      
    } catch (e) {
      print('Error sending provider notification: $e');
    }
  }
  
  /// Get status of a service request
  Future<Map<String, dynamic>> getRequestStatus(String requestId) async {
    try {
      DocumentSnapshot requestDoc = await _firestore
          .collection('customer_requests')
          .doc(requestId)
          .get();
      
      if (!requestDoc.exists) {
        return {'error': 'Request not found'};
      }
      
      Map<String, dynamic> requestData = requestDoc.data() as Map<String, dynamic>;
      
      // Get provider responses
      QuerySnapshot responsesSnapshot = await _firestore
          .collection('service_requests')
          .where('customer_request.requestId', isEqualTo: requestId)
          .get();
      
      List<Map<String, dynamic>> responses = [];
      for (var doc in responsesSnapshot.docs) {
        responses.add(doc.data() as Map<String, dynamic>);
      }
      
      return {
        'request': requestData,
        'responses': responses,
        'status': requestData['status'],
        'lastUpdated': requestData['updated_at'],
      };
      
    } catch (e) {
      print('Error getting request status: $e');
      return {'error': 'Failed to get request status: $e'};
    }
  }
  
  /// Cancel a service request
  Future<bool> cancelRequest(String requestId) async {
    try {
      await _firestore
          .collection('customer_requests')
          .doc(requestId)
          .update({
        'status': 'cancelled',
        'updated_at': FieldValue.serverTimestamp(),
      });
      
      // Also cancel provider requests
      QuerySnapshot providerRequests = await _firestore
          .collection('service_requests')
          .where('customer_request.requestId', isEqualTo: requestId)
          .get();
      
      for (var doc in providerRequests.docs) {
        await doc.reference.update({
          'status': 'cancelled',
          'updated_at': FieldValue.serverTimestamp(),
        });
      }
      
      return true;
      
    } catch (e) {
      print('Error cancelling request: $e');
      return false;
    }
  }
} 