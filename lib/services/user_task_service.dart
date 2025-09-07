import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/user_request.dart';
import '../models/service_bid.dart';
import '../models/bidding_session.dart';
import '../config/api_config.dart';

class UserTaskService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Public getter for Firestore instance
  static FirebaseFirestore get firestore => _firestore;

  /// Get all user requests (tasks) for a specific user
  static Stream<List<UserRequest>> getUserTasks(String userId) {
    return _firestore
        .collection('user_requests')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return UserRequest.fromFirestore(doc);
      }).toList();
    });
  }

  /// Get active tasks with enhanced bidding status detection
  static Stream<List<Map<String, dynamic>>> getActiveTasksWithBiddingInfo(String userId) {
    print('🔍 Querying user_requests with bidding info for userId: $userId');
    return _firestore
        .collection('user_requests')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots(includeMetadataChanges: true)
        .asyncMap((snapshot) async {
      print('📊 Found ${snapshot.docs.length} documents in user_requests for $userId');
      
      final activeTasksWithInfo = <Map<String, dynamic>>[];
      
      for (final doc in snapshot.docs) {
        try {
          final request = UserRequest.fromFirestore(doc);
          
          // Only include active requests
          if (!['pending', 'matched', 'assigned'].contains(request.status)) {
            continue;
          }
          
          // Filter out old tasks without modifying database
          final now = DateTime.now();
          final taskAge = now.difference(request.createdAt);
          
          // Hide pending tasks older than 2 hours (no providers found) - don't modify database
          if (taskAge.inHours >= 2 && request.status == 'pending') {
            print('⏰ Hiding old pending task ${doc.id}: ${taskAge.inHours} hours old (UI filter only)');
            continue; // Skip from display, but don't modify database
          }
          
          // Keep all other tasks - users might want to see old quotes
          
          print('📄 Processing request ${doc.id}: status=${request.status}');
          
          // Check for bidding session and bids
          String actualStatus = request.status;
          int bidCount = 0;
          BiddingSession? biddingSession;
          
          if (request.status == 'matched') {
            // Check if there's an active bidding session with bids
            final sessionQuery = await _firestore
                .collection('bidding_sessions')
                .where('requestId', isEqualTo: doc.id)
                .where('sessionStatus', isEqualTo: 'active')
                .limit(1)
                .get();
            
            if (sessionQuery.docs.isNotEmpty) {
              biddingSession = BiddingSession.fromFirestore(sessionQuery.docs.first);
              bidCount = biddingSession.receivedBids.length;
              
              // If there are bids, consider this as "bidding" status
              if (bidCount > 0) {
                actualStatus = 'bidding';
                print('🔍 Request ${doc.id} has ${bidCount} bids - changing status to bidding');
              }
            }
          }
          
          activeTasksWithInfo.add({
            'request': request,
            'actualStatus': actualStatus,
            'bidCount': bidCount,
            'biddingSession': biddingSession,
          });
          
          print('✅ Added request: ${request.requestId}, actualStatus: $actualStatus, bidCount: $bidCount');
        } catch (e) {
          print('❌ Error processing document ${doc.id}: $e');
        }
      }
      
      print('✅ Returning ${activeTasksWithInfo.length} active tasks with bidding info');
      return activeTasksWithInfo;
    }).handleError((error) {
      print('❌ Error getting active tasks with bidding info: $error');
      return <Map<String, dynamic>>[];
    });
  }

  /// Get active tasks (backward compatibility)
  static Stream<List<UserRequest>> getActiveTasks(String userId) {
    return getActiveTasksWithBiddingInfo(userId).map((tasksWithInfo) {
      return tasksWithInfo.map((info) => info['request'] as UserRequest).toList();
    });
  }

  /// Get completed tasks
  static Stream<List<UserRequest>> getCompletedTasks(String userId) {
    return _firestore
        .collection('user_requests')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return UserRequest.fromFirestore(doc);
      }).where((request) {
        // Filter completed tasks in memory to avoid Firestore index issues
        return ['completed', 'cancelled'].contains(request.status);
      }).toList();
    }).handleError((error) {
      print('Error getting completed tasks: $error');
      return <UserRequest>[];
    });
  }

  /// Get bids for a specific request
  static Stream<List<ServiceBid>> getBidsForRequest(String requestId) {
    print('🔍 USER_TASK_SERVICE: Getting bids for requestId: $requestId');
    return _firestore
        .collection('service_bids')
        .where('requestId', isEqualTo: requestId)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) {
      print('📊 USER_TASK_SERVICE: Found ${snapshot.docs.length} bids for request $requestId');
      return snapshot.docs.map((doc) {
        try {
          final bid = ServiceBid.fromFirestore(doc);
          print('✅ USER_TASK_SERVICE: Parsed bid ${doc.id} with price ${bid.priceQuote}');
          return bid;
        } catch (e) {
          print('❌ USER_TASK_SERVICE: Error parsing bid ${doc.id}: $e');
          rethrow;
        }
      }).toList();
    }).handleError((error) {
      print('❌ USER_TASK_SERVICE: Error in getBidsForRequest stream: $error');
    });
  }

  /// Get bidding session for a request
  static Future<BiddingSession?> getBiddingSession(String requestId) async {
    try {
      final querySnapshot = await _firestore
          .collection('bidding_sessions')
          .where('requestId', isEqualTo: requestId)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        return BiddingSession.fromFirestore(querySnapshot.docs.first);
      }
      return null;
    } catch (e) {
      print('Error getting bidding session: $e');
      return null;
    }
  }

  /// Get provider details for a bid
  /// Get user details from users collection
  static Future<Map<String, dynamic>?> getUserDetails(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists) {
        return userDoc.data();
      }
      return null;
    } catch (e) {
      print('Error getting user details: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>?> getProviderDetails(String providerId) async {
    try {
      final doc = await _firestore
          .collection('providers')
          .doc(providerId)
          .get();

      if (doc.exists) {
        return doc.data();
      }
      return null;
    } catch (e) {
      print('Error getting provider details: $e');
      return null;
    }
  }

  /// Accept a bid and close bidding session
  static Future<bool> acceptBid(String bidId, String userId) async {
    try {
      // Call the Firebase Function to accept the bid
      // This will handle updating bid status, closing other bids, and updating request status
      
      // For now, we'll implement a direct Firestore update
      // In production, this should call the accept_bid Firebase Function
      
      final bidDoc = await _firestore.collection('service_bids').doc(bidId).get();
      if (!bidDoc.exists) {
        throw Exception('Bid not found');
      }

      final bidData = bidDoc.data()!;
      final requestId = bidData['requestId'];

      // Update the winning bid
      await _firestore.collection('service_bids').doc(bidId).update({
        'bidStatus': 'accepted',
        'acceptedAt': FieldValue.serverTimestamp(),
      });

      // Update the user request
      await _firestore.collection('user_requests').doc(requestId).update({
        'status': 'assigned',
        'assignedProviderId': bidData['providerId'],
        'selectedBidId': bidId,
        'assignedAt': FieldValue.serverTimestamp(),
      });

      // Reject other bids for this request
      final otherBids = await _firestore
          .collection('service_bids')
          .where('requestId', isEqualTo: requestId)
          .where(FieldPath.documentId, isNotEqualTo: bidId)
          .get();

      final batch = _firestore.batch();
      for (final doc in otherBids.docs) {
        batch.update(doc.reference, {
          'bidStatus': 'rejected',
          'rejectedAt': FieldValue.serverTimestamp(),
          'rejectionReason': 'Another bid was selected',
        });
      }
      await batch.commit();

      return true;
    } catch (e) {
      print('Error accepting bid: $e');
      return false;
    }
  }

  /// Accept a bid with final service date and time
  static Future<bool> acceptBidWithSchedule(
    String bidId, 
    String userId, 
    DateTime serviceDateTime,
    String formattedSchedule,
  ) async {
    try {
      print('🗓️ Accepting bid with schedule: $bidId for user: $userId');
      print('🗓️ Service scheduled for: $formattedSchedule');
      
      final bidDoc = await _firestore.collection('service_bids').doc(bidId).get();
      if (!bidDoc.exists) {
        throw Exception('Bid not found');
      }

      final bidData = bidDoc.data()!;
      final requestId = bidData['requestId'];
      final providerId = bidData['providerId'];

      // Update the winning bid with final schedule
      await _firestore.collection('service_bids').doc(bidId).update({
        'bidStatus': 'accepted',
        'acceptedAt': FieldValue.serverTimestamp(),
        'finalServiceDateTime': Timestamp.fromDate(serviceDateTime),
        'finalServiceSchedule': formattedSchedule,
        'serviceDate': serviceDateTime.toIso8601String().split('T')[0], // YYYY-MM-DD
        'serviceTime': '${serviceDateTime.hour.toString().padLeft(2, '0')}:${serviceDateTime.minute.toString().padLeft(2, '0')}', // HH:MM
      });

      // Update the user request with final schedule
      await _firestore.collection('user_requests').doc(requestId).update({
        'status': 'assigned',
        'assignedProviderId': providerId,
        'selectedBidId': bidId,
        'assignedAt': FieldValue.serverTimestamp(),
        'finalServiceDateTime': Timestamp.fromDate(serviceDateTime),
        'finalServiceSchedule': formattedSchedule,
        'serviceDate': serviceDateTime.toIso8601String().split('T')[0],
        'serviceTime': '${serviceDateTime.hour.toString().padLeft(2, '0')}:${serviceDateTime.minute.toString().padLeft(2, '0')}',
      });

      // Create assigned task record for provider
      await _firestore.collection('assigned_tasks').add({
        'requestId': requestId,
        'bidId': bidId,
        'providerId': providerId,
        'userId': userId,
        'serviceCategory': bidData['serviceCategory'] ?? 'general',
        'finalServiceDateTime': Timestamp.fromDate(serviceDateTime),
        'finalServiceSchedule': formattedSchedule,
        'serviceDate': serviceDateTime.toIso8601String().split('T')[0],
        'serviceTime': '${serviceDateTime.hour.toString().padLeft(2, '0')}:${serviceDateTime.minute.toString().padLeft(2, '0')}',
        'taskStatus': 'scheduled',
        'createdAt': FieldValue.serverTimestamp(),
        'priceQuote': bidData['priceQuote'],
        'customerName': bidData['customerName'] ?? 'Customer',
        'customerPhone': bidData['customerPhone'] ?? '',
        'serviceAddress': bidData['serviceAddress'] ?? '',
      });

      // Reject other bids for this request
      final otherBids = await _firestore
          .collection('service_bids')
          .where('requestId', isEqualTo: requestId)
          .where(FieldPath.documentId, isNotEqualTo: bidId)
          .get();

      final batch = _firestore.batch();
      for (final doc in otherBids.docs) {
        batch.update(doc.reference, {
          'bidStatus': 'rejected',
          'rejectedAt': FieldValue.serverTimestamp(),
          'rejectionReason': 'Another bid was selected',
        });
      }
      await batch.commit();

      print('✅ Bid accepted with final schedule: $formattedSchedule');
      return true;
    } catch (e) {
      print('❌ Error accepting bid with schedule: $e');
      return false;
    }
  }

  /// Accept a bid with simple service time text
  static Future<bool> acceptBidWithScheduleText(
    String bidId, 
    String userId, 
    String serviceTimeText,
  ) async {
    try {
      print('🗓️ Accepting bid with service time: $bidId for user: $userId');
      print('🗓️ Service time: $serviceTimeText');
      
      final bidDoc = await _firestore.collection('service_bids').doc(bidId).get();
      if (!bidDoc.exists) {
        throw Exception('Bid not found');
      }

      final bidData = bidDoc.data()!;
      final requestId = bidData['requestId'];
      final providerId = bidData['providerId'];

      // Update the winning bid with service time
      await _firestore.collection('service_bids').doc(bidId).update({
        'bidStatus': 'accepted',
        'acceptedAt': FieldValue.serverTimestamp(),
        'finalServiceSchedule': serviceTimeText,
      });

      // Update the user request with final schedule
      await _firestore.collection('user_requests').doc(requestId).update({
        'status': 'assigned',
        'assignedProviderId': providerId,
        'selectedBidId': bidId,
        'assignedAt': FieldValue.serverTimestamp(),
        'finalServiceSchedule': serviceTimeText,
      });

      // Create assigned task record for provider
      await _firestore.collection('assigned_tasks').add({
        'requestId': requestId,
        'bidId': bidId,
        'providerId': providerId,
        'userId': userId,
        'finalServiceSchedule': serviceTimeText,
        'taskStatus': 'scheduled',
        'createdAt': FieldValue.serverTimestamp(),
        'priceQuote': bidData['priceQuote'],
      });

      // Reject other bids for this request
      final otherBids = await _firestore
          .collection('service_bids')
          .where('requestId', isEqualTo: requestId)
          .where(FieldPath.documentId, isNotEqualTo: bidId)
          .get();

      final batch = _firestore.batch();
      for (final doc in otherBids.docs) {
        batch.update(doc.reference, {
          'bidStatus': 'rejected',
          'rejectedAt': FieldValue.serverTimestamp(),
          'rejectionReason': 'Another bid was selected',
        });
      }
      await batch.commit();

      print('✅ Bid accepted with service time: $serviceTimeText');
      return true;
    } catch (e) {
      print('❌ Error accepting bid with service time: $e');
      return false;
    }
  }

  /// Get task status display info
  static Map<String, dynamic> getTaskStatusInfo(String status, {UserRequest? task}) {
    switch (status.toLowerCase()) {
      case 'pending':
        return {
          'label': 'Pending',
          'color': Colors.orange,
          'icon': Icons.hourglass_empty,
          'description': 'Looking for providers',
        };
      case 'matched':
        String description = 'Providers found';
        if (task != null) {
          // Get matched providers information from user request
          final matchedProviders = _getMatchedProvidersFromFirestore(task.requestId!);
          // For now, show count from stored field or fallback
          final providerCount = _getProviderCount(task);
          if (providerCount > 0) {
            description = '$providerCount provider${providerCount > 1 ? 's' : ''} found';
          }
        }
        return {
          'label': 'Matched',
          'color': Colors.blue,
          'icon': Icons.people,
          'description': description,
        };
      case 'bidding':
        return {
          'label': 'Waiting for quotes',
          'color': Color(0xFFFBB04C),
          'icon': Icons.gavel,
          'description': 'Receiving quotes',
        };
      case 'assigned':
        return {
          'label': 'Quote received',
          'color': Colors.green,
          'icon': Icons.check_circle,
          'description': 'Provider assigned',
        };
      case 'completed':
        return {
          'label': 'Completed',
          'color': Colors.green[700],
          'icon': Icons.done_all,
          'description': 'Task completed',
        };
      case 'cancelled':
        return {
          'label': 'Cancelled',
          'color': Colors.red,
          'icon': Icons.cancel,
          'description': 'Task cancelled',
        };
      default:
        return {
          'label': status,
          'color': Colors.grey,
          'icon': Icons.help,
          'description': 'Unknown status',
        };
    }
  }

  /// Format time remaining for bidding
  static String formatTimeRemaining(DateTime deadline) {
    final now = DateTime.now();
    final difference = deadline.difference(now);

    if (difference.isNegative) {
      return 'Expired';
    }

    if (difference.inDays > 0) {
      return '${difference.inDays}d ${difference.inHours % 24}h';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ${difference.inMinutes % 60}m';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m';
    } else {
      return 'Expires soon';
    }
  }

  /// Get provider count from user request
  static int _getProviderCount(UserRequest task) {
    // Check if matchedProviders field exists and has data
    if (task.toFirestore()['matchedProviders'] is List) {
      final matchedProviders = task.toFirestore()['matchedProviders'] as List;
      return matchedProviders.length;
    }
    
    // Fallback to matchCount field if available
    if (task.toFirestore()['matchCount'] is int) {
      return task.toFirestore()['matchCount'] as int;
    }
    
    return 0;
  }

  /// Get matched providers information from Firestore (async helper for future use)
  static Future<List<String>> _getMatchedProvidersFromFirestore(String requestId) async {
    try {
      final doc = await _firestore.collection('user_requests').doc(requestId).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        if (data['matchedProviders'] is List) {
          return List<String>.from(data['matchedProviders']);
        }
      }
      return [];
    } catch (e) {
      print('Error getting matched providers: $e');
      return [];
    }
  }

  /// Debug function to manually check a specific request status
  static Future<void> debugCheckRequestStatus(String requestId) async {
    try {
      print('🔍 DEBUG: Checking status of request $requestId');
      final doc = await _firestore.collection('user_requests').doc(requestId).get();
      
      if (doc.exists) {
        final data = doc.data()!;
        print('🔍 DEBUG: Request $requestId status: ${data['status']}');
        print('🔍 DEBUG: Full document: $data');
        
        // Also check for any bids
        final bidsQuery = await _firestore
            .collection('service_bids')
            .where('requestId', isEqualTo: requestId)
            .get();
        
        print('🔍 DEBUG: Found ${bidsQuery.docs.length} bids for request $requestId');
        for (final bidDoc in bidsQuery.docs) {
          final bidData = bidDoc.data();
          print('🔍 DEBUG: Bid ${bidDoc.id}: status=${bidData['bidStatus']}, provider=${bidData['providerId']}, price=${bidData['priceQuote']}');
        }
      } else {
        print('🔍 DEBUG: Request $requestId not found');
      }
    } catch (e) {
      print('🔍 DEBUG: Error checking request status: $e');
    }
  }
}
