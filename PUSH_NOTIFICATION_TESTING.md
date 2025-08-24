# Push Notification Testing Guide

## Overview
This guide explains how to test the enhanced push notification system for service provider verification status updates.

## ✅ What's Implemented

### 1. **Enhanced Notification Service** (`lib/services/notification_service.dart`)
- ✅ FCM token management and registration
- ✅ Background & foreground message handling
- ✅ Deep linking support for notification taps
- ✅ Notification settings management
- ✅ Test notification functionality
- ✅ Rich notification display with company names

### 2. **Firebase Cloud Functions** (`functions/main.py`)
- ✅ Automatic notification triggers on status changes
- ✅ Enhanced APNS configuration for iOS
- ✅ Batch notification sending
- ✅ Invalid token cleanup
- ✅ Rich notification content with custom data

### 3. **In-App Testing Tools**
- ✅ Notification Test Screen accessible from notification history
- ✅ Provider status update functions
- ✅ Settings inspection and management

### 4. **Background Message Handling** (`lib/main.dart`)
- ✅ Background message handler setup
- ✅ Notification tap handling from terminated state

## 🧪 Testing Methods

### Method 1: In-App Testing (Recommended)
1. **Open the Magic Home Provider app**
2. **Navigate to notifications**: Tap the notification bell icon in the top-right
3. **Open test screen**: Tap the blue science beaker icon
4. **Test notifications**:
   - Enter your provider ID (auto-filled if logged in)
   - Select status: `verified`, `active`, or `rejected`
   - Tap "Send Test Notification" for a direct test
   - Tap "Update Status" to trigger the real notification system

### Method 2: Node.js Test Script
```bash
# Navigate to your project root
cd /Users/liyin/magic_home_app

# Install dependencies (if not already installed)
npm install firebase-admin

# Test with status update (triggers Cloud Function)
node test_push_notifications.js "YOUR_PROVIDER_ID" "verified"

# Test with direct notification (bypasses Cloud Function)
node test_push_notifications.js "YOUR_PROVIDER_ID" "verified" --direct
```

### Method 3: Firebase Console Functions
1. Go to Firebase Console > Functions
2. Use the `update_provider_status` HTTP function
3. Send POST request with JSON: `{"provider_id": "xxx", "status": "verified"}`

### Method 4: Manual Firestore Update
1. Go to Firebase Console > Firestore
2. Navigate to `providers` collection
3. Find your provider document
4. Update the `status` field to `verified`
5. Add `statusUpdatedAt` field with current timestamp

## 📱 Expected Behavior

### When Status Changes to "Verified"
- **Push Notification**: "🎉 Account Verified! Congratulations [Company Name]! You can now start accepting service requests."
- **In-App**: Success snackbar with green background
- **Email**: Welcome email sent to provider
- **Action**: Tapping notification should navigate to provider dashboard

### When Status Changes to "Rejected"
- **Push Notification**: "Application Update - Hi [Company Name], please check your email for details about your application."
- **In-App**: Update snackbar with red background
- **Email**: Rejection email sent to provider
- **Action**: Tapping notification should navigate to support

### Notification Features
- ✅ **Rich Content**: Includes company name and personalized messages
- ✅ **iOS Badge**: Shows notification count on app icon
- ✅ **Sound**: Default notification sound
- ✅ **Background Handling**: Works when app is closed/backgrounded
- ✅ **Deep Linking**: Opens relevant screens when tapped
- ✅ **Token Management**: Automatically removes invalid tokens

## 🔧 Prerequisites for Testing

### 1. **Device Setup**
- Install the Magic Home Provider app on a physical device
- Grant notification permissions when prompted
- Ensure the app is logged in with a provider account

### 2. **Firebase Setup**
- FCM tokens must be registered (happens automatically when app starts)
- Provider document must exist in Firestore
- Firebase Functions must be deployed

### 3. **Network Requirements**
- Device must have internet connection
- Firebase Cloud Messaging must be reachable

## 🐛 Troubleshooting

### No Notifications Received
1. **Check notification permissions**: Settings > Magic Home > Notifications
2. **Verify FCM tokens**: Use the test screen to check if tokens are registered
3. **Check Firebase logs**: Console > Functions > Logs
4. **Test network**: Ensure device has internet connection

### Notifications Not Showing in Foreground
- Check console logs for "Got a message whilst in the foreground!"
- Verify the `_handleStatusUpdateNotification` function is being called

### iOS-Specific Issues
- Ensure APNS certificates are properly configured in Firebase
- Check that the app is not in "Do Not Disturb" mode
- Verify app is not backgrounded for too long (iOS may limit notifications)

### Firebase Function Errors
- Check Functions logs in Firebase Console
- Verify the provider document exists and has the correct structure
- Ensure FCM tokens array is not empty

## 📋 Test Checklist

### Basic Functionality
- [ ] App requests notification permissions on first launch
- [ ] FCM token is saved to provider document
- [ ] In-app notifications show when status changes
- [ ] Push notifications arrive when app is backgrounded
- [ ] Notification history displays previous notifications

### Status Change Tests
- [ ] Verify "pending" → "verified" triggers notification
- [ ] Verify "pending" → "rejected" triggers notification
- [ ] Verify no notification for "verified" → "verified" (no change)
- [ ] Verify notification includes correct company name

### Advanced Features
- [ ] Notification tapping opens appropriate screen
- [ ] Invalid tokens are automatically removed
- [ ] Background message handler processes notifications
- [ ] Test screen functionality works correctly
- [ ] Settings can be updated and persist

### Edge Cases
- [ ] Multiple FCM tokens (multiple devices) all receive notifications
- [ ] Notifications work after app restart
- [ ] Notifications work after device restart
- [ ] Old tokens are cleaned up when devices uninstall

## 🔍 Monitoring & Analytics

### Firebase Console
- **Functions**: Monitor execution count and errors
- **Firestore**: Check `provider_notifications` collection for logs
- **Cloud Messaging**: View message delivery statistics

### App Logs
- Check device logs for FCM-related messages
- Monitor console output for notification handling
- Use the test screen to inspect current settings

### Provider Notification History
- View notification history in the app
- Check `provider_notifications` Firestore collection
- Monitor email delivery (stored in `admin_emails` collection)

## 🚀 Production Deployment

### Before Going Live
1. **Test thoroughly** on multiple devices (iOS & Android)
2. **Monitor Firebase quotas** (FCM has usage limits)
3. **Set up proper error handling** for failed notifications
4. **Configure APNS production certificates** for iOS
5. **Remove test/debug features** from production build

### Post-Deployment Monitoring
- Monitor notification delivery rates
- Track user engagement with notifications
- Monitor Firebase Function execution costs
- Set up alerts for notification failures

---

## 📞 Need Help?

If you encounter issues:
1. Check the troubleshooting section above
2. Review Firebase Console logs
3. Use the in-app test screen to diagnose
4. Check provider document structure in Firestore
5. Verify notification permissions on device

## 🎯 Summary

The push notification system is now fully implemented and ready for testing. The key enhancement is that notifications are automatically sent when a provider's verification status changes to "verified", providing immediate feedback to service providers about their application status.

The system handles both foreground and background scenarios, includes rich content, and provides multiple testing methods for verification before deployment.
