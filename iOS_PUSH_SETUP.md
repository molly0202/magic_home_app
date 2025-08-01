# 🍎 iOS Push Notifications Setup Guide

Now that you have an Apple Developer Account, here's how to complete the iOS push notification system:

## 📋 Step 1: Apple Developer Account Configuration

### 1.1 Create App Identifier
1. Go to [Apple Developer Portal](https://developer.apple.com/account/)
2. Navigate to **Certificates, Identifiers & Profiles**
3. Click **Identifiers** → **+** (Add new)
4. Select **App IDs** → **App**
5. Enter:
   - **Bundle ID**: `com.magichome.app` (or your existing bundle ID)
   - **Description**: Magic Home App
6. Enable **Push Notifications** capability
7. Click **Continue** → **Register**

### 1.2 Create APNs Key (Recommended Method)
1. Go to **Keys** → **+** (Add new)
2. Enter **Key Name**: "Magic Home APNs Key"
3. Enable **Apple Push Notifications service (APNs)**
4. Click **Continue** → **Register**
5. **Download the .p8 key file** (save it safely!)
6. Note down:
   - **Key ID** (10 characters)
   - **Team ID** (from account settings)

## 📋 Step 2: Firebase Console Configuration

### 2.1 Upload APNs Key to Firebase
1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select your project: **magic-home-01**
3. Go to **Project Settings** (gear icon) → **Cloud Messaging**
4. In **iOS app configuration**:
   - Click **Upload** in APNs Authentication Key
   - Upload your `.p8` file
   - Enter **Key ID**
   - Enter **Team ID**
5. Click **Upload**

### 2.2 Add iOS App to Firebase (if not done)
1. In Firebase Console → **Project Overview**
2. Click **Add app** → **iOS**
3. Enter **Bundle ID**: `com.magichome.app`
4. Download **GoogleService-Info.plist**
5. Add to your iOS project in Xcode

## 📋 Step 3: Deploy Firebase Functions

```bash
# Deploy the push notification functions
firebase deploy --only functions
```

## 📋 Step 4: Test the System

### 4.1 Test from Flutter App
```dart
// In your provider app, call this to register for notifications
NotificationService.initializePushNotifications(providerId);
```

### 4.2 Test Manually via HTTP
```bash
# Test notification
curl -X POST https://us-central1-magic-home-01.cloudfunctions.net/test_notification \
  -H "Content-Type: application/json" \
  -d '{"provider_id": "test_provider_01", "status": "verified"}'

# Update provider status (triggers automatic notification)
curl -X POST https://us-central1-magic-home-01.cloudfunctions.net/update_provider_status \
  -H "Content-Type: application/json" \
  -d '{"provider_id": "test_provider_01", "status": "verified"}'
```

### 4.3 Test from App (Admin Function)
```dart
// Update provider status programmatically
await NotificationService.updateProviderStatus('test_provider_01', 'verified');
```

## 📋 Step 5: iOS App Configuration

### 5.1 Enable Push Notifications in Xcode
1. Open your iOS project in Xcode
2. Select **Runner** target
3. Go to **Signing & Capabilities**
4. Click **+ Capability**
5. Add **Push Notifications**
6. Add **Background Modes** if needed
   - Enable **Background fetch**
   - Enable **Remote notifications**

### 5.2 Update Info.plist
Add to `ios/Runner/Info.plist`:
```xml
<key>UIBackgroundModes</key>
<array>
    <string>remote-notification</string>
    <string>background-fetch</string>
</array>
```

## 🔧 Troubleshooting

### Invalid Bundle ID
- Make sure Bundle ID in Xcode matches Firebase and Apple Developer Portal

### No FCM Token
- Ensure `initializePushNotifications()` is called
- Check device permissions for notifications
- Test on physical device (not simulator)

### Push Not Received
- Check Firebase Functions logs: `firebase functions:log`
- Verify APNs key is uploaded correctly
- Ensure app is using correct GoogleService-Info.plist

### Testing on Simulator
- iOS Simulator doesn't support push notifications
- Always test on physical iOS device

## 🚀 What Happens Now

1. **Automatic**: When admin changes provider status → Push notification sent
2. **Real-time**: Provider gets notification instantly
3. **Fallback**: Email notification also sent
4. **Logging**: All notifications logged in Firestore
5. **Error Handling**: Invalid tokens automatically cleaned up

## 📱 Notification Types

- **✅ Verified**: "🎉 Account Verified! Congratulations! You can now start accepting service requests."
- **❌ Rejected**: "Application Update - Please check your email for details about your application."

Your iOS push notification system is now complete! 🎉 