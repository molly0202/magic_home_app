const admin = require('firebase-admin');

// Initialize Firebase Admin with default credentials
admin.initializeApp();
const db = admin.firestore();

async function fixRequestStatus() {
  try {
    console.log('🔍 Looking for recent pending requests...');
    
    // Find recent requests with status 'pending' that should be 'matched'
    const pendingRequests = await db.collection('user_requests')
      .where('status', '==', 'pending')
      .orderBy('createdAt', 'desc')
      .limit(5)
      .get();
    
    console.log(`Found ${pendingRequests.docs.length} pending requests`);
    
    for (const doc of pendingRequests.docs) {
      const data = doc.data();
      console.log(`\n📄 Request: ${doc.id}`);
      console.log(`   Service: ${data.serviceCategory}`);
      console.log(`   Created: ${data.createdAt ? data.createdAt.toDate() : 'unknown'}`);
      console.log(`   Matched Providers: ${JSON.stringify(data.matchedProviders || 'none')}`);
      
      // If it has matchedProviders, it should be status 'matched'
      if (data.matchedProviders && data.matchedProviders.length > 0) {
        console.log(`   ✅ Fixing status: pending → matched`);
        await doc.ref.update({
          status: 'matched'
        });
        console.log(`   ✅ Status updated!`);
      }
    }
    
    console.log('\n🎯 Checking if Magic Home provider can now see bidding opportunities...');
    
    // Check what opportunities Magic Home provider should see
    const magicHomeId = 'wDIHYfAmbJgreRJO6gPCobg724h1';
    const matchedRequests = await db.collection('user_requests')
      .where('status', '==', 'matched')
      .where('matchedProviders', 'array-contains', magicHomeId)
      .get();
    
    console.log(`🔥 Magic Home should see ${matchedRequests.docs.length} bidding opportunities`);
    
    for (const doc of matchedRequests.docs) {
      const data = doc.data();
      console.log(`   📋 ${data.serviceCategory} - ${data.description}`);
    }
    
  } catch (error) {
    console.error('❌ Error:', error);
  } finally {
    process.exit(0);
  }
}

fixRequestStatus();
