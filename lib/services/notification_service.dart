import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class NotificationService {
  static final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  static const String _adminEmail = 'molly930202@gmail.com';
  
  // Stream to listen for provider status changes
  static Stream<DocumentSnapshot> getProviderStatusStream(String providerId) {
    return FirebaseFirestore.instance
        .collection('providers')
        .doc(providerId)
        .snapshots();
  }

  // Listen for status changes and show notifications
  static void listenForStatusChanges(String providerId, BuildContext context) {
    getProviderStatusStream(providerId).listen((snapshot) {
      if (snapshot.exists) {
        final data = snapshot.data() as Map<String, dynamic>;
        final status = data['status'] as String?;
        final previousStatus = data['previousStatus'] as String?;
        
        // Check if status changed to verified/active
        if (status == 'verified' || status == 'active') {
          if (previousStatus != 'verified' && previousStatus != 'active') {
            _showVerificationSuccessNotification(context, data);
            _sendVerificationEmailToProvider(data);
          }
        }
        
        // Check if status changed to rejected
        if (status == 'rejected') {
          if (previousStatus != 'rejected') {
            _showRejectionNotification(context, data);
            _sendRejectionEmailToProvider(data);
          }
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
      
      // Update status with previous status tracking
      await FirebaseFirestore.instance
          .collection('providers')
          .doc(providerId)
          .update({
        'status': newStatus,
        'previousStatus': currentStatus,
        'statusUpdatedAt': FieldValue.serverTimestamp(),
        'reviewedBy': 'admin', // In production, use actual admin user ID
      });
      
      print('Provider status updated: $providerId -> $newStatus');
      
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
      print('User granted permission for push notifications');
      // Get the FCM token
      String? fcmToken = await _firebaseMessaging.getToken();
      if (fcmToken != null) {
        print('FCM Token: $fcmToken');
        // Save the token to Firestore
        await _saveTokenToDatabase(providerId, fcmToken);
      }

      // Listen for token refresh
      _firebaseMessaging.onTokenRefresh.listen((newToken) {
        _saveTokenToDatabase(providerId, newToken);
      });
    } else {
      print('User declined or has not accepted permission');
    }
    
    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Got a message whilst in the foreground!');
      print('Message data: ${message.data}');

      if (message.notification != null) {
        print('Message also contained a notification: ${message.notification}');
        // Here you could show an in-app notification dialog or snackbar
        // For now, we'll just print it.
      }
    });
  }

  // Save FCM token to the provider's document
  static Future<void> _saveTokenToDatabase(String providerId, String token) async {
    try {
      await FirebaseFirestore.instance
          .collection('providers')
          .doc(providerId)
          .update({
        'fcmTokens': FieldValue.arrayUnion([token]),
      });
    } catch (e) {
      print('Error saving FCM token to database: $e');
    }
  }
} 