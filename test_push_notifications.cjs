const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function testProviderBidNotification() {
  try {
    console.log('🔔 Testing Provider Bid Notification for Magic Home...');
    
    // Get Magic Home provider ID
    const providersQuery = await db.collection('providers')
      .where('companyName', '==', 'Magic Home')
      .limit(1)
      .get();
    
    if (providersQuery.empty) {
      console.log('❌ Magic Home provider not found');
      return;
    }
    
    const magicHomeDoc = providersQuery.docs[0];
    const magicHomeId = magicHomeDoc.id;
    const magicHomeData = magicHomeDoc.data();
    
    console.log('✅ Found Magic Home provider:', magicHomeId);
    console.log('📱 FCM tokens:', magicHomeData.fcmTokens?.length || 0);
    
    // Get Li YIN user ID
    const usersQuery = await db.collection('users')
      .where('email', '==', 'lyin3922@gmail.com')
      .limit(1)
      .get();
    
    if (usersQuery.empty) {
      console.log('❌ Li YIN user not found');
      return;
    }
    
    const userDoc = usersQuery.docs[0];
    const userId = userDoc.id;
    const userData = userDoc.data();
    
    console.log('✅ Found Li YIN user:', userId);
    
    // Create a test service request
    const testRequestId = 'test_request_' + Date.now();
    const testRequest = {
      requestId: testRequestId,
      userId: userId,
      serviceCategory: 'handyman',
      description: 'Test service request for push notification testing',
      address: '123 Test Street, Seattle, WA 98109',
      phoneNumber: '555-0123',
      mediaUrls: [],
      userAvailability: {
        preferredTime: 'This weekend'
      },
      location: null,
      preferences: {
        price_range: '$100-200'
      },
      status: 'pending',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      tags: ['test'],
      priority: 3
    };
    
    // Add the test request
    await db.collection('user_requests').doc(testRequestId).set(testRequest);
    console.log('✅ Created test request:', testRequestId);
    
    // Trigger provider matching by calling the Firebase Function
    console.log('🔥 Triggering provider matching...');
    
    // Create a bidding session to trigger notifications
    const biddingSessionId = 'test_session_' + Date.now();
    const biddingSession = {
      sessionId: biddingSessionId,
      requestId: testRequestId,
      userId: userId,
      sessionStatus: 'active',
      notifiedProviders: [magicHomeId],
      deadline: admin.firestore.Timestamp.fromDate(new Date(Date.now() + 2 * 60 * 60 * 1000)), // 2 hours
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      maxBids: 10
    };
    
    await db.collection('bidding_sessions').doc(biddingSessionId).set(biddingSession);
    console.log('✅ Created bidding session:', biddingSessionId);
    
    // Add provider notification document to trigger the function
    const notificationId = 'test_notification_' + Date.now();
    await db.collection('provider_notifications').doc(notificationId).set({
      providerId: magicHomeId,
      type: 'bidding_opportunity',
      requestId: testRequestId,
      message: 'New service request available for bidding',
      data: {
        serviceCategory: 'handyman',
        location: '123 Test Street, Seattle, WA 98109',
        deadline: biddingSession.deadline,
        estimatedPrice: '$100-200'
      },
      read: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp()
    });
    
    console.log('🔔 Provider notification created - Magic Home should receive push notification!');
    console.log('📱 Check Magic Home provider device for notification');
    
  } catch (error) {
    console.error('❌ Error testing provider notification:', error);
  }
}

async function testUserQuoteNotification() {
  try {
    console.log('🔔 Testing User Quote Notification for Li YIN...');
    
    // Get Li YIN user
    const usersQuery = await db.collection('users')
      .where('email', '==', 'lyin3922@gmail.com')
      .limit(1)
      .get();
    
    const userId = usersQuery.docs[0].id;
    const userData = usersQuery.docs[0].data();
    
    console.log('✅ Found Li YIN user:', userId);
    console.log('📱 FCM tokens:', userData.fcmTokens?.length || 0);
    
    // Get Magic Home provider
    const providersQuery = await db.collection('providers')
      .where('companyName', '==', 'Magic Home')
      .limit(1)
      .get();
    
    const magicHomeId = providersQuery.docs[0].id;
    
    // Find an existing matched request for this user
    const requestsQuery = await db.collection('user_requests')
      .where('userId', '==', userId)
      .where('status', '==', 'matched')
      .limit(1)
      .get();
    
    if (requestsQuery.empty) {
      console.log('❌ No matched requests found for user');
      return;
    }
    
    const requestDoc = requestsQuery.docs[0];
    const requestId = requestDoc.id;
    
    console.log('✅ Using existing request:', requestId);
    
    // Create a test bid to trigger quote notification
    const testBidId = 'test_bid_' + Date.now();
    const testBid = {
      bidId: testBidId,
      requestId: requestId,
      providerId: magicHomeId,
      userId: userId,
      priceQuote: 180.0,
      availability: 'Available this weekend',
      bidMessage: 'Test quote - I can help with your service request',
      bidStatus: 'pending',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      expiresAt: admin.firestore.Timestamp.fromDate(new Date(Date.now() + 2 * 60 * 60 * 1000)),
      priceBenchmark: 'normal'
    };
    
    // Add the test bid - this should trigger the quote notification
    await db.collection('service_bids').doc(testBidId).set(testBid);
    
    console.log('🔔 Test bid created - Li YIN should receive quote notification!');
    console.log('📱 Check Li YIN user device for notification');
    console.log('💰 Quote amount: $180');
    
  } catch (error) {
    console.error('❌ Error testing user notification:', error);
  }
}

// Main execution
async function runTests() {
  console.log('🧪 Starting Push Notification Tests...');
  console.log('');
  
  console.log('📋 Test 1: Provider Bid Notification');
  await testProviderBidNotification();
  console.log('');
  
  console.log('📋 Test 2: User Quote Notification');
  await testUserQuoteNotification();
  console.log('');
  
  console.log('✅ All notification tests triggered!');
  console.log('📱 Check both devices for push notifications');
  
  process.exit(0);
}

runTests().catch(error => {
  console.error('❌ Test error:', error);
  process.exit(1);
});
