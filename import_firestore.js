import admin from 'firebase-admin';
import fs from 'fs';

// Initialize Firebase Admin with service account
// You'll need to download a service account key from Firebase Console
try {
  // Try to use service account key file (method 1)
  if (fs.existsSync('./serviceAccountKey.json')) {
    const serviceAccount = JSON.parse(fs.readFileSync('./serviceAccountKey.json', 'utf8'));
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
      projectId: 'magic-home-01'
    });
    console.log('✅ Initialized with service account key');
  } else {
    // Fallback to application default credentials (method 2)
    admin.initializeApp({
      projectId: 'magic-home-01'
    });
    console.log('✅ Initialized with default credentials');
  }
} catch (error) {
  console.error('❌ Firebase initialization failed:', error.message);
  console.log('\n📋 To fix this, you need authentication. Choose one option:');
  console.log('\n🔑 OPTION 1: Service Account Key (Recommended)');
  console.log('1. Go to Firebase Console > Project Settings > Service Accounts');
  console.log('2. Click "Generate new private key"');
  console.log('3. Save as "serviceAccountKey.json" in this directory');
  console.log('\n🔑 OPTION 2: Application Default Credentials');
  console.log('1. Install Google Cloud SDK: https://cloud.google.com/sdk/docs/install');
  console.log('2. Run: gcloud auth application-default login');
  console.log('3. Run: gcloud config set project magic-home-01');
  process.exit(1);
}

const db = admin.firestore();

// Load provider data
const providersData = JSON.parse(fs.readFileSync('./providers_import.json', 'utf8'));

async function importProviders() {
  console.log('🚀 Starting programmatic import of test providers...\n');
  
  try {
    const batch = db.batch();
    const providerIds = Object.keys(providersData);
    
    console.log(`📦 Preparing batch import of ${providerIds.length} providers...`);
    
    // Add all providers to batch
    providerIds.forEach((providerId, index) => {
      const providerData = providersData[providerId];
      const docRef = db.collection('providers').doc(providerId);
      
      // Add timestamps
      const enhancedData = {
        ...providerData,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        lastActive: admin.firestore.FieldValue.serverTimestamp(),
        verifiedAt: admin.firestore.FieldValue.serverTimestamp(),
      };
      
      batch.set(docRef, enhancedData);
      
      console.log(`📝 Queued: ${providerData.name} (${providerId})`);
      console.log(`   📧 ${providerData.email}`);
      console.log(`   🔧 Services: ${providerData.serviceType.join(', ')}`);
      console.log(`   📍 ${providerData.location}`);
      console.log(`   ⭐ Rating: ${providerData.rating}`);
      console.log('');
    });
    
    console.log('💾 Committing batch write to Firestore...');
    await batch.commit();
    console.log('✅ Successfully imported all providers!\n');
    
    // Update user referral arrays
    console.log('🔗 Updating user referral arrays...');
    
    // Group providers by referring user
    const userProviderMap = {};
    providerIds.forEach(providerId => {
      const provider = providersData[providerId];
      const referringUserId = provider.referred_by_user_ids[0];
      
      if (!userProviderMap[referringUserId]) {
        userProviderMap[referringUserId] = [];
      }
      userProviderMap[referringUserId].push(providerId);
    });
    
    // Update each user's referral array
    const userUpdatePromises = Object.entries(userProviderMap).map(async ([userId, providerIds]) => {
      try {
        const userRef = db.collection('users').doc(userId);
        await userRef.update({
          referred_provider_ids: admin.firestore.FieldValue.arrayUnion(...providerIds)
        });
        console.log(`✅ Updated user ${userId} with ${providerIds.length} provider referrals`);
      } catch (error) {
        console.log(`⚠️  Warning: Could not update user ${userId}: ${error.message}`);
      }
    });
    
    await Promise.all(userUpdatePromises);
    
    console.log('\n🎉 IMPORT COMPLETE!');
    console.log(`📊 Imported ${providerIds.length} test providers`);
    console.log(`👥 Updated ${Object.keys(userProviderMap).length} user referral lists`);
    console.log('\n📋 Imported Provider IDs:');
    providerIds.forEach((id, index) => {
      console.log(`${index + 1}. ${id}`);
    });
    
  } catch (error) {
    console.error('❌ Import failed:', error);
    
    if (error.code === 'permission-denied') {
      console.log('\n🔒 Permission denied. Make sure:');
      console.log('1. Your service account has Firestore write permissions');
      console.log('2. Firestore security rules allow writes to "providers" collection');
      console.log('3. You\'re using the correct project ID');
    }
    
    throw error;
  } finally {
    // Close the app
    setTimeout(() => {
      process.exit(0);
    }, 1000);
  }
}

async function clearTestProviders() {
  console.log('🧹 Clearing existing test providers...\n');
  
  try {
    // Query for test providers
    const snapshot = await db.collection('providers')
      .where('name', '>=', 'test_provider_')
      .where('name', '<=', 'test_provider_\uf8ff')
      .get();

    if (snapshot.empty) {
      console.log('ℹ️  No test providers found to delete.');
      return;
    }

    const batch = db.batch();
    const deletedIds = [];

    snapshot.forEach((doc) => {
      batch.delete(doc.ref);
      deletedIds.push(doc.id);
      console.log(`🗑️  Marked for deletion: ${doc.data().name} (${doc.id})`);
    });

    await batch.commit();
    console.log(`✅ Deleted ${deletedIds.length} test providers\n`);
    
  } catch (error) {
    console.error('❌ Error clearing test providers:', error);
    throw error;
  }
}

// Main execution
async function main() {
  const args = process.argv.slice(2);
  
  try {
    if (args.includes('--clear')) {
      await clearTestProviders();
      return;
    }
    
    if (args.includes('--clear-and-import')) {
      await clearTestProviders();
      await importProviders();
      return;
    }
    
    // Default: just import
    await importProviders();
    
  } catch (error) {
    console.error('💥 Script failed:', error.message);
    process.exit(1);
  }
}

// Run the script
main(); 