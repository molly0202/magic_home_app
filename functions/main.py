# Welcome to Cloud Functions for Firebase for Python!
# To get started, simply uncomment the below code or create your own.
# Deploy with `firebase deploy`

import firebase_admin
from firebase_admin import credentials, firestore, messaging
from firebase_functions import firestore_fn, https_fn
import logging

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
            
        new_data = event.data.to_dict()
        
        # Get the previous document data if it exists
        old_data = {}
        if hasattr(event, 'data_before') and event.data_before:
            old_data = event.data_before.to_dict()
        
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
                
            # Create notification based on status
            if new_status in ['verified', 'active']:
                notification = messaging.Notification(
                    title="🎉 Account Verified!",
                    body="Congratulations! You can now start accepting service requests.",
                    image=None
                )
                data = {
                    'type': 'status_update',
                    'status': new_status,
                    'provider_id': provider_id,
                    'action': 'verified'
                }
            else:  # rejected
                notification = messaging.Notification(
                    title="Application Update",
                    body="Please check your email for details about your application.",
                    image=None
                )
                data = {
                    'type': 'status_update',
                    'status': new_status,
                    'provider_id': provider_id,
                    'action': 'rejected'
                }
            
            # Send notification to all registered devices
            messages = []
            for token in fcm_tokens:
                message = messaging.Message(
                    notification=notification,
                    data=data,
                    token=token,
                    apns=messaging.APNSConfig(
                        payload=messaging.APNSPayload(
                            aps=messaging.Aps(
                                alert=messaging.ApsAlert(
                                    title=notification.title,
                                    body=notification.body
                                ),
                                badge=1,
                                sound="default",
                                category="STATUS_UPDATE"
                            )
                        )
                    )
                )
                messages.append(message)
            
            # Send batch notification
            if messages:
                response = messaging.send_all(messages)
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
        response = messaging.send_all(messages)
        
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