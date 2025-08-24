const admin = require('firebase-admin');

// Initialize Firebase Admin
if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.applicationDefault(),
    projectId: 'magic-home-01'
  });
}

const db = admin.firestore();

async function updateProvider() {
  const providerId = 'wDIHYfAmbJgreRJO6gPCobg724h1';
  
  try {
    // First, get the current provider data
    const providerRef = db.collection('providers').doc(providerId);
    const providerDoc = await providerRef.get();
    
    if (!providerDoc.exists) {
      console.log(`❌ Provider ${providerId} not found`);
      return;
    }
    
    const currentData = providerDoc.data();
    console.log('📋 Current provider data:');
    console.log(JSON.stringify(currentData, null, 2));
    console.log('\n');
    
    // Complete provider data with all required fields
    const updatedData = {
      // Keep existing data
      ...currentData,
      
      // Basic provider information (add if missing)
      name: currentData.name || 'Sample Provider',
      company: currentData.company || currentData.companyName || 'Sample Provider Services',
      phone: currentData.phone || currentData.phoneNumber || '(555) 123-4567',
      location: currentData.location || currentData.address || '123 Main St, Seattle, WA 98101',
      
      // Service information
      service_categories: currentData.service_categories || ['general', 'handyman'],
      service_areas: currentData.service_areas || ['Seattle', 'Bellevue', 'Redmond'],
      
      // Status and verification
      status: currentData.status || 'verified',
      role: 'provider',
      verificationStep: currentData.verificationStep || 'completed',
      is_active: currentData.is_active !== undefined ? currentData.is_active : true,
      accepting_new_requests: currentData.accepting_new_requests !== undefined ? currentData.accepting_new_requests : true,
      
      // Referral system
      referralCode: currentData.referralCode || `PROV${Math.random().toString(36).substr(2, 4).toUpperCase()}`,
      referred_by_user_ids: currentData.referred_by_user_ids || [],
      
      // Performance metrics
      rating: currentData.rating || '4.5',
      thumbs_up_count: currentData.thumbs_up_count || 50,
      total_jobs_completed: currentData.total_jobs_completed || 25,
      hourly_rate: currentData.hourly_rate || 75,
      response_time_avg: currentData.response_time_avg || '1-3 hours',
      availability_status: currentData.availability_status || 'available',
      
      // Professional details
      emergency_rate_multiplier: currentData.emergency_rate_multiplier || 1.5,
      minimum_charge: currentData.minimum_charge || 50,
      license_number: currentData.license_number || `LIC${Math.random().toString(36).substr(2, 4).toUpperCase()}`,
      insurance_verified: currentData.insurance_verified !== undefined ? currentData.insurance_verified : true,
      background_check_passed: currentData.background_check_passed !== undefined ? currentData.background_check_passed : true,
      
      // Timestamps
      createdAt: currentData.createdAt || admin.firestore.FieldValue.serverTimestamp(),
      lastActive: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };
    
    // Update the provider document
    await providerRef.set(updatedData, { merge: true });
    
    console.log('✅ Successfully updated provider with complete data:');
    console.log('📋 Updated fields:');
    console.log({
      name: updatedData.name,
      company: updatedData.company,
      phone: updatedData.phone,
      location: updatedData.location,
      service_categories: updatedData.service_categories,
      service_areas: updatedData.service_areas,
      status: updatedData.status,
      is_active: updatedData.is_active,
      accepting_new_requests: updatedData.accepting_new_requests,
      referralCode: updatedData.referralCode,
      rating: updatedData.rating,
      total_jobs_completed: updatedData.total_jobs_completed,
      hourly_rate: updatedData.hourly_rate,
      license_number: updatedData.license_number,
      insurance_verified: updatedData.insurance_verified,
      background_check_passed: updatedData.background_check_passed,
    });
    
  } catch (error) {
    console.error('❌ Error updating provider:', error);
  }
}

// Run the update
updateProvider()
  .then(() => {
    console.log('\n🎉 Provider update completed!');
    process.exit(0);
  })
  .catch(error => {
    console.error('💥 Fatal error:', error);
    process.exit(1);
  });
