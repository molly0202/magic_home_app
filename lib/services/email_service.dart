import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:url_launcher/url_launcher.dart';

class EmailService {
  // Email configuration
  static const String _adminEmail = 'molly930202@gmail.com';
  static const String _approvalBaseUrl = 'https://your-app.com/api'; // Update with your backend URL
  
  // EmailJS configuration
  static const String _emailJSServiceId = 'service_magic_home';
  static const String _emailJSTemplateId = 'template_provider_verification';
  static const String _emailJSUserId = 'iLY_CBGff8qVFvaYf'; // Replace with your EmailJS user ID
  static const String _emailJSBaseUrl = 'https://api.emailjs.com/api/v1.0/email/send';

  static Future<void> sendVerificationEmailWithAttachments({
    required Map<String, dynamic> providerData,
    required Map<String, File> documentFiles,
  }) async {
    try {
      print('Starting email sending process...');
      
      // Step 1: Try to upload documents to Firebase Storage
      final documentUrls = <String, String>{};
      final uploadErrors = <String>[];
      
      for (final entry in documentFiles.entries) {
        final docType = entry.key;
        final file = entry.value;
        
        print('Uploading $docType to Firebase Storage...');
        try {
          final downloadUrl = await _uploadFileToStorage(file, docType, providerData['uid']);
          if (downloadUrl != null) {
            documentUrls[docType] = downloadUrl;
            print('Successfully uploaded $docType');
          } else {
            throw Exception('Upload returned null URL for $docType');
          }
        } catch (e) {
          final errorMsg = 'Failed to upload $docType: $e';
          print(errorMsg);
          uploadErrors.add(errorMsg);
          documentUrls[docType] = 'Upload failed - File available locally';
        }
      }
      
      print('Upload summary: ${documentUrls.length} entries, ${uploadErrors.length} errors');
      
      // Step 2: Open the mail app with pre-filled content
      print('Opening mail app with document links...');
      await _openMailApp(providerData, documentUrls);
      
      // Step 3: Store in Firestore for tracking
      await FirebaseFirestore.instance
          .collection('admin_emails')
          .add({
        'to': _adminEmail,
        'subject': 'New Provider Verification Required - ${providerData['companyName']}',
        'providerData': providerData,
        'documentUrls': documentUrls,
        'uploadErrors': uploadErrors,
        'timestamp': FieldValue.serverTimestamp(),
        'status': uploadErrors.isEmpty ? 'sent' : 'sent_with_partial_uploads',
      });

      print('Verification email sent successfully to $_adminEmail');
      
      if (uploadErrors.isNotEmpty) {
        print('Warning: Some uploads failed but email was sent with available documents');
      }
      
    } catch (e) {
      print('Error sending verification email: $e');
      throw e;
    }
  }

  static Future<String?> _uploadFileToStorage(File file, String documentType, String userId) async {
    try {
      print('Starting upload for $documentType, file size: ${await file.length()} bytes');
      
      // Check if file exists and is not empty
      if (!await file.exists()) {
        throw Exception('File does not exist');
      }
      
      final fileSize = await file.length();
      if (fileSize == 0) {
        throw Exception('File is empty');
      }
      
      if (fileSize > 25 * 1024 * 1024) { // 25MB limit
        throw Exception('File too large (max 25MB)');
      }
      
      // Create a unique filename with timestamp
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = '${documentType}_${userId}_$timestamp.jpg';
      
      // Initialize Firebase Storage with explicit bucket
      final storage = FirebaseStorage.instanceFor(
        bucket: 'magic-home-01.firebasestorage.app'
      );
      
      // Get the storage reference with a simpler path structure
      final storageRef = storage
          .ref()
          .child('verification_documents')
          .child(fileName);
      
      print('Uploading to Firebase Storage: ${storageRef.fullPath}');
      print('Storage bucket: ${storageRef.bucket}');
      
      // Upload the file with metadata
      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {
          'userId': userId,
          'documentType': documentType,
          'uploadedAt': timestamp.toString(),
        },
      );
      
      try {
        // First, try to create the reference
        await storageRef.putData(
          await file.readAsBytes(),
          metadata,
        ).timeout(
          const Duration(minutes: 5),
          onTimeout: () {
            throw Exception('Upload timeout after 5 minutes');
          },
        );
        
        print('Upload completed for $documentType, getting download URL...');
        
        // Get download URL with retry
        String? downloadUrl;
        int retryCount = 0;
        while (downloadUrl == null && retryCount < 3) {
          try {
            downloadUrl = await storageRef.getDownloadURL();
            print('Successfully got download URL for $documentType: $downloadUrl');
          } catch (e) {
            retryCount++;
            print('Failed to get download URL (attempt $retryCount): $e');
            if (retryCount < 3) {
              print('Retrying in 2 seconds...');
              await Future.delayed(const Duration(seconds: 2));
            }
          }
        }
        
        if (downloadUrl == null) {
          throw Exception('Failed to get download URL after 3 attempts');
        }
        
        return downloadUrl;
      } catch (uploadError) {
        print('Error during upload process: $uploadError');
        // Try to get more information about the error
        if (uploadError is FirebaseException) {
          print('Firebase error code: ${uploadError.code}');
          print('Firebase error message: ${uploadError.message}');
          print('Firebase error plugin: ${uploadError.plugin}');
        }
        rethrow;
      }
    } catch (e) {
      print('Error uploading $documentType to storage: $e');
      rethrow;
    }
  }

  static Future<void> _openMailApp(
    Map<String, dynamic> providerData,
    Map<String, String> documentUrls,
  ) async {
    try {
      final subject = Uri.encodeComponent('New Provider Verification Required - ${providerData['companyName']}');
      final body = Uri.encodeComponent(_buildSimpleEmailText(providerData, documentUrls));
      final mailtoUrl = 'mailto:$_adminEmail?subject=$subject&body=$body';
      final uri = Uri.parse(mailtoUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
        print('Mail app opened successfully');
      } else {
        print('Could not open mail app');
      }
    } catch (e) {
      print('Error opening mail app: $e');
    }
  }

  static String _buildSimpleEmailText(
    Map<String, dynamic> providerData,
    Map<String, String> documentUrls,
  ) {
    return '''
🏠 Magic Home Provider Verification Request

PROVIDER INFORMATION:
• Company Name: ${providerData['companyName']}
• Email: ${providerData['email']}
• Legal Representative: ${providerData['legalRepresentativeName']}
• Phone Number: ${providerData['phoneNumber']}
• Address: ${providerData['address']}
• Referral Code: ${providerData['referralCode'] ?? 'N/A'}

DOCUMENT LINKS:
• Government ID: ${documentUrls['governmentId'] ?? 'Not available'}
• Business License: ${documentUrls['businessLicense'] ?? 'Not available'}
• Insurance: ${documentUrls['insurance'] ?? 'Not available'}

Please review the documents and verify the provider's information.
''';
  }

  static String _buildHTMLEmailContent(
    Map<String, dynamic> providerData,
    Map<String, String> documentUrls,
  ) {
    return '''
    <!DOCTYPE html>
    <html>
    <head>
        <meta charset="UTF-8">
        <title>Provider Verification Required</title>
        <style>
            body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
            .container { max-width: 600px; margin: 0 auto; padding: 20px; }
            .header { background-color: #FBB04C; color: white; padding: 20px; text-align: center; }
            .content { padding: 20px; background-color: #f9f9f9; }
            .provider-info { background-color: white; padding: 15px; margin: 10px 0; border-radius: 5px; }
            .documents { background-color: white; padding: 15px; margin: 10px 0; border-radius: 5px; }
            .document-link { display: inline-block; margin: 5px 10px; padding: 8px 12px; background-color: #007bff; color: white; text-decoration: none; border-radius: 3px; }
        </style>
    </head>
    <body>
        <div class="container">
            <div class="header">
                <h1>🏠 Magic Home Provider Verification</h1>
                <p>New Service Provider Registration Requires Review</p>
            </div>
            
            <div class="content">
                <h2>Provider Information</h2>
                <div class="provider-info">
                    <p><strong>Company Name:</strong> ${providerData['companyName']}</p>
                    <p><strong>Legal Representative:</strong> ${providerData['legalRepresentativeName']}</p>
                    <p><strong>Email:</strong> ${providerData['email']}</p>
                    <p><strong>Phone:</strong> ${providerData['phoneNumber']}</p>
                    <p><strong>Address:</strong> ${providerData['address']}</p>
                    <p><strong>Referral Code:</strong> ${providerData['referralCode'] ?? 'None'}</p>
                    <p><strong>Provider ID:</strong> ${providerData['uid']}</p>
                </div>

                <h2>Submitted Documents</h2>
                <div class="documents">
                    <p>Please review the following documents:</p>
                    <a href="${documentUrls['governmentId']}" class="document-link" target="_blank">📄 Government ID</a>
                    <a href="${documentUrls['businessLicense']}" class="document-link" target="_blank">📋 Business License</a>
                    <a href="${documentUrls['insurance']}" class="document-link" target="_blank">🛡️ Insurance Proof</a>
                </div>

                <div style="margin-top: 30px; padding: 15px; background-color: #e9ecef; border-radius: 5px;">
                    <h4>Instructions:</h4>
                    <ol>
                        <li>Review all submitted documents by clicking the document links above</li>
                        <li>Verify the provider's business license and insurance are valid</li>
                        <li>Reply to this email with your decision</li>
                    </ol>
                    <p><strong>To approve:</strong> Reply with "APPROVE ${providerData['uid']}"</p>
                    <p><strong>To reject:</strong> Reply with "REJECT ${providerData['uid']}"</p>
                    <p><em>The provider will be notified automatically of your decision.</em></p>
                </div>
            </div>
        </div>
    </body>
    </html>
    ''';
  }

  static String _buildEmailContentWithAttachments(
    Map<String, dynamic> providerData,
    Map<String, File> documentFiles,
  ) {
    final providerId = providerData['uid'];
    final approveUrl = '$_approvalBaseUrl/approve/$providerId';
    final rejectUrl = '$_approvalBaseUrl/reject/$providerId';

    return '''
    <!DOCTYPE html>
    <html>
    <head>
        <meta charset="UTF-8">
        <title>Provider Verification Required</title>
        <style>
            body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
            .container { max-width: 600px; margin: 0 auto; padding: 20px; }
            .header { background-color: #FBB04C; color: white; padding: 20px; text-align: center; }
            .content { padding: 20px; background-color: #f9f9f9; }
            .provider-info { background-color: white; padding: 15px; margin: 10px 0; border-radius: 5px; }
            .documents { background-color: white; padding: 15px; margin: 10px 0; border-radius: 5px; }
            .action-buttons { text-align: center; margin: 20px 0; }
            .btn { display: inline-block; padding: 12px 24px; margin: 10px; text-decoration: none; border-radius: 5px; font-weight: bold; }
            .btn-approve { background-color: #28a745; color: white; }
            .btn-reject { background-color: #dc3545; color: white; }
            .document-link { display: inline-block; margin: 5px 10px; padding: 8px 12px; background-color: #007bff; color: white; text-decoration: none; border-radius: 3px; }
        </style>
    </head>
    <body>
        <div class="container">
            <div class="header">
                <h1>🏠 Magic Home Provider Verification</h1>
                <p>New Service Provider Registration Requires Review</p>
            </div>
            
            <div class="content">
                <h2>Provider Information</h2>
                <div class="provider-info">
                    <p><strong>Company Name:</strong> ${providerData['companyName']}</p>
                    <p><strong>Legal Representative:</strong> ${providerData['legalRepresentativeName']}</p>
                    <p><strong>Email:</strong> ${providerData['email']}</p>
                    <p><strong>Phone:</strong> ${providerData['phoneNumber']}</p>
                    <p><strong>Address:</strong> ${providerData['address']}</p>
                    <p><strong>Referral Code:</strong> ${providerData['referralCode'] ?? 'None'}</p>
                    <p><strong>Provider ID:</strong> ${providerData['uid']}</p>
                </div>

                <h2>Submitted Documents</h2>
                <div class="documents">
                    <p>Please review the following attached documents:</p>
                    <ul>
                        <li>📄 Government ID (${documentFiles['governmentId']?.path.split('/').last})</li>
                        <li>📋 Business License (${documentFiles['businessLicense']?.path.split('/').last})</li>
                        <li>🛡️ Insurance Proof (${documentFiles['insurance']?.path.split('/').last})</li>
                    </ul>
                    <p><em>Documents are attached to this email for your review.</em></p>
                </div>

                <div class="action-buttons">
                    <h3>Review Actions</h3>
                    <a href="$approveUrl" class="btn btn-approve">✅ Approve Provider</a>
                    <a href="$rejectUrl" class="btn btn-reject">❌ Reject Application</a>
                </div>

                <div style="margin-top: 30px; padding: 15px; background-color: #e9ecef; border-radius: 5px;">
                    <h4>Instructions:</h4>
                    <ol>
                        <li>Review all submitted documents by clicking the document links above</li>
                        <li>Verify the provider's business license and insurance are valid</li>
                        <li>Click "Approve Provider" to activate their account</li>
                        <li>Click "Reject Application" if documents are insufficient</li>
                    </ol>
                    <p><em>The provider will be notified automatically of your decision.</em></p>
                </div>
            </div>
        </div>
    </body>
    </html>
    ''';
  }

  // Method to handle approval/rejection from admin
  static Future<void> updateProviderStatus(String providerId, String status) async {
    try {
      // Get current status first
      final currentDoc = await FirebaseFirestore.instance
          .collection('providers')
          .doc(providerId)
          .get();
      
      if (!currentDoc.exists) {
        throw Exception('Provider not found');
      }
      
      final currentData = currentDoc.data()!;
      final currentStatus = currentData['status'] as String?;
      
      // Only update if status actually changed
      if (currentStatus != status) {
        await FirebaseFirestore.instance
            .collection('providers')
            .doc(providerId)
            .update({
          'status': status, // 'verified', 'active' or 'rejected'
          'previousStatus': currentStatus,
          'statusUpdatedAt': FieldValue.serverTimestamp(),
          'reviewedAt': FieldValue.serverTimestamp(),
        });

        // Send notification email to provider (optional)
        await _sendStatusNotificationToProvider(providerId, status);
        
        print('Provider status updated via EmailService: $providerId -> $status (from $currentStatus)');
      } else {
        print('Provider status unchanged via EmailService: $providerId already has status $status');
      }
      
    } catch (e) {
      print('Error updating provider status: $e');
      throw e;
    }
  }

  static Future<void> _sendStatusNotificationToProvider(String providerId, String status) async {
    try {
      // Get provider details
      final providerDoc = await FirebaseFirestore.instance
          .collection('providers')
          .doc(providerId)
          .get();
      
      if (!providerDoc.exists) return;
      
      final providerData = providerDoc.data()!;
      final providerEmail = providerData['email'];
      final companyName = providerData['companyName'];
      
      final subject = status == 'active' 
          ? 'Welcome to Magic Home! Your application has been approved'
          : 'Magic Home Application Update';
          
      final message = status == 'active'
          ? 'Congratulations! Your Magic Home provider application has been approved. You can now start accepting service requests.'
          : 'Thank you for your interest in Magic Home. Unfortunately, we cannot approve your application at this time. Please contact support for more information.';
      
      // Store notification email (in production, send actual email)
      await FirebaseFirestore.instance
          .collection('provider_notifications')
          .add({
        'to': providerEmail,
        'subject': subject,
        'message': message,
        'companyName': companyName,
        'status': status,
        'timestamp': FieldValue.serverTimestamp(),
      });
      
    } catch (e) {
      print('Error sending status notification: $e');
    }
  }

  // TODO: Implement actual email sending with your preferred service
  /*
  static Future<void> _sendActualEmail(Map<String, dynamic> emailData) async {
    // Example with SendGrid, Mailgun, or other email service
    try {
      final response = await http.post(
        Uri.parse(_emailServiceUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer YOUR_API_KEY',
        },
        body: jsonEncode(emailData),
      );
      
      if (response.statusCode != 200) {
        throw Exception('Failed to send email: ${response.body}');
      }
    } catch (e) {
      print('Error sending actual email: $e');
      throw e;
    }
  }
  */
} 