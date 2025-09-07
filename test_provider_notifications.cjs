const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function testProviderBidNotification() {
  try {
    console.log('🏢 Testing Provider Bid Opportunity Notification...');
    
    // Get Magic Home provider
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
    console.log('📱 Magic Home FCM tokens:', magicHomeData.fcmTokens?.length || 0);
    
    // Get Li YIN user for creating test request
    const usersQuery = await db.collection('users')
      .where('email', '==', 'lyin3922@gmail.com')
      .limit(1)
      .get();
    
    const userId = usersQuery.docs[0].id;
    
    // Create a test service request that should trigger provider notification
    const testRequestId = 'provider_test_request_' + Date.now();
    const testRequest = {
      requestId: testRequestId,
      userId: userId,
      serviceCategory: 'handyman',
      description: 'Test handyman request for provider notification testing - need help with door repair',
      address: '456 Provider Test Street, Seattle, WA 98109',
      phoneNumber: '555-0199',
      mediaUrls: [],
      userAvailability: {
        preferredTime: 'This weekend',
        urgency: 'normal'
      },
      location: {
        lat: 47.6062,
        lng: -122.3321,
        formatted_address: '456 Provider Test Street, Seattle, WA 98109'
      },
      preferences: {
        budget: '$200-400',
        timeframe: 'This week'
      },
      status: 'pending',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      tags: ['provider-test'],
      priority: 4
    };
    
    // Add the test request
    await db.collection('user_requests').doc(testRequestId).set(testRequest);
    console.log('✅ Created test service request:', testRequestId);
    
    // Create bidding session to notify providers
    const biddingSessionId = 'provider_test_session_' + Date.now();
    const biddingSession = {
      sessionId: biddingSessionId,
      requestId: testRequestId,
      userId: userId,
      sessionStatus: 'active',
      notifiedProviders: [magicHomeId],
      deadline: admin.firestore.Timestamp.fromDate(new Date(Date.now() + 2 * 60 * 60 * 1000)), // 2 hours
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      maxBids: 10,
      receivedBids: []
    };
    
    await db.collection('bidding_sessions').doc(biddingSessionId).set(biddingSession);
    console.log('✅ Created bidding session:', biddingSessionId);
    
    // Now create provider notification to trigger the notification
    const providerNotificationId = 'provider_test_notification_' + Date.now();
    await db.collection('provider_notifications').doc(providerNotificationId).set({
      providerId: magicHomeId,
      type: 'bidding_opportunity',
      requestId: testRequestId,
      message: 'New handyman request available in your area',
      data: {
        serviceCategory: 'handyman',
        location: '456 Provider Test Street, Seattle, WA 98109',
        budget: '$200-400',
        deadline: biddingSession.deadline,
        estimatedPrice: '$200-400',
        urgency: 'normal',
        description: 'Door repair needed this weekend'
      },
      read: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp()
    });
    
    console.log('🔔 Provider notification created!');
    console.log('📱 Magic Home provider should receive bidding opportunity notification');
    console.log('💼 Service: Handyman - Door repair');
    console.log('💰 Budget: $200-400');
    console.log('📍 Location: Seattle, WA');
    
    // Also send direct FCM notification to provider if they have tokens
    if (magicHomeData.fcmTokens && magicHomeData.fcmTokens.length > 0) {
      console.log('📤 Sending direct FCM notification to provider...');
      
      const providerMessage = {
        notification: {
          title: '🏠 New Service Request Available',
          body: 'Handyman request in Seattle, WA. Budget: $200-400. Tap to bid!'
        },
        data: {
          type: 'bidding_opportunity',
          requestId: testRequestId,
          serviceCategory: 'handyman',
          location: 'Seattle, WA',
          budget: '$200-400',
          click_action: 'OPEN_BIDDING'
        },
        apns: {
          payload: {
            aps: {
              sound: 'default',
              badge: 1,
              alert: {
                title: '🏠 New Service Request Available',
                body: 'Handyman request in Seattle, WA. Budget: $200-400. Tap to bid!'
              }
            }
          }
        },
        tokens: magicHomeData.fcmTokens.slice(0, 3) // Send to first 3 tokens
      };
      
      const providerResponse = await admin.messaging().sendEachForMulticast(providerMessage);
      console.log('📊 Provider notification result:');
      console.log('   Success:', providerResponse.successCount);
      console.log('   Failure:', providerResponse.failureCount);
      
      if (providerResponse.failureCount > 0) {
        console.log('❌ Provider notification failures:');
        providerResponse.responses.forEach((resp, index) => {
          if (!resp.success) {
            console.log('   Token', index, ':', resp.error?.code, resp.error?.message);
          }
        });
      }
    } else {
      console.log('⚠️ Magic Home provider has no FCM tokens - need to open provider app first');
    }
    
  } catch (error) {
    console.error('❌ Error testing provider notification:', error);
  }
  
  process.exit(0);
}

console.log('🧪 Testing Provider Side Bidding Opportunity Notifications...');
testProviderBidNotification();
