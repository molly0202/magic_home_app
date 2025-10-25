import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../widgets/app_logo.dart';
import '../../services/auth_service.dart';
import '../home/hsp_home_screen.dart';
import 'hsp_verification_screen.dart';

class HspPhoneOtpScreen extends StatefulWidget {
  final String phoneNumber;
  final String verificationId;
  final bool isLogin;
  final String? providerId;
  final String? providerName;
  final String? referralCode;
  final String? referrerUserId;

  const HspPhoneOtpScreen({
    super.key,
    required this.phoneNumber,
    required this.verificationId,
    required this.isLogin,
    this.providerId,
    this.providerName,
    this.referralCode,
    this.referrerUserId,
  });

  @override
  State<HspPhoneOtpScreen> createState() => _HspPhoneOtpScreenState();
}

class _HspPhoneOtpScreenState extends State<HspPhoneOtpScreen> {
  final List<TextEditingController> _otpControllers = List.generate(6, (index) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (index) => FocusNode());
  final TextEditingController _hiddenOtpController = TextEditingController();
  final AuthService _authService = AuthService();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    for (var controller in _otpControllers) {
      controller.dispose();
    }
    for (var focusNode in _focusNodes) {
      focusNode.dispose();
    }
    _hiddenOtpController.dispose();
    super.dispose();
  }

  String get _otpCode {
    return _otpControllers.map((controller) => controller.text).join();
  }

  Future<void> _verifyOTP() async {
    final otpCode = _otpCode;
    
    if (otpCode.length != 6) {
      setState(() {
        _errorMessage = 'Please enter the complete 6-digit OTP';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final credential = _authService.getCredential(
        verificationId: widget.verificationId,
        smsCode: otpCode,
      );

      final userCredential = await _authService.signInWithPhoneCredential(credential);
      final user = userCredential.user;

      if (user == null) {
        throw Exception('Authentication failed');
      }

      if (widget.isLogin) {
        // Login flow - navigate to HSP home
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => HspHomeScreen(user: user)),
            (route) => false,
          );
        }
      } else {
        // Registration flow - create provider profile
        await _createProviderProfile(user.uid);
      }

    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Invalid OTP. Please try again.';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _createProviderProfile(String userId) async {
    try {
      // Create provider profile in Firestore
      final providerData = {
        'phoneNumber': widget.phoneNumber,
        'name': widget.providerName,
        'status': 'pending_verification',
        'createdAt': FieldValue.serverTimestamp(),
        'verificationStep': 'documents_pending',
        'role': 'provider',
        'referralCode': widget.referralCode,
        'referred_by_user_ids': [widget.referrerUserId],
      };

      await FirebaseFirestore.instance
          .collection('providers')
          .doc(userId)
          .set(providerData);

      // Update the referrer user's referred_provider_ids
      if (widget.referrerUserId != null) {
        try {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(widget.referrerUserId!)
              .update({
            'referred_provider_ids': FieldValue.arrayUnion([userId]),
          });
          print('✅ Updated referrer user with new provider');
        } catch (e) {
          print('Error updating referrer user: $e');
        }
      }

      if (!mounted) return;

      // Navigate to document verification screen
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => HspVerificationScreen(
            user: firebase_auth.FirebaseAuth.instance.currentUser!,
            email: null, // No email for phone auth
            phoneNumber: widget.phoneNumber,
          ),
        ),
        (route) => false,
      );
      
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

  Future<void> _resendOTP() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _authService.verifyPhoneNumber(
        phoneNumber: widget.phoneNumber,
        onCodeSent: (verificationId, resendToken) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('OTP sent successfully!'),
                backgroundColor: Colors.green,
              ),
            );
          }
        },
        onVerificationFailed: (error) {
          if (mounted) {
            setState(() {
              _errorMessage = 'Failed to resend OTP: ${error.message}';
            });
          }
        },
        onVerificationCompleted: (credential) {
          // Handle auto-verification if needed
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to resend OTP: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showSMSHelpDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('SMS Delivery Help'),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('If you\'re not receiving SMS codes:'),
              SizedBox(height: 10),
              Text('• Check spam/blocked messages'),
              Text('• Wait up to 10 minutes for delivery'),
              Text('• Some carriers block automated SMS'),
              Text('• Try a Google Voice number'),
              SizedBox(height: 10),
              Text('Contact support if the issue persists.'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
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
                  const Text(
                    'Verify Phone Number',
                    style: TextStyle(
                      fontSize: 28, 
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'We sent a 6-digit verification code to ${widget.phoneNumber}',
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 40),
                  
                  // OTP input fields with auto-fill support
                  Stack(
                    children: [
                      // Hidden text field for SMS auto-fill
                      Positioned(
                        left: 0,
                        top: 0,
                        child: Container(
                          width: 1,
                          height: 1,
                          child: TextField(
                            controller: _hiddenOtpController,
                            keyboardType: TextInputType.number,
                            autofillHints: const [AutofillHints.oneTimeCode],
                            style: const TextStyle(color: Colors.transparent),
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              fillColor: Colors.transparent,
                              filled: true,
                            ),
                            onChanged: (value) {
                              if (value.length == 6) {
                                // Auto-fill detected, populate individual fields
                                for (int i = 0; i < 6; i++) {
                                  _otpControllers[i].text = value[i];
                                }
                                // Auto-verify if we have 6 digits
                                _verifyOTP();
                              }
                            },
                          ),
                        ),
                      ),
                      // Visible OTP input fields
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: List.generate(6, (index) {
                          return SizedBox(
                            width: 45,
                            height: 55,
                            child: TextField(
                              controller: _otpControllers[index],
                              focusNode: _focusNodes[index],
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              maxLength: 1,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                              decoration: InputDecoration(
                                fillColor: Colors.white,
                                filled: true,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide.none,
                                ),
                                counterText: '',
                              ),
                              onChanged: (value) {
                                if (value.length > 1) {
                                  // Handle paste or auto-fill in individual field
                                  if (value.length == 6) {
                                    // Full OTP pasted
                                    for (int i = 0; i < 6; i++) {
                                      _otpControllers[i].text = i < value.length ? value[i] : '';
                                    }
                                    _verifyOTP();
                                    return;
                                  } else {
                                    // Multiple digits in one field, take only first
                                    _otpControllers[index].text = value[0];
                                    value = value[0];
                                  }
                                }
                                
                                if (value.isNotEmpty && index < 5) {
                                  _focusNodes[index + 1].requestFocus();
                                } else if (value.isEmpty && index > 0) {
                                  _focusNodes[index - 1].requestFocus();
                                }
                              },
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                            ),
                          );
                        }),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 20),
                  
                  if (_errorMessage != null)
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.white),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  
                  const SizedBox(height: 30),
                  
                  // Verify button
                  ElevatedButton(
                    onPressed: _isLoading ? null : _verifyOTP,
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
                      : Text(
                          widget.isLogin ? 'Sign In' : 'Verify & Continue',
                          style: const TextStyle(
                            fontSize: 18, 
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Resend OTP and alternatives
                  Column(
                    children: [
                      TextButton(
                        onPressed: _isLoading ? null : _resendOTP,
                        child: const Text(
                          'Didn\'t receive code? Resend',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'SMS can take 5-10 minutes. Check spam/blocked messages.',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),
                      TextButton(
                        onPressed: () {
                          // Show help dialog
                          _showSMSHelpDialog();
                        },
                        child: const Text(
                          'Still no SMS? Get help',
                          style: TextStyle(
                            color: Colors.white,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
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
