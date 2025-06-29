import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../../services/email_service.dart';
import '../home/hsp_home_screen.dart';

class HspVerificationScreen extends StatefulWidget {
  final firebase_auth.User user;
  final String email;

  const HspVerificationScreen({
    super.key,
    required this.user,
    required this.email,
  });

  @override
  State<HspVerificationScreen> createState() => _HspVerificationScreenState();
}

class _HspVerificationScreenState extends State<HspVerificationScreen> {
  final TextEditingController _companyNameController = TextEditingController();
  final TextEditingController _legalRepNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _referralCodeController = TextEditingController();
  
  bool _backgroundCheckConsent = false;
  bool _isLoading = false;
  String? _errorMessage;
  
  File? _governmentIdFile;
  File? _businessLicenseFile;
  File? _insuranceFile;
  
  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    _companyNameController.dispose();
    _legalRepNameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _referralCodeController.dispose();
    super.dispose();
  }

  Future<void> _pickFile(String documentType) async {
    try {
      // Show dialog to choose between camera and gallery
      final ImageSource? source = await showDialog<ImageSource>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Select Image Source'),
            content: const Text('Choose how you want to add your document:'),
            actions: [
              TextButton.icon(
                onPressed: () => Navigator.pop(context, ImageSource.camera),
                icon: const Icon(Icons.camera_alt),
                label: const Text('Take Photo'),
              ),
              TextButton.icon(
                onPressed: () => Navigator.pop(context, ImageSource.gallery),
                icon: const Icon(Icons.photo_library),
                label: const Text('Choose from Gallery'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ],
          );
        },
      );

      if (source == null) return; // User cancelled

      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 1920,
        maxHeight: 1920,
      );
      
      if (pickedFile != null) {
        setState(() {
          switch (documentType) {
            case 'government_id':
              _governmentIdFile = File(pickedFile.path);
              break;
            case 'business_license':
              _businessLicenseFile = File(pickedFile.path);
              break;
            case 'insurance':
              _insuranceFile = File(pickedFile.path);
              break;
          }
        });
      }
    } catch (e) {
      // Handle specific camera permission errors
      String errorMessage = 'Failed to pick file: $e';
      
      if (e.toString().contains('camera_access_denied') || 
          e.toString().contains('Permission denied')) {
        errorMessage = 'Camera permission is required to take photos. Please enable camera access in Settings > Privacy & Security > Camera > Magic Home.';
      } else if (e.toString().contains('photo_access_denied')) {
        errorMessage = 'Photo library permission is required. Please enable photo access in Settings > Privacy & Security > Photos > Magic Home.';
      }
      
      setState(() {
        _errorMessage = errorMessage;
      });
      
      // Show user-friendly error dialog
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Permission Required'),
          content: Text(errorMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _submitVerification() async {
    // Validation
    if (_companyNameController.text.trim().isEmpty ||
        _legalRepNameController.text.trim().isEmpty ||
        _phoneController.text.trim().isEmpty ||
        _addressController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = 'Please fill in all required fields';
      });
      return;
    }

    if (_governmentIdFile == null || _businessLicenseFile == null || _insuranceFile == null) {
      setState(() {
        _errorMessage = 'Please upload all required documents';
      });
      return;
    }

    if (!_backgroundCheckConsent) {
      setState(() {
        _errorMessage = 'Please consent to the background check';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      setState(() {
        _errorMessage = 'Validating files...';
      });

      // Check if files exist and are accessible
      for (final entry in {
        'Government ID': _governmentIdFile!,
        'Business License': _businessLicenseFile!,
        'Insurance': _insuranceFile!,
      }.entries) {
        if (!await entry.value.exists()) {
          throw Exception('${entry.key} file no longer exists. Please select again.');
        }
        final size = await entry.value.length();
        if (size == 0) {
          throw Exception('${entry.key} file is empty. Please select a valid file.');
        }
        print('${entry.key}: ${size} bytes');
      }

      setState(() {
        _errorMessage = 'Uploading documents to server...';
      });

      // Send verification email to admin with document attachments FIRST
      await EmailService.sendVerificationEmailWithAttachments(
        providerData: {
          'uid': widget.user.uid,
          'email': widget.email,
          'companyName': _companyNameController.text.trim(),
          'legalRepresentativeName': _legalRepNameController.text.trim(),
          'phoneNumber': _phoneController.text.trim(),
          'address': _addressController.text.trim(),
          'referralCode': _referralCodeController.text.trim(),
        },
        documentFiles: {
          'governmentId': _governmentIdFile!,
          'businessLicense': _businessLicenseFile!,
          'insurance': _insuranceFile!,
        },
      );

      setState(() {
        _errorMessage = 'Updating your application status...';
      });

      // Only update status AFTER successful file upload and email sending
      await FirebaseFirestore.instance
          .collection('providers')
          .doc(widget.user.uid)
          .update({
        'companyName': _companyNameController.text.trim(),
        'legalRepresentativeName': _legalRepNameController.text.trim(),
        'phoneNumber': _phoneController.text.trim(),
        'address': _addressController.text.trim(),
        'referralCode': _referralCodeController.text.trim(),
        'backgroundCheckConsent': _backgroundCheckConsent,
        'verificationStep': 'documents_submitted',
        'status': 'under_review', // Set status for admin review
        'submittedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      setState(() {
        _errorMessage = 'Documents submitted successfully!';
      });

      // Small delay to show success message
      await Future.delayed(const Duration(seconds: 1));

      // Navigate to HSP home screen
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => HspHomeScreen(user: widget.user),
        ),
        (route) => false,
      );
    } catch (e) {
      setState(() {
        _errorMessage = 'Submission failed: $e';
        _isLoading = false;
      });
    }
  }

  Widget _buildFileUploadSection(String title, File? file, String documentType) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => _pickFile(documentType),
          child: Container(
            height: 120,
            width: double.infinity,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300, width: 2),
              borderRadius: BorderRadius.circular(8),
              color: Colors.grey.shade50,
            ),
            child: file != null
                ? Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.file(
                          file,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                        ),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  )
                : const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add,
                        size: 40,
                        color: Color(0xFFFBB04C),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Upload Document',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Verification'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text(
              'Close',
              style: TextStyle(color: Color(0xFFFBB04C)),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.all(10),
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),

            // Company Name
            const Text(
              'Company Name',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _companyNameController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Enter company name',
              ),
            ),
            const SizedBox(height: 20),

            // Legal Representative Name
            const Text(
              'Legal Representative Name',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _legalRepNameController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Enter legal representative name',
              ),
            ),
            const SizedBox(height: 20),

            // Phone Number
            const Text(
              'Phone Number',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Enter phone number',
              ),
            ),
            const SizedBox(height: 20),

            // Address
            const Text(
              'Address',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _addressController,
              maxLines: 2,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Enter business address',
              ),
            ),
            const SizedBox(height: 20),

            // Document Upload Sections
            _buildFileUploadSection(
              'Government ID (Legal Representative)',
              _governmentIdFile,
              'government_id',
            ),

            _buildFileUploadSection(
              'Business License',
              _businessLicenseFile,
              'business_license',
            ),

            _buildFileUploadSection(
              'Proof of Liability Insurance',
              _insuranceFile,
              'insurance',
            ),

            // Background check consent
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Checkbox(
                  value: _backgroundCheckConsent,
                  onChanged: (value) {
                    setState(() {
                      _backgroundCheckConsent = value ?? false;
                    });
                  },
                  activeColor: const Color(0xFFFBB04C),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _backgroundCheckConsent = !_backgroundCheckConsent;
                      });
                    },
                    child: const Text(
                      'By checking this box, you are authorizing us to initiate a background check. Please refer to our terms and conditions.',
                      style: TextStyle(fontSize: 14),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 30),

            // Submit button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submitVerification,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFBB04C),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Submit',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
} 