import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/provider_stats.dart';
import '../models/service_order.dart';
import '../models/service_request.dart';

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

  // Get upcoming tasks (scheduled orders)
  static Stream<List<ServiceOrder>> getUpcomingTasks(String providerId) {
    final now = DateTime.now();
    
    return _firestore
        .collection('service_orders')
        .where('provider_id', isEqualTo: providerId)
        .where('status', whereIn: ['confirmed', 'in_progress'])
        .where('scheduled_time', isGreaterThan: Timestamp.fromDate(now))
        .orderBy('scheduled_time')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();
            return ServiceOrder(
              orderId: doc.id,
              requestId: data['request_id'] ?? '',
              providerId: data['provider_id'] ?? '',
              userId: data['user_id'] ?? '',
              finalPrice: (data['final_price'] ?? 0.0).toDouble(),
              scheduledTime: (data['scheduled_time'] as Timestamp).toDate(),
              confirmedAddress: data['confirmed_address'] ?? '',
              status: data['status'] ?? '',
              serviceDescription: data['service_description'],
              customerName: data['customer_name'],
              customerPhotoUrl: data['customer_photo_url'],
            );
          }).toList();
        });
  }

  // Get pending requests (service requests that haven't been converted to orders)
  static Stream<List<ServiceRequest>> getPendingRequests(String providerId) {
    return _firestore
        .collection('service_requests')
        .where('status', isEqualTo: 'pending')
        .orderBy('created_at', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();
            return ServiceRequest(
              category: data['category'] ?? 'general',
              description: data['description'] ?? '',
              details: Map<String, dynamic>.from(data['details'] ?? {
                'preferred_time': data['preferred_time'],
                'location_masked': data['location_masked'],
                'final_address': data['final_address'],
                'status': data['status'],
                'price_range': data['price_range'],
                'customer_name': data['customer_name'],
                'customer_photo_url': data['customer_photo_url'],
              }),
              mediaUrls: List<String>.from(data['media_urls'] ?? []),
              location: data['location'],
              contactInfo: data['contact_info'],
              pricing: data['pricing'] != null ? Map<String, dynamic>.from(data['pricing']) : null,
              availability: data['availability'] != null ? 
                Map<String, dynamic>.from(data['availability']) : 
                {'preferredTime': data['preferred_time'] ?? 'Not specified'},
              tags: List<String>.from(data['tags'] ?? []),
              priority: data['priority'],
              createdAt: (data['created_at'] as Timestamp).toDate(),
              userId: data['user_id'] ?? '',
              requestId: doc.id,
            );
          }).toList();
        });
  }

  // Accept a service request (create a service order)
  static Future<void> acceptServiceRequest(
    String requestId,
    String providerId,
    double finalPrice,
    DateTime scheduledTime,
    String confirmedAddress,
  ) async {
    try {
      // Get the service request
      final requestDoc = await _firestore
          .collection('service_requests')
          .doc(requestId)
          .get();

      if (!requestDoc.exists) {
        throw Exception('Service request not found');
      }

      final requestData = requestDoc.data()!;

      // Create a new service order
      await _firestore.collection('service_orders').add({
        'request_id': requestId,
        'provider_id': providerId,
        'user_id': requestData['user_id'],
        'final_price': finalPrice,
        'scheduled_time': Timestamp.fromDate(scheduledTime),
        'confirmed_address': confirmedAddress,
        'status': 'confirmed',
        'service_description': requestData['description'],
        'customer_name': requestData['customer_name'],
        'customer_photo_url': requestData['customer_photo_url'],
        'created_at': FieldValue.serverTimestamp(),
      });

      // Update the service request status
      await _firestore
          .collection('service_requests')
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
} 