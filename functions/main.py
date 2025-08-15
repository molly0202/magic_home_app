# Welcome to Cloud Functions for Firebase for Python!
# To get started, simply uncomment the below code or create your own.
# Deploy with `firebase deploy`

import firebase_admin
from firebase_admin import credentials, firestore, messaging
from firebase_functions import firestore_fn, https_fn
import logging
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
                    sound = "critical_alert.wav"
                    priority = "high"
                    badge_count = 5
                elif urgency == 'high':
                    title = "⏰ NEW SERVICE OPPORTUNITY"
                    body = f"High-value task: {task_description[:50]}... Respond by {deadline_str}"
                    sound = "urgent_alert.wav"
                    priority = "high"
                    badge_count = 3
                else:
                    title = "💼 Service Request Available"
                    body = f"New opportunity: {task_description[:60]}... Deadline: {deadline_str}"
                    sound = "notification_alert.wav"
                    priority = "normal"
                    badge_count = 1
                
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
                                    sound=messaging.CriticalSound(
                                        critical=True if urgency == 'critical' else False,
                                        name=sound,
                                        volume=1.0
                                    ),
                                    content_available=True,
                                    mutable_content=True,
                                    category='BIDDING_OPPORTUNITY',
                                    thread_id=f'bidding_{request_id}'
                                ),
                                # Custom payload for app-specific handling
                                custom_data={
                                    'bidding_data': data_payload,
                                    'vibration_pattern': 'strong' if urgency in ['high', 'critical'] else 'normal',
                                    'led_color': '#FF4444' if urgency == 'critical' else '#FFA500'
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
                                sound=sound,
                                channel_id='bidding_alerts',
                                priority='high',
                                vibrate_timings=[100, 200, 100, 200, 100, 200],  # Strong vibration
                                light_settings=messaging.LightSettings(
                                    color={'red': 1.0, 'green': 0.0, 'blue': 0.0, 'alpha': 1.0},
                                    light_on_duration_millis=500,
                                    light_off_duration_millis=500
                                ),
                                sticky=True,  # Harder to dismiss
                                local_only=False,
                                default_sound=False,
                                default_vibrate_pattern=False,
                                default_light_settings=False
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