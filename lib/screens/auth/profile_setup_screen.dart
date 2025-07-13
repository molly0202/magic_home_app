import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../widgets/app_logo.dart';
import '../../main.dart';

class ProfileSetupScreen extends StatefulWidget {
  final String userId;
  final String? referralCode;

  const ProfileSetupScreen({
    super.key, 
    required this.userId,
    this.referralCode,
  });

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  File? _profileImage;
  bool _isLoading = false;
  String? _errorMessage;
  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        setState(() {
          _profileImage = File(pickedFile.path);
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to pick image: $e';
      });
    }
  }

  Future<String?> _uploadProfileImage() async {
    if (_profileImage == null) return null;

    const maxRetries = 3;
    int retryCount = 0;
    
    while (retryCount < maxRetries) {
      try {
        print('Uploading profile image (attempt ${retryCount + 1}/$maxRetries)');
        
        // Fix storage path to match Firebase Storage rules
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('profile_pictures')
            .child(widget.userId)
            .child('profile.jpg');
        
        final uploadTask = storageRef.putFile(_profileImage!);
        final snapshot = await uploadTask;
        final downloadUrl = await snapshot.ref.getDownloadURL();
        
        print('Profile image uploaded successfully: $downloadUrl');
        return downloadUrl;
        
      } catch (e) {
        retryCount++;
        print('Image upload failed (attempt $retryCount/$maxRetries): $e');
        
        if (retryCount >= maxRetries) {
          print('Image upload failed after $maxRetries attempts');
          
          // Log the failure for debugging
          try {
            await FirebaseFirestore.instance
                .collection('upload_errors')
                .add({
              'userId': widget.userId,
              'errorType': 'profile_image_upload',
              'error': e.toString(),
              'timestamp': FieldValue.serverTimestamp(),
              'attempts': maxRetries,
            });
          } catch (logError) {
            print('Failed to log upload error: $logError');
          }
          
          throw e; // Re-throw for handling in calling function
        }
        
        // Wait before retry (exponential backoff)
        await Future.delayed(Duration(seconds: retryCount * 2));
      }
    }
    
    return null; // Should never reach here
  }

  Future<void> _saveProfile() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      String? profileImageUrl;
      bool profileUpdateSuccessful = false;
      
      // Upload profile image if selected (with retry)
      if (_profileImage != null) {
        try {
          profileImageUrl = await _uploadProfileImage();
          print('Profile image uploaded successfully');
        } catch (e) {
          print('Profile image upload failed: $e');
          // Continue without profile image - don't block account setup
        }
      }

      // Update user profile (critical operation)
      try {
        final updateData = {
          'profileCompleted': true,
          if (profileImageUrl != null) 'profileImageUrl': profileImageUrl,
          'profileSetupTimestamp': FieldValue.serverTimestamp(),
        };
        
        print('Updating user profile with data: $updateData');
        print('Profile image URL: $profileImageUrl');
        
        await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.userId)
            .update(updateData);
        
        profileUpdateSuccessful = true;
        print('User profile updated successfully');
        
      } catch (e) {
        print('Critical error: Failed to update user profile: $e');
        throw Exception('Failed to complete account setup. Please try again.');
      }

      // Referral code processing is now handled in ReferralCodeScreen
      // No need to process referral code here

      if (!mounted) return;

      // Navigate to home screen immediately after profile update
      print('Navigating to home screen');
      final currentUser = FirebaseAuth.instance.currentUser;
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/home',
        (route) => false,
        arguments: {'firebaseUser': currentUser},
      );
      
    } catch (e) {
      print('Profile setup failed: $e');
      
      // Show user-friendly error message
      String userMessage = 'Failed to complete account setup.';
      if (e.toString().contains('network')) {
        userMessage = 'Network error. Please check your connection and try again.';
      } else if (e.toString().contains('permission')) {
        userMessage = 'Permission error. Please try again.';
      }
      
      setState(() {
        _errorMessage = userMessage;
        _isLoading = false;
      });
    }
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBB04C),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Custom wave with logo
            Stack(
              children: [
                CustomPaint(
                  size: Size(MediaQuery.of(context).size.width, 100),
                  painter: WavePainter(),
                ),
                Positioned(
                  top: 0,
                  right: 30,
                  child: AppLogo(size: 80),
                ),
              ],
            ),
            
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 20),
                  const Text(
                    'Complete Your Profile',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Add a profile picture to complete your account setup.',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 50),
                  
                  // Profile image picker
                  Center(
                    child: GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        width: 150,
                        height: 150,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 4),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: _profileImage != null
                            ? ClipOval(
                                child: Image.file(
                                  _profileImage!,
                                  fit: BoxFit.cover,
                                  width: 150,
                                  height: 150,
                                ),
                              )
                            : const Icon(
                                Icons.add_a_photo,
                                size: 60,
                                color: Color(0xFFFBB04C),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Center(
                    child: Text(
                      'Tap to add profile picture',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 50),
                  
                  // Error message
                  if (_errorMessage != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red[100],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red),
                      ),
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  
                  const SizedBox(height: 30),
                  
                  // Save button
                  ElevatedButton(
                    onPressed: _isLoading ? null : _saveProfile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFBB04C),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      elevation: 5,
                      disabledBackgroundColor: Colors.grey,
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
                            'Continue',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class WavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    
    final path = Path();
    
    path.moveTo(0, 0);
    path.lineTo(0, size.height * 0.8);
    path.quadraticBezierTo(
      size.width * 0.25, 
      size.height * 1.2, 
      size.width, 
      size.height * 0.8
    );
    path.lineTo(size.width, 0);
    path.close();
    
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
} 