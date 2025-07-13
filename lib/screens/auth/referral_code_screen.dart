import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../main.dart';
import '../auth/login_screen.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../widgets/app_logo.dart';
import 'profile_setup_screen.dart';

class ReferralCodeScreen extends StatefulWidget {
  const ReferralCodeScreen({super.key});

  @override
  State<ReferralCodeScreen> createState() => _ReferralCodeScreenState();
}

class _ReferralCodeScreenState extends State<ReferralCodeScreen> {
  final TextEditingController _referralController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _referralController.dispose();
    super.dispose();
  }

  Future<bool> _processReferralCode(String referralCode, String currentUserId) async {
    const maxRetries = 2;
    int retryCount = 0;
    
    while (retryCount < maxRetries) {
      try {
        print('Processing referral code: $referralCode (attempt ${retryCount + 1}/$maxRetries)');
        
        // Find the user who owns this referral code
        final referralQuery = await FirebaseFirestore.instance
            .collection('users')
            .where('referralCode', isEqualTo: referralCode)
            .limit(1)
            .get();
        
        if (referralQuery.docs.isEmpty) {
          setState(() {
            _errorMessage = 'Invalid referral code. Please enter a valid code or continue without one.';
          });
          return false;
        }
        
        final referrerDoc = referralQuery.docs.first;
        final referrerId = referrerDoc.id;
        
        print('Found referrer: $referrerId for code: $referralCode');
        
        // Create bidirectional referral relationship
        final batch = FirebaseFirestore.instance.batch();
        
        // Add referrer to current user's referred_by_user_ids
        batch.update(
          FirebaseFirestore.instance.collection('users').doc(currentUserId),
          {
            'referred_by_user_ids': FieldValue.arrayUnion([referrerId]),
          },
        );
        
        // Add current user to referrer's referred_user_ids
        batch.update(
          FirebaseFirestore.instance.collection('users').doc(referrerId),
          {
            'referred_user_ids': FieldValue.arrayUnion([currentUserId]),
          },
        );
        
        await batch.commit();
        print('Referral relationship established: $currentUserId <- $referrerId');
        return true;
        
      } catch (e) {
        retryCount++;
        print('Error processing referral code (attempt $retryCount/$maxRetries): $e');
        
        if (retryCount >= maxRetries) {
          // After all retries failed, show user-friendly error and allow to continue
          print('Referral code processing failed after $maxRetries attempts');
          
          final shouldContinue = await _showContinueAnywayDialog();
          if (shouldContinue) {
            print('User chose to continue without referral code');
            return true; // Continue without referral
          } else {
            setState(() {
              _errorMessage = 'Unable to process referral code. Please try again or continue without it.';
            });
            return false; // Let user try again
          }
        }
        
        // Brief wait before retry
        await Future.delayed(Duration(seconds: retryCount));
      }
    }
    
    return false; // Should never reach here
  }

  Future<bool> _showContinueAnywayDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Connection Issue'),
        content: const Text(
          'We\'re having trouble processing your referral code due to network issues. You can:\n\n'
          '• Continue without the referral code\n'
          '• Try again\n'
          '• Add the referral code later in your profile'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Try Again'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFBB04C),
              foregroundColor: Colors.white,
            ),
            child: const Text('Continue Anyway'),
          ),
        ],
      ),
    );
    
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBB04C), // Orange background color
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
                    'If you have a referral code, you can enter it here now. Or you can always enter it in your profile page later.',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 40),
                  
                  // Referral code input - Updated hint text to emphasize optional
                  TextField(
                    controller: _referralController,
                    decoration: const InputDecoration(
                      fillColor: Colors.white,
                      filled: true,
                      border: OutlineInputBorder(
                        borderSide: BorderSide.none,
                        borderRadius: BorderRadius.all(Radius.circular(8.0)),
                      ),
                      hintText: 'Enter referral code (optional)',
                      floatingLabelBehavior: FloatingLabelBehavior.always,
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
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
                  
                  const SizedBox(height: 160),
                  
                  // Continue button
                  Padding(
                    padding: const EdgeInsets.only(bottom: 30.0),
                    child: ElevatedButton(
                      onPressed: () async {
                        setState(() {
                          _isLoading = true;
                          _errorMessage = null;
                        });
                        
                        String referralCode = _referralController.text.trim();
                        
                        // Get the current user from Firebase Auth directly
                        final firebaseUser = FirebaseAuth.instance.currentUser;
                        if (firebaseUser == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Error: User not found. Please try logging in again.')),
                          );
                          setState(() => _isLoading = false);
                          return;
                        }
                        
                        // Process referral code if provided
                        if (referralCode.isNotEmpty) {
                          final success = await _processReferralCode(referralCode, firebaseUser.uid);
                          if (!success) {
                            // Error already shown in _processReferralCode
                            setState(() => _isLoading = false);
                            return;
                          }
                        }
                        
                        if (!mounted) return;
                        
                        // Navigate to ProfileSetupScreen (no referral code needed since it's already processed)
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ProfileSetupScreen(
                              userId: firebaseUser.uid,
                              referralCode: null, // Already processed
                            ),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFBB04C),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        elevation: 5,
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
                  ),
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