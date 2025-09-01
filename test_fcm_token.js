#!/usr/bin/env node

/**
 * Quick test to add an FCM token to a provider document
 * Usage: node test_fcm_token.js <provider_id>
 */

const admin = require('firebase-admin');

// Initialize Firebase Admin
if (!admin.apps.length) {
    admin.initializeApp({
        credential: admin.credential.applicationDefault(),
    });
}

const db = admin.firestore();

async function addTestFCMToken(providerId) {
    try {
        console.log(`Adding test FCM token to provider: ${providerId}`);
        
        // Generate a fake FCM token for testing
        const testToken = `test_fcm_token_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
        
        // Get the provider document
        const providerRef = db.collection('providers').doc(providerId);
        const providerDoc = await providerRef.get();
        
        if (!providerDoc.exists) {
            console.log('Provider document does not exist, creating it...');
            await providerRef.set({
                fcmTokens: [testToken],
                status: 'pending',
                createdAt: admin.firestore.FieldValue.serverTimestamp(),
                testTokenAdded: true
            });
        } else {
            console.log('Provider document exists, adding FCM token...');
            await providerRef.update({
                fcmTokens: admin.firestore.FieldValue.arrayUnion(testToken),
                lastTokenUpdate: admin.firestore.FieldValue.serverTimestamp(),
                testTokenAdded: true
            });
        }
        
        console.log(`✅ Test FCM token added: ${testToken}`);
        
        // Verify it was saved
        const updatedDoc = await providerRef.get();
        if (updatedDoc.exists) {
            const data = updatedDoc.data();
            const tokens = data.fcmTokens || [];
            console.log(`🔍 Provider now has ${tokens.length} FCM token(s):`);
            tokens.forEach((token, index) => {
                console.log(`  ${index + 1}. ${token}`);
            });
        }
        
        return testToken;
        
    } catch (error) {
        console.error('❌ Error adding test FCM token:', error);
        throw error;
    }
}

async function main() {
    const args = process.argv.slice(2);
    
    if (args.length < 1) {
        console.log('Usage: node test_fcm_token.js <provider_id>');
        console.log('Example: node test_fcm_token.js wDIHYfAmbJgreRJO6gPCobg724h1');
        process.exit(1);
    }
    
    const providerId = args[0];
    
    console.log('🧪 FCM Token Test');
    console.log('=================');
    console.log(`Provider ID: ${providerId}`);
    console.log('');
    
    try {
        const testToken = await addTestFCMToken(providerId);
        
        console.log('');
        console.log('✅ Test completed successfully!');
        console.log('');
        console.log('Now you can test push notifications by updating the provider status to "verified"');
        console.log('The notification should be sent to the test FCM token.');
        
    } catch (error) {
        console.error('❌ Test failed:', error.message);
        process.exit(1);
    }
}

main();
