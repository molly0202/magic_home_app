# Welcome to Cloud Functions for Firebase for Python!
# To get started, simply uncomment the below code or create your own.
# Deploy with `firebase deploy`

import firebase_admin
from firebase_admin import credentials, firestore, messaging
from firebase_functions import firestore_fn, https_fn
import logging
import json
from datetime import datetime, timedelta

# Initialize Firebase Admin SDK
if not firebase_admin._apps:
    firebase_admin.initialize_app()

@firestore_fn.on_document_updated(document="providers/{provider_id}")
def send_provider_notification(event: firestore_fn.Event[firestore_fn.DocumentSnapshot | None]) -> None:
    """
    Triggered when a provider document is updated.
    Sends push notification when status changes to 'verified' or 'rejected'.
    """
    try:
        # Get the provider ID from the event context
        provider_id = event.params["provider_id"]
        
        # Get the updated document data
        if event.data is None:
            logging.warning(f"No data found for provider {provider_id}")
            return
            
        # For firestore document updated events, event.data is a Change object
        # that has 'after' and 'before' properties containing DocumentSnapshot objects
        new_snapshot = event.data.after
        old_snapshot = event.data.before
        
        if new_snapshot is None:
            logging.warning(f"No document snapshot found for provider {provider_id}")
            return
            
        new_data = new_snapshot.to_dict()
        
        # Get the previous document data if it exists
        old_data = {}
        if old_snapshot and old_snapshot.exists:
            old_data = old_snapshot.to_dict()
        
        # Check if status actually changed
        new_status = new_data.get('status')
        old_status = old_data.get('status')
        
        if new_status == old_status:
            logging.info(f"Status unchanged for provider {provider_id}: {new_status}")
            return
            
        # Check if status changed to verified or rejected
        if new_status in ['verified', 'active', 'rejected']:
            logging.info(f"Provider {provider_id} status changed: {old_status} -> {new_status}")
            
            # Get FCM tokens for this provider
            fcm_tokens = new_data.get('fcmTokens', [])
            
            if not fcm_tokens:
                logging.warning(f"No FCM tokens found for provider {provider_id}")
                return
                
            # Get additional provider info for richer notifications
            company_name = new_data.get('companyName', 'Provider')
            
            # Create notification based on status
            if new_status in ['verified', 'active']:
                notification = messaging.Notification(
                    title="🎉 Account Verified!",
                    body=f"Congratulations {company_name}! You can now start accepting service requests.",
                    image=None
                )
                data = {
                    'type': 'status_update',
                    'status': new_status,
                    'provider_id': provider_id,
                    'action': 'verified',
                    'company_name': company_name,
                    'timestamp': str(firestore.SERVER_TIMESTAMP),
                    'click_action': 'OPEN_PROVIDER_DASHBOARD'
                }
            else:  # rejected
                notification = messaging.Notification(
                    title="Application Update",
                    body=f"Hi {company_name}, please check your email for details about your application.",
                    image=None
                )
                data = {
                    'type': 'status_update',
                    'status': new_status,
                    'provider_id': provider_id,
                    'action': 'rejected',
                    'company_name': company_name,
                    'timestamp': str(firestore.SERVER_TIMESTAMP),
                    'click_action': 'OPEN_SUPPORT'
                }
            
            # Send notification to all registered devices
            messages = []
            for token in fcm_tokens:
                # Enhanced APNS config for iOS with action buttons
                apns_config = messaging.APNSConfig(
                    headers={'apns-priority': '10'},
                    payload=messaging.APNSPayload(
                        aps=messaging.Aps(
                            alert=messaging.ApsAlert(
                                title=notification.title,
                                body=notification.body
                            ),
                            badge=1,
                            sound="default",
                            category="STATUS_UPDATE",
                            mutable_content=True
                        ),
                        custom_data={
                            'click_action': data.get('click_action', ''),
                            'company_name': data.get('company_name', ''),
                            'provider_id': provider_id
                        }
                    )
                )
                
                message = messaging.Message(
                    notification=notification,
                    data=data,
                    token=token,
                    apns=apns_config
                )
                messages.append(message)
            
            # Send batch notification
            if messages:
                response = messaging.send_each(messages)
                logging.info(f"Sent {response.success_count} notifications for provider {provider_id}")
                
                if response.failure_count > 0:
                    logging.warning(f"Failed to send {response.failure_count} notifications")
                    
                    # Remove invalid tokens
                    invalid_tokens = []
                    for idx, resp in enumerate(response.responses):
                        if not resp.success:
                            invalid_tokens.append(fcm_tokens[idx])
                            logging.error(f"Failed to send to token {fcm_tokens[idx]}: {resp.exception}")
                    
                    # Update provider document to remove invalid tokens
                    if invalid_tokens:
                        db = firestore.client()
                        provider_ref = db.collection('providers').document(provider_id)
                        provider_ref.update({
                            'fcmTokens': firestore.ArrayRemove(invalid_tokens)
                        })
                        logging.info(f"Removed {len(invalid_tokens)} invalid tokens for provider {provider_id}")
                
                # Log notification to provider_notifications collection
                db = firestore.client()
                db.collection('provider_notifications').add({
                    'providerId': provider_id,
                    'type': 'push_notification',
                    'status': new_status,
                    'title': notification.title,
                    'body': notification.body,
                    'sentTo': len(fcm_tokens),
                    'successCount': response.success_count,
                    'failureCount': response.failure_count,
                    'timestamp': firestore.SERVER_TIMESTAMP
                })
                
        else:
            logging.info(f"Status change for provider {provider_id} ({old_status} -> {new_status}) does not require notification")
            
    except Exception as e:
        logging.error(f"Error sending notification for provider {provider_id}: {str(e)}")
        raise e


@https_fn.on_request()
def test_notification(req: https_fn.Request) -> https_fn.Response:
    """
    HTTP function to test push notifications manually.
    Usage: POST /test_notification with JSON body: {"provider_id": "xxx", "status": "verified"}
    """
    try:
        # Parse request
        if req.method != 'POST':
            return https_fn.Response("Method not allowed", status=405)
            
        data = req.get_json()
        if not data or 'provider_id' not in data:
            return https_fn.Response("Missing provider_id in request body", status=400)
            
        provider_id = data['provider_id']
        test_status = data.get('status', 'verified')
        
        # Get provider data
        db = firestore.client()
        provider_doc = db.collection('providers').document(provider_id).get()
        
        if not provider_doc.exists:
            return https_fn.Response(f"Provider {provider_id} not found", status=404)
            
        provider_data = provider_doc.to_dict()
        fcm_tokens = provider_data.get('fcmTokens', [])
        
        if not fcm_tokens:
            return https_fn.Response(f"No FCM tokens found for provider {provider_id}", status=400)
            
        # Create test notification
        notification = messaging.Notification(
            title="🧪 Test Notification",
            body=f"This is a test notification for status: {test_status}",
            image=None
        )
        
        data_payload = {
            'type': 'test_notification',
            'status': test_status,
            'provider_id': provider_id,
            'timestamp': str(firestore.SERVER_TIMESTAMP)
        }
        
        # Send to all tokens
        messages = []
        for token in fcm_tokens:
            message = messaging.Message(
                notification=notification,
                data=data_payload,
                token=token,
                apns=messaging.APNSConfig(
                    payload=messaging.APNSPayload(
                        aps=messaging.Aps(
                            alert=messaging.ApsAlert(
                                title=notification.title,
                                body=notification.body
                            ),
                            badge=1,
                            sound="default"
                        )
                    )
                )
            )
            messages.append(message)
        
        # Send batch
        response = messaging.send_each(messages)
        
        return https_fn.Response(
            f"Test notification sent! Success: {response.success_count}, Failed: {response.failure_count}",
            status=200
        )
        
    except Exception as e:
        logging.error(f"Error in test_notification: {str(e)}")
        return https_fn.Response(f"Error: {str(e)}", status=500)


@https_fn.on_request()
def update_provider_status(req: https_fn.Request) -> https_fn.Response:
    """
    HTTP function to update provider status (for admin use).
    Usage: POST /update_provider_status with JSON: {"provider_id": "xxx", "status": "verified"}
    """
    try:
        if req.method != 'POST':
            return https_fn.Response("Method not allowed", status=405)
            
        data = req.get_json()
        if not data or 'provider_id' not in data or 'status' not in data:
            return https_fn.Response("Missing provider_id or status in request body", status=400)
            
        provider_id = data['provider_id']
        new_status = data['status']
        
        if new_status not in ['pending', 'verified', 'active', 'rejected', 'suspended']:
            return https_fn.Response("Invalid status value", status=400)
            
        # Update provider status
        db = firestore.client()
        provider_ref = db.collection('providers').document(provider_id)
        
        # Get current status first
        provider_doc = provider_ref.get()
        if not provider_doc.exists:
            return https_fn.Response(f"Provider {provider_id} not found", status=404)
            
        current_data = provider_doc.to_dict()
        current_status = current_data.get('status')
        
        if current_status == new_status:
            return https_fn.Response(f"Provider {provider_id} already has status {new_status}", status=200)
            
        # Update with timestamp to trigger the notification function
        provider_ref.update({
            'status': new_status,
            'previousStatus': current_status,
            'statusUpdatedAt': firestore.SERVER_TIMESTAMP,
            'reviewedBy': 'admin',  # In production, use actual admin user ID
            'reviewedAt': firestore.SERVER_TIMESTAMP
        })
        
        return https_fn.Response(
            f"Provider {provider_id} status updated: {current_status} -> {new_status}",
            status=200
        )
        
    except Exception as e:
        logging.error(f"Error updating provider status: {str(e)}")
        return https_fn.Response(f"Error: {str(e)}", status=500)


@https_fn.on_request()
def update_provider_profile(req: https_fn.Request) -> https_fn.Response:
    """
    HTTP function to update provider profile with complete data.
    Usage: POST /update_provider_profile with JSON: {"provider_id": "xxx"}
    """
    try:
        if req.method != 'POST':
            return https_fn.Response("Method not allowed", status=405)
            
        data = req.get_json()
        if not data or 'provider_id' not in data:
            return https_fn.Response("Missing provider_id in request body", status=400)
            
        provider_id = data['provider_id']
        
        # Get Firestore client
        db = firestore.client()
        provider_ref = db.collection('providers').document(provider_id)
        
        # Get current provider data
        provider_doc = provider_ref.get()
        if not provider_doc.exists:
            return https_fn.Response(f"Provider {provider_id} not found", status=404)
            
        current_data = provider_doc.to_dict()
        
        # Complete provider data with all required fields
        update_data = {
            # Basic provider information (preserve existing or set defaults)
            'name': current_data.get('name', 'Sample Provider'),
            'company': current_data.get('company') or current_data.get('companyName', 'Sample Provider Services'),
            'phone': current_data.get('phone') or current_data.get('phoneNumber', '(555) 123-4567'),
            'location': current_data.get('location') or current_data.get('address', '123 Main St, Seattle, WA 98101'),
            'email': current_data.get('email', 'provider@example.com'),
            
            # Service information
            'service_categories': current_data.get('service_categories', ['general', 'handyman', 'maintenance']),
            'service_areas': current_data.get('service_areas', ['Seattle', 'Bellevue', 'Redmond']),
            
            # Status and verification (preserve existing status)
            'status': current_data.get('status', 'verified'),
            'role': 'provider',
            'verificationStep': current_data.get('verificationStep', 'completed'),
            'is_active': current_data.get('is_active', True),
            'accepting_new_requests': current_data.get('accepting_new_requests', True),
            
            # Referral system
            'referralCode': current_data.get('referralCode', f'PROV{provider_id[-4:].upper()}'),
            'referred_by_user_ids': current_data.get('referred_by_user_ids', []),
            
            # Performance metrics
            'rating': current_data.get('rating', '4.5'),
            'thumbs_up_count': current_data.get('thumbs_up_count', 75),
            'total_jobs_completed': current_data.get('total_jobs_completed', 50),
            'hourly_rate': current_data.get('hourly_rate', 85),
            'response_time_avg': current_data.get('response_time_avg', '1-3 hours'),
            'availability_status': current_data.get('availability_status', 'available'),
            
            # Professional details
            'emergency_rate_multiplier': current_data.get('emergency_rate_multiplier', 1.5),
            'minimum_charge': current_data.get('minimum_charge', 75),
            'license_number': current_data.get('license_number', f'LIC{provider_id[-4:].upper()}'),
            'insurance_verified': current_data.get('insurance_verified', True),
            'background_check_passed': current_data.get('background_check_passed', True),
            
            # Timestamps (preserve existing, add missing)
            'updatedAt': firestore.SERVER_TIMESTAMP,
        }
        
        # Preserve existing timestamps if they exist
        if 'createdAt' in current_data:
            update_data['createdAt'] = current_data['createdAt']
        if 'verifiedAt' in current_data:
            update_data['verifiedAt'] = current_data['verifiedAt']
        
        # Update the provider document
        provider_ref.update(update_data)
        
        # Return success with updated fields
        response_data = {
            'success': True,
            'provider_id': provider_id,
            'message': 'Provider profile updated successfully',
            'updated_fields': {
                'name': update_data['name'],
                'company': update_data['company'],
                'phone': update_data['phone'],
                'location': update_data['location'],
                'service_categories': update_data['service_categories'],
                'service_areas': update_data['service_areas'],
                'status': update_data['status'],
                'is_active': update_data['is_active'],
                'accepting_new_requests': update_data['accepting_new_requests'],
                'referralCode': update_data['referralCode'],
                'rating': update_data['rating'],
                'total_jobs_completed': update_data['total_jobs_completed'],
                'hourly_rate': update_data['hourly_rate'],
                'license_number': update_data['license_number'],
                'insurance_verified': update_data['insurance_verified'],
                'background_check_passed': update_data['background_check_passed'],
            }
        }
        
        return https_fn.Response(
            json.dumps(response_data, indent=2),
            status=200,
            headers={'Content-Type': 'application/json'}
        )
        
    except Exception as e:
        logging.error(f"Error updating provider profile: {str(e)}")
        return https_fn.Response(f"Error: {str(e)}", status=500)


@https_fn.on_request()
def send_bidding_notification(req: https_fn.Request) -> https_fn.Response:
    """
    Send high-priority bidding notifications with alarm-style effects.
    Usage: POST /send_bidding_notification with JSON body: {
        "provider_ids": ["id1", "id2"],
        "request_id": "req123",
        "task_description": "...",
        "suggested_price": "100-150",
        "urgency": "high",
        "deadline_hours": 2
    }
    """
    try:
        if req.method != 'POST':
            return https_fn.Response("Method not allowed", status=405)
            
        data = req.get_json()
        if not data:
            return https_fn.Response("Missing request body", status=400)
        
        provider_ids = data.get('provider_ids', [])
        request_id = data.get('request_id')
        task_description = data.get('task_description', '')
        suggested_price = data.get('suggested_price', '')
        urgency = data.get('urgency', 'normal')  # 'normal', 'high', 'critical'
        deadline_hours = data.get('deadline_hours', 2)
        
        if not provider_ids or not request_id:
            return https_fn.Response("Missing provider_ids or request_id", status=400)
        
        db = firestore.client()
        total_sent = 0
        
        # Get deadline timestamp
        deadline = datetime.now() + timedelta(hours=deadline_hours)
        deadline_str = deadline.strftime("%I:%M %p")
        
        # First, create the service request in Firestore
        service_request_ref = db.collection('service_requests').document()
        service_request_data = {
            'request_id': request_id,
            'user_id': 'system_bidding',  # Special user ID for bidding requests
            'description': task_description,
            'media_urls': [],
            'preferred_time': 'ASAP',
            'location_masked': 'Available upon acceptance',
            'final_address': '',
            'status': 'bidding',  # Special status for bidding requests
            'created_at': firestore.SERVER_TIMESTAMP,
            'price_range': suggested_price,
            'customer_name': 'Service Request',
            'customer_photo_url': '',
            'urgency': urgency,
            'deadline_timestamp': int(deadline.timestamp()),
            'deadline_hours': deadline_hours,
            'bidding_providers': provider_ids,  # Track which providers can bid
            'bids_received': [],  # Track received bids
        }
        
        # Create the service request
        service_request_ref.set(service_request_data)
        logging.info(f"Created service request {request_id} for bidding")

        for provider_id in provider_ids:
            try:
                # Get provider data
                provider_doc = db.collection('providers').document(provider_id).get()
                if not provider_doc.exists:
                    logging.warning(f"Provider {provider_id} not found")
                    continue
                    
                provider_data = provider_doc.to_dict()
                company_name = provider_data.get('companyName', 'Provider')
                fcm_tokens = provider_data.get('fcmTokens', [])
                
                if not fcm_tokens:
                    logging.warning(f"No FCM tokens for provider {provider_id}")
                    continue
                
                # Create high-priority notification based on urgency
                if urgency == 'critical':
                    title = "🚨 URGENT SERVICE REQUEST"
                    body = f"Critical task available! {task_description[:60]}... Deadline: {deadline_str}"
                    sound = "default"  # Use iOS default sound (loudest available)
                    priority = "high"
                    badge_count = 3  # Red badge - highest urgency
                elif urgency == 'high':
                    title = "⏰ NEW SERVICE OPPORTUNITY"
                    body = f"High-value task: {task_description[:50]}... Respond by {deadline_str}"
                    sound = "default"  # Use iOS default sound
                    priority = "high"
                    badge_count = 2  # Orange badge - high urgency
                else:
                    title = "💼 Service Request Available"
                    body = f"New opportunity: {task_description[:60]}... Deadline: {deadline_str}"
                    sound = "default"  # Use iOS default sound
                    priority = "normal"
                    badge_count = 1  # Yellow badge - normal urgency
                
                # Enhanced notification payload
                notification = messaging.Notification(
                    title=title,
                    body=body
                )
                
                # Rich data payload
                data_payload = {
                    'type': 'bidding_opportunity',
                    'request_id': request_id,
                    'provider_id': provider_id,
                    'urgency': urgency,
                    'task_description': task_description,
                    'suggested_price': suggested_price,
                    'deadline_timestamp': str(int(deadline.timestamp())),
                    'deadline_hours': str(deadline_hours),
                    'click_action': 'OPEN_BIDDING_SCREEN',
                    'sound_effect': sound,
                    'badge_increment': str(badge_count)
                }
                
                # Create messages for each FCM token
                messages = []
                for token in fcm_tokens:
                    message = messaging.Message(
                        notification=notification,
                        data=data_payload,
                        token=token,
                        # iOS-specific configuration for stronger notifications
                        apns=messaging.APNSConfig(
                            headers={
                                'apns-priority': '10',  # High priority
                                'apns-push-type': 'alert'
                            },
                            payload=messaging.APNSPayload(
                                aps=messaging.Aps(
                                    alert=messaging.ApsAlert(
                                        title=title,
                                        body=body,
                                        launch_image='notification_bg.png'
                                    ),
                                    badge=badge_count,
                                    sound=sound,
                                    content_available=True,
                                    mutable_content=True,
                                    category='BIDDING_OPPORTUNITY',
                                    thread_id=f'bidding_{request_id}'
                                ),
                                # Custom payload for app-specific handling
                                custom_data={
                                    'bidding_data': data_payload,
                                    'vibration_pattern': 'strong' if urgency in ['high', 'critical'] else 'normal',
                                    'led_color': '#FF4444' if urgency == 'critical' else '#FFA500' if urgency == 'high' else '#00FF00'
                                }
                            )
                        ),
                        # Android-specific configuration
                        android=messaging.AndroidConfig(
                            priority='high',
                            notification=messaging.AndroidNotification(
                                title=title,
                                body=body,
                                icon='ic_notification',
                                color='#FF6B35',
                                sound='default' if urgency != 'critical' else 'alarm',
                                channel_id='bidding_alerts',
                                priority='high',
                                # Removed unsupported parameters
                                sticky=True,  # Harder to dismiss
                                local_only=False
                            ),
                            data=data_payload
                        )
                    )
                    messages.append(message)
                
                # Send notifications
                if messages:
                    response = messaging.send_each(messages)
                    total_sent += response.success_count
                    
                    if response.failure_count > 0:
                        logging.warning(f"Failed to send {response.failure_count} notifications to {provider_id}")
                    
                    logging.info(f"Sent {response.success_count} bidding notifications to {company_name}")
                    
            except Exception as provider_error:
                logging.error(f"Error sending to provider {provider_id}: {str(provider_error)}")
                continue
        
        return https_fn.Response(
            f"Bidding notifications sent successfully! Total: {total_sent}",
            status=200
        )
        
    except Exception as e:
        logging.error(f"Error in send_bidding_notification: {str(e)}")
        return https_fn.Response(f"Error: {str(e)}", status=500)


@firestore_fn.on_document_updated(document="user_requests/{request_id}")
def initiate_bidding_session(event: firestore_fn.Event[firestore_fn.DocumentSnapshot | None]) -> None:
    """
    Triggered when a user_request status changes to 'matched'.
    Creates a bidding session and sends notifications to matched providers.
    """
    try:
        request_id = event.params["request_id"]
        
        if event.data is None:
            logging.warning(f"No data found for request {request_id}")
            return
            
        new_snapshot = event.data.after
        old_snapshot = event.data.before
        
        if new_snapshot is None:
            logging.warning(f"No document snapshot found for request {request_id}")
            return
            
        new_data = new_snapshot.to_dict()
        old_data = {}
        if old_snapshot and old_snapshot.exists:
            old_data = old_snapshot.to_dict()
        
        # Check if status changed to 'matched'
        new_status = new_data.get('status')
        old_status = old_data.get('status')
        
        if new_status != 'matched' or old_status == 'matched':
            return  # Only trigger on new 'matched' status
            
        logging.info(f"Initiating bidding session for request {request_id}")
        
        # Debug: Log the complete request data
        logging.info(f"Request data for {request_id}: {new_data}")
        
        # Get matched providers from the request
        matched_providers = new_data.get('matchedProviders', [])
        logging.info(f"Matched providers for {request_id}: {matched_providers}")
        
        if not matched_providers:
            logging.warning(f"No matched providers found for request {request_id}")
            return
            
        user_id = new_data.get('userId', '')
        
        # Create bidding session
        db = firestore.client()
        session_data = {
            'requestId': request_id,
            'userId': user_id,
            'notifiedProviders': matched_providers,
            'receivedBids': [],
            'sessionStatus': 'active',
            'createdAt': firestore.SERVER_TIMESTAMP,
            'deadline': datetime.now() + timedelta(hours=2),
            'sessionMetadata': {
                'notificationsSent': len(matched_providers),
                'expectedResponses': len(matched_providers),
            }
        }
        
        # Create bidding session document
        session_ref = db.collection('bidding_sessions').document()
        session_ref.set(session_data)
        
        # Send bidding notifications to matched providers
        task_description = new_data.get('description', 'Service request')
        ai_price_estimation = new_data.get('aiPriceEstimation', {})
        
        # Format price range from AI estimation
        suggested_price = "Price available in app"
        if ai_price_estimation and 'suggestedRange' in ai_price_estimation:
            range_data = ai_price_estimation['suggestedRange']
            min_price = range_data.get('min', 0)
            max_price = range_data.get('max', 0)
            if min_price and max_price:
                suggested_price = f"${int(min_price)}-${int(max_price)}"
        
        # Determine urgency based on user preferences
        preferences = new_data.get('preferences', {})
        urgency = preferences.get('urgency', 'normal')
        
        # Send high-priority notifications
        notification_payload = {
            'provider_ids': matched_providers,
            'request_id': request_id,
            'task_description': task_description,
            'suggested_price': suggested_price,
            'urgency': urgency,
            'deadline_hours': 2
        }
        
        # Create a mock request to call send_bidding_notification
        from firebase_functions.https_fn import Request
        from unittest.mock import Mock
        
        mock_req = Mock(spec=Request)
        mock_req.method = 'POST'
        mock_req.get_json.return_value = notification_payload
        
        # Call the bidding notification function
        send_bidding_notification(mock_req)
        
        logging.info(f"Bidding session created and notifications sent for request {request_id}")
        
    except Exception as e:
        logging.error(f"Error initiating bidding session for request {request_id}: {str(e)}")


@https_fn.on_request()
def submit_bid(req: https_fn.Request) -> https_fn.Response:
    """
    HTTP function to submit a provider bid.
    Usage: POST /submit_bid with JSON body: {
        "request_id": "req123",
        "provider_id": "prov456",
        "price_quote": 150.0,
        "availability": "Available today 2-5 PM",
        "bid_message": "I can handle this job professionally..."
    }
    """
    try:
        if req.method != 'POST':
            return https_fn.Response("Method not allowed", status=405)
            
        data = req.get_json()
        if not data:
            return https_fn.Response("Missing request body", status=400)
        
        required_fields = ['request_id', 'provider_id', 'price_quote', 'availability', 'bid_message']
        for field in required_fields:
            if field not in data:
                return https_fn.Response(f"Missing required field: {field}", status=400)
        
        request_id = data['request_id']
        provider_id = data['provider_id']
        price_quote = float(data['price_quote'])
        availability = data['availability']
        bid_message = data['bid_message']
        
        db = firestore.client()
        
        # Get user request to validate and get user_id
        request_doc = db.collection('user_requests').document(request_id).get()
        if not request_doc.exists:
            return https_fn.Response("User request not found", status=404)
            
        request_data = request_doc.to_dict()
        user_id = request_data.get('userId', '')
        
        # Check if bidding is still active
        if request_data.get('status') != 'matched':
            return https_fn.Response("Bidding is no longer active for this request", status=400)
        
        # Calculate price benchmark using AI estimation
        ai_estimation = request_data.get('aiPriceEstimation', {})
        price_benchmark = _calculate_price_benchmark(price_quote, ai_estimation)
        
        # Create bid document
        bid_data = {
            'requestId': request_id,
            'providerId': provider_id,
            'userId': user_id,
            'priceQuote': price_quote,
            'availability': availability,
            'bidMessage': bid_message,
            'bidStatus': 'pending',
            'createdAt': datetime.now(),
            'expiresAt': datetime.now() + timedelta(hours=2),
            'priceBenchmark': price_benchmark['benchmark'],
            'benchmarkMetadata': {
                'isAIGenerated': price_benchmark.get('isAIGenerated', False),
                'confidenceLevel': price_benchmark.get('confidenceLevel', 'medium'),
                'aiSuggestedMin': price_benchmark.get('aiSuggestedMin'),
                'aiSuggestedMax': price_benchmark.get('aiSuggestedMax'),
            }
        }
        
        # Save bid to Firestore
        bid_ref = db.collection('service_bids').document()
        bid_ref.set(bid_data)
        bid_id = bid_ref.id
        
        # Update user request status to 'bidding' if this is the first bid
        bids_query = db.collection('service_bids').where('requestId', '==', request_id).get()
        if len(bids_query.docs) == 1:  # This is the first bid
            db.collection('user_requests').document(request_id).update({
                'status': 'bidding',
                'biddingStartedAt': datetime.now(),
                'firstBidReceivedAt': datetime.now()
            })
            logging.info(f"Updated user request {request_id} status to 'bidding' - first bid received")
        
        # Update bidding session
        session_query = db.collection('bidding_sessions').where('requestId', '==', request_id).limit(1)
        sessions = session_query.get()
        
        if sessions:
            session_doc = sessions[0]
            session_ref = db.collection('bidding_sessions').document(session_doc.id)
            session_ref.update({
                'receivedBids': firestore.ArrayUnion([bid_id]),
                'updatedAt': firestore.SERVER_TIMESTAMP
            })
        
        # Send immediate notification to user about new bid
        _send_new_bid_notification_to_user(user_id, provider_id, price_quote, price_benchmark['benchmark'])
        
        logging.info(f"Bid submitted: {bid_id} for request {request_id} by provider {provider_id}")
        
        return https_fn.Response(
            json.dumps({
                'success': True,
                'bid_id': bid_id,
                'price_benchmark': price_benchmark['benchmark'],
                'message': 'Bid submitted successfully'
            }),
            status=200,
            headers={'Content-Type': 'application/json'}
        )
        
    except Exception as e:
        logging.error(f"Error submitting bid: {str(e)}")
        return https_fn.Response(
            json.dumps({'error': str(e)}),
            status=500,
            headers={'Content-Type': 'application/json'}
        )


@https_fn.on_request()
def accept_bid(req: https_fn.Request) -> https_fn.Response:
    """
    HTTP function to accept a bid and close the bidding session.
    Usage: POST /accept_bid with JSON body: {
        "bid_id": "bid123",
        "user_id": "user456"
    }
    """
    try:
        if req.method != 'POST':
            return https_fn.Response("Method not allowed", status=405)
            
        data = req.get_json()
        if not data or 'bid_id' not in data or 'user_id' not in data:
            return https_fn.Response("Missing bid_id or user_id", status=400)
        
        bid_id = data['bid_id']
        user_id = data['user_id']
        
        db = firestore.client()
        
        # Get the winning bid
        bid_doc = db.collection('service_bids').document(bid_id).get()
        if not bid_doc.exists:
            return https_fn.Response("Bid not found", status=404)
            
        bid_data = bid_doc.to_dict()
        request_id = bid_data['requestId']
        winning_provider_id = bid_data['providerId']
        
        # Verify user owns this request
        if bid_data['userId'] != user_id:
            return https_fn.Response("Unauthorized: You don't own this request", status=403)
        
        # Update winning bid status
        db.collection('service_bids').document(bid_id).update({
            'bidStatus': 'accepted',
            'acceptedAt': firestore.SERVER_TIMESTAMP
        })
        
        # Update all other bids to rejected
        other_bids_query = db.collection('service_bids').where('requestId', '==', request_id).where(firestore.FieldPath.document_id(), '!=', bid_id)
        other_bids = other_bids_query.get()
        
        batch = db.batch()
        for other_bid in other_bids:
            batch.update(other_bid.reference, {
                'bidStatus': 'rejected',
                'rejectedAt': firestore.SERVER_TIMESTAMP,
                'rejectionReason': 'Another bid was selected'
            })
        batch.commit()
        
        # Update bidding session
        session_query = db.collection('bidding_sessions').where('requestId', '==', request_id).limit(1)
        sessions = session_query.get()
        
        if sessions:
            session_doc = sessions[0]
            db.collection('bidding_sessions').document(session_doc.id).update({
                'sessionStatus': 'completed',
                'selectedBidId': bid_id,
                'winningProviderId': winning_provider_id,
                'completedAt': firestore.SERVER_TIMESTAMP
            })
        
        # Update user request status
        db.collection('user_requests').document(request_id).update({
            'status': 'assigned',
            'assignedProviderId': winning_provider_id,
            'selectedBidId': bid_id,
            'assignedAt': firestore.SERVER_TIMESTAMP
        })
        
        # Send notifications to all providers
        _send_bid_result_notifications(request_id, winning_provider_id, bid_data['priceQuote'])
        
        logging.info(f"Bid {bid_id} accepted for request {request_id}, provider {winning_provider_id} selected")
        
        return https_fn.Response({
            'success': True,
            'message': 'Bid accepted successfully',
            'winning_provider_id': winning_provider_id,
            'price': bid_data['priceQuote']
        }, status=200)
        
    except Exception as e:
        logging.error(f"Error accepting bid: {str(e)}")
        return https_fn.Response(f"Error: {str(e)}", status=500)


def _calculate_price_benchmark(price_quote, ai_estimation):
    """Helper function to calculate price benchmark"""
    if not ai_estimation or 'suggestedRange' not in ai_estimation:
        return {
            'benchmark': 'normal',
            'isAIGenerated': False,
            'confidenceLevel': 'low'
        }
    
    try:
        suggested_range = ai_estimation['suggestedRange']
        min_price = float(suggested_range.get('min', 0))
        max_price = float(suggested_range.get('max', 0))
        
        if min_price <= 0 or max_price <= 0:
            return {'benchmark': 'normal', 'isAIGenerated': False}
        
        if price_quote < min_price:
            benchmark = 'low'
        elif price_quote <= max_price:
            benchmark = 'normal'
        else:
            benchmark = 'high'
        
        return {
            'benchmark': benchmark,
            'isAIGenerated': True,
            'confidenceLevel': ai_estimation.get('confidenceLevel', 'medium'),
            'aiSuggestedMin': min_price,
            'aiSuggestedMax': max_price,
        }
    except Exception as e:
        logging.error(f"Error calculating price benchmark: {e}")
        return {'benchmark': 'normal', 'isAIGenerated': False}


def _send_new_bid_notification_to_user(user_id, provider_id, price_quote, price_benchmark):
    """Helper function to send new bid notification to user"""
    try:
        db = firestore.client()
        
        # Get user's FCM tokens
        user_doc = db.collection('users').document(user_id).get()
        if not user_doc.exists:
            return
            
        user_data = user_doc.to_dict()
        fcm_tokens = user_data.get('fcmTokens', [])
        
        if not fcm_tokens:
            return
        
        # Get provider name
        provider_doc = db.collection('providers').document(provider_id).get()
        provider_name = "A provider"
        if provider_doc.exists:
            provider_data = provider_doc.to_dict()
            provider_name = provider_data.get('companyName', 'A provider')
        
        # Create notification
        benchmark_emoji = {'low': '💰', 'normal': '📊', 'high': '💸'}.get(price_benchmark, '📊')
        
        notification = messaging.Notification(
            title=f"{benchmark_emoji} New Bid Received!",
            body=f"{provider_name} submitted a bid for ${int(price_quote)}"
        )
        
        data_payload = {
            'type': 'new_bid_received',
            'provider_id': provider_id,
            'provider_name': provider_name,
            'price_quote': str(price_quote),
            'price_benchmark': price_benchmark,
            'click_action': 'OPEN_BID_COMPARISON'
        }
        
        # Send to all user tokens
        messages = []
        for token in fcm_tokens:
            message = messaging.Message(
                notification=notification,
                data=data_payload,
                token=token,
                apns=messaging.APNSConfig(
                    payload=messaging.APNSPayload(
                        aps=messaging.Aps(
                            alert=messaging.ApsAlert(
                                title=notification.title,
                                body=notification.body
                            ),
                            badge=1,
                            sound="default"
                        )
                    )
                )
            )
            messages.append(message)
        
        if messages:
            messaging.send_each(messages)
            logging.info(f"Sent new bid notification to user {user_id}")
            
    except Exception as e:
        logging.error(f"Error sending new bid notification to user: {e}")


def _send_bid_result_notifications(request_id, winning_provider_id, winning_price):
    """Helper function to send bid result notifications to all providers"""
    try:
        db = firestore.client()
        
        # Get all bids for this request
        bids_query = db.collection('service_bids').where('requestId', '==', request_id)
        bids = bids_query.get()
        
        for bid_doc in bids:
            bid_data = bid_doc.to_dict()
            provider_id = bid_data['providerId']
            
            # Get provider's FCM tokens
            provider_doc = db.collection('providers').document(provider_id).get()
            if not provider_doc.exists:
                continue
                
            provider_data = provider_doc.to_dict()
            fcm_tokens = provider_data.get('fcmTokens', [])
            company_name = provider_data.get('companyName', 'Provider')
            
            if not fcm_tokens:
                continue
            
            # Create different notifications for winner vs losers
            if provider_id == winning_provider_id:
                notification = messaging.Notification(
                    title="🎉 Congratulations! You Won the Bid!",
                    body=f"Your bid of ${int(winning_price)} was selected. Check your dashboard for next steps."
                )
                click_action = "OPEN_JOB_DETAILS"
            else:
                notification = messaging.Notification(
                    title="Bid Update",
                    body="The customer has selected another provider for this job. Keep an eye out for more opportunities!"
                )
                click_action = "OPEN_PROVIDER_DASHBOARD"
            
            data_payload = {
                'type': 'bid_result',
                'request_id': request_id,
                'provider_id': provider_id,
                'is_winner': str(provider_id == winning_provider_id).lower(),
                'winning_price': str(winning_price),
                'click_action': click_action
            }
            
            # Send notifications
            messages = []
            for token in fcm_tokens:
                message = messaging.Message(
                    notification=notification,
                    data=data_payload,
                    token=token,
                    apns=messaging.APNSConfig(
                        payload=messaging.APNSPayload(
                            aps=messaging.Aps(
                                alert=messaging.ApsAlert(
                                    title=notification.title,
                                    body=notification.body
                                ),
                                badge=1,
                                sound="default"
                            )
                        )
                    )
                )
                messages.append(message)
            
            if messages:
                messaging.send_each(messages)
                logging.info(f"Sent bid result notification to {company_name} ({'winner' if provider_id == winning_provider_id else 'participant'})")
                
    except Exception as e:
        logging.error(f"Error sending bid result notifications: {e}")


@https_fn.on_request()
def migrate_service_requests(req: https_fn.Request) -> https_fn.Response:
    """
    HTTP function to migrate existing service_requests to user_requests collection.
    Usage: POST /migrate_service_requests
    """
    try:
        logging.info("🔄 Starting migration from service_requests to user_requests...")
        
        # Initialize Firestore client
        db = firestore.client()
        
        # Get all existing service_requests
        service_requests_ref = db.collection('service_requests')
        service_requests = service_requests_ref.stream()
        
        migrated_count = 0
        batch = db.batch()
        
        for doc in service_requests:
            service_request_data = doc.to_dict()
            service_request_id = doc.id
            
            # Transform ServiceRequest data to UserRequest format
            user_request_data = {
                # Core fields
                'userId': service_request_data.get('user_id', ''),
                'serviceCategory': 'general',  # Default category for migrated requests
                'description': service_request_data.get('description', ''),
                'mediaUrls': service_request_data.get('media_urls', []),
                
                # Availability - convert from simple preferred_time to structured format
                'userAvailability': {
                    'preferredTimes': [service_request_data.get('preferred_time', 'Flexible')],
                    'preferredDays': ['Any'],
                    'urgency': 'normal'
                },
                
                # Location
                'address': service_request_data.get('location_masked', ''),
                'phoneNumber': '',  # Not available in old format
                'location': None,  # No coordinates in old format
                
                # Preferences
                'preferences': {
                    'price_range': service_request_data.get('price_range', ''),
                    'urgency': 'normal'
                },
                
                # Metadata
                'createdAt': service_request_data.get('created_at', firestore.SERVER_TIMESTAMP),
                'status': service_request_data.get('status', 'pending'),
                'tags': ['migrated'],
                'priority': 3,
                
                # Migration metadata
                'migratedFrom': {
                    'collection': 'service_requests',
                    'originalId': service_request_id,
                    'migratedAt': firestore.SERVER_TIMESTAMP
                },
                
                # Legacy fields for compatibility
                'customerName': service_request_data.get('customer_name'),
                'customerPhotoUrl': service_request_data.get('customer_photo_url'),
                'finalAddress': service_request_data.get('final_address')
            }
            
            # Add to batch
            new_doc_ref = db.collection('user_requests').document()
            batch.set(new_doc_ref, user_request_data)
            
            logging.info(f"📝 Prepared migration for request: {service_request_id} -> {new_doc_ref.id}")
            migrated_count += 1
            
            # Execute batch every 500 documents (Firestore limit)
            if migrated_count % 500 == 0:
                batch.commit()
                batch = db.batch()
                logging.info(f"✅ Committed batch of {migrated_count} migrations")
        
        # Commit final batch
        if migrated_count % 500 != 0:
            batch.commit()
        
        logging.info(f"✅ Successfully migrated {migrated_count} service requests to user_requests!")
        
        return https_fn.Response(
            f"Successfully migrated {migrated_count} service requests to user_requests collection",
            status=200
        )
        
    except Exception as e:
        logging.error(f"❌ Migration failed: {str(e)}")
        return https_fn.Response(f"Migration failed: {str(e)}", status=500)


@https_fn.on_request(cors=True)
def cleanup_test_data(req: https_fn.Request) -> https_fn.Response:
    """HTTP Cloud Function to clean up old test data from Firestore"""
    try:
        db = firestore.client()
        cleanup_count = 0
        
        logging.info("🧹 Starting database cleanup...")
        
        # Collections to clean up
        collections_to_cleanup = [
            'user_requests',
            'bidding_sessions', 
            'service_bids',
            'matching_results',
            'matching_logs',
            'service_requests'  # Legacy collection
        ]
        
        for collection_name in collections_to_cleanup:
            logging.info(f"Cleaning up {collection_name}...")
            
            # Get all documents in batches
            collection_ref = db.collection(collection_name)
            docs = collection_ref.limit(500).stream()
            
            # Delete in batches
            batch = db.batch()
            batch_count = 0
            
            for doc in docs:
                batch.delete(doc.reference)
                batch_count += 1
                cleanup_count += 1
                
                # Commit batch every 500 operations
                if batch_count >= 500:
                    batch.commit()
                    logging.info(f"Deleted batch of {batch_count} documents from {collection_name}")
                    batch = db.batch()
                    batch_count = 0
            
            # Commit remaining documents
            if batch_count > 0:
                batch.commit()
                logging.info(f"Deleted final batch of {batch_count} documents from {collection_name}")
        
        logging.info(f"✅ Database cleanup complete! Deleted {cleanup_count} documents total.")
        
        return https_fn.Response(
            f"Successfully cleaned up {cleanup_count} documents from database",
            status=200
        )
        
    except Exception as e:
        logging.error(f"❌ Cleanup failed: {str(e)}")
        return https_fn.Response(f"Cleanup failed: {str(e)}", status=500)