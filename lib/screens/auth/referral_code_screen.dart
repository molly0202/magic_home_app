import 'package:flutter/material.dart';
import '../../main.dart';
import '../../services/auth_service.dart';
import '../auth/login_screen.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../widgets/app_logo.dart';

class ReferralCodeScreen extends StatefulWidget {
  const ReferralCodeScreen({super.key});

  @override
  State<ReferralCodeScreen> createState() => _ReferralCodeScreenState();
}

class _ReferralCodeScreenState extends State<ReferralCodeScreen> {
  final TextEditingController _referralController = TextEditingController();
  final AuthService _authService = AuthService();
  bool _isLoading = false;

  @override
  void dispose() {
    _referralController.dispose();
    super.dispose();
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
                  
                  const SizedBox(height: 200),
                  
                  // Continue button
                  Padding(
                    padding: const EdgeInsets.only(bottom: 30.0),
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() => _isLoading = true);
                        // Allow a small delay to show loading state
                        Future.delayed(const Duration(milliseconds: 500), () {
                          if (!mounted) return;
                          
                          // Get the current user
                          final user = _authService.currentUser;
                          if (user != null) {
                            // Navigate to HomeScreen
                            Navigator.pushNamedAndRemoveUntil(
                              context,
                              '/home',
                              (route) => false,
                              arguments: {'googleUser': null, 'googleSignIn': GoogleSignIn(
                                clientId: '441732602904-ib5itb3on72gkv6qffdjv6g58kgvmpnf.apps.googleusercontent.com',
                              )},
                            );
                          } else {
                            // Fallback - show error
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Error: User data not found')),
                            );
                            setState(() => _isLoading = false);
                          }
                        });
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