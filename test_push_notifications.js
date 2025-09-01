#!/usr/bin/env node

/**
 * Test script for push notifications
 * Usage: node test_push_notifications.js <provider_id> <status>
 * 
 * Example:
 * node test_push_notifications.js "abc123" "verified"
 * node test_push_notifications.js "abc123" "rejected"
 */

const admin = require('firebase-admin');

// Initialize Firebase Admin (make sure you have the service account key)
if (!admin.apps.length) {
    admin.initializeApp({
        credential: admin.credential.applicationDefault(),
        databaseURL: 'https://magic-home-app-default-rtdb.firebaseio.com'
    });
}

const db = admin.firestore();

async function updateProviderStatus(providerId, newStatus) {
    try {
        console.log(`Updating provider ${providerId} status to ${newStatus}...`);
        
        // Get current provider data
        const providerRef = db.collection('providers').doc(providerId);
        const providerDoc = await providerRef.get();
        
        if (!providerDoc.exists) {
            console.error('Provider not found!');
            return;
        }
        
        const currentData = providerDoc.data();
        const currentStatus = currentData.status;
        
        console.log(`Current status: ${currentStatus}`);
        
        if (currentStatus === newStatus) {
            console.log('Status is already set to:', newStatus);
            return;
        }
        
        // Update the status (this will trigger the Cloud Function)
        await providerRef.update({
            status: newStatus,
            previousStatus: currentStatus,
            statusUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
            reviewedBy: 'test_script',
            reviewedAt: admin.firestore.FieldValue.serverTimestamp()
        });
        
        console.log(`✅ Successfully updated status to: ${newStatus}`);
        console.log('This should trigger a push notification to the provider.');
        
        // Check FCM tokens
        const fcmTokens = currentData.fcmTokens || [];
        console.log(`Provider has ${fcmTokens.length} FCM token(s)`);
        
        if (fcmTokens.length === 0) {
            console.warn('⚠️  No FCM tokens found. Make sure the app is installed and notification permissions are granted.');
        }
        
    } catch (error) {
        console.error('Error updating provider status:', error);
    }
}

async function testDirectNotification(providerId, testStatus) {
    try {
        console.log(`Sending direct test notification to provider ${providerId}...`);
        
        // Get provider data
        const providerDoc = await db.collection('providers').doc(providerId).get();
        
        if (!providerDoc.exists) {
            console.error('Provider not found!');
            return;
        }
        
        const providerData = providerDoc.data();
        const fcmTokens = providerData.fcmTokens || [];
        
        if (fcmTokens.length === 0) {
            console.error('No FCM tokens found for provider');
            return;
        }
        
        // Create test notification
        const notification = {
            title: '🧪 Test Notification',
            body: `This is a test notification for status: ${testStatus}`
        };
        
        const data = {
            type: 'test_notification',
            status: testStatus,
            provider_id: providerId,
            timestamp: new Date().toISOString()
        };
        
        // Send to all tokens
        const messages = fcmTokens.map(token => ({
            notification,
            data,
            token,
            apns: {
                headers: { 'apns-priority': '10' },
                payload: {
                    aps: {
                        alert: {
                            title: notification.title,
                            body: notification.body
                        },
                        badge: 1,
                        sound: 'default'
                    }
                }
            }
        }));
        
        const response = await admin.messaging().sendAll(messages);
        
        console.log(`✅ Sent ${response.successCount} notifications`);
        if (response.failureCount > 0) {
            console.warn(`⚠️  ${response.failureCount} notifications failed`);
        }
        
    } catch (error) {
        console.error('Error sending test notification:', error);
    }
}

// Main execution
async function main() {
    const args = process.argv.slice(2);
    
    if (args.length < 2) {
        console.log('Usage: node test_push_notifications.js <provider_id> <status>');
        console.log('Status options: verified, active, rejected, pending');
        console.log('');
        console.log('Examples:');
        console.log('  node test_push_notifications.js abc123 verified');
        console.log('  node test_push_notifications.js abc123 rejected');
        console.log('');
        console.log('Add "--direct" flag to send direct notification without status update:');
        console.log('  node test_push_notifications.js abc123 verified --direct');
        process.exit(1);
    }
    
    const providerId = args[0];
    const status = args[1];
    const isDirect = args.includes('--direct');
    
    console.log('🧪 Magic Home Push Notification Test');
    console.log('====================================');
    console.log(`Provider ID: ${providerId}`);
    console.log(`Status: ${status}`);
    console.log(`Mode: ${isDirect ? 'Direct notification' : 'Status update (triggers Cloud Function)'}`);
    console.log('');
    
    if (isDirect) {
        await testDirectNotification(providerId, status);
    } else {
        await updateProviderStatus(providerId, status);
    }
    
    console.log('');
    console.log('Check your device for the notification!');
    console.log('Also check Firebase Console > Functions logs for details.');
}

main().catch(console.error);
