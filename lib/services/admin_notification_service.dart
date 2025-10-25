import 'package:cloud_firestore/cloud_firestore.dart';

class AdminNotificationService {
  // Simple admin notification via Firestore documents and Cloud Function logs
  
  /// Notify admins when a new provider verification is submitted
  static Future<void> notifyProviderVerificationSubmitted({
    required String providerId,
    required String providerName,
    required String? phoneNumber,
    required String? email,
    required Map<String, String> documentUrls,
  }) async {
    try {
      print('📧 Notifying admins of new provider verification...');
      
      // Create admin notification document in Firestore
      await FirebaseFirestore.instance
          .collection('admin_notifications')
          .add({
        'type': 'provider_verification',
        'providerId': providerId,
        'providerName': providerName,
        'phoneNumber': phoneNumber,
        'email': email,
        'documentUrls': documentUrls,
        'status': 'pending_review',
        'createdAt': FieldValue.serverTimestamp(),
        'priority': 'high',
        'read': false,
      });
      
      // Cloud Function will automatically log this to Firebase Console for admin review
      print('📧 Admin will be notified via Cloud Function logs');
      
      print('✅ Admin notifications sent successfully');
      
    } catch (e) {
      print('❌ Error sending admin notifications: $e');
      // Don't throw error - notification failure shouldn't block provider registration
    }
  }
  
  // Admin push notifications removed - using email notifications via Cloud Function logs instead
  
  // Email notifications handled automatically by Cloud Function triggers
  
  /// Notify admins when provider storefront is completed
  static Future<void> notifyProviderStorefrontCompleted({
    required String providerId,
    required String providerName,
    required String? phoneNumber,
    required int showcasePhotosCount,
    required int employeesCount,
    required List<String> services,
  }) async {
    try {
      // Create admin notification
      await FirebaseFirestore.instance
          .collection('admin_notifications')
          .add({
        'type': 'provider_storefront_completed',
        'providerId': providerId,
        'providerName': providerName,
        'phoneNumber': phoneNumber,
        'showcasePhotosCount': showcasePhotosCount,
        'employeesCount': employeesCount,
        'services': services,
        'status': 'info',
        'createdAt': FieldValue.serverTimestamp(),
        'priority': 'medium',
        'read': false,
      });
      
      // Cloud Function will automatically log this event for admin review
      
      print('✅ Admin storefront completion notification sent');
      
    } catch (e) {
      print('❌ Error sending storefront completion notification: $e');
    }
  }
}
