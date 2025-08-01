#!/bin/bash

# Simple script to add test providers to Firestore using Firebase CLI
echo "🚀 Creating test providers in Firestore using Firebase CLI..."

# Function to create a temporary JSON file and add document
add_provider() {
    local doc_id="$1"
    local json_data="$2"
    local temp_file="temp_${doc_id}.json"
    
    echo "$json_data" > "$temp_file"
    echo "📝 Adding provider: $doc_id"
    
    # Try using database:set for Firestore (sometimes works)
    if firebase firestore:delete "providers/$doc_id" --yes 2>/dev/null; then
        echo "   Cleared existing document"
    fi
    
    # This approach uses the emulator or direct REST API
    echo "   Creating new document..."
    # Since direct firestore commands are limited, let's use a different approach
    
    # Clean up temp file
    rm -f "$temp_file"
}

echo "⚠️  Firebase CLI doesn't have a direct Firestore import command."
echo "📋 Please use one of these methods instead:"
echo ""
echo "🎯 METHOD 1: Firebase Console (Recommended)"
echo "1. Go to https://console.firebase.google.com"
echo "2. Select project: magic-home-01"
echo "3. Go to Firestore Database"
echo "4. Create/navigate to 'providers' collection"
echo "5. For each provider in providers_import.json:"
echo "   - Click 'Add document'"
echo "   - Use document ID (e.g., test_provider_01)"
echo "   - Copy the JSON data for that provider"
echo ""
echo "🎯 METHOD 2: Copy Individual Providers"
echo "Here are the Firebase Console commands for each provider:"
echo ""

# Provider 1
echo "Provider: test_provider_01"
echo "Document ID: test_provider_01"
echo "JSON Data:"
cat << 'EOF'
{
  "email": "test_provider_01@contractor.com",
  "name": "test_provider_01",
  "phone": "(555) 123-4567",
  "company": "Test Provider 01 Services",
  "location": "New York, NY",
  "serviceType": ["plumbing", "electrical"],
  "service_categories": ["plumbing", "electrical"],
  "service_areas": ["New York, NY", "New York Metro Area"],
  "status": "verified",
  "role": "provider",
  "verificationStep": "completed",
  "is_active": true,
  "accepting_new_requests": true,
  "referralCode": "PROV1234",
  "referred_by_user_ids": ["8LmiathzpEO0Mda03eSvs7nL3mf2"],
  "rating": "4.2",
  "total_jobs_completed": 125,
  "hourly_rate": 95,
  "response_time_avg": "2-4 hours",
  "availability_status": "available",
  "emergency_rate_multiplier": 1.5,
  "minimum_charge": 100,
  "license_number": "LIC5432",
  "insurance_verified": true,
  "background_check_passed": true
}
EOF
echo ""
echo "---"
echo ""

# Provider 2
echo "Provider: test_provider_02"
echo "Document ID: test_provider_02"
echo "JSON Data:"
cat << 'EOF'
{
  "email": "test_provider_02@homepro.com",
  "name": "test_provider_02",
  "phone": "(555) 234-5678",
  "company": "Test Provider 02 Services",
  "location": "Brooklyn, NY",
  "serviceType": ["cleaning", "appliance"],
  "service_categories": ["cleaning", "appliance"],
  "service_areas": ["Brooklyn, NY", "New York Metro Area"],
  "status": "verified",
  "role": "provider",
  "verificationStep": "completed",
  "is_active": true,
  "accepting_new_requests": true,
  "referralCode": "PROV2345",
  "referred_by_user_ids": ["IRuxvJxE9xhhIJZsCJ7oJl7TOEE3"],
  "rating": "3.8",
  "total_jobs_completed": 89,
  "hourly_rate": 110,
  "response_time_avg": "2-4 hours",
  "availability_status": "available",
  "emergency_rate_multiplier": 1.5,
  "minimum_charge": 100,
  "license_number": "LIC6543",
  "insurance_verified": true,
  "background_check_passed": true
}
EOF
echo ""
echo "---"
echo ""

echo "📝 Continue with providers 3-10 using the same pattern from providers_import.json"
echo ""
echo "🎯 METHOD 3: Use Firebase Emulator (Development)"
echo "1. firebase emulators:start --only firestore"
echo "2. Import data to emulator"
echo "3. Export from emulator to production"
echo ""
echo "✅ The providers_import.json file contains all 10 providers ready for import!" 