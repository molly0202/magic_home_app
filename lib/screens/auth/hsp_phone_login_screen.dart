import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../widgets/app_logo.dart';
import '../../services/auth_service.dart';
import '../home/hsp_home_screen.dart';
import 'hsp_phone_register_screen.dart';
import 'hsp_phone_otp_screen.dart';

class HspPhoneLoginScreen extends StatefulWidget {
  const HspPhoneLoginScreen({super.key});

  @override
  State<HspPhoneLoginScreen> createState() => _HspPhoneLoginScreenState();
}

class _HspPhoneLoginScreenState extends State<HspPhoneLoginScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final AuthService _authService = AuthService();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  String _formatPhoneNumber(String phoneNumber) {
    // Remove any non-digit characters
    final digits = phoneNumber.replaceAll(RegExp(r'\D'), '');
    
    // Add country code if not present
    if (digits.length == 10) {
      return '+1$digits';
    } else if (digits.length == 11 && digits.startsWith('1')) {
      return '+$digits';
    }
    
    return phoneNumber; // Return as-is if already formatted
  }

  Future<void> _sendOTP() async {
    final phoneNumber = _formatPhoneNumber(_phoneController.text.trim());
    
    if (phoneNumber.isEmpty || phoneNumber.length < 12) {
      setState(() {
        _errorMessage = 'Please enter a valid phone number';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // First check if provider exists with this phone number
      final providerQuery = await FirebaseFirestore.instance
          .collection('providers')
          .where('phoneNumber', isEqualTo: phoneNumber)
          .limit(1)
          .get();

      if (providerQuery.docs.isEmpty) {
        setState(() {
          _errorMessage = 'No provider account found with this phone number. Please register first.';
          _isLoading = false;
        });
        return;
      }

      // Send OTP
      await _authService.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        onCodeSent: (verificationId, resendToken) {
          if (!mounted) return;
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => HspPhoneOtpScreen(
                phoneNumber: phoneNumber,
                verificationId: verificationId,
                isLogin: true,
                providerId: providerQuery.docs.first.id,
              ),
            ),
          );
        },
        onVerificationFailed: (error) {
          if (!mounted) return;
          print('🚨 Phone Auth Error: ${error.code} - ${error.message}');
          String userFriendlyMessage = 'Failed to send OTP: ${error.message}';
          
          // Provide specific error messages
          switch (error.code) {
            case 'invalid-phone-number':
              userFriendlyMessage = 'Invalid phone number. Use format: +1234567890';
              break;
            case 'too-many-requests':
              userFriendlyMessage = 'Too many attempts. Please wait 30 minutes and try again.';
              break;
            case 'app-not-authorized':
              userFriendlyMessage = 'App not authorized for phone auth. Check Firebase Console.';
              break;
            case 'network-request-failed':
              userFriendlyMessage = 'Network error. Check your internet connection.';
              break;
            default:
              userFriendlyMessage = 'Phone verification failed: ${error.message}';
          }
          
          setState(() {
            _errorMessage = userFriendlyMessage;
            _isLoading = false;
          });
        },
        onVerificationCompleted: (credential) async {
          // Auto-verification completed
          try {
            final userCredential = await _authService.signInWithPhoneCredential(credential);
            final user = userCredential.user;
            
            if (user != null && mounted) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => HspHomeScreen(user: user)),
              );
            }
          } catch (e) {
            if (mounted) {
              setState(() {
                _errorMessage = 'Login failed: $e';
                _isLoading = false;
              });
            }
          }
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to send OTP: $e';
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
              padding: const EdgeInsets.all(30.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Provider Sign In',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Enter your phone number to access your provider dashboard',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 30),
                  
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
                      ),
                    ),
                  
                  const SizedBox(height: 20),
                  
                  // Phone number input
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
                  
                  const SizedBox(height: 30),
                  
                  ElevatedButton(
                    onPressed: _isLoading ? null : _sendOTP,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFFFBB04C),
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Color(0xFFFBB04C),
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Send OTP',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'New provider? ',
                        style: TextStyle(color: Colors.white),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const HspPhoneRegisterScreen(),
                            ),
                          );
                        },
                        child: const Text(
                          'Register Here',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
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
