#!/usr/bin/env python3
"""
Test script to check if FCM tokens are valid and can receive notifications.
This will help debug why notifications show "Total: 0" even when tokens exist.
"""

import firebase_admin
from firebase_admin import credentials, messaging, firestore
import sys

def test_fcm_tokens():
    # Initialize Firebase (assumes service account key is set up)
    try:
        if not firebase_admin._apps:
            cred = credentials.ApplicationDefault()
            firebase_admin.initialize_app(cred)
        
        db = firestore.client()
        
        # Test provider ID
        provider_id = "wDIHYfAmbJgreRJO6gPCobg724h1"
        
        print(f"🔍 Testing FCM tokens for provider: {provider_id}")
        
        # Get provider document
        provider_doc = db.collection('providers').document(provider_id).get()
        
        if not provider_doc.exists:
            print(f"❌ Provider {provider_id} not found!")
            return
            
        provider_data = provider_doc.to_dict()
        fcm_tokens = provider_data.get('fcmTokens', [])
        
        print(f"📊 Found {len(fcm_tokens)} FCM tokens")
        
        if not fcm_tokens:
            print("❌ No FCM tokens found!")
            return
        
        # Test each token individually
        for i, token in enumerate(fcm_tokens):
            print(f"\n🧪 Testing token {i+1}: {token[:50]}...")
            
            try:
                # Create a simple test message
                message = messaging.Message(
                    notification=messaging.Notification(
                        title="🧪 FCM Token Test",
                        body=f"Testing token {i+1} validity"
                    ),
                    data={
                        'test': 'true',
                        'token_index': str(i)
                    },
                    token=token
                )
                
                # Send the message
                response = messaging.send(message)
                print(f"✅ Token {i+1} SUCCESS: {response}")
                
            except Exception as e:
                print(f"❌ Token {i+1} FAILED: {str(e)}")
                
                # Check if it's an invalid token error
                if "registration-token-not-registered" in str(e):
                    print(f"🗑️  Token {i+1} is invalid and should be removed")
                elif "mismatched-credential" in str(e):
                    print(f"🔐 Token {i+1} has credential mismatch")
                elif "invalid-argument" in str(e):
                    print(f"🚫 Token {i+1} has invalid format")
        
        print(f"\n📋 Summary: Tested {len(fcm_tokens)} tokens")
        
    except Exception as e:
        print(f"❌ Error: {str(e)}")

if __name__ == "__main__":
    test_fcm_tokens()
