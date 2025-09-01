const admin = require('firebase-admin');

// Initialize Firebase Admin
const serviceAccount = require('./functions/service-account-key.json');
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function checkAssignedTasks() {
  try {
    console.log('🔍 Checking for assigned tasks...');
    
    // Check all user requests with status 'assigned'
    const assignedQuery = await db.collection('user_requests')
      .where('status', '==', 'assigned')
      .get();
    
    console.log(`📋 Found ${assignedQuery.size} assigned tasks`);
    
    assignedQuery.forEach(doc => {
      const data = doc.data();
      console.log(`\n📝 Task ID: ${doc.id}`);
      console.log(`   Status: ${data.status}`);
      console.log(`   Assigned Provider: ${data.assignedProviderId}`);
      console.log(`   User ID: ${data.userId}`);
      console.log(`   Category: ${data.category}`);
      console.log(`   Created: ${data.createdAt?.toDate()}`);
    });
    
    // Also check for any tasks with selectedBidId (which should be assigned)
    const withBidsQuery = await db.collection('user_requests')
      .where('selectedBidId', '!=', null)
      .get();
    
    console.log(`\n🎯 Found ${withBidsQuery.size} tasks with selected bids`);
    
    withBidsQuery.forEach(doc => {
      const data = doc.data();
      console.log(`\n📝 Task ID: ${doc.id}`);
      console.log(`   Status: ${data.status}`);
      console.log(`   Selected Bid: ${data.selectedBidId}`);
      console.log(`   Assigned Provider: ${data.assignedProviderId}`);
      console.log(`   User ID: ${data.userId}`);
      console.log(`   Category: ${data.category}`);
    });
    
  } catch (error) {
    console.error('❌ Error:', error);
  }
}

checkAssignedTasks();
