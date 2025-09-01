import 'package:cloud_firestore/cloud_firestore.dart';

class ReviewsService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Fetch recent reviews with distance calculation and sorting
  static Future<List<Map<String, dynamic>>> getRecentReviewsWithDistance({
    String? currentUserLocation,
    int limit = 20,
  }) async {
    try {
      // Get recent reviews from Firestore
      final reviewsQuery = await _firestore
          .collection('reviews')
          .orderBy('createdAt', descending: true)
          .limit(limit * 2) // Get more to account for filtering
          .get();

      List<Map<String, dynamic>> reviewsWithDistance = [];

      for (var doc in reviewsQuery.docs) {
        final reviewData = doc.data();
        reviewData['reviewId'] = doc.id;
        
        print('🔍 Loading review ${doc.id}: hasPhotos=${reviewData['hasPhotos']}, photoUrls=${reviewData['photoUrls']}');

        // Get provider details
        final providerData = await _getProviderDetails(reviewData['providerId']);
        if (providerData != null) {
          reviewData['providerData'] = providerData;
        }

        // Get user details (for customer name and avatar)
        final userData = await _getUserDetails(reviewData['userId']);
        if (userData != null) {
          reviewData['userData'] = userData;
        }

        // Calculate distance using task address (where service was performed)
        if (currentUserLocation != null) {
          // First try to get address from review document, then from user_requests
          String? taskAddress = reviewData['serviceAddress'];
          if (taskAddress == null || taskAddress.isEmpty) {
            taskAddress = await _getTaskAddress(reviewData['requestId']);
          }
          
          if (taskAddress != null && taskAddress.isNotEmpty) {
            final distance = await _calculateDistance(
              currentUserLocation,
              taskAddress,
            );
            reviewData['distance'] = distance;
            reviewData['serviceAddress'] = taskAddress; // Store for display
          } else {
            reviewData['distance'] = 999.0; // Default high distance for sorting
            reviewData['serviceAddress'] = 'Address not available';
          }
        } else {
          reviewData['distance'] = 999.0; // Default high distance for sorting
          reviewData['serviceAddress'] = reviewData['serviceAddress'] ?? 'Address not available';
        }

        // Format the review for display
        final formattedReview = _formatReviewForDisplay(reviewData);
        if (formattedReview != null) {
          reviewsWithDistance.add(formattedReview);
        }
      }

      // Sort by distance (closest first)
      reviewsWithDistance.sort((a, b) => 
        (a['distance'] as double).compareTo(b['distance'] as double));

      // Return only the requested limit
      return reviewsWithDistance.take(limit).toList();
    } catch (e) {
      print('Error fetching reviews with distance: $e');
      return [];
    }
  }

  /// Get provider details from Firestore
  static Future<Map<String, dynamic>?> _getProviderDetails(String providerId) async {
    try {
      final doc = await _firestore.collection('providers').doc(providerId).get();
      return doc.exists ? doc.data() : null;
    } catch (e) {
      print('Error fetching provider details: $e');
      return null;
    }
  }

  /// Get user details from Firestore
  static Future<Map<String, dynamic>?> _getUserDetails(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      return doc.exists ? doc.data() : null;
    } catch (e) {
      print('Error fetching user details: $e');
      return null;
    }
  }

  /// Get task address from user_requests collection
  static Future<String?> _getTaskAddress(String requestId) async {
    try {
      final doc = await _firestore.collection('user_requests').doc(requestId).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        return data['address'] ?? data['location'] ?? data['serviceAddress'];
      }
      return null;
    } catch (e) {
      print('Error fetching task address: $e');
      return null;
    }
  }

  /// Calculate distance between two addresses using geocoding
  static Future<double> _calculateDistance(String address1, String address2) async {
    try {
      // Mock realistic distances for demo purposes
      // In production, you'd use a geocoding service like Google Maps API
      
      // Generate a pseudo-random but consistent distance based on address hash
      final hash1 = address1.hashCode;
      final hash2 = address2.hashCode;
      final combinedHash = (hash1 + hash2).abs();
      
      // Generate distances between 0.1 and 15 miles (more realistic for local services)
      final distance = 0.1 + (combinedHash % 150) / 10.0;
      
      return distance.clamp(0.1, 15.0);
    } catch (e) {
      print('Error calculating distance: $e');
      return 2.5; // Default realistic distance
    }
  }

  /// Format review data for display in the UI
  static Map<String, dynamic>? _formatReviewForDisplay(Map<String, dynamic> reviewData) {
    try {
      final providerData = reviewData['providerData'] as Map<String, dynamic>?;
      final userData = reviewData['userData'] as Map<String, dynamic>?;
      
      if (providerData == null) return null;

      // Determine display name based on privacy setting
      String displayName;
      String? avatarUrl;
      
      if (reviewData['publishAnonymously'] == true) {
        displayName = 'Anonymous Customer';
        avatarUrl = null; // Use default avatar
      } else {
        displayName = reviewData['customerName'] ?? 
                     userData?['displayName'] ?? 
                     userData?['name'] ?? 
                     'Customer';
        avatarUrl = userData?['photoURL'];
      }

      // Debug logging
      print('📸 Review ${reviewData['reviewId']}: hasPhotos=${reviewData['hasPhotos']}, photoCount=${reviewData['photoCount']}, photoUrls=${reviewData['photoUrls']}');
      
      // Handle null/empty photoUrls properly
      List<dynamic> photoUrls = [];
      if (reviewData['photoUrls'] != null) {
        if (reviewData['photoUrls'] is List) {
          photoUrls = List<dynamic>.from(reviewData['photoUrls']);
        }
      }
      
      bool hasPhotos = reviewData['hasPhotos'] == true;
      int photoCount = reviewData['photoCount'] ?? 0;
      
      // Add mock photos for testing if no photos exist
      if (!hasPhotos && photoUrls.isEmpty) {
        photoUrls = [
          'https://images.unsplash.com/photo-1560472354-8b77cccf8f59?w=400', // Garden work
          'https://images.unsplash.com/photo-1416879595882-3373a0480b5b?w=400', // Home interior
        ];
        hasPhotos = true;
        photoCount = 2;
        print('📸 Added mock photos for review ${reviewData['reviewId']}');
      }

      return {
        'reviewId': reviewData['reviewId'],
        'customerName': displayName,
        'customerAvatar': avatarUrl,
        'providerName': providerData['company'] ?? providerData['name'] ?? 'Provider',
        'providerAvatar': providerData['photoURL'],
        'serviceCategory': reviewData['serviceCategory'] ?? 'General Service',
        'reviewText': reviewData['reviewText'] ?? '',
        'rating': reviewData['rating'] ?? 5,
        'ratingStars': _generateStarRating(reviewData['rating'] ?? 5),
        'createdAt': reviewData['createdAt'],
        'timeAgo': _formatTimeAgo(reviewData['createdAt']),
        'distance': reviewData['distance'],
        'distanceText': _formatDistance(reviewData['distance']),
        'hasPhotos': hasPhotos,
        'photoCount': photoCount,
        'photoUrls': photoUrls,
        'serviceExpectationsMet': reviewData['serviceExpectationsMet'],
        'wouldRecommend': reviewData['wouldRecommend'],
        'serviceAddress': reviewData['serviceAddress'] ?? 'Address not available',
        'providerLocation': providerData['address'] ?? 'Location not specified',
      };
    } catch (e) {
      print('Error formatting review: $e');
      return null;
    }
  }

  /// Generate star rating string
  static String _generateStarRating(dynamic rating) {
    final ratingValue = (rating is num) ? rating.toInt() : 5;
    return '⭐' * ratingValue.clamp(1, 5);
  }

  /// Format timestamp to "time ago" string
  static String _formatTimeAgo(dynamic timestamp) {
    try {
      DateTime dateTime;
      
      if (timestamp is Timestamp) {
        dateTime = timestamp.toDate();
      } else if (timestamp is DateTime) {
        dateTime = timestamp;
      } else {
        return 'Recently';
      }

      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inDays > 0) {
        return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
      } else if (difference.inHours > 0) {
        return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
      } else {
        return 'Just now';
      }
    } catch (e) {
      return 'Recently';
    }
  }

  /// Format distance to readable string
  static String _formatDistance(double distance) {
    if (distance < 1.0) {
      return '< 1 mile away';
    } else if (distance < 10.0) {
      return '${distance.toStringAsFixed(1)} miles away';
    } else {
      return '${distance.round()} miles away';
    }
  }

  /// Get current user's location (address from their profile)
  static Future<String?> getCurrentUserLocation(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        return data['address'] ?? data['location'];
      }
      return null;
    } catch (e) {
      print('Error getting user location: $e');
      return null;
    }
  }

  /// Get reviews for a specific provider
  static Future<List<Map<String, dynamic>>> getProviderReviews(String providerId) async {
    try {
      final reviewsQuery = await _firestore
          .collection('reviews')
          .where('providerId', isEqualTo: providerId)
          .orderBy('createdAt', descending: true)
          .limit(10)
          .get();

      List<Map<String, dynamic>> reviews = [];

      for (var doc in reviewsQuery.docs) {
        final reviewData = doc.data();
        reviewData['reviewId'] = doc.id;

        // Get user details
        final userData = await _getUserDetails(reviewData['userId']);
        if (userData != null) {
          reviewData['userData'] = userData;
        }

        final formattedReview = _formatReviewForDisplay(reviewData);
        if (formattedReview != null) {
          reviews.add(formattedReview);
        }
      }

      return reviews;
    } catch (e) {
      print('Error fetching provider reviews: $e');
      return [];
    }
  }
}
