import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/service_bid.dart';
import '../models/user_request.dart';
import '../widgets/new_quote_notification.dart';
import 'dart:developer' as developer;

class InAppNotificationService {
  static final InAppNotificationService _instance = InAppNotificationService._internal();
  factory InAppNotificationService() => _instance;
  InAppNotificationService._internal();

  // Global overlay entry for notifications
  OverlayEntry? _currentNotificationOverlay;
  
  // Keep track of shown notifications to avoid duplicates
  final Set<String> _shownNotifications = <String>{};

  // Initialize the service and start listening for new bids
  void initialize(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _listenForNewQuotes(user.uid, context);
    }
  }

  // Listen for new bids/quotes for the current user
  void _listenForNewQuotes(String userId, BuildContext context) {
    developer.log('🔔 Starting to listen for new quotes for user: $userId');
    
    // Listen to service_bids collection for new bids
    FirebaseFirestore.instance
        .collection('service_bids')
        .where('userId', isEqualTo: userId)
        .where('bidStatus', isEqualTo: 'pending')
        .snapshots()
        .listen((snapshot) {
      
      for (final change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final bid = ServiceBid.fromFirestore(change.doc);
          final bidId = change.doc.id;
          
          // Check if we've already shown this notification
          if (!_shownNotifications.contains(bidId)) {
            _shownNotifications.add(bidId);
            developer.log('🔔 New quote detected: $bidId from provider ${bid.providerId}');
            
            // Get the user request details
            _getUserRequestAndShowNotification(bid, context);
          }
        }
      }
    }, onError: (error) {
      developer.log('❌ Error listening for new quotes: $error');
    });
  }

  // Get user request details and show notification
  Future<void> _getUserRequestAndShowNotification(ServiceBid bid, BuildContext context) async {
    try {
      final requestDoc = await FirebaseFirestore.instance
          .collection('user_requests')
          .doc(bid.requestId)
          .get();
      
      if (requestDoc.exists) {
        final userRequest = UserRequest.fromFirestore(requestDoc);
        _showNewQuoteNotification(bid, userRequest, context);
      }
    } catch (e) {
      developer.log('❌ Error fetching user request for notification: $e');
    }
  }

  // Show the in-app notification
  void _showNewQuoteNotification(ServiceBid bid, UserRequest userRequest, BuildContext context) {
    // Dismiss any existing notification first
    _dismissCurrentNotification();

    final overlay = Overlay.of(context);
    _currentNotificationOverlay = OverlayEntry(
      builder: (context) => NewQuoteNotification(
        bid: bid,
        userRequest: userRequest,
        onDismiss: _dismissCurrentNotification,
      ),
    );

    overlay.insert(_currentNotificationOverlay!);
    developer.log('🔔 Showing in-app notification for quote from provider ${bid.providerId}');

    // Send push notification as well
    _sendPushNotification(bid, userRequest);
  }

  // Dismiss current notification
  void _dismissCurrentNotification() {
    _currentNotificationOverlay?.remove();
    _currentNotificationOverlay = null;
  }

  // Send push notification for new quote
  Future<void> _sendPushNotification(ServiceBid bid, UserRequest userRequest) async {
    try {
      // This would typically be handled by your backend/Firebase Functions
      // For now, we'll just log it
      developer.log('📱 Would send push notification: New quote from provider ${bid.providerId} for \$${bid.priceQuote.toInt()}');
      
      // In a real implementation, you'd call a Firebase Function here:
      /*
      await FirebaseFirestore.instance.collection('push_notifications').add({
        'userId': userRequest.userId,
        'type': 'new_quote',
        'title': 'New Quote Received!',
                  'body': 'You received a quote for \$${bid.priceQuote.toInt()} from provider ${bid.providerId}',
        'data': {
          'bidId': bid.bidId,
          'requestId': userRequest.requestId,
          'providerId': bid.providerId,
          'priceQuote': bid.priceQuote,
        },
        'timestamp': FieldValue.serverTimestamp(),
      });
      */
    } catch (e) {
      developer.log('❌ Error sending push notification: $e');
    }
  }

  // Manually trigger a test notification (for debugging)
  void showTestNotification(BuildContext context) {
    final testBid = ServiceBid(
      bidId: 'test_bid_${DateTime.now().millisecondsSinceEpoch}',
      requestId: 'test_request',
      providerId: 'test_provider',
      userId: FirebaseAuth.instance.currentUser?.uid ?? '',
      priceQuote: 150.0,
      availability: 'Available this weekend',
      bidMessage: 'Test quote for your service request',
      bidStatus: 'pending',
      createdAt: DateTime.now(),
      expiresAt: DateTime.now().add(const Duration(hours: 2)),
      priceBenchmark: 'normal',
    );

    final testUserRequest = UserRequest(
      requestId: 'test_request',
      userId: FirebaseAuth.instance.currentUser?.uid ?? '',
      serviceCategory: 'handyman',
      description: 'Test service request',
      mediaUrls: [],
      userAvailability: {},
      address: 'Test Address',
      phoneNumber: '555-0123',
      location: null,
      preferences: {},
      createdAt: DateTime.now(),
      status: 'bidding',
      tags: [],
      priority: 3,
    );

    _showNewQuoteNotification(testBid, testUserRequest, context);
  }

  // Clear notification history (for testing)
  void clearNotificationHistory() {
    _shownNotifications.clear();
    developer.log('🔔 Cleared notification history');
  }
}
