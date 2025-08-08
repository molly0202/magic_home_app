import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:google_sign_in/google_sign_in.dart';
import '../../services/auth_service.dart';
import '../../widgets/app_logo.dart';
import '../../main.dart';
import '../auth/login_screen.dart';
import 'referral_code_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';

class OtpVerificationScreen extends StatefulWidget {
  final String phoneNumber;
  final String verificationId;
  final void Function()? onVerified;
  
  const OtpVerificationScreen({
    super.key,
    required this.phoneNumber,
    required this.verificationId,
    this.onVerified,
  });

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final List<TextEditingController> _otpControllers = List.generate(
    6, 
    (_) => TextEditingController()
  );
  
  final List<FocusNode> _focusNodes = List.generate(
    6, 
    (_) => FocusNode()
  );
  
  final AuthService _authService = AuthService();
  bool _isLoading = false;
  int _timerSeconds = 60;
  Timer? _timer;
  String _errorMessage = '';
  bool _isVerified = false;
  
  @override
  void initState() {
    super.initState();
    _startTimer();
    
    // For demo purposes, pre-fill the OTP with "123456"
    // In a production app, this would be removed
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _prefilDemoOtp();
    });
  }
  
  // Demo method - would be removed in production
  void _prefilDemoOtp() {
    // Simulate typing the code after a short delay
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      
      const demoCode = "123456";
      for (int i = 0; i < 6; i++) {
        _otpControllers[i].text = demoCode[i];
      }
      
      // Show a hint
      setState(() {
        _errorMessage = 'Demo code auto-filled. In production, this would come via SMS.';
      });
    });
  }
  
  void _startTimer() {
    _timerSeconds = 60;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timerSeconds > 0) {
        setState(() {
          _timerSeconds--;
        });
      } else {
        _timer?.cancel();
      }
    });
  }

  @override
  void dispose() {
    for (var controller in _otpControllers) {
      controller.dispose();
    }
    for (var focusNode in _focusNodes) {
      focusNode.dispose();
    }
    _timer?.cancel();
    super.dispose();
  }
  
  String get _otp {
    return _otpControllers.map((controller) => controller.text).join();
  }
  
  void _onOtpDigitChanged(int index, String value) {
    setState(() {
      _errorMessage = '';
    });
    
    if (value.isNotEmpty && index < 5) {
      // Move to next field when digit is entered
      _focusNodes[index + 1].requestFocus();
    } else if (value.isEmpty && index > 0) {
      // Move to previous field when digit is deleted
      _focusNodes[index - 1].requestFocus();
    }
    
    // If all fields are filled, automatically verify OTP after a short delay
    if (_otpControllers.every((controller) => controller.text.isNotEmpty)) {
      // Add a short delay before verification to give feedback
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted && !_isLoading && !_isVerified) {
          _verifyOtp();
        }
      });
    }
  }
  
  // Allow pasting the entire OTP
  void _handlePaste() async {
    final ClipboardData? data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data != null && data.text != null) {
      final String text = data.text!.trim();
      
      // Check if pasted content is numerical and has 6 digits
      if (text.length == 6 && RegExp(r'^\d{6}$').hasMatch(text)) {
        for (int i = 0; i < 6; i++) {
          _otpControllers[i].text = text[i];
        }
        
        // Verify after a short delay
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted && !_isLoading && !_isVerified) {
            _verifyOtp();
          }
        });
      }
    }
  }
  
  Future<void> _verifyOtp() async {
    final otp = _otp;
    if (otp.length != 6) {
      setState(() {
        _errorMessage = 'Please enter the complete 6-digit code';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final credential = _authService.getCredential(
        verificationId: widget.verificationId,
        smsCode: otp,
      );

      if (FirebaseAuth.instance.currentUser != null) {
        await _authService.linkWithPhoneCredential(credential);
        if (widget.onVerified != null) widget.onVerified!();
        // Optionally navigate or show success
      } else {
        await _authService.signInWithPhoneCredential(credential);
        if (widget.onVerified != null) widget.onVerified!();
        // Optionally navigate or show success
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorMessage = 'Verification failed:  [${e.toString()}]';
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
  
  void _resendOtp() {
    if (_timerSeconds == 0) {
      setState(() {
        _errorMessage = '';
        _isLoading = true;
      });
      
      // Resend OTP via Firebase
      _authService.verifyPhoneNumber(
        phoneNumber: widget.phoneNumber,
        onCodeSent: (verificationId, resendToken) {
          if (!mounted) return;
          
          setState(() {
            _isLoading = false;
          });
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('New verification code sent')),
          );
          _startTimer();
        },
        onVerificationFailed: (error) {
          if (!mounted) return;
          
          setState(() {
            _isLoading = false;
            _errorMessage = 'Failed to resend code: [${error.toString()}]';
          });
        },
        onVerificationCompleted: (credential) {
          if (!mounted) return;
          
          setState(() {
            _isLoading = false;
            _isVerified = true;
          });
          // Optionally handle auto-verification
        },
      );
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
                    'Verify phone number',
                    style: TextStyle(
                      fontSize: 28, 
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Enter the 6-digit code sent to ${widget.phoneNumber}',
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 10),
                  
                  // Error message
                  if (_errorMessage.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        _errorMessage,
                        style: TextStyle(
                          color: _errorMessage.contains('production') 
                            ? Colors.white70 
                            : Colors.red[100],
                          fontSize: 14,
                        ),
                      ),
                    ),
                    
                  const SizedBox(height: 20),
                  
                  // OTP input fields
                  GestureDetector(
                    onTap: _handlePaste,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: List.generate(
                        6,
                        (index) => SizedBox(
                          width: 45,
                          height: 50,
                          child: TextField(
                            controller: _otpControllers[index],
                            focusNode: _focusNodes[index],
                            textAlign: TextAlign.center,
                            keyboardType: TextInputType.number,
                            maxLength: 1,
                            style: const TextStyle(fontSize: 24),
                            decoration: InputDecoration(
                              counterText: "",
                              fillColor: _isVerified ? Colors.green[50] : Colors.white,
                              filled: true,
                              border: OutlineInputBorder(
                                borderSide: BorderSide.none,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderSide: BorderSide(
                                  color: _isVerified ? Colors.green : const Color(0xFFFBB04C),
                                  width: 1.5,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            onChanged: (value) => _onOtpDigitChanged(index, value),
                            enabled: !_isVerified,
                          ),
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // "Tap to paste" hint
                  Center(
                    child: Text(
                      'Tap to paste code',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Resend code button
                  Center(
                    child: TextButton(
                      onPressed: _timerSeconds == 0 && !_isVerified ? _resendOtp : null,
                      child: Text(
                        _timerSeconds > 0
                            ? 'Resend code in $_timerSeconds seconds'
                            : 'Resend code',
                        style: TextStyle(
                          color: _timerSeconds > 0 || _isVerified ? Colors.white70 : Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 80),
                  
                  // Verify button
                  Padding(
                    padding: const EdgeInsets.only(bottom: 30.0),
                    child: ElevatedButton(
                      onPressed: _isLoading || _isVerified ? null : _verifyOtp,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isVerified ? Colors.green : const Color(0xFFFBB04C),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        elevation: 5,
                        disabledBackgroundColor: _isVerified ? Colors.green : Colors.grey,
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
                            _isVerified ? 'Verified' : 'Verify',
                            style: const TextStyle(
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