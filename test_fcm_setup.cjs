const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function testDirectFCMSend() {
  try {
    console.log('📱 Testing Direct FCM Send...');
    
    // Get Li YIN user FCM tokens
    const usersQuery = await db.collection('users')
      .where('email', '==', 'lyin3922@gmail.com')
      .limit(1)
      .get();
    
    if (usersQuery.empty) {
      console.log('❌ User not found');
      return;
    }
    
    const userData = usersQuery.docs[0].data();
    const fcmTokens = userData.fcmTokens || [];
    
    console.log('👤 User FCM tokens:', fcmTokens.length);
    
    if (fcmTokens.length === 0) {
      console.log('❌ No FCM tokens found for user');
      console.log('🔧 Need to register FCM tokens from the app first');
      return;
    }
    
    // Try to send a test notification directly
    const message = {
      notification: {
        title: '🌟 Test Quote Notification',
        body: 'Testing push notification system - Magic Home sent you a quote for $180'
      },
      data: {
        type: 'new_bid_received',
        requestId: 'test_request_123',
        providerId: 'wDIHYfAmbJgreRJO6gPCobg724h1',
        priceQuote: '180'
      },
      tokens: fcmTokens.slice(0, 5) // Send to first 5 tokens
    };
    
    console.log('📤 Sending test notification to', fcmTokens.length, 'tokens...');
    
    const response = await admin.messaging().sendEachForMulticast(message);
    
    console.log('✅ Notification sent!');
    console.log('📊 Success count:', response.successCount);
    console.log('📊 Failure count:', response.failureCount);
    
    if (response.failureCount > 0) {
      console.log('❌ Failures:');
      response.responses.forEach((resp, index) => {
        if (!resp.success) {
          console.log('  Token', index, ':', resp.error?.message);
        }
      });
    }
    
  } catch (error) {
    console.error('❌ Error testing FCM:', error);
  }
}

async function checkFCMTokens() {
  try {
    console.log('🔍 Checking FCM Token Registration...');
    
    // Check Li YIN user tokens
    const usersQuery = await db.collection('users')
      .where('email', '==', 'lyin3922@gmail.com')
      .limit(1)
      .get();
    
    const userData = usersQuery.docs[0].data();
    const userTokens = userData.fcmTokens || [];
    
    console.log('👤 Li YIN FCM tokens:', userTokens.length);
    if (userTokens.length > 0) {
      console.log('  Latest token:', userTokens[userTokens.length - 1].substring(0, 50) + '...');
    }
    
    // Check Magic Home provider tokens  
    const providersQuery = await db.collection('providers')
      .where('companyName', '==', 'Magic Home')
      .limit(1)
      .get();
    
    if (!providersQuery.empty) {
      const providerData = providersQuery.docs[0].data();
      const providerTokens = providerData.fcmTokens || [];
      
      console.log('🏢 Magic Home FCM tokens:', providerTokens.length);
      if (providerTokens.length > 0) {
        console.log('  Latest token:', providerTokens[providerTokens.length - 1].substring(0, 50) + '...');
      }
    }
    
  } catch (error) {
    console.error('❌ Error checking tokens:', error);
  }
}

// Run both tests
async function runTests() {
  await checkFCMTokens();
  console.log('');
  await testDirectFCMSend();
  process.exit(0);
}

runTests().catch(error => {
  console.error('❌ Test error:', error);
  process.exit(1);
});
