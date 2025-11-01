#!/usr/bin/env node

/**
 * Test script for provider push notifications when new requests arrive
 * Usage: node test_provider_new_request_notification.js <provider_id>
 * 
 * Example:
 * node test_provider_new_request_notification.js "your_provider_uid"
 * 
 * This will:
 * 1. Get the provider's FCM token
 * 2. Send a test notification about a new service request
 */

const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

// Initialize Firebase Admin
if (!admin.apps.length) {
    admin.initializeApp({
        credential: admin.credential.cert(serviceAccount),
        databaseURL: 'https://magic-home-01-default-rtdb.firebaseio.com'
    });
}

const db = admin.firestore();
const messaging = admin.messaging();

async function testProviderNotification(providerId) {
    try {
        console.log(`\n🔔 Testing Provider Notification for: ${providerId}\n`);
        
        // Get provider's FCM token
        const providerDoc = await db.collection('providers').doc(providerId).get();
        
        if (!providerDoc.exists) {
            console.error('❌ Provider not found!');
            process.exit(1);
        }
        
        const providerData = providerDoc.data();
        const fcmToken = providerData.fcmToken;
        
        if (!fcmToken) {
            console.error('❌ No FCM token found for this provider');
            console.log('Provider needs to log in to the app to register FCM token');
            process.exit(1);
        }
        
        console.log(`✅ Found FCM token: ${fcmToken.substring(0, 20)}...`);
        console.log(`📍 Provider location: ${providerData.address || 'Not set'}\n`);
        
        // Test 1: New Request Notification
        console.log('📨 Test 1: Sending NEW REQUEST notification...');
        const newRequestMessage = {
            token: fcmToken,
            notification: {
                title: '🔥 New Service Request!',
                body: 'A customer needs help with plumbing. Tap to view details and submit your quote.',
            },
            data: {
                type: 'new_request',
                requestId: 'test_request_123',
                category: 'Plumbing',
                city: 'Seattle',
                urgency: 'medium',
                budget: '$150-300',
            },
            apns: {
                payload: {
                    aps: {
                        sound: 'default',
                        badge: 1,
                    },
                },
            },
        };
        
        const result1 = await messaging.send(newRequestMessage);
        console.log(`✅ New Request notification sent! Message ID: ${result1}\n`);
        
        // Wait 3 seconds
        await new Promise(resolve => setTimeout(resolve, 3000));
        
        // Test 2: User Reply Notification
        console.log('📨 Test 2: Sending USER REPLY notification...');
        const userReplyMessage = {
            token: fcmToken,
            notification: {
                title: '💬 Customer Replied',
                body: 'John Doe responded to your quote for landscaping services.',
            },
            data: {
                type: 'user_reply',
                requestId: 'test_request_456',
                userId: 'test_user_123',
                userName: 'John Doe',
                message: 'When can you start? I\'m available this weekend.',
            },
            apns: {
                payload: {
                    aps: {
                        sound: 'default',
                        badge: 2,
                    },
                },
            },
        };
        
        const result2 = await messaging.send(userReplyMessage);
        console.log(`✅ User Reply notification sent! Message ID: ${result2}\n`);
        
        // Wait 3 seconds
        await new Promise(resolve => setTimeout(resolve, 3000));
        
        // Test 3: Quote Accepted Notification
        console.log('📨 Test 3: Sending QUOTE ACCEPTED notification...');
        const quoteAcceptedMessage = {
            token: fcmToken,
            notification: {
                title: '🎉 Quote Accepted!',
                body: 'Your quote for electrical work has been accepted. Contact the customer to schedule.',
            },
            data: {
                type: 'quote_accepted',
                requestId: 'test_request_789',
                customerId: 'test_user_456',
                customerName: 'Sarah Smith',
                amount: '$250',
            },
            apns: {
                payload: {
                    aps: {
                        sound: 'default',
                        badge: 3,
                    },
                },
            },
        };
        
        const result3 = await messaging.send(quoteAcceptedMessage);
        console.log(`✅ Quote Accepted notification sent! Message ID: ${result3}\n`);
        
        console.log('✨ All test notifications sent successfully!');
        console.log('📱 Check your iPhone for the notifications\n');
        
        process.exit(0);
        
    } catch (error) {
        console.error('❌ Error sending notifications:', error);
        if (error.code === 'messaging/invalid-registration-token') {
            console.log('\n💡 Tip: The FCM token may be expired or invalid.');
            console.log('   Ask the provider to log out and log back in to refresh the token.\n');
        }
        process.exit(1);
    }
}

// Get provider ID from command line
const providerId = process.argv[2];

if (!providerId) {
    console.log('\n❌ Usage: node test_provider_new_request_notification.js <provider_id>');
    console.log('\nExample:');
    console.log('  node test_provider_new_request_notification.js "abc123xyz"\n');
    process.exit(1);
}

testProviderNotification(providerId);

