import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/provider_stats.dart';
import '../models/service_order.dart';
import '../models/user_request.dart';

class HspHomeService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get provider stats
  static Future<ProviderStats> getProviderStats(String providerId) async {
    try {
      // Get current month's start date
      final now = DateTime.now();
      final monthStart = DateTime(now.year, now.month, 1);

      // Get all orders for this provider
      final ordersQuery = await _firestore
          .collection('service_orders')
          .where('provider_id', isEqualTo: providerId)
          .get();

      int totalTasks = ordersQuery.docs.length;
      double totalEarned = 0.0;
      int tasksThisMonth = 0;
      int completedTasks = 0;
      int pendingTasks = 0;
      double totalRating = 0.0;
      int ratingCount = 0;

      for (var doc in ordersQuery.docs) {
        final data = doc.data();
        final price = data['final_price'] as double? ?? 0.0;
        final scheduledTime = (data['scheduled_time'] as Timestamp).toDate();
        final status = data['status'] as String? ?? '';
        final rating = data['rating'] as double?;
        
        totalEarned += price;
        
        // Check if task is from current month
        if (scheduledTime.isAfter(monthStart)) {
          tasksThisMonth++;
        }
        
        // Count by status
        if (status == 'completed') {
          completedTasks++;
        } else if (status == 'confirmed' || status == 'in_progress') {
          pendingTasks++;
        }
        
        // Calculate average rating
        if (rating != null) {
          totalRating += rating;
          ratingCount++;
        }
      }

      final averageRating = ratingCount > 0 ? totalRating / ratingCount : 0.0;

      return ProviderStats(
        tasksThisMonth: tasksThisMonth,
        totalTasks: totalTasks,
        totalEarned: totalEarned,
        averageRating: averageRating,
        completedTasks: completedTasks,
        pendingTasks: pendingTasks,
      );
    } catch (e) {
      print('Error getting provider stats: $e');
      return ProviderStats();
    }
  }

  // Get upcoming tasks (assigned requests with finalServiceSchedule)
  static Stream<List<UserRequest>> getUpcomingTasks(String providerId) {
    return _firestore
        .collection('user_requests')
        .where('assignedProviderId', isEqualTo: providerId)
        .where('status', isEqualTo: 'assigned')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          final now = DateTime.now();
          
          // Filter and sort by finalServiceSchedule
          final upcomingTasks = snapshot.docs
              .map((doc) => UserRequest.fromFirestore(doc))
              .where((task) {
                // Only include tasks with a finalServiceSchedule
                if (task.finalServiceSchedule == null || task.finalServiceSchedule!.isEmpty) {
                  return false;
                }
                
                // Try to parse the finalServiceSchedule to check if it's in the future
                try {
                  final scheduleTime = DateTime.parse(task.finalServiceSchedule!);
                  return scheduleTime.isAfter(now);
                } catch (e) {
                  // If we can't parse the date, include it anyway
                  return true;
                }
              })
              .toList();
          
          // Sort by finalServiceSchedule (earliest first)
          upcomingTasks.sort((a, b) {
            try {
              final timeA = DateTime.parse(a.finalServiceSchedule!);
              final timeB = DateTime.parse(b.finalServiceSchedule!);
              return timeA.compareTo(timeB);
            } catch (e) {
              // If parsing fails, maintain original order
              return 0;
            }
          });
          
          return upcomingTasks;
        });
  }

  // Get pending requests (user requests that haven't been converted to orders)
  static Stream<List<UserRequest>> getPendingRequests(String providerId) {
    return _firestore
        .collection('user_requests')
        .where('status', whereIn: ['pending', 'bidding'])
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.where((doc) {
            final data = doc.data();
            final status = data['status'] ?? '';
            
            // Include regular pending requests
            if (status == 'pending') return true;
            
            // Include bidding requests only if this provider is in the bidding list
            if (status == 'bidding') {
              final biddingProviders = List<String>.from(data['bidding_providers'] ?? []);
              return biddingProviders.contains(providerId);
            }
            
            return false;
          }).map((doc) {
            return UserRequest.fromFirestore(doc);
          }).toList();
        });
  }

  // Accept a user request (create a service order)
  static Future<void> acceptServiceRequest(
    String requestId,
    String providerId,
    double finalPrice,
    DateTime scheduledTime,
    String confirmedAddress,
  ) async {
    try {
      // Get the user request
      final requestDoc = await _firestore
          .collection('user_requests')
          .doc(requestId)
          .get();

      if (!requestDoc.exists) {
        throw Exception('User request not found');
      }

      final userRequest = UserRequest.fromFirestore(requestDoc);

      // Create a new service order
      await _firestore.collection('service_orders').add({
        'request_id': requestId,
        'provider_id': providerId,
        'user_id': userRequest.userId,
        'final_price': finalPrice,
        'scheduled_time': Timestamp.fromDate(scheduledTime),
        'confirmed_address': confirmedAddress,
        'status': 'confirmed',
        'service_description': userRequest.description,
        'customer_name': '', // Will be loaded from user profile if needed
        'customer_photo_url': '', // Will be loaded from user profile if needed
        'created_at': FieldValue.serverTimestamp(),
      });

      // Update the user request status
      await _firestore
          .collection('user_requests')
          .doc(requestId)
          .update({
        'status': 'accepted',
        'accepted_by': providerId,
        'accepted_at': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error accepting service request: $e');
      rethrow;
    }
  }

  // Update order status
  static Future<void> updateOrderStatus(String orderId, String status) async {
    try {
      await _firestore
          .collection('service_orders')
          .doc(orderId)
          .update({
        'status': status,
        'updated_at': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating order status: $e');
      rethrow;
    }
  }

  // Submit quote (placeholder for now)
  static Future<void> submitQuote({
    required String requestId,
    required double price,
    required String scheduledDate,
    required String address,
  }) async {
    // TODO: Implement quote submission logic
    print('Quote submitted: \$${price} for request ${requestId}');
    // This would integrate with the bidding system
    throw UnimplementedError('Quote submission not yet implemented - use bidding system instead');
  }

  // Get assigned tasks (user requests with status 'assigned' to this provider)
  static Stream<List<UserRequest>> getAssignedTasks(String providerId) {
    return _firestore
        .collection('user_requests')
        .where('status', isEqualTo: 'assigned')
        .where('assignedProviderId', isEqualTo: providerId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return UserRequest.fromFirestore(doc);
      }).toList();
    });
  }

  // Get completed tasks for a provider
  static Stream<List<ServiceOrder>> getCompletedTasks(String providerId) {
    return _firestore
        .collection('service_orders')
        .where('provider_id', isEqualTo: providerId)
        .where('status', isEqualTo: 'completed')
        .orderBy('created_at', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();
            return ServiceOrder.fromMap(doc.id, data);
          }).toList();
        });
  }
} 