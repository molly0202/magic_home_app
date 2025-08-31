import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_request.dart';
import '../models/provider_match.dart';
import 'google_maps_service.dart';

class ProviderMatchingService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  /// Main function to find and rank providers for a user request
  static Future<List<ProviderMatch>> findMatchingProviders({
    required UserRequest userRequest,
    int maxResults = 10,
  }) async {
    try {
      print('🔍 Starting provider matching for request: ${userRequest.requestId}');
      
      // Step 1: Get user's friends and work history for referral system
      final userContext = await _getUserContext(userRequest.userId);
      
      // Step 2: Get all active providers that match service category
      final eligibleProviders = await _getEligibleProviders(userRequest.serviceCategory);
      
      if (eligibleProviders.isEmpty) {
        print('⚠️ No eligible providers found for category: ${userRequest.serviceCategory}');
        return [];
      }
      
      print('📊 Found ${eligibleProviders.length} eligible providers');
      
      // Step 3: Calculate scores for each provider
      List<ProviderMatch> matches = [];
      
      for (final provider in eligibleProviders) {
        final providerId = provider.id;
        final providerData = provider.data() as Map<String, dynamic>;
        
        // Calculate all scoring components
        final scores = await _calculateProviderScores(
          userRequest: userRequest,
          providerId: providerId,
          providerData: providerData,
          userContext: userContext,
        );
        
        // Create match object with all scores
        final match = ProviderMatch.fromProviderWithScores(
          providerId: providerId,
          providerData: providerData,
          serviceCategoryMatch: scores['serviceCategoryMatch']!,
          locationProximityScore: scores['locationProximityScore']!,
          ratingScore: scores['ratingScore']!,
          availabilityScore: scores['availabilityScore']!,
          referralBonus: scores['referralBonus']!,
          collectedWorkBonus: scores['collectedWorkBonus']!,
          distanceKm: scores['distanceKm']!,
          isReferredByFriend: scores['isReferredByFriend']! > 0,
          hasCollectedWork: scores['hasCollectedWork']! > 0,
          referralSourceUserIds: userContext['referralProviderIds'],
          collectedWorkIds: userContext['collectedWorkIds'],
          matchReason: _generateMatchReason(scores, providerId, userContext),
          additionalDetails: {
            ...scores,
            'referringFriendNames': (userContext['providerToFriendNames'] as Map<String, List<String>>? ?? {})[providerId] ?? [],
          },
        );
        
        matches.add(match);
      }
      
      // Step 4: Sort by overall score (descending)
      matches.sort((a, b) => b.overallScore.compareTo(a.overallScore));
      
      // Step 5: Return top results
      final topMatches = matches.take(maxResults).toList();
      
      print('✅ Found ${topMatches.length} matches, top score: ${topMatches.isNotEmpty ? topMatches.first.overallScore.toStringAsFixed(2) : 'N/A'}');
      
      // Log the matching results
      await _logMatchingResults(userRequest, topMatches);
      
      return topMatches;
      
    } catch (e, stackTrace) {
      print('❌ Error in provider matching: $e');
      print('Stack trace: $stackTrace');
      return [];
    }
  }
  
  /// Get user context for referral and work history
  static Future<Map<String, dynamic>> _getUserContext(String userId) async {
    try {
      // Get user document
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final userData = userDoc.data() ?? {};
      
      // Get friend connections (user's friends who have referred providers)
      final friendIds = List<String>.from(userData['friends'] ?? []);
      
      // Get providers referred by friends with friend names
      List<String> referralProviderIds = [];
      Map<String, List<String>> providerToFriendNames = {}; // providerId -> [friend names]
      
      if (friendIds.isNotEmpty) {
        final friendDocs = await _firestore
            .collection('users')
            .where(FieldPath.documentId, whereIn: friendIds)
            .get();
        
        for (final friendDoc in friendDocs.docs) {
          final friendData = friendDoc.data();
          final friendName = friendData['name'] ?? friendData['displayName'] ?? 'A friend';
          final friendReferrals = List<String>.from(friendData['referred_provider_ids'] ?? []);
          
          for (final providerId in friendReferrals) {
            referralProviderIds.add(providerId);
            
            // Track which friend referred this provider
            if (providerToFriendNames[providerId] == null) {
              providerToFriendNames[providerId] = [];
            }
            providerToFriendNames[providerId]!.add(friendName);
          }
        }
      }
      
      // Get user's own referred providers (marked as "you")
      final userReferrals = List<String>.from(userData['referred_provider_ids'] ?? []);
      for (final providerId in userReferrals) {
        referralProviderIds.add(providerId);
        if (providerToFriendNames[providerId] == null) {
          providerToFriendNames[providerId] = [];
        }
        providerToFriendNames[providerId]!.add('you');
      }
      
      // Get user's collected work history
      final collectedWorkIds = List<String>.from(userData['collected_work_ids'] ?? []);
      
      return {
        'friendIds': friendIds,
        'referralProviderIds': referralProviderIds.toSet().toList(), // Remove duplicates
        'providerToFriendNames': providerToFriendNames, // NEW: mapping of provider -> friend names
        'collectedWorkIds': collectedWorkIds,
        'userLocation': userData['location'],
      };
    } catch (e) {
      print('⚠️ Error getting user context: $e');
      return {
        'friendIds': <String>[],
        'referralProviderIds': <String>[],
        'providerToFriendNames': <String, List<String>>{},
        'collectedWorkIds': <String>[],
        'userLocation': null,
      };
    }
  }
  
  /// Get eligible providers based on service category
  static Future<List<QueryDocumentSnapshot>> _getEligibleProviders(String serviceCategory) async {
    try {
      print('🔍 Searching for providers with service category: "$serviceCategory"');
      
      // Normalize service category to lowercase for matching
      final normalizedCategory = serviceCategory.toLowerCase();
      print('🔍 Normalized category: "$normalizedCategory"');
      
      // Query providers that:
      // 1. Are active
      // 2. Accept new requests
      // 3. Have the required service category (case-insensitive)
      // 4. Are verified
      
      final query = await _firestore
          .collection('providers')
          .where('is_active', isEqualTo: true)
          .where('accepting_new_requests', isEqualTo: true)
          .where('service_categories', arrayContains: normalizedCategory)
          .where('status', isEqualTo: 'verified')
          .get();
      
      print('🔍 Found ${query.docs.length} eligible providers for "$normalizedCategory"');
      
      // Log provider details for debugging
      for (final doc in query.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final providerName = data['name'] ?? data['company'] ?? 'Unknown';
        print('   - ${doc.id}: $providerName');
      }
      
      return query.docs;
    } catch (e) {
      print('⚠️ Error getting eligible providers: $e');
      return [];
    }
  }
  
  /// Calculate all scoring components for a provider
  static Future<Map<String, double>> _calculateProviderScores({
    required UserRequest userRequest,
    required String providerId,
    required Map<String, dynamic> providerData,
    required Map<String, dynamic> userContext,
  }) async {
    
    // 1. Service Category Match Score (0.0 - 1.0)
    final serviceCategoryMatch = _calculateServiceCategoryMatch(
      userRequest.serviceCategory,
      List<String>.from(providerData['service_categories'] ?? []),
    );
    
    // 2. Location Proximity Score (0.0 - 1.0) - Now using Google Maps API
    final locationScores = await _calculateLocationProximity(
      userRequest.location,
      providerData['location'],
      userRequest.address,
    );
    
    // 3. Thumbs Up Percentage Score (0.0 - 1.0)
    final ratingScore = _calculateThumbsUpScore(
      providerData['total_jobs_completed'],
      providerData['thumbs_up_count'],
    );
    
    // 4. Availability Score (0.0 - 1.0)
    final availabilityScore = _calculateAvailabilityMatch(
      userRequest.userAvailability,
      providerData,
    );
    
    // 5. Referral Bonus (0.0 - 1.0) - Now factors in number of friends
    final referralBonus = _calculateReferralBonus(
      providerId,
      userContext,
    );
    
    // 6. Collected Work Bonus (0.0 - 0.2)
    final collectedWorkBonus = _calculateCollectedWorkBonus(
      providerId,
      userContext['collectedWorkIds'],
    );
    
    return {
      'serviceCategoryMatch': serviceCategoryMatch,
      'locationProximityScore': locationScores['score']!,
      'ratingScore': ratingScore,
      'availabilityScore': availabilityScore,
      'referralBonus': referralBonus,
      'collectedWorkBonus': collectedWorkBonus,
      'distanceKm': locationScores['distance']!,
      'isReferredByFriend': referralBonus > 0 ? 1.0 : 0.0,
      'hasCollectedWork': collectedWorkBonus > 0 ? 1.0 : 0.0,
    };
  }
  
  /// Calculate service category match score
  static double _calculateServiceCategoryMatch(String requestedCategory, List<String> providerCategories) {
    if (providerCategories.contains(requestedCategory)) {
      return 1.0; // Perfect match
    }
    
    // Check for related categories
    final relatedCategories = _getRelatedCategories(requestedCategory);
    for (final category in providerCategories) {
      if (relatedCategories.contains(category)) {
        return 0.7; // Good related match
      }
    }
    
    return 0.0; // No match
  }
  
  /// Get related service categories
  static List<String> _getRelatedCategories(String category) {
    const Map<String, List<String>> relatedMap = {
      'plumbing': ['handyman'],
      'electrical': ['handyman'],
      'hvac': ['handyman'],
      'handyman': ['plumbing', 'electrical', 'hvac', 'appliance'],
      'cleaning': ['appliance'],
      'landscaping': ['handyman'],
      'appliance': ['handyman', 'cleaning'],
    };
    
    return relatedMap[category] ?? [];
  }
  
  /// Calculate location proximity score with distance using Google Maps
  static Future<Map<String, double>> _calculateLocationProximity(
    Map<String, dynamic>? userLocation,
    String? providerLocation,
    String userAddress,
  ) async {
    // Try Google Maps API for real distance calculation
    if (providerLocation != null && providerLocation.isNotEmpty) {
      try {
        final distanceResult = await GoogleMapsService.calculateDistance(
          originAddress: userAddress,
          destinationAddress: providerLocation,
        );
        
        if (distanceResult['success'] == true) {
          final distanceKm = distanceResult['distanceKm'] as double;
          print('🎯 Real distance: ${distanceResult['distanceText']} (${distanceKm}km)');
          
          return {
            'score': _distanceToScore(distanceKm),
            'distance': distanceKm,
          };
        }
      } catch (e) {
        print('⚠️ Google Maps API failed, using fallback: $e');
      }
    }
    
    // Fallback to simulated distance for Seattle area
    final distance = _simulateSeattleDistance(userAddress, providerLocation);
    return {
      'score': _distanceToScore(distance),
      'distance': distance,
    };
  }
  
  /// Simulate distance calculation for Seattle area
  static double _simulateSeattleDistance(String userAddress, String? providerLocation) {
    final random = Random();
    
    // Seattle area simulation based on neighborhoods
    final userLower = userAddress.toLowerCase();
    final providerLower = providerLocation?.toLowerCase() ?? '';
    
    // Same neighborhood - closer distance
    if (_sameSeattleNeighborhood(userLower, providerLower)) {
      return 2.0 + (random.nextDouble() * 4.0); // 2-6 km
    }
    
    // Same city (Seattle/Bellevue/etc) - medium distance  
    if (_sameSeattleCity(userLower, providerLower)) {
      return 5.0 + (random.nextDouble() * 8.0); // 5-13 km
    }
    
    // Greater Seattle area - longer distance
    return 8.0 + (random.nextDouble() * 15.0); // 8-23 km
  }
  
  /// Check if addresses are in the same Seattle neighborhood
  static bool _sameSeattleNeighborhood(String addr1, String addr2) {
    const neighborhoods = [
      ['capitol hill', 'first hill'],
      ['ballard', 'fremont', 'wallingford'],
      ['queen anne', 'south lake union'],
      ['bellevue', 'redmond', 'kirkland'],
      ['seattle center', 'lower queen anne'],
      ['university district', 'ravenna'],
    ];
    
    for (final group in neighborhoods) {
      bool addr1Match = group.any((n) => addr1.contains(n));
      bool addr2Match = group.any((n) => addr2.contains(n));
      if (addr1Match && addr2Match) return true;
    }
    return false;
  }
  
  /// Check if addresses are in the same Seattle metro city
  static bool _sameSeattleCity(String addr1, String addr2) {
    const cities = ['seattle', 'bellevue', 'redmond', 'kirkland', 'bothell', 'renton'];
    
    for (final city in cities) {
      if (addr1.contains(city) && addr2.contains(city)) {
        return true;
      }
    }
    return false;
  }
  
  /// Convert distance to score
  static double _distanceToScore(double distanceKm) {
    if (distanceKm <= 5.0) return 1.0;    // Excellent - within 5km
    if (distanceKm <= 10.0) return 0.8;   // Good - within 10km
    if (distanceKm <= 20.0) return 0.6;   // Fair - within 20km
    if (distanceKm <= 30.0) return 0.4;   // Poor - within 30km
    return 0.2;                           // Very poor - beyond 30km
  }
  

  
  /// Calculate thumbs up percentage score (0.0-1.0 scale)
  static double _calculateThumbsUpScore(dynamic totalJobs, dynamic thumbsUpCount) {
    final total = int.tryParse(totalJobs?.toString() ?? '0') ?? 0;
    final thumbsUp = int.tryParse(thumbsUpCount?.toString() ?? '0') ?? 0;
    
    if (total == 0) {
      return 0.5; // No reviews yet - neutral score
    }
    
    final thumbsUpPercentage = thumbsUp / total;
    
    // Convert percentage to score
    if (thumbsUpPercentage >= 0.90) return 1.0;  // 90%+ thumbs up - excellent
    if (thumbsUpPercentage >= 0.80) return 0.9;  // 80-89% thumbs up - very good
    if (thumbsUpPercentage >= 0.70) return 0.8;  // 70-79% thumbs up - good
    if (thumbsUpPercentage >= 0.60) return 0.6;  // 60-69% thumbs up - fair
    if (thumbsUpPercentage >= 0.50) return 0.4;  // 50-59% thumbs up - poor
    return 0.2; // <50% thumbs up - very poor
  }
  
  /// Calculate availability match score
  static double _calculateAvailabilityMatch(
    Map<String, dynamic> userAvailability,
    Map<String, dynamic> providerData,
  ) {
    // MVP: Simple availability matching based on accepting_new_requests toggle
    // Since we already filter by accepting_new_requests = true in _getEligibleProviders,
    // all providers reaching this point are available for new work
    
    final acceptingNewRequests = providerData['accepting_new_requests'] ?? false;
    
    if (acceptingNewRequests) {
      return 1.0; // Provider is accepting new requests
    } else {
      return 0.0; // Provider is not accepting new requests (shouldn't reach here due to filtering)
    }
  }
  
  /// Calculate referral bonus based on number of friends who referred (0.0-1.0 scale)
  static double _calculateReferralBonus(String providerId, Map<String, dynamic> userContext) {
    final providerToFriendNames = userContext['providerToFriendNames'] as Map<String, List<String>>? ?? {};
    final friendNames = providerToFriendNames[providerId] ?? [];
    
    if (friendNames.isEmpty) {
      return 0.0; // No referrals
    }
    
    // Scale based on number of friends who referred this provider
    // 1 friend = 0.6, 2 friends = 0.8, 3+ friends = 1.0
    if (friendNames.length >= 3) {
      return 1.0; // Multiple friends recommend - highest confidence
    } else if (friendNames.length == 2) {
      return 0.8; // Two friends recommend - high confidence  
    } else {
      return 0.6; // One friend recommends - good confidence
    }
  }
  
  /// Calculate collected work bonus (0.0-1.0 scale for weighted scoring)
  static double _calculateCollectedWorkBonus(String providerId, List<String> collectedWorkIds) {
    // Check if user has previous work history with this provider
    // This would require more complex logic to match provider IDs with work history
    // For now, we'll simulate based on provider ID patterns
    
    for (final workId in collectedWorkIds) {
      if (workId.contains(providerId)) {
        return 1.0; // Full collected work score (will be weighted at 5% in final calculation)
      }
    }
    return 0.0;
  }
  
  /// Generate match reason description
  static String _generateMatchReason(Map<String, double> scores, String providerId, Map<String, dynamic> userContext) {
    List<String> reasons = [];
    
    // PRIORITY 1: Referrals (most important for referral-based app)
    if (scores['referralBonus']! > 0) {
      final providerToFriendNames = userContext['providerToFriendNames'] as Map<String, List<String>>? ?? {};
      final friendNames = providerToFriendNames[providerId] ?? [];
      
      if (friendNames.isNotEmpty) {
        if (friendNames.length == 1) {
          if (friendNames.first.toLowerCase() == 'you') {
            reasons.add('🤝 Recommended by you');
          } else {
            reasons.add('🤝 Recommended by ${friendNames.first}');
          }
        } else {
          // Multiple friends recommended this provider
          final friendList = friendNames.where((name) => name.toLowerCase() != 'you').toList();
          final hasUserReferral = friendNames.any((name) => name.toLowerCase() == 'you');
          
          if (friendList.length == 1 && hasUserReferral) {
            reasons.add('🤝 Recommended by you & ${friendList.first}');
          } else if (friendList.length == 2) {
            reasons.add('🤝 Recommended by ${friendList.join(' & ')}');
          } else if (friendList.length > 2) {
            reasons.add('🤝 Recommended by ${friendList.take(2).join(', ')} & ${friendList.length - 2} more');
          } else {
            reasons.add('🤝 Recommended by you');
          }
        }
      } else {
        reasons.add('🤝 Recommended by friends');
      }
    }
    
    // PRIORITY 2: Service category match
    if (scores['serviceCategoryMatch']! >= 1.0) {
      reasons.add('Perfect service match');
    } else if (scores['serviceCategoryMatch']! >= 0.7) {
      reasons.add('Related service expertise');
    }
    
    // PRIORITY 3: Previous work history
    if (scores['collectedWorkBonus']! > 0) {
      reasons.add('Previous work history');
    }
    
    // PRIORITY 4: High rating
    if (scores['ratingScore']! >= 0.8) {
      reasons.add('Highly rated');
    }
    
    // PRIORITY 5: Location (lower priority now)
    if (scores['locationProximityScore']! >= 0.8) {
      reasons.add('Nearby location');
    }
    
    return reasons.isNotEmpty ? reasons.join(', ') : 'Available provider';
  }
  
  /// Log matching results for analytics
  static Future<void> _logMatchingResults(UserRequest userRequest, List<ProviderMatch> matches) async {
    try {
      await _firestore.collection('matching_logs').add({
        'requestId': userRequest.requestId,
        'userId': userRequest.userId,
        'serviceCategory': userRequest.serviceCategory,
        'matchCount': matches.length,
        'topMatches': matches.take(3).map((m) => {
          'providerId': m.providerId,
          'name': m.name,
          'overallScore': m.overallScore,
          'matchQuality': m.matchQuality,
        }).toList(),
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('⚠️ Error logging matching results: $e');
    }
  }
} 