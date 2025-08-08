import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/auth_service.dart';
import '../../widgets/app_logo.dart';
import 'referral_code_screen.dart';
import 'otp_verification_screen.dart';

class PhoneVerificationScreen extends StatefulWidget {
  const PhoneVerificationScreen({super.key});

  @override
  State<PhoneVerificationScreen> createState() => _PhoneVerificationScreenState();
}

class _PhoneVerificationScreenState extends State<PhoneVerificationScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final AuthService _authService = AuthService();
  bool _isLoading = false;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }
  
  Future<void> _verifyPhone() async {
    final phoneNumber = _phoneController.text.trim();
    
    if (phoneNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your phone number')),
      );
      return;
    }
    
    setState(() => _isLoading = true);
    
    try {
      await _authService.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        onCodeSent: (verificationId, resendToken) {
          if (!mounted) return;
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => OtpVerificationScreen(
                phoneNumber: phoneNumber,
                verificationId: verificationId,
              ),
            ),
          );
        },
        onVerificationFailed: (error) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Verification failed: ${error.toString()}')),
          );
        },
        onVerificationCompleted: (credential) async {
          // Optionally, you can auto-link or sign in here
          try {
            await _authService.linkWithPhoneCredential(credential);
            // Success! Optionally navigate or show a message
          } catch (e) {
            // Handle error
          }
        },
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send OTP: ${e.toString()}')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
                  const Text(
                    'Add phone number',
                    style: TextStyle(
                      fontSize: 28, 
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'We will send an OTP verification to you. We require a phone number so service providers can contact you.',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 40),
                  
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
                  
                  // Add a large SizedBox instead of Spacer
                  const SizedBox(height: 200),
                  
                  // Continue button
                  Padding(
                    padding: const EdgeInsets.only(bottom: 30.0),
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _verifyPhone,
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