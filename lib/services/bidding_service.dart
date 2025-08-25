import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import '../models/service_bid.dart';
import '../models/bidding_session.dart';
import '../models/user_request.dart';
import '../config/api_config.dart';

class BiddingService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Get real-time stream of bids for a specific request (for users to see incoming bids)
  static Stream<List<ServiceBid>> getBidsStream(String requestId) {
    return _firestore
        .collection('service_bids')
        .where('requestId', isEqualTo: requestId)
        .orderBy('createdAt', descending: true) // Most recent first
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ServiceBid.fromFirestore(doc))
            .toList());
  }

  /// Get real-time bid count stream for a request
  static Stream<int> getBidCountStream(String requestId) {
    return getBidsStream(requestId).map((bids) => bids.length);
  }

  /// Get bidding session for a request
  static Stream<BiddingSession?> getBiddingSessionStream(String requestId) {
    return _firestore
        .collection('bidding_sessions')
        .where('requestId', isEqualTo: requestId)
        .limit(1)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) return null;
      return BiddingSession.fromFirestore(snapshot.docs.first);
    });
  }

  /// Get active bidding opportunities for a provider
  static Stream<List<Map<String, dynamic>>> getProviderBiddingOpportunities(String providerId) {
    print('🔍 BIDDING_SERVICE: Looking for opportunities for provider: $providerId');
    return _firestore
        .collection('user_requests')
        .where('status', isEqualTo: 'matched')
        .where('matchedProviders', arrayContains: providerId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
      print('🔍 BIDDING_SERVICE: Found ${snapshot.docs.length} matched requests for provider $providerId');
      List<Map<String, dynamic>> opportunities = [];
      
      for (var doc in snapshot.docs) {
        var requestData = doc.data();
        print('🔍 BIDDING_SERVICE DEBUG - Raw Firestore data:');
        print('🔍 Doc ID: ${doc.id}');
        print('🔍 UserAvailability in Firestore: ${requestData['userAvailability']}');
        print('🔍 AiPriceEstimation in Firestore: ${requestData['aiPriceEstimation']}');
        print('🔍 Preferences in Firestore: ${requestData['preferences']}');
        
        var request = UserRequest.fromFirestore(doc);
        print('🔍 After UserRequest.fromFirestore():');
        print('🔍 UserAvailability in model: ${request.userAvailability}');
        print('🔍 AiPriceEstimation in model: ${request.aiPriceEstimation}');
        print('🔍 Preferences in model: ${request.preferences}');
        
        // Check if provider has already bid
        var existingBidQuery = await _firestore
            .collection('service_bids')
            .where('requestId', isEqualTo: doc.id)
            .where('providerId', isEqualTo: providerId)
            .limit(1)
            .get();
        
        bool hasExistingBid = existingBidQuery.docs.isNotEmpty;
        print('🔍 BIDDING_SERVICE: Request ${doc.id} - hasExistingBid: $hasExistingBid');
        
        // Get bidding session to check deadline
        var sessionQuery = await _firestore
            .collection('bidding_sessions')
            .where('requestId', isEqualTo: doc.id)
            .limit(1)
            .get();
        
        DateTime? deadline;
        if (sessionQuery.docs.isNotEmpty) {
          var sessionData = sessionQuery.docs.first.data();
          deadline = (sessionData['deadline'] as Timestamp).toDate();
          print('🔍 BIDDING_SERVICE: Request ${doc.id} - deadline: $deadline');
        } else {
          print('🔍 BIDDING_SERVICE: Request ${doc.id} - no bidding session found');
        }
        
        // Only include if deadline hasn't passed and no existing bid
        bool isDeadlineValid = deadline == null || DateTime.now().isBefore(deadline);
        print('🔍 BIDDING_SERVICE: Request ${doc.id} - isDeadlineValid: $isDeadlineValid');
        
        if (!hasExistingBid && isDeadlineValid) {
          opportunities.add({
            'request': request,
            'deadline': deadline,
            'timeRemaining': deadline != null 
                ? deadline.difference(DateTime.now()) 
                : null,
            'hasExistingBid': false,
          });
        }
      }
      
      print('🔍 BIDDING_SERVICE: Returning ${opportunities.length} opportunities for provider $providerId');
      return opportunities;
    });
  }

  /// Submit a bid for a service request
  static Future<Map<String, dynamic>> submitBid({
    required String requestId,
    required double priceQuote,
    required String availability,
    required String bidMessage,
  }) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      final providerId = currentUser.uid;

      // Validate inputs
      if (priceQuote <= 0) {
        throw Exception('Price quote must be greater than 0');
      }
      
      if (availability.trim().isEmpty) {
        throw Exception('Availability is required');
      }
      
      if (bidMessage.trim().isEmpty) {
        throw Exception('Bid message is required');
      }

      // Check if bidding is still active
      final requestDoc = await _firestore
          .collection('user_requests')
          .doc(requestId)
          .get();
      
      if (!requestDoc.exists) {
        throw Exception('Service request not found');
      }
      
      final requestData = requestDoc.data()!;
      if (requestData['status'] != 'matched') {
        throw Exception('Bidding is no longer active for this request');
      }

      // Check if provider has already submitted a bid
      final existingBidQuery = await _firestore
          .collection('service_bids')
          .where('requestId', isEqualTo: requestId)
          .where('providerId', isEqualTo: providerId)
          .limit(1)
          .get();
      
      if (existingBidQuery.docs.isNotEmpty) {
        throw Exception('You have already submitted a bid for this request');
      }

      // Call Firebase Function to submit bid
      final functionUrl = '${ApiConfig.firebaseFunctionsUrl}/submit_bid';
      
      print('🔍 BIDDING_SERVICE: Submitting bid to $functionUrl');
      print('🔍 BIDDING_SERVICE: Request data: ${json.encode({
        'request_id': requestId,
        'provider_id': providerId,
        'price_quote': priceQuote,
        'availability': availability,
        'bid_message': bidMessage,
      })}');
      
      final response = await http.post(
        Uri.parse(functionUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${await currentUser.getIdToken()}',
        },
        body: json.encode({
          'request_id': requestId,
          'provider_id': providerId,
          'price_quote': priceQuote,
          'availability': availability,
          'bid_message': bidMessage,
        }),
      );

      print('🔍 BIDDING_SERVICE: Response status: ${response.statusCode}');
      print('🔍 BIDDING_SERVICE: Response body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        print('🔍 BIDDING_SERVICE: Success response: $responseData');
        return {
          'success': true,
          'message': 'Bid submitted successfully',
          'bidId': responseData['bid_id'],
          'priceBenchmark': responseData['price_benchmark'],
        };
      } else {
        print('🔍 BIDDING_SERVICE: Error response: ${response.statusCode} - ${response.body}');
        throw Exception('Failed to submit bid: ${response.body}');
      }
    } catch (e) {
      print('Error submitting bid: $e');
      return {
        'success': false,
        'message': e.toString(),
      };
    }
  }

  /// Accept a bid (for users)
  static Future<Map<String, dynamic>> acceptBid(String bidId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      final userId = currentUser.uid;
      
      // Call Firebase Function to accept bid
      final functionUrl = '${ApiConfig.firebaseFunctionsUrl}/accept_bid';
      
      final response = await http.post(
        Uri.parse(functionUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${await currentUser.getIdToken()}',
        },
        body: json.encode({
          'bid_id': bidId,
          'user_id': userId,
        }),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return {
          'success': true,
          'message': 'Bid accepted successfully',
          'winningProviderId': responseData['winning_provider_id'],
          'price': responseData['price'],
        };
      } else {
        throw Exception('Failed to accept bid: ${response.body}');
      }
    } catch (e) {
      print('Error accepting bid: $e');
      return {
        'success': false,
        'message': e.toString(),
      };
    }
  }

  /// Get bid details by ID
  static Future<ServiceBid?> getBidById(String bidId) async {
    try {
      final doc = await _firestore.collection('service_bids').doc(bidId).get();
      if (doc.exists) {
        return ServiceBid.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      print('Error getting bid by ID: $e');
      return null;
    }
  }

  /// Get provider's bid history
  static Stream<List<ServiceBid>> getProviderBidHistory(String providerId) {
    return _firestore
        .collection('service_bids')
        .where('providerId', isEqualTo: providerId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ServiceBid.fromFirestore(doc))
            .toList());
  }

  /// Get user's bid requests history
  static Stream<List<Map<String, dynamic>>> getUserBidHistory(String userId) {
    return _firestore
        .collection('bidding_sessions')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
      List<Map<String, dynamic>> history = [];
      
      for (var doc in snapshot.docs) {
        var session = BiddingSession.fromFirestore(doc);
        
        // Get the user request
        var requestDoc = await _firestore
            .collection('user_requests')
            .doc(session.requestId)
            .get();
        
        if (requestDoc.exists) {
          var request = UserRequest.fromFirestore(requestDoc);
          
          // Get bids for this session
          var bidsQuery = await _firestore
              .collection('service_bids')
              .where('requestId', isEqualTo: session.requestId)
              .get();
          
          var bids = bidsQuery.docs
              .map((doc) => ServiceBid.fromFirestore(doc))
              .toList();
          
          history.add({
            'session': session,
            'request': request,
            'bids': bids,
            'bidCount': bids.length,
          });
        }
      }
      
      return history;
    });
  }

  /// Check if provider can bid on a request
  static Future<Map<String, dynamic>> canProviderBid(String requestId, String providerId) async {
    try {
      // Check if request exists and is in 'matched' status
      final requestDoc = await _firestore
          .collection('user_requests')
          .doc(requestId)
          .get();
      
      if (!requestDoc.exists) {
        return {
          'canBid': false,
          'reason': 'Service request not found',
        };
      }
      
      final requestData = requestDoc.data()!;
      
      if (requestData['status'] != 'matched') {
        return {
          'canBid': false,
          'reason': 'Bidding is no longer active',
        };
      }
      
      // Check if provider is in matched providers list
      final matchedProviders = List<String>.from(requestData['matchedProviders'] ?? []);
      if (!matchedProviders.contains(providerId)) {
        return {
          'canBid': false,
          'reason': 'You are not eligible to bid on this request',
        };
      }
      
      // Check if provider already submitted a bid
      final existingBidQuery = await _firestore
          .collection('service_bids')
          .where('requestId', isEqualTo: requestId)
          .where('providerId', isEqualTo: providerId)
          .limit(1)
          .get();
      
      if (existingBidQuery.docs.isNotEmpty) {
        return {
          'canBid': false,
          'reason': 'You have already submitted a bid',
          'existingBid': ServiceBid.fromFirestore(existingBidQuery.docs.first),
        };
      }
      
      // Check if deadline has passed
      final sessionQuery = await _firestore
          .collection('bidding_sessions')
          .where('requestId', isEqualTo: requestId)
          .limit(1)
          .get();
      
      if (sessionQuery.docs.isNotEmpty) {
        final sessionData = sessionQuery.docs.first.data();
        final deadline = (sessionData['deadline'] as Timestamp).toDate();
        
        if (DateTime.now().isAfter(deadline)) {
          return {
            'canBid': false,
            'reason': 'Bidding deadline has passed',
          };
        }
        
        return {
          'canBid': true,
          'deadline': deadline,
          'timeRemaining': deadline.difference(DateTime.now()),
        };
      }
      
      return {
        'canBid': true,
        'message': 'You can submit a bid for this request',
      };
      
    } catch (e) {
      print('Error checking if provider can bid: $e');
      return {
        'canBid': false,
        'reason': 'Error checking bid eligibility: $e',
      };
    }
  }

  /// Get bid statistics for analytics
  static Future<Map<String, dynamic>> getBidStatistics(String providerId) async {
    try {
      final bidsQuery = await _firestore
          .collection('service_bids')
          .where('providerId', isEqualTo: providerId)
          .get();
      
      final bids = bidsQuery.docs
          .map((doc) => ServiceBid.fromFirestore(doc))
          .toList();
      
      int totalBids = bids.length;
      int acceptedBids = bids.where((bid) => bid.bidStatus == 'accepted').length;
      int rejectedBids = bids.where((bid) => bid.bidStatus == 'rejected').length;
      int pendingBids = bids.where((bid) => bid.bidStatus == 'pending').length;
      
      double winRate = totalBids > 0 ? (acceptedBids / totalBids) : 0.0;
      
      // Calculate average bid amount
      double averageBidAmount = 0.0;
      if (bids.isNotEmpty) {
        double totalAmount = bids.fold(0.0, (sum, bid) => sum + bid.priceQuote);
        averageBidAmount = totalAmount / bids.length;
      }
      
      // Get price benchmark distribution
      Map<String, int> benchmarkDistribution = {
        'low': bids.where((bid) => bid.priceBenchmark == 'low').length,
        'normal': bids.where((bid) => bid.priceBenchmark == 'normal').length,
        'high': bids.where((bid) => bid.priceBenchmark == 'high').length,
      };
      
      return {
        'totalBids': totalBids,
        'acceptedBids': acceptedBids,
        'rejectedBids': rejectedBids,
        'pendingBids': pendingBids,
        'winRate': winRate,
        'averageBidAmount': averageBidAmount,
        'benchmarkDistribution': benchmarkDistribution,
      };
    } catch (e) {
      print('Error getting bid statistics: $e');
      return {};
    }
  }

  /// Format time remaining for display
  static String formatTimeRemaining(Duration duration) {
    if (duration.isNegative) {
      return "EXPIRED";
    }
    
    int hours = duration.inHours;
    int minutes = duration.inMinutes % 60;
    int seconds = duration.inSeconds % 60;
    
    if (hours > 0) {
      return "${hours}h ${minutes}m remaining";
    } else if (minutes > 0) {
      return "${minutes}m ${seconds}s remaining";
    } else {
      return "${seconds}s remaining";
    }
  }

  /// Format price for display
  static String formatPrice(double price) {
    if (price >= 1000) {
      return '\$${(price / 1000).toStringAsFixed(1)}k';
    }
    return '\$${price.toStringAsFixed(0)}';
  }
}
