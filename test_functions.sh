#!/bin/bash

# Firebase Functions Testing Script
echo "🧪 Testing Firebase Functions"
echo "================================"

# Test 1: Test Notification Function
echo "📱 Testing basic test notification..."
curl -X POST https://test-notification-24e4euigxq-uc.a.run.app \
  -H "Content-Type: application/json" \
  -d '{
    "provider_id": "wDIHYfAmbJgreRJO6gPCobg724h1",
    "status": "verified"
  }'
echo -e "\n"

# Test 2: Update Provider Status (triggers automatic notification)
echo "🔄 Testing provider status update..."
curl -X POST https://update-provider-status-24e4euigxq-uc.a.run.app \
  -H "Content-Type: application/json" \
  -d '{
    "provider_id": "wDIHYfAmbJgreRJO6gPCobg724h1",
    "new_status": "verified",
    "reason": "All documents approved"
  }'
echo -e "\n"

# Test 3: Bidding Notification (alarm-style)
echo "🚨 Testing bidding notification..."
curl -X POST https://us-central1-magic-home-01.cloudfunctions.net/send_bidding_notification \
  -H "Content-Type: application/json" \
  -d '{
    "provider_ids": ["wDIHYfAmbJgreRJO6gPCobg724h1"],
    "request_id": "test_request_123",
    "task_description": "Emergency plumbing repair - burst pipe in kitchen",
    "suggested_price": "150-250",
    "urgency": "critical",
    "deadline_hours": 2
  }'
echo -e "\n"

# Test 4: Check Firebase Function Logs
echo "📋 Fetching recent function logs..."
firebase functions:log --limit 10

echo "✅ Testing complete!"
