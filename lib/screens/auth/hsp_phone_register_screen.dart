import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/auth_service.dart';
import 'hsp_phone_otp_screen.dart';

class HspPhoneRegisterScreen extends StatefulWidget {
  const HspPhoneRegisterScreen({super.key});

  @override
  State<HspPhoneRegisterScreen> createState() => _HspPhoneRegisterScreenState();
}

class _HspPhoneRegisterScreenState extends State<HspPhoneRegisterScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _referralCodeController = TextEditingController();
  final AuthService _authService = AuthService();
  bool _acceptTerms = false;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _phoneController.dispose();
    _nameController.dispose();
    _referralCodeController.dispose();
    super.dispose();
  }

  String _formatPhoneNumber(String phoneNumber) {
    print('📱 Original phone input: "$phoneNumber"');
    
    // Remove any non-digit characters
    final digits = phoneNumber.replaceAll(RegExp(r'\D'), '');
    print('📱 Digits only: "$digits"');
    
    String formatted;
    // Add country code if not present
    if (digits.length == 10) {
      formatted = '+1$digits';
    } else if (digits.length == 11 && digits.startsWith('1')) {
      formatted = '+$digits';
    } else {
      formatted = phoneNumber; // Return as-is if already formatted
    }
    
    print('📱 Formatted phone: "$formatted"');
    print('📱 Length: ${formatted.length}');
    
    return formatted;
  }

  Future<void> _register() async {
    final phoneNumber = _formatPhoneNumber(_phoneController.text.trim());
    final name = _nameController.text.trim();
    final referralCode = _referralCodeController.text.trim();

    // Validation
    if (name.isEmpty || phoneNumber.isEmpty || referralCode.isEmpty) {
      setState(() {
        _errorMessage = 'Please fill in all required fields';
      });
      return;
    }

    if (phoneNumber.length < 12) {
      setState(() {
        _errorMessage = 'Please enter a valid phone number';
      });
      return;
    }

    if (!_acceptTerms) {
      setState(() {
        _errorMessage = 'Please accept the terms and conditions';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      print('🔍 Starting provider registration for phone: $phoneNumber');
      
      // Check if phone number already exists
      final phoneQuery = await FirebaseFirestore.instance
          .collection('providers')
          .where('phoneNumber', isEqualTo: phoneNumber)
          .limit(1)
          .get();

      if (phoneQuery.docs.isNotEmpty) {
        setState(() {
          _errorMessage = 'This phone number is already registered. Please sign in instead.';
          _isLoading = false;
        });
        return;
      }

      print('🔍 Verifying referral code: "$referralCode"');
      // Verify referral code before proceeding
      final referralQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('referralCode', isEqualTo: referralCode.trim().toUpperCase())
          .limit(1)
          .get();
      
      print('📋 Referral query result: ${referralQuery.docs.length} documents found');
      
      if (referralQuery.docs.isEmpty) {
        // Try case-sensitive search as backup
        final backupQuery = await FirebaseFirestore.instance
            .collection('users')
            .where('referralCode', isEqualTo: referralCode.trim())
            .limit(1)
            .get();
            
        print('📋 Backup query result: ${backupQuery.docs.length} documents found');
        
        if (backupQuery.docs.isEmpty) {
          setState(() {
            _errorMessage = 'Invalid referral code "$referralCode". Please check the code and try again.';
            _isLoading = false;
          });
          return;
        } else {
          // Use backup query results
          final referrerUserId = backupQuery.docs.first.id;
          print('✅ Referral code verified (backup): $referralCode -> $referrerUserId');
        }
      }
      
      final referrerUserId = referralQuery.docs.first.id;
      print('✅ Referral code verified: $referralCode -> $referrerUserId');

      // Send OTP for phone verification
      print('📱 Sending OTP to: $phoneNumber');
      await _authService.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        onCodeSent: (verificationId, resendToken) {
          print('✅ OTP sent successfully to: $phoneNumber');
          print('📋 Verification ID: ${verificationId.substring(0, 20)}...');
          if (!mounted) return;
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => HspPhoneOtpScreen(
                phoneNumber: phoneNumber,
                verificationId: verificationId,
                isLogin: false,
                providerName: name,
                referralCode: referralCode,
                referrerUserId: referrerUserId,
              ),
            ),
          );
        },
        onVerificationFailed: (error) {
          if (!mounted) return;
          print('🚨 Firebase Phone Auth Error:');
          print('   Code: ${error.code}');
          print('   Message: ${error.message}');
          print('   Phone: $phoneNumber');
          setState(() {
            _errorMessage = 'Failed to send OTP: ${error.message}';
            _isLoading = false;
          });
        },
        onVerificationCompleted: (credential) async {
          // Auto-verification completed - this is rare but possible
          try {
            final userCredential = await _authService.signInWithPhoneCredential(credential);
            final user = userCredential.user;
            
            if (user != null) {
              // Create provider profile
              await _createProviderProfile(user.uid, phoneNumber, name, referralCode, referrerUserId);
            }
          } catch (e) {
            if (mounted) {
              setState(() {
                _errorMessage = 'Registration failed: $e';
                _isLoading = false;
              });
            }
          }
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Registration failed: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _createProviderProfile(String userId, String phoneNumber, String name, String referralCode, String referrerUserId) async {
    try {
      // Create provider profile in Firestore
      final providerData = {
        'phoneNumber': phoneNumber,
        'name': name,
        'status': 'pending_verification', // Status field for admin approval
        'createdAt': FieldValue.serverTimestamp(),
        'verificationStep': 'documents_pending',
        'role': 'provider',
        'referralCode': referralCode,
        'referred_by_user_ids': [referrerUserId],
      };

      await FirebaseFirestore.instance
          .collection('providers')
          .doc(userId)
          .set(providerData);

      // Update the referrer user's referred_provider_ids
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(referrerUserId)
            .update({
          'referred_provider_ids': FieldValue.arrayUnion([userId]),
        });
        print('✅ Updated referrer user with new provider');
      } catch (e) {
        print('Error updating referrer user: $e');
        // Continue with registration - referral tracking is not critical
      }

      if (!mounted) return;

      // Navigate to verification screen (you might want to create a phone-specific verification screen)
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Registration successful! Please complete document verification.'),
          backgroundColor: Colors.green,
        ),
      );

      // For now, navigate back to login - in a full implementation you'd navigate to verification
      Navigator.of(context).popUntil((route) => route.isFirst);
      
    } catch (e) {
      print('Error creating provider profile: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to create provider profile: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBB04C),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Custom wave header with logo
            Stack(
              children: [
                CustomPaint(
                  size: Size(MediaQuery.of(context).size.width, 120),
                  painter: WavePainter(),
                ),
                // Home icon with sparkles
                Positioned(
                  top: 40,
                  right: 40,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Stack(
                      children: [
                        const Icon(
                          Icons.home,
                          size: 40,
                          color: Color(0xFFFBB04C),
                        ),
                        Positioned(
                          top: -5,
                          right: -5,
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.star,
                              size: 8,
                              color: Color(0xFFFBB04C),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            
            Padding(
              padding: const EdgeInsets.all(30.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Create Provider Account',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 30),
                  
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
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  
                  // Name field
                  const Text(
                    'Full Name',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _nameController,
                    keyboardType: TextInputType.name,
                    decoration: const InputDecoration(
                      fillColor: Colors.white,
                      filled: true,
                      border: OutlineInputBorder(
                        borderSide: BorderSide.none,
                        borderRadius: BorderRadius.all(Radius.circular(8.0)),
                      ),
                      hintText: 'Enter your full name',
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Phone number field
                  const Text(
                    'Phone Number',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    child: Row(
                      children: [
                        // Country code prefix
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          decoration: const BoxDecoration(
                            border: Border(
                              right: BorderSide(color: Colors.grey, width: 0.5),
                            ),
                          ),
                          child: const Text(
                            '+1',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        // Phone number field
                        Expanded(
                          child: TextField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(10),
                            ],
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              hintText: '(123) 456-7890',
                              contentPadding: EdgeInsets.symmetric(horizontal: 16.0),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Referral Code field
                  const Text(
                    'Referral Code',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _referralCodeController,
                    decoration: const InputDecoration(
                      fillColor: Colors.white,
                      filled: true,
                      border: OutlineInputBorder(
                        borderSide: BorderSide.none,
                        borderRadius: BorderRadius.all(Radius.circular(8.0)),
                      ),
                      hintText: 'Enter referral code',
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Terms and conditions checkbox
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Checkbox(
                        value: _acceptTerms,
                        onChanged: (value) {
                          setState(() {
                            _acceptTerms = value ?? false;
                          });
                        },
                        activeColor: Colors.white,
                        checkColor: const Color(0xFFFBB04C),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _acceptTerms = !_acceptTerms;
                            });
                          },
                          child: const Text(
                            'By checking this box, you are agreeing to our terms and conditions.',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 30),
                  
                  // Continue button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _register,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFBB04C),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
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
                              'Send OTP',
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
    path.lineTo(0, size.height * 0.7);
    path.quadraticBezierTo(
      size.width * 0.3, 
      size.height * 1.1, 
      size.width, 
      size.height * 0.7
    );
    path.lineTo(size.width, 0);
    path.close();
    
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
