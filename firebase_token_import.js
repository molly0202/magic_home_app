import admin from 'firebase-admin';
import fs from 'fs';
import { execSync } from 'child_process';

// Initialize Firebase with token or service account
async function initializeFirebase() {
  // Check if already initialized
  try {
    admin.app(); // This will throw if no default app exists
    console.log('✅ Firebase already initialized');
    return true;
  } catch (error) {
    // App doesn't exist, proceed with initialization
  }

  // Try service account first
  if (fs.existsSync('./serviceAccountKey.json')) {
    try {
      const serviceAccount = JSON.parse(fs.readFileSync('./serviceAccountKey.json', 'utf8'));
      admin.initializeApp({
        credential: admin.credential.cert(serviceAccount),
        projectId: 'magic-home-01'
      });
      console.log('✅ Initialized with service account key');
      return true;
    } catch (error) {
      console.log('❌ Service account initialization failed:', error.message);
    }
  }

  // Try environment token
  const token = process.env.FIREBASE_TOKEN;
  
  if (token) {
    try {
      admin.initializeApp({
        credential: admin.credential.refreshToken(token),
        projectId: 'magic-home-01'
      });
      console.log('✅ Initialized with Firebase token');
      return true;
    } catch (error) {
      console.log('❌ Token authentication failed:', error.message);
    }
  }

  return false;
}

// Direct import function using Firebase Admin SDK
async function importProvidersWithAdmin() {
  console.log('🚀 Starting programmatic import of test providers...\n');
  
  const db = admin.firestore();
  
  try {
    // Load provider data
    const providersData = JSON.parse(fs.readFileSync('./providers_import.json', 'utf8'));
    
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
      console.log(`   🔧 Services: ${providerData.service_categories.join(', ')}`);
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
    
    return true;
    
  } catch (error) {
    console.error('❌ Import failed:', error);
    
    if (error.code === 'permission-denied') {
      console.log('\n🔒 Permission denied. Make sure:');
      console.log('1. Your service account has Firestore write permissions');
      console.log('2. Firestore security rules allow writes to "providers" collection');
      console.log('3. You\'re using the correct project ID');
    }
    
    return false;
  }
}

// Quick alternative - use Firebase REST API directly
async function importWithRestAPI() {
  console.log('🔄 Trying Firebase REST API approach...');
  
  try {
    // Get access token from Firebase CLI
    const tokenOutput = execSync('firebase auth:print-access-token', { encoding: 'utf8' });
    const accessToken = tokenOutput.trim();
    
    if (!accessToken) {
      throw new Error('No access token available');
    }

    console.log('✅ Got Firebase access token');
    
    // Load provider data
    const providersData = JSON.parse(fs.readFileSync('./providers_import.json', 'utf8'));
    const providerIds = Object.keys(providersData);
    
    console.log(`🚀 Importing ${providerIds.length} providers via REST API...`);
    
    // Import each provider via REST API
    for (const providerId of providerIds) {
      const providerData = providersData[providerId];
      
      // Add server timestamp fields
      const enhancedData = {
        ...providerData,
        createdAt: new Date().toISOString(),
        lastActive: new Date().toISOString(),
        verifiedAt: new Date().toISOString(),
      };
      
      const url = `https://firestore.googleapis.com/v1/projects/magic-home-01/databases/(default)/documents/providers/${providerId}`;
      
      // Convert data to Firestore REST format
      const firestoreDoc = convertToFirestoreFormat(enhancedData);
      
      const response = await fetch(url, {
        method: 'PATCH',
        headers: {
          'Authorization': `Bearer ${accessToken}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          fields: firestoreDoc
        })
      });
      
      if (response.ok) {
        console.log(`✅ Imported: ${providerData.name}`);
      } else {
        const error = await response.text();
        console.log(`❌ Failed to import ${providerData.name}: ${error}`);
      }
    }
    
    console.log('🎉 REST API import completed!');
    return true;
    
  } catch (error) {
    console.log('❌ REST API approach failed:', error.message);
    return false;
  }
}

// Convert JavaScript object to Firestore REST API format
function convertToFirestoreFormat(obj) {
  const result = {};
  
  for (const [key, value] of Object.entries(obj)) {
    if (typeof value === 'string') {
      result[key] = { stringValue: value };
    } else if (typeof value === 'number') {
      result[key] = { integerValue: value.toString() };
    } else if (typeof value === 'boolean') {
      result[key] = { booleanValue: value };
    } else if (Array.isArray(value)) {
      result[key] = {
        arrayValue: {
          values: value.map(item => ({ stringValue: item }))
        }
      };
    } else if (value && typeof value === 'object') {
      result[key] = { mapValue: { fields: convertToFirestoreFormat(value) } };
    }
  }
  
  return result;
}

// Main execution
async function main() {
  console.log('🚀 Firebase Programmatic Import Tool\n');
  
  // Try Firebase Admin SDK first
  const adminInitialized = await initializeFirebase();
  
  if (adminInitialized) {
    const success = await importProvidersWithAdmin();
    if (success) {
      return;
    }
  }
  
  // Fallback to REST API
  console.log('🔄 Falling back to REST API method...');
  const restSuccess = await importWithRestAPI();
  
  if (!restSuccess) {
    console.log('\n📋 MANUAL SETUP REQUIRED:');
    console.log('\n🔑 Option 1: Service Account Key');
    console.log('1. Go to Firebase Console > Project Settings > Service Accounts');
    console.log('2. Generate new private key → Save as serviceAccountKey.json');
    console.log('3. Run: node firebase_token_import.js');
    console.log('\n🔑 Option 2: Google Cloud SDK');
    console.log('1. Install: https://cloud.google.com/sdk/docs/install');
    console.log('2. Run: gcloud auth application-default login');
    console.log('3. Run: node import_firestore.js');
    console.log('\n💡 Or use the manual Firebase Console method from SETUP_AUTH.md');
  }
}

main().catch(console.error); 