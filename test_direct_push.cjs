const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function sendDirectPushNotifications() {
  try {
    console.log('📱 Testing Direct Push Notifications...');
    
    // Get Li YIN user tokens
    const usersQuery = await db.collection('users')
      .where('email', '==', 'lyin3922@gmail.com')
      .limit(1)
      .get();
    
    const userData = usersQuery.docs[0].data();
    const userTokens = userData.fcmTokens || [];
    
    console.log('👤 Li YIN tokens:', userTokens.length);
    
    // Get Magic Home provider tokens
    const providersQuery = await db.collection('providers')
      .where('companyName', '==', 'Magic Home')
      .limit(1)
      .get();
    
    const providerData = providersQuery.docs[0].data();
    const providerTokens = providerData.fcmTokens || [];
    
    console.log('🏢 Magic Home tokens:', providerTokens.length);
    
    // Test 1: Send quote notification to user
    if (userTokens.length > 0) {
      console.log('🔔 Sending quote notification to Li YIN...');
      
      const userMessage = {
        notification: {
          title: '💰 New Quote Received!',
          body: 'Magic Home sent you a quote for $250. Tap to view details.'
        },
        data: {
          type: 'new_bid_received',
          requestId: '5E35fxBO4ZHu3bnDwLYR',
          providerId: 'wDIHYfAmbJgreRJO6gPCobg724h1',
          priceQuote: '250',
          click_action: 'OPEN_BID_COMPARISON'
        },
        apns: {
          payload: {
            aps: {
              sound: 'default',
              badge: 1,
              alert: {
                title: '💰 New Quote Received!',
                body: 'Magic Home sent you a quote for $250. Tap to view details.'
              }
            }
          }
        },
        tokens: userTokens.slice(0, 3) // Send to first 3 tokens
      };
      
      const userResponse = await admin.messaging().sendEachForMulticast(userMessage);
      console.log('📊 User notification - Success:', userResponse.successCount, 'Failure:', userResponse.failureCount);
      
      if (userResponse.failureCount > 0) {
        userResponse.responses.forEach((resp, index) => {
          if (!resp.success) {
            console.log('❌ User token', index, 'failed:', resp.error?.code, resp.error?.message);
          }
        });
      }
    }
    
    // Test 2: Send bid opportunity notification to provider
    if (providerTokens.length > 0) {
      console.log('🔔 Sending bid opportunity to Magic Home...');
      
      const providerMessage = {
        notification: {
          title: '🏠 New Service Request',
          body: 'New handyman request available in Seattle. $100-300 budget.'
        },
        data: {
          type: 'bidding_opportunity',
          requestId: 'test_request_1757210205867',
          serviceCategory: 'handyman',
          location: 'Seattle, WA',
          budget: '$100-300'
        },
        apns: {
          payload: {
            aps: {
              sound: 'default',
              badge: 1,
              alert: {
                title: '🏠 New Service Request',
                body: 'New handyman request available in Seattle. $100-300 budget.'
              }
            }
          }
        },
        tokens: providerTokens.slice(0, 3) // Send to first 3 tokens
      };
      
      const providerResponse = await admin.messaging().sendEachForMulticast(providerMessage);
      console.log('📊 Provider notification - Success:', providerResponse.successCount, 'Failure:', providerResponse.failureCount);
      
      if (providerResponse.failureCount > 0) {
        providerResponse.responses.forEach((resp, index) => {
          if (!resp.success) {
            console.log('❌ Provider token', index, 'failed:', resp.error?.code, resp.error?.message);
          }
        });
      }
    }
    
    console.log('');
    console.log('✅ Direct push notifications sent!');
    console.log('📱 Check both devices for notifications');
    console.log('');
    console.log('💡 If notifications don\'t appear:');
    console.log('   1. Check iOS Settings → Magic Home App → Notifications');
    console.log('   2. Ensure app is in background/closed');
    console.log('   3. Check Do Not Disturb is off');
    console.log('   4. Verify APNs certificate in Firebase Console');
    
  } catch (error) {
    console.error('❌ Error sending direct push:', error);
  }
  
  process.exit(0);
}

sendDirectPushNotifications();
