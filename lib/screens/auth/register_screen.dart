import 'package:flutter/material.dart';
import '../../widgets/auth_logo_header.dart';
import '../../widgets/app_logo.dart';
import '../../services/auth_service.dart';
import 'phone_verification_screen.dart';
import 'verify_email_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _acceptTerms = false;
  bool _isLoading = false;
  final AuthService _authService = AuthService();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<String> _generateReferralCode(String uid) async {
    // Simple unique code: first 6 of UID + random 2 digits
    final random = DateTime.now().millisecondsSinceEpoch % 100;
    return uid.substring(0, 6).toUpperCase() + random.toString().padLeft(2, '0');
  }

  Future<void> _register() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;
    
    if (email.isEmpty || password.isEmpty || confirmPassword.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }
    if (password != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match')),
      );
      return;
    }
    setState(() => _isLoading = true);
    try {
      // Check both users and providers collections for email
      final usersQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: email)
          .get();
      final providersQuery = await FirebaseFirestore.instance
          .collection('providers')
          .where('email', isEqualTo: email)
          .get();
      if (usersQuery.docs.isNotEmpty || providersQuery.docs.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Email is already in use for another account')), 
        );
        setState(() => _isLoading = false);
        return;
      }
      // Register the user with Firebase Auth
      UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = userCredential.user;
      if (user == null) throw Exception('User creation failed');
      // Generate unique referral code
      final referralCode = await _generateReferralCode(user.uid);
      // Write user profile to Firestore with role 'user' and referral code
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({
        'email': email,
        'role': 'user',
        'referralCode': referralCode,
        'createdAt': FieldValue.serverTimestamp(),
      });
      // Show profile setup dialog
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => _ProfileSetupDialog(userId: user.uid),
      );
      // Go to homepage
      Navigator.pushReplacementNamed(
        context,
        '/home',
        arguments: {'firebaseUser': user},
      );
    } on FirebaseAuthException catch (e) {
      String errorMsg = 'Registration failed: \\${e.message}';
      if (e.code == 'email-already-in-use') {
        errorMsg = 'Email is already in use';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMsg)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Registration failed: \\${e.toString()}')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBB04C), // Orange background color
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Custom wave with logo
            Stack(
              children: [
                CustomPaint(
                  size: Size(MediaQuery.of(context).size.width, 200),
                  painter: WavePainter(),
                ),
                Positioned(
                  top: 70,
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
                    'Create Account',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 30),
                  
                  // Username field
                  const Text(
                    'User Name',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      fillColor: Colors.white,
                      filled: true,
                      border: OutlineInputBorder(
                        borderSide: BorderSide.none,
                        borderRadius: BorderRadius.all(Radius.circular(8.0)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // Email field
                  const Text(
                    'Email',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    decoration: const InputDecoration(
                      fillColor: Colors.white,
                      filled: true,
                      border: OutlineInputBorder(
                        borderSide: BorderSide.none,
                        borderRadius: BorderRadius.all(Radius.circular(8.0)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // Password field
                  const Text(
                    'Password',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _passwordController,
                    obscureText: !_isPasswordVisible,
                    autofillHints: const [AutofillHints.newPassword],
                    decoration: InputDecoration(
                      fillColor: Colors.white,
                      filled: true,
                      border: const OutlineInputBorder(
                        borderSide: BorderSide.none,
                        borderRadius: BorderRadius.all(Radius.circular(8.0)),
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                          color: Colors.grey,
                        ),
                        onPressed: () {
                          setState(() {
                            _isPasswordVisible = !_isPasswordVisible;
                          });
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // Confirm Password field
                  const Text(
                    'Confirm Password',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _confirmPasswordController,
                    obscureText: !_isConfirmPasswordVisible,
                    decoration: InputDecoration(
                      fillColor: Colors.white,
                      filled: true,
                      border: const OutlineInputBorder(
                        borderSide: BorderSide.none,
                        borderRadius: BorderRadius.all(Radius.circular(8.0)),
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _isConfirmPasswordVisible ? Icons.visibility : Icons.visibility_off,
                          color: Colors.grey,
                        ),
                        onPressed: () {
                          setState(() {
                            _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
                          });
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // Terms and conditions checkbox
                  Row(
                    children: [
                      Checkbox(
                        value: _acceptTerms,
                        onChanged: (value) {
                          setState(() {
                            _acceptTerms = value ?? false;
                          });
                        },
                        fillColor: MaterialStateProperty.resolveWith<Color>(
                          (Set<MaterialState> states) {
                            if (states.contains(MaterialState.selected)) {
                              return Colors.white;
                            }
                            return Colors.white;
                          },
                        ),
                        checkColor: const Color(0xFFFBB04C),
                      ),
                      Expanded(
                        child: Text(
                          'By checking this box, you are agreeing to our terms and conditions.',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),
                  
                  // Continue button
                  ElevatedButton(
                    onPressed: (_acceptTerms && !_isLoading) ? _register : null,
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

// Profile setup dialog widget
class _ProfileSetupDialog extends StatefulWidget {
  final String userId;
  const _ProfileSetupDialog({required this.userId});
  @override
  State<_ProfileSetupDialog> createState() => _ProfileSetupDialogState();
}
class _ProfileSetupDialogState extends State<_ProfileSetupDialog> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  bool _saving = false;
  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }
  Future<void> _saveProfile() async {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final address = _addressController.text.trim();
    if (name.isEmpty || phone.isEmpty || address.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }
    setState(() => _saving = true);
    await FirebaseFirestore.instance.collection('users').doc(widget.userId).update({
      'name': name,
      'phone': phone,
      'address': address,
    });
    if (mounted) Navigator.of(context).pop();
  }
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Set Up Your Profile'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Phone'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _addressController,
              decoration: const InputDecoration(labelText: 'Address'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : _saveProfile,
          child: _saving
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Save'),
        ),
      ],
    );
  }
} 