import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_request.dart';
import '../models/provider_match.dart';
import 'provider_matching_service.dart';

class UserRequestService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  /// Create a new user request from AI intake service data
  static Future<UserRequest> createRequestFromAIIntake({
    required String userId,
    required Map<String, dynamic> aiIntakeData,
  }) async {
    try {
      print('📝 Creating user request from AI intake data...');
      
      // Extract and validate data from AI intake
      final serviceCategory = aiIntakeData['serviceCategory']?.toString() ?? 
                             aiIntakeData['category']?.toString() ?? '';
      
      if (serviceCategory.isEmpty) {
        throw ArgumentError('Service category is required');
      }
      
      // Create UserRequest object
      final userRequest = UserRequest.fromAIIntake(
        userId: userId,
        serviceCategory: serviceCategory,
        description: aiIntakeData['description']?.toString() ?? '',
        mediaUrls: _extractMediaUrls(aiIntakeData),
        userAvailability: _extractAvailability(aiIntakeData),
        address: aiIntakeData['address']?.toString() ?? 
                aiIntakeData['location']?.toString() ?? '',
        phoneNumber: aiIntakeData['phoneNumber']?.toString() ?? 
                    aiIntakeData['phone']?.toString() ?? '',
        location: _extractLocationData(aiIntakeData),
        preferences: _extractPreferences(aiIntakeData),
        tags: _extractTags(aiIntakeData),
        priority: _determinePriority(aiIntakeData),
        aiPriceEstimation: _extractAiPriceEstimation(aiIntakeData),
      );
      
      // Save to Firestore
      final docRef = await _firestore.collection('user_requests').add(userRequest.toFirestore());
      
      // Return request with ID
      final savedRequest = userRequest.copyWith(requestId: docRef.id);
      
      print('✅ Created user request: ${savedRequest.requestId}');
      return savedRequest;
      
    } catch (e, stackTrace) {
      print('❌ Error creating user request: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }
  
  /// Process a user request: create request and find matching providers
  static Future<Map<String, dynamic>> processUserRequest({
    required String userId,
    required Map<String, dynamic> aiIntakeData,
    int maxProviders = 10,
  }) async {
    try {
      print('🚀 Processing complete user request...');
      
      // Step 1: Create the user request
      final userRequest = await createRequestFromAIIntake(
        userId: userId,
        aiIntakeData: aiIntakeData,
      );
      
      // Step 2: Find matching providers
      final matchingProviders = await ProviderMatchingService.findMatchingProviders(
        userRequest: userRequest,
        maxResults: maxProviders,
      );
      
      // Step 3: Store matching results FIRST (includes matchedProviders field)
      await _storeMatchingResults(userRequest.requestId!, matchingProviders);
      
      // Step 4: Update request status LAST to trigger bidding (after matchedProviders is saved)
      await updateRequestStatus(userRequest.requestId!, 'matched');
      
      print('✅ Processing complete: ${matchingProviders.length} providers matched');
      
      return {
        'success': true,
        'userRequest': userRequest.toFirestore(),
        'matchingProviders': matchingProviders.map((p) => p.toMap()).toList(),
        'matchingSummary': {
          'totalMatches': matchingProviders.length,
          'topScore': matchingProviders.isNotEmpty ? matchingProviders.first.overallScore : 0.0,
          'hasReferrals': matchingProviders.any((p) => p.isReferredByFriend),
          'hasPreviousWork': matchingProviders.any((p) => p.hasCollectedWork),
          'avgDistance': matchingProviders.isNotEmpty 
            ? matchingProviders.map((p) => p.distanceKm).reduce((a, b) => a + b) / matchingProviders.length
            : 0.0,
        }
      };
      
    } catch (e, stackTrace) {
      print('❌ Error processing user request: $e');
      print('Stack trace: $stackTrace');
      
      return {
        'success': false,
        'error': e.toString(),
        'matchingProviders': <Map<String, dynamic>>[],
      };
    }
  }
  
  /// Get existing user request by ID
  static Future<UserRequest?> getUserRequest(String requestId) async {
    try {
      final doc = await _firestore.collection('user_requests').doc(requestId).get();
      
      if (doc.exists) {
        return UserRequest.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      print('❌ Error getting user request: $e');
      return null;
    }
  }
  
  /// Update request status
  static Future<void> updateRequestStatus(String requestId, String status) async {
    try {
      print('🔄 Attempting to update request $requestId status to: $status');
      await _firestore.collection('user_requests').doc(requestId).update({
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      print('✅ Successfully updated request $requestId status to: $status');
      
      // Verify the update worked
      final doc = await _firestore.collection('user_requests').doc(requestId).get();
      if (doc.exists) {
        final currentStatus = doc.data()?['status'];
        print('🔍 Verified current status in database: $currentStatus');
      }
    } catch (e) {
      print('❌ CRITICAL ERROR updating request status: $e');
      rethrow; // Re-throw so we know if this is the problem
    }
  }
  
  /// Get user's request history
  static Future<List<UserRequest>> getUserRequestHistory(String userId, {int limit = 20}) async {
    try {
      final query = await _firestore
          .collection('user_requests')
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();
      
      return query.docs.map((doc) => UserRequest.fromFirestore(doc)).toList();
    } catch (e) {
      print('❌ Error getting user request history: $e');
      return [];
    }
  }
  
  /// Re-run matching for an existing request
  static Future<List<ProviderMatch>> rematchProviders(String requestId) async {
    try {
      final userRequest = await getUserRequest(requestId);
      if (userRequest == null) {
        throw ArgumentError('Request not found: $requestId');
      }
      
      final matches = await ProviderMatchingService.findMatchingProviders(
        userRequest: userRequest,
        maxResults: 10,
      );
      
      await _storeMatchingResults(requestId, matches);
      
      return matches;
    } catch (e) {
      print('❌ Error re-matching providers: $e');
      return [];
    }
  }
  
  // Helper methods for data extraction
  
  static List<String> _extractMediaUrls(Map<String, dynamic> data) {
    final mediaUrls = <String>[];
    
    // Check various possible field names
    if (data['mediaUrls'] is List) {
      mediaUrls.addAll(List<String>.from(data['mediaUrls']));
    } else if (data['media_urls'] is List) {
      mediaUrls.addAll(List<String>.from(data['media_urls']));
    } else if (data['images'] is List) {
      mediaUrls.addAll(List<String>.from(data['images']));
    } else if (data['photos'] is List) {
      mediaUrls.addAll(List<String>.from(data['photos']));
    }
    
    return mediaUrls;
  }
  
  static Map<String, dynamic> _extractAvailability(Map<String, dynamic> data) {
    final availability = <String, dynamic>{};
    
    // Extract availability information
    if (data['availability'] is Map) {
      availability.addAll(Map<String, dynamic>.from(data['availability']));
    } else if (data['availability'] is List) {
      // Handle availability as array (e.g., ['This weekend', 'Available today'])
      availability['timeSlots'] = List<String>.from(data['availability']);
    }
    
    // Extract urgency
    if (data['urgency'] != null) {
      availability['urgency'] = data['urgency'];
    } else if (data['priority'] != null) {
      availability['urgency'] = data['priority'];
    }
    
    // Extract preferred time
    if (data['preferredTime'] != null) {
      availability['preferredTime'] = data['preferredTime'];
    } else if (data['preferred_time'] != null) {
      availability['preferredTime'] = data['preferred_time'];
    }
    
    // Extract schedule preferences
    if (data['schedule'] != null) {
      availability['schedule'] = data['schedule'];
    }
    
    return availability.isNotEmpty ? availability : {'urgency': 'normal'};
  }
  
  static Map<String, dynamic>? _extractLocationData(Map<String, dynamic> data) {
    if (data['location'] is Map) {
      final location = Map<String, dynamic>.from(data['location']);
      if (location['lat'] != null && location['lng'] != null) {
        return location;
      }
    }
    
    // Try to extract coordinates from other fields
    if (data['latitude'] != null && data['longitude'] != null) {
      return {
        'lat': data['latitude'],
        'lng': data['longitude'],
        'formatted_address': data['address']?.toString() ?? '',
      };
    }
    
    return null;
  }
  
  static Map<String, dynamic> _extractPreferences(Map<String, dynamic> data) {
    final preferences = <String, dynamic>{};
    
    // NOTE: Budget/price preferences removed for MVP - providers set their own prices
    
    // Extract quality preferences
    if (data['qualityPreference'] != null) {
      preferences['qualityPreference'] = data['qualityPreference'];
    }
    
    // Extract timing preferences
    if (data['timePreference'] != null) {
      preferences['timePreference'] = data['timePreference'];
    }
    
    return preferences;
  }
  
  static List<String> _extractTags(Map<String, dynamic> data) {
    final tags = <String>[];
    
    if (data['tags'] is List) {
      tags.addAll(List<String>.from(data['tags']));
    }
    
    // Auto-generate tags based on content
    final description = data['description']?.toString().toLowerCase() ?? '';
    
    if (description.contains('urgent') || description.contains('emergency')) {
      tags.add('urgent');
    }
    if (description.contains('professional') || description.contains('expert')) {
      tags.add('professional_required');
    }
    if (description.contains('budget') || description.contains('cheap') || description.contains('affordable')) {
      tags.add('budget_conscious');
    }
    if (description.contains('quality') || description.contains('premium')) {
      tags.add('quality_focused');
    }
    
    return tags.toSet().toList(); // Remove duplicates
  }
  
  static int _determinePriority(Map<String, dynamic> data) {
    // Check explicit priority
    if (data['priority'] is int) {
      return (data['priority'] as int).clamp(1, 5);
    }
    
    // Determine from urgency
    final urgency = data['urgency']?.toString().toLowerCase() ?? '';
    switch (urgency) {
      case 'emergency':
        return 5;
      case 'urgent':
        return 4;
      case 'high':
        return 4;
      case 'normal':
        return 3;
      case 'low':
        return 2;
      default:
        return 3;
    }
  }
  
  /// Store matching results for future reference
  static Future<void> _storeMatchingResults(String requestId, List<ProviderMatch> matches) async {
    try {
      // Store detailed results in separate collection
      await _firestore.collection('matching_results').doc(requestId).set({
        'requestId': requestId,
        'matches': matches.map((m) => m.toMap()).toList(),
        'matchCount': matches.length,
        'topScore': matches.isNotEmpty ? matches.first.overallScore : 0.0,
        'createdAt': FieldValue.serverTimestamp(),
      });
      
      // CRITICAL: Update the user request with matchedProviders for bidding system
      final matchedProviderIds = matches.map((m) => m.providerId).toList();
      await _firestore.collection('user_requests').doc(requestId).update({
        'matchedProviders': matchedProviderIds,
        'matchCount': matches.length,
        'topScore': matches.isNotEmpty ? matches.first.overallScore : 0.0,
        'matchingCompletedAt': FieldValue.serverTimestamp(),
      });
      
      print('✅ Stored ${matches.length} matching results and updated user request with provider IDs');
    } catch (e) {
      print('⚠️ Error storing matching results: $e');
    }
  }
  
  /// Get stored matching results
  static Future<List<ProviderMatch>> getMatchingResults(String requestId) async {
    try {
      final doc = await _firestore.collection('matching_results').doc(requestId).get();
      
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final matchesData = List<Map<String, dynamic>>.from(data['matches'] ?? []);
        
        // Note: This would need a proper fromMap constructor in ProviderMatch
        // For now, we'll return empty list and log that results were found
        print('📊 Found ${matchesData.length} stored matching results');
        return [];
      }
      
      return [];
    } catch (e) {
      print('❌ Error getting matching results: $e');
      return [];
    }
  }
  
  static Map<String, dynamic>? _extractAiPriceEstimation(Map<String, dynamic> data) {
    if (data['aiPriceEstimation'] is Map) {
      return Map<String, dynamic>.from(data['aiPriceEstimation']);
    }
    
    // Also check alternative field names
    if (data['priceEstimation'] is Map) {
      return Map<String, dynamic>.from(data['priceEstimation']);
    }
    
    if (data['ai_price_estimation'] is Map) {
      return Map<String, dynamic>.from(data['ai_price_estimation']);
    }
    
    return null;
  }
} 