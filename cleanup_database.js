const admin = require('firebase-admin');

// Initialize Firebase Admin SDK
admin.initializeApp();
const db = admin.firestore();

async function cleanupCollections() {
  console.log('🧹 Starting database cleanup...');
  
  const collectionsToCleanup = [
    'user_requests',
    'bidding_sessions', 
    'service_bids',
    'matching_results',
    'matching_logs',
    'service_requests'  // Legacy collection
  ];
  
  let totalDeleted = 0;
  
  for (const collectionName of collectionsToCleanup) {
    console.log(`\n📁 Cleaning up ${collectionName}...`);
    
    try {
      const collection = db.collection(collectionName);
      
      // Get all documents in the collection
      const snapshot = await collection.get();
      console.log(`Found ${snapshot.size} documents in ${collectionName}`);
      
      if (snapshot.size === 0) {
        console.log(`✅ ${collectionName} is already empty`);
        continue;
      }
      
      // Delete documents in batches
      const batch = db.batch();
      let batchCount = 0;
      
      snapshot.docs.forEach((doc) => {
        batch.delete(doc.ref);
        batchCount++;
        totalDeleted++;
        
        // Commit batch every 500 documents (Firestore limit)
        if (batchCount >= 500) {
          console.log(`Committing batch of ${batchCount} documents...`);
          batch.commit();
          batchCount = 0;
        }
      });
      
      // Commit remaining documents
      if (batchCount > 0) {
        await batch.commit();
        console.log(`✅ Deleted ${snapshot.size} documents from ${collectionName}`);
      }
      
    } catch (error) {
      console.error(`❌ Error cleaning ${collectionName}:`, error.message);
    }
  }
  
  console.log(`\n✅ Database cleanup complete! Deleted ${totalDeleted} documents total.`);
  process.exit(0);
}

// Handle errors
process.on('unhandledRejection', (error) => {
  console.error('❌ Unhandled rejection:', error);
  process.exit(1);
});

// Run cleanup
cleanupCollections().catch((error) => {
  console.error('❌ Cleanup failed:', error);
  process.exit(1);
});
