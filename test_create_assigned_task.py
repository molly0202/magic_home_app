#!/usr/bin/env python3

import requests
import json
from datetime import datetime

# Firebase Functions URL (replace with your actual project URL)
BASE_URL = "https://us-central1-magic-home-01.cloudfunctions.net"

def test_create_assigned_task():
    """Test creating an assigned task by accepting a bid"""
    
    # First, let's create a test bid and then accept it
    print("🧪 Testing assigned task creation...")
    
    # Test data - you may need to adjust these IDs based on your actual data
    test_data = {
        "bid_id": "test_bid_123",  # This would be a real bid ID
        "user_id": "test_user_456"  # This would be a real user ID
    }
    
    try:
        # Call accept_bid function
        response = requests.post(
            f"{BASE_URL}/accept_bid",
            json=test_data,
            headers={'Content-Type': 'application/json'}
        )
        
        print(f"📤 Accept bid response: {response.status_code}")
        print(f"📄 Response body: {response.text}")
        
        if response.status_code == 200:
            print("✅ Bid accepted successfully!")
            print("🔍 Check the provider's My Tasks tab for the assigned task")
        else:
            print(f"❌ Error accepting bid: {response.text}")
            
    except Exception as e:
        print(f"❌ Error: {e}")

def check_provider_id():
    """Check what provider ID we should be testing with"""
    print("\n🔍 To test assigned tasks, you need:")
    print("1. A valid bid ID from the service_bids collection")
    print("2. The corresponding user ID who owns the request")
    print("3. The provider ID should be: wDIHYfAmbJgreRJO6gPCobg724h1 (Magic Home)")
    print("\n💡 Try accepting a quote from the user side first, then check the provider's My Tasks tab")

if __name__ == "__main__":
    check_provider_id()
    # Uncomment the line below if you have valid test data
    # test_create_assigned_task()
