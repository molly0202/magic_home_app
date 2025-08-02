class ProviderMatch {
  final String providerId;
  final String name;
  final String company;
  final List<String> serviceCategories;
  final String location;
  final String email;
  final String phone;
  final double rating;
  final int totalJobsCompleted;
  final int hourlyRate;
  final bool isActive;
  final bool acceptingNewRequests;
  
  // Matching scores (0.0 - 1.0)
  final double overallScore;
  final double serviceCategoryMatch;
  final double locationProximityScore;
  final double ratingScore;
  final double availabilityScore;
  final double referralBonus;
  final double collectedWorkBonus;
  final double distanceKm;
  
  // Referral information
  final bool isReferredByFriend;
  final bool hasCollectedWork;
  final List<String> referralSourceUserIds;
  final List<String> collectedWorkIds;
  
  // Additional match details
  final String matchReason;
  final Map<String, dynamic> matchDetails;

  ProviderMatch({
    required this.providerId,
    required this.name,
    required this.company,
    required this.serviceCategories,
    required this.location,
    required this.email,
    required this.phone,
    required this.rating,
    required this.totalJobsCompleted,
    required this.hourlyRate,
    required this.isActive,
    required this.acceptingNewRequests,
    required this.overallScore,
    required this.serviceCategoryMatch,
    required this.locationProximityScore,
    required this.ratingScore,
    required this.availabilityScore,
    required this.referralBonus,
    required this.collectedWorkBonus,
    required this.distanceKm,
    required this.isReferredByFriend,
    required this.hasCollectedWork,
    required this.referralSourceUserIds,
    required this.collectedWorkIds,
    required this.matchReason,
    required this.matchDetails,
  });

  // Create from provider document with calculated scores
  factory ProviderMatch.fromProviderWithScores({
    required String providerId,
    required Map<String, dynamic> providerData,
    required double serviceCategoryMatch,
    required double locationProximityScore,
    required double ratingScore,
    required double availabilityScore,
    required double referralBonus,
    required double collectedWorkBonus,
    required double distanceKm,
    required bool isReferredByFriend,
    required bool hasCollectedWork,
    required List<String> referralSourceUserIds,
    required List<String> collectedWorkIds,
    required String matchReason,
    Map<String, dynamic>? additionalDetails,
  }) {
    // Calculate overall score with weights
    final double overallScore = _calculateOverallScore(
      serviceCategoryMatch: serviceCategoryMatch,
      locationProximityScore: locationProximityScore,
      ratingScore: ratingScore,
      availabilityScore: availabilityScore,
      referralBonus: referralBonus,
      collectedWorkBonus: collectedWorkBonus,
    );

    return ProviderMatch(
      providerId: providerId,
      name: providerData['name'] ?? '',
      company: providerData['company'] ?? '',
      serviceCategories: List<String>.from(providerData['service_categories'] ?? []),
      location: providerData['location'] ?? '',
      email: providerData['email'] ?? '',
      phone: providerData['phone'] ?? '',
      rating: double.tryParse(providerData['rating']?.toString() ?? '0') ?? 0.0,
      totalJobsCompleted: providerData['total_jobs_completed'] ?? 0,
      hourlyRate: providerData['hourly_rate'] ?? 0,
      isActive: providerData['is_active'] ?? false,
      acceptingNewRequests: providerData['accepting_new_requests'] ?? false,
      overallScore: overallScore,
      serviceCategoryMatch: serviceCategoryMatch,
      locationProximityScore: locationProximityScore,
      ratingScore: ratingScore,
      availabilityScore: availabilityScore,
      referralBonus: referralBonus,
      collectedWorkBonus: collectedWorkBonus,
      distanceKm: distanceKm,
      isReferredByFriend: isReferredByFriend,
      hasCollectedWork: hasCollectedWork,
      referralSourceUserIds: referralSourceUserIds,
      collectedWorkIds: collectedWorkIds,
      matchReason: matchReason,
      matchDetails: additionalDetails ?? {},
    );
  }

  // Calculate weighted overall score
  static double _calculateOverallScore({
    required double serviceCategoryMatch,
    required double locationProximityScore,
    required double ratingScore,
    required double availabilityScore,
    required double referralBonus,
    required double collectedWorkBonus,
  }) {
    // OPTIMIZED SCORING FOR REFERRAL-BASED APP (all values 0.0-1.0)
    // Base weights reduced to make room for bonuses
    const double categoryWeight = 0.25;      // 25% - Service category match
    const double locationWeight = 0.15;      // 15% - Location proximity 
    const double ratingWeight = 0.20;        // 20% - Provider rating
    const double availabilityWeight = 0.15;  // 15% - Availability match
    const double referralWeight = 0.20;      // 20% - Referral bonus (HIGH PRIORITY)
    const double collectedWorkWeight = 0.05; // 5% - Previous work bonus
    // Total: 100%
    
    // Calculate weighted score (all components capped at 1.0)
    double finalScore = (serviceCategoryMatch * categoryWeight) +
                       (locationProximityScore * locationWeight) +
                       (ratingScore * ratingWeight) +
                       (availabilityScore * availabilityWeight) +
                       (referralBonus * referralWeight) +
                       (collectedWorkBonus * collectedWorkWeight);
    
    // Ensure score stays within 0.0-1.0 range
    return finalScore.clamp(0.0, 1.0);
  }

  // Get formatted distance string
  String get formattedDistance {
    if (distanceKm < 1.0) {
      return '${(distanceKm * 1000).round()}m away';
    } else if (distanceKm < 10.0) {
      return '${distanceKm.toStringAsFixed(1)}km away';
    } else {
      return '${distanceKm.round()}km away';
    }
  }

  // Get match quality description
  String get matchQuality {
    if (overallScore >= 0.9) return 'Excellent Match';
    if (overallScore >= 0.8) return 'Great Match';
    if (overallScore >= 0.7) return 'Good Match';
    if (overallScore >= 0.6) return 'Fair Match';
    return 'Basic Match';
  }

  // Get priority tags for this match
  List<String> get priorityTags {
    List<String> tags = [];
    
    // PRIORITY ORDER: Referrals first, then quality indicators
    if (isReferredByFriend) tags.add('🤝 Friend Referral'); // TOP PRIORITY
    if (hasCollectedWork) tags.add('⚡ Previous Work');
    if (serviceCategoryMatch >= 0.9) tags.add('✨ Perfect Match');
    if (rating >= 4.5) tags.add('⭐ Top Rated');
    if (totalJobsCompleted >= 100) tags.add('🏆 Experienced');
    if (distanceKm <= 5.0) tags.add('📍 Nearby');
    
    return tags;
  }

  // Convert to map for storage or API
  Map<String, dynamic> toMap() {
    return {
      'providerId': providerId,
      'name': name,
      'company': company,
      'serviceCategories': serviceCategories,
      'location': location,
      'email': email,
      'phone': phone,
      'rating': rating,
      'totalJobsCompleted': totalJobsCompleted,
      'hourlyRate': hourlyRate,
      'isActive': isActive,
      'acceptingNewRequests': acceptingNewRequests,
      'overallScore': overallScore,
      'serviceCategoryMatch': serviceCategoryMatch,
      'locationProximityScore': locationProximityScore,
      'ratingScore': ratingScore,
      'availabilityScore': availabilityScore,
      'referralBonus': referralBonus,
      'collectedWorkBonus': collectedWorkBonus,
      'distanceKm': distanceKm,
      'isReferredByFriend': isReferredByFriend,
      'hasCollectedWork': hasCollectedWork,
      'referralSourceUserIds': referralSourceUserIds,
      'collectedWorkIds': collectedWorkIds,
      'matchReason': matchReason,
      'matchDetails': matchDetails,
      'formattedDistance': formattedDistance,
      'matchQuality': matchQuality,
      'priorityTags': priorityTags,
    };
  }

  @override
  String toString() {
    return 'ProviderMatch(providerId: $providerId, name: $name, overallScore: ${overallScore.toStringAsFixed(2)}, matchQuality: $matchQuality)';
  }
} 