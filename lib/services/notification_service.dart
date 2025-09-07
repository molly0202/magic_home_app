import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../screens/bidding/provider_bid_screen.dart';
import '../screens/bidding/bid_comparison_screen.dart';
import '../models/user_request.dart';

class NotificationService {
  static final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  static const String _adminEmail = 'molly930202@gmail.com';
  
  // Navigation callback for handling notification taps
  static Function(String notificationType, Map<String, dynamic> data)? _navigationCallback;
  
  // Set navigation callback for notification taps
  static void setNavigationCallback(Function(String notificationType, Map<String, dynamic> data) callback) {
    _navigationCallback = callback;
  }

  // Initialize FCM and register token
  static Future<void> initializeFCM() async {
    try {
      print('🔄 Starting FCM initialization...');
      
      // Request permission for iOS
      final settings = await _firebaseMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      
      print('📱 FCM Permission status: ${settings.authorizationStatus}');

      // Get FCM token
      final token = await _firebaseMessaging.getToken();
      if (token != null) {
        print('📱 FCM Token obtained: ${token.substring(0, 50)}...');
        
        // Save token later when user signs in - for now just log it
        print('⏳ Will save token when user authenticates');
      } else {
        print('❌ Failed to get FCM token');
      }

      // Listen for foreground messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        print('📱 Received foreground message: ${message.notification?.title}');
        _handleForegroundMessage(message);
      });

      // Listen for background message taps
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        print('📱 App opened from background message: ${message.notification?.title}');
        _handleMessageTap(message);
      });

      print('✅ FCM initialization completed');
    } catch (e) {
      print('❌ Error initializing FCM: $e');
      print('❌ FCM Error details: ${e.toString()}');
    }
  }

  // Save FCM token for authenticated user
  static Future<void> saveFCMTokenForUser(String userId) async {
    try {
      final token = await _firebaseMessaging.getToken();
      if (token != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .update({
          'fcmTokens': FieldValue.arrayUnion([token]),
          'lastTokenUpdate': FieldValue.serverTimestamp(),
        });
        print('✅ FCM token saved for user: $userId');
      }
    } catch (e) {
      print('❌ Error saving FCM token: $e');
    }
  }

  static void _handleForegroundMessage(RemoteMessage message) {
    // Handle foreground notifications - could show in-app notification
    final data = message.data;
    if (data['type'] == 'new_bid_received') {
      print('📱 New bid notification received in foreground');
      // The in-app notification service will handle this
    }
  }

  static void _handleMessageTap(RemoteMessage message) {
    // Handle when user taps on notification
    final data = message.data;
    if (data['type'] == 'new_bid_received' && _navigationCallback != null) {
      _navigationCallback!('new_bid_received', data);
    }
  }

  // Stream to listen for provider status changes
  static Stream<DocumentSnapshot> getProviderStatusStream(String providerId) {
    return FirebaseFirestore.instance
        .collection('providers')
        .doc(providerId)
        .snapshots();
  }

  // Listen for status changes and show notifications
  static void listenForStatusChanges(String providerId, BuildContext context) {
    String? lastKnownStatus;
    
    getProviderStatusStream(providerId).listen((snapshot) {
      if (snapshot.exists) {
        final data = snapshot.data() as Map<String, dynamic>;
        final currentStatus = data['status'] as String?;
        final statusUpdatedAt = data['statusUpdatedAt'] as Timestamp?;
        
        // Only process if this is a real status change
        if (currentStatus != null && currentStatus != lastKnownStatus) {
          // Additional check: only trigger for recent status updates (within last 30 seconds)
          final now = DateTime.now();
          final statusUpdateTime = statusUpdatedAt?.toDate();
          final isRecentStatusUpdate = statusUpdateTime != null && 
              now.difference(statusUpdateTime).inSeconds <= 30;
          
          // Check if status changed to verified/active
          if ((currentStatus == 'verified' || currentStatus == 'active') && 
              lastKnownStatus != null && 
              lastKnownStatus != 'verified' && 
              lastKnownStatus != 'active' &&
              isRecentStatusUpdate) {
            _showVerificationSuccessNotification(context, data);
            _sendVerificationEmailToProvider(data);
          }
          
          // Check if status changed to rejected
          if (currentStatus == 'rejected' && 
              lastKnownStatus != null && 
              lastKnownStatus != 'rejected' &&
              isRecentStatusUpdate) {
            _showRejectionNotification(context, data);
            _sendRejectionEmailToProvider(data);
          }
          
          // Update the last known status
          lastKnownStatus = currentStatus;
        } else if (lastKnownStatus == null) {
          // First time loading - just record the current status without notifications
          lastKnownStatus = currentStatus;
        }
      }
    });
  }

  // Show in-app notification for verification success
  static void _showVerificationSuccessNotification(BuildContext context, Map<String, dynamic> providerData) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Account Verified! 🎉',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const Text(
                    'You can now start accepting service requests',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 8),
        action: SnackBarAction(
          label: 'View',
          textColor: Colors.white,
          onPressed: () {
            // Navigate to dashboard or show more details
            _showVerificationDetailsDialog(context, providerData);
          },
        ),
      ),
    );
  }

  // Show in-app notification for rejection
  static void _showRejectionNotification(BuildContext context, Map<String, dynamic> providerData) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Application Update',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const Text(
                    'Please check your email for details',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 8),
        action: SnackBarAction(
          label: 'Contact Support',
          textColor: Colors.white,
          onPressed: () {
            _contactSupport();
          },
        ),
      ),
    );
  }

  // Show detailed verification success dialog
  static void _showVerificationDetailsDialog(BuildContext context, Map<String, dynamic> providerData) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.verified, color: Colors.green, size: 28),
            const SizedBox(width: 8),
            const Text('Account Verified!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Congratulations, ${providerData['companyName'] ?? 'Provider'}!',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              'Your Magic Home provider account has been successfully verified. You can now:',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 12),
            const Text('• Accept service requests from customers'),
            const Text('• Set your availability and pricing'),
            const Text('• Manage your bookings and schedule'),
            const Text('• Access your earnings dashboard'),
            const SizedBox(height: 16),
            const Text(
              'A confirmation email has been sent to your registered email address.',
              style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it!'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Navigate to dashboard or start accepting requests
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFBB04C),
              foregroundColor: Colors.white,
            ),
            child: const Text('Start Accepting Requests'),
          ),
        ],
      ),
    );
  }

  // Send verification success email to provider
  static Future<void> _sendVerificationEmailToProvider(Map<String, dynamic> providerData) async {
    try {
      final providerEmail = providerData['email'];
      final companyName = providerData['companyName'] ?? 'Provider';
      final providerId = providerData['uid'];
      
      final subject = Uri.encodeComponent('🎉 Welcome to Magic Home! Your account has been verified');
      final body = Uri.encodeComponent('''
Dear ${companyName},

🎉 Congratulations! Your Magic Home provider account has been successfully verified.

You can now start accepting service requests from customers and begin earning with Magic Home.

What's next:
• Set your availability and service areas
• Configure your pricing and services
• Start receiving and accepting customer requests
• Manage your bookings through the app

If you have any questions or need assistance, please don't hesitate to contact our support team.

Welcome to the Magic Home family!

Best regards,
The Magic Home Team
      ''');
      
      final mailtoUrl = 'mailto:$providerEmail?subject=$subject&body=$body';
      final uri = Uri.parse(mailtoUrl);
      
      // Store notification in Firestore for tracking
      await FirebaseFirestore.instance
          .collection('provider_notifications')
          .add({
        'providerId': providerId,
        'to': providerEmail,
        'subject': 'Account Verified - Welcome to Magic Home!',
        'message': body,
        'companyName': companyName,
        'status': 'verified',
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'verification_success',
      });
      
      print('Verification success email prepared for $providerEmail');
      
    } catch (e) {
      print('Error sending verification email: $e');
    }
  }

  // Send rejection email to provider
  static Future<void> _sendRejectionEmailToProvider(Map<String, dynamic> providerData) async {
    try {
      final providerEmail = providerData['email'];
      final companyName = providerData['companyName'] ?? 'Provider';
      final providerId = providerData['uid'];
      
      final subject = Uri.encodeComponent('Magic Home Application Update');
      final body = Uri.encodeComponent('''
Dear ${companyName},

Thank you for your interest in becoming a Magic Home service provider.

After careful review of your application and submitted documents, we regret to inform you that we cannot approve your application at this time.

This decision may be due to:
• Incomplete or unclear documentation
• Business license or insurance requirements not met
• Other verification criteria not satisfied

If you believe this decision was made in error or if you would like to reapply with updated documentation, please contact our support team.

We appreciate your interest in Magic Home and wish you the best in your future endeavors.

Best regards,
The Magic Home Team
      ''');
      
      // Store notification in Firestore for tracking
      await FirebaseFirestore.instance
          .collection('provider_notifications')
          .add({
        'providerId': providerId,
        'to': providerEmail,
        'subject': 'Magic Home Application Update',
        'message': body,
        'companyName': companyName,
        'status': 'rejected',
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'application_rejection',
      });
      
      print('Rejection email prepared for $providerEmail');
      
    } catch (e) {
      print('Error sending rejection email: $e');
    }
  }

  // Contact support function
  static Future<void> _contactSupport() async {
    try {
      final subject = Uri.encodeComponent('Magic Home Provider Support Request');
      final body = Uri.encodeComponent('''
Hello Magic Home Support Team,

I need assistance with my provider application.

[Please provide details about your issue here]

Thank you.
      ''');
      
      final mailtoUrl = 'mailto:$_adminEmail?subject=$subject&body=$body';
      final uri = Uri.parse(mailtoUrl);
      
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        print('Could not open mail app');
      }
    } catch (e) {
      print('Error opening mail app: $e');
    }
  }

  // Manual status update function (for admin use)
  static Future<void> updateProviderStatus(String providerId, String newStatus) async {
    try {
      // Get current status
      final currentDoc = await FirebaseFirestore.instance
          .collection('providers')
          .doc(providerId)
          .get();
      
      if (!currentDoc.exists) {
        throw Exception('Provider not found');
      }
      
      final currentData = currentDoc.data()!;
      final currentStatus = currentData['status'] as String?;
      
      // Only update if status actually changed
      if (currentStatus != newStatus) {
        // Update status with proper timestamp for notification detection
        await FirebaseFirestore.instance
            .collection('providers')
            .doc(providerId)
            .update({
          'status': newStatus,
          'previousStatus': currentStatus,
          'statusUpdatedAt': FieldValue.serverTimestamp(),
          'reviewedBy': 'admin', // In production, use actual admin user ID
        });
        
        print('Provider status updated: $providerId -> $newStatus (from $currentStatus)');
      } else {
        print('Provider status unchanged: $providerId already has status $newStatus');
      }
      
    } catch (e) {
      print('Error updating provider status: $e');
      throw e;
    }
  }

  // Get notification history for a provider
  static Stream<QuerySnapshot> getNotificationHistory(String providerId) {
    return FirebaseFirestore.instance
        .collection('provider_notifications')
        .where('providerId', isEqualTo: providerId)
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  // Initialize Push Notifications
  static Future<void> initializePushNotifications(String providerId) async {
    try {
      print('🚀 Starting push notification initialization for provider: $providerId');
      
      // Request permission from user
      NotificationSettings settings = await _firebaseMessaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        print('✅ User granted permission for push notifications');
        
        // For iOS, we need to wait for APNS token to be available
        if (Platform.isIOS) {
          print('📱 Waiting for APNS token (iOS)...');
          String? apnsToken = await _firebaseMessaging.getAPNSToken();
          print('📱 First APNS attempt: ${apnsToken != null ? "SUCCESS" : "FAILED"}');
          
          if (apnsToken != null) {
            print('📱 APNS Token received: ${apnsToken.substring(0, 20)}...');
          } else {
            print('⚠️  APNS token not immediately available, will retry in 3 seconds...');
            // Wait a bit and try again
            await Future.delayed(const Duration(seconds: 3));
            apnsToken = await _firebaseMessaging.getAPNSToken();
            print('📱 Second APNS attempt: ${apnsToken != null ? "SUCCESS" : "FAILED"}');
            
            if (apnsToken != null) {
              print('📱 APNS Token received after retry: ${apnsToken.substring(0, 20)}...');
            } else {
              print('❌ APNS Token STILL not available after retry!');
              print('❌ This indicates Push Notifications capability issue in Xcode');
              // Don't return here, let's try to get FCM token anyway
            }
          }
        }
        
        // Now get the FCM token
        print('🔑 Getting FCM token...');
        String? fcmToken = await _firebaseMessaging.getToken();
        if (fcmToken != null) {
          print('🔑 FCM Token received: ${fcmToken.substring(0, 50)}...');
          // Save the token to Firestore
          await _saveTokenToDatabase(providerId, fcmToken);
        } else {
          print('❌ Failed to get FCM token');
        }

        // Listen for token refresh
        _firebaseMessaging.onTokenRefresh.listen((newToken) {
          print('🔄 FCM token refreshed: ${newToken.substring(0, 50)}...');
          _saveTokenToDatabase(providerId, newToken);
        });
      } else {
        print('❌ User declined or has not accepted permission: ${settings.authorizationStatus}');
      }
    } catch (e) {
      print('❌ Error initializing push notifications: $e');
    }
    
      // Handle foreground messages
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    print('Got a message whilst in the foreground!');
    print('Message data: ${message.data}');

    if (message.notification != null) {
      print('Message also contained a notification: ${message.notification}');
      
      // Handle different notification types
      final notificationType = message.data['type'];
      if (notificationType == 'status_update') {
        _handleStatusUpdateNotification(message);
      } else if (notificationType == 'bidding_opportunity') {
        _handleBiddingNotification(message);
      } else if (notificationType == 'test_notification') {
        _handleTestNotification(message);
      } else {
        // Handle any other notification types
        _handleGenericNotification(message);
      }
    }
  });

  // Handle background message taps (when app is in background but not terminated)
  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    print('A new onMessageOpenedApp event was published!');
    _handleNotificationTap(message);
  });

  // Check if app was opened from a terminated state due to notification
  FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
    if (message != null) {
      print('App opened from terminated state via notification');
      _handleNotificationTap(message);
    }
  });
  }

  // Save FCM token to the provider's document
  static Future<void> _saveTokenToDatabase(String providerId, String token) async {
    try {
      print('🔐 Starting FCM token save process...');
      print('Provider ID: $providerId');
      print('FCM Token: $token');
      
      // First check if the provider document exists
      final docRef = FirebaseFirestore.instance.collection('providers').doc(providerId);
      final docSnapshot = await docRef.get();
      
      if (!docSnapshot.exists) {
        print('⚠️  Provider document does not exist! Creating with FCM token...');
        // Create the document with basic fields and FCM token
        await docRef.set({
          'fcmTokens': [token],
          'createdAt': FieldValue.serverTimestamp(),
          'status': 'pending',
        });
        print('✅ Created new provider document with FCM token');
      } else {
        print('📄 Provider document exists, adding FCM token...');
        // Use set with merge to add the FCM token
        await docRef.set({
          'fcmTokens': FieldValue.arrayUnion([token]),
          'lastTokenUpdate': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        print('✅ Added FCM token to existing provider document');
      }
      
      // Verify the token was saved
      final updatedDoc = await docRef.get();
      if (updatedDoc.exists) {
        final data = updatedDoc.data()!;
        final tokens = data['fcmTokens'] as List<dynamic>?;
        print('🔍 Verification: Document now has ${tokens?.length ?? 0} FCM token(s)');
        if (tokens != null) {
          print('🔍 Tokens: $tokens');
        }
      }
      
    } catch (e) {
      print('❌ Error saving FCM token to database: $e');
      print('Stack trace: ${StackTrace.current}');
    }
  }

  // Handle bidding opportunity notifications
  static void _handleBiddingNotification(RemoteMessage message) {
    print('🎯 Bidding opportunity received!');
    
    // Extract notification details
    final title = message.notification?.title ?? 'New Service Opportunity';
    final body = message.notification?.body ?? 'A new bidding opportunity is available';
    final urgency = message.data['urgency'] ?? 'normal';
    final requestId = message.data['request_id'];
    final notificationType = message.data['type'];
    
    print('🎯 Title: $title');
    print('🎯 Body: $body');
    print('🎯 Urgency: $urgency');
    print('🎯 Request ID: $requestId');
    print('🎯 Type: $notificationType');
    
    // Store notification data for later navigation if user taps
    // This will be handled by _handleNotificationTap
    print('🎯 Bidding notification handled - ready for navigation on tap');
  }

  // Handle test notifications
  static void _handleTestNotification(RemoteMessage message) {
    print('🧪 Test notification received!');
    final title = message.notification?.title ?? 'Test';
    final body = message.notification?.body ?? 'Test notification';
    print('🧪 Title: $title');
    print('🧪 Body: $body');
  }

  // Handle generic notifications
  static void _handleGenericNotification(RemoteMessage message) {
    print('📬 Generic notification received!');
    final title = message.notification?.title ?? 'Notification';
    final body = message.notification?.body ?? 'You have a new notification';
    print('📬 Title: $title');
    print('📬 Body: $body');
  }

  // Handle status update notifications when app is in foreground
  static void _handleStatusUpdateNotification(RemoteMessage message) {
    final status = message.data['status'];
    final providerId = message.data['provider_id'];
    
    if (status == 'verified' || status == 'active') {
      _showForegroundVerificationNotification(message);
    } else if (status == 'rejected') {
      _showForegroundRejectionNotification(message);
    }
  }

  // Handle notification tap (from background or terminated state)
  static void _handleNotificationTap(RemoteMessage message) {
    final notificationType = message.data['type'];
    final status = message.data['status'];
    final providerId = message.data['provider_id'];
    final requestId = message.data['request_id'];
    final userId = message.data['user_id'];

    print('🔔 Notification tapped: $notificationType');
    
    // Call navigation callback if set
    if (_navigationCallback != null) {
      _navigationCallback!(notificationType, message.data);
      return;
    }

    // Fallback navigation (for debugging)
    if (notificationType == 'status_update') {
      if (status == 'verified' || status == 'active') {
        print('📱 Would navigate to provider dashboard due to verification success');
      } else if (status == 'rejected') {
        print('📱 Would navigate to help/support due to application rejection');
      }
    } else if (notificationType == 'bidding_opportunity') {
      print('📱 Would navigate to bidding screen for request: $requestId');
    } else if (notificationType == 'new_bid_received') {
      print('📱 Would navigate to bid comparison screen for request: $requestId');
    } else if (notificationType == 'bid_result') {
      final isWinner = message.data['is_winner'] == 'true';
      if (isWinner) {
        print('📱 Would navigate to job details screen - bid accepted!');
      } else {
        print('📱 Would navigate to provider dashboard - bid not selected');
      }
    }
  }

  // Show foreground notification for verification success
  static void _showForegroundVerificationNotification(RemoteMessage message) {
    // This would typically use an overlay or dialog service
    // For now, we'll use a simple print statement
    print('🎉 FOREGROUND NOTIFICATION: Account Verified!');
    print('You can now start accepting service requests.');
    
    // In a real implementation, you could show a banner notification
    // or update the app's badge/notification icon
  }

  // Show foreground notification for rejection
  static void _showForegroundRejectionNotification(RemoteMessage message) {
    print('❌ FOREGROUND NOTIFICATION: Application Update');
    print('Please check your email for details about your application.');
  }

  // Test notification function for admins
  static Future<String> sendTestNotification(String providerId, String testStatus) async {
    try {
      // Get provider data
      final providerDoc = await FirebaseFirestore.instance
          .collection('providers')
          .doc(providerId)
          .get();
      
      if (!providerDoc.exists) {
        return 'Error: Provider not found';
      }
      
      final providerData = providerDoc.data()!;
      final fcmTokens = providerData['fcmTokens'] as List<dynamic>?;
      
      if (fcmTokens == null || fcmTokens.isEmpty) {
        return 'Error: No FCM tokens found for provider';
      }
      
      // Create test notification data
      final notificationData = {
        'type': 'test_notification',
        'status': testStatus,
        'provider_id': providerId,
        'timestamp': DateTime.now().toIso8601String(),
      };
      
      // Store notification for testing
      await FirebaseFirestore.instance
          .collection('test_notifications')
          .add({
        'providerId': providerId,
        'testStatus': testStatus,
        'fcmTokenCount': fcmTokens.length,
        'data': notificationData,
        'timestamp': FieldValue.serverTimestamp(),
      });
      
      return 'Test notification prepared for ${fcmTokens.length} tokens';
      
    } catch (e) {
      return 'Error: $e';
    }
  }

  // Get provider's current notification settings
  static Future<Map<String, dynamic>> getNotificationSettings(String providerId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('providers')
          .doc(providerId)
          .get();
      
      if (!doc.exists) {
        return {'error': 'Provider not found'};
      }
      
      final data = doc.data()!;
      return {
        'fcmTokens': data['fcmTokens'] ?? [],
        'notificationEnabled': data['notificationEnabled'] ?? true,
        'emailNotificationEnabled': data['emailNotificationEnabled'] ?? true,
        'status': data['status'] ?? 'unknown',
      };
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  // Update notification preferences
  static Future<void> updateNotificationSettings(String providerId, {
    bool? pushNotifications,
    bool? emailNotifications,
  }) async {
    try {
      final updateData = <String, dynamic>{};
      
      if (pushNotifications != null) {
        updateData['notificationEnabled'] = pushNotifications;
      }
      if (emailNotifications != null) {
        updateData['emailNotificationEnabled'] = emailNotifications;
      }
      
      if (updateData.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('providers')
            .doc(providerId)
            .update(updateData);
      }
    } catch (e) {
      print('Error updating notification settings: $e');
    }
  }
} 