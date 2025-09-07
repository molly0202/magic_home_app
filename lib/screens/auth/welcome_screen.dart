import 'package:flutter/material.dart';
import '../../widgets/auth_logo_header.dart';
import '../../widgets/logo_with_text.dart';
import '../../widgets/translatable_text.dart';
import 'login_screen.dart';
import 'register_screen.dart';
import 'referral_code_screen.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'hsp_entry_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../home/hsp_home_screen.dart';
import '../../services/account_merge_service.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  bool _isLoading = false;
  String? _errorMessage;

  Future<String> _generateReferralCode(String uid) async {
    final random = DateTime.now().millisecondsSinceEpoch % 100;
    return uid.substring(0, 6).toUpperCase() + random.toString().padLeft(2, '0');
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Google sign-in cancelled.';
        });
        return;
      }

      final String email = googleUser.email;
      
      // Check if there's an existing account with this email
      final existingAuthMethods = await AccountMergeService.getExistingAuthProviders(email);
      
      if (existingAuthMethods.contains('password')) {
        // Email/password account already exists - offer to link
        final shouldLink = await AccountMergeService.showAccountLinkDialog(
          context, 
          email, 
          AccountMergeService.getAuthMethodName('password'), 
          AccountMergeService.getAuthMethodName('google.com')
        );
        
        if (shouldLink) {
          // Ask for password to link accounts
          final password = await AccountMergeService.showPasswordDialog(context, email);
          if (password != null) {
            final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
            final googleCredential = firebase_auth.GoogleAuthProvider.credential(
              accessToken: googleAuth.accessToken,
              idToken: googleAuth.idToken,
            );
            
            final linkedCredential = await AccountMergeService.linkGoogleToExistingAccount(
              email, 
              password, 
              googleCredential
            );
            
            if (linkedCredential != null) {
              await _handleSuccessfulSignIn(linkedCredential.user!, googleUser);
              return;
            } else {
              setState(() {
                _errorMessage = 'Failed to link accounts. Please check your password.';
              });
              return;
            }
          } else {
            setState(() {
              _isLoading = false;
            });
            return;
          }
        } else {
          setState(() {
            _isLoading = false;
          });
          return;
        }
      }
      
      // Normal Google sign-in flow
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final credential = firebase_auth.GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final userCredential = await firebase_auth.FirebaseAuth.instance.signInWithCredential(credential);
      if (!mounted) return;
      final user = userCredential.user;
      if (user == null) throw Exception('Google sign-in failed: user not found');
      
      await _handleSuccessfulSignIn(user, googleUser);
      
    } catch (e) {
      setState(() {
        _errorMessage = 'Google sign-in failed: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _handleSuccessfulSignIn(firebase_auth.User user, GoogleSignInAccount googleUser) async {
    // Check Firestore for user role
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    if (userDoc.exists && userDoc.data()?['role'] == 'user') {
      Navigator.pushReplacementNamed(
        context,
        '/home',
        arguments: {'firebaseUser': user, 'googleUser': googleUser, 'googleSignIn': GoogleSignIn()},
      );
      return;
    }
    final providerDoc = await FirebaseFirestore.instance.collection('providers').doc(user.uid).get();
    if (providerDoc.exists && providerDoc.data()?['role'] == 'provider') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => HspHomeScreen(user: user)),
      );
      return;
    }
    // If not found, create user profile, generate referral code, and navigate to referral code screen
    final referralCode = await _generateReferralCode(user.uid);
    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      'email': user.email,
      'role': 'user',
      'referralCode': referralCode,
      'createdAt': FieldValue.serverTimestamp(),
    });
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => const ReferralCodeScreen(),
      ),
    );
  }

  Future<void> _signInWithApple() async {
    // Placeholder for Apple Sign-In
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Apple Sign-In coming soon!')),
    );
  }

  @override
  void initState() {
    super.initState();
    print('WelcomeScreen initState called');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    print('WelcomeScreen didChangeDependencies called');
    // Preload the logo image
    precacheImage(
      const AssetImage('assets/images/logo.png'),
      context,
    );
  }

  @override
  Widget build(BuildContext context) {
    print('Building WelcomeScreen');
    return Scaffold(
      backgroundColor: const Color(0xFFFBB04C),
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(flex: 4),
            // Logo and app name
            const LogoWithText(
              logoSize: 240,
              fontSize: 20,
              includeText: true,
            ),
            const Spacer(flex: 3),
            // Sign in button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const LoginScreen()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFFFBB04C),
                    elevation: 4,
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  child: const TranslatableText('Sign in'),
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Sign up button
            TextButton(
              onPressed: _isLoading ? null : () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const RegisterScreen()),
                );
              },
              child: const TranslatableText(
                'Sign up',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            const Spacer(flex: 2),
            // Divider with 'or'
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Row(
                children: [
                  const Expanded(
                    child: Divider(
                      color: Colors.white,
                      thickness: 2,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0),
                    child: TranslatableText(
                      'or',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 24,
                        letterSpacing: 1.2,
                        shadows: [Shadow(color: Colors.black26, blurRadius: 2)],
                      ),
                    ),
                  ),
                  const Expanded(
                    child: Divider(
                      color: Colors.white,
                      thickness: 2,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            // Social buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Google
                GestureDetector(
                  onTap: _isLoading ? null : _signInWithGoogle,
                  child: Container(
                    width: 70,
                    height: 70,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 8,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                                          child: const Icon(
                      Icons.g_mobiledata,
                      size: 40,
                      color: Color(0xFFFBB04C),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 40),
                // Apple
                GestureDetector(
                  onTap: _isLoading ? null : _signInWithApple,
                  child: Container(
                    width: 70,
                    height: 70,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 8,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                                              child: const Icon(
                          Icons.apple,
                          size: 40,
                          color: Color(0xFFFBB04C),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const Spacer(flex: 4),
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 10),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              ),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: CircularProgressIndicator(color: Colors.white),
              ),
            Padding(
              padding: const EdgeInsets.only(bottom: 32.0, top: 8.0),
              child: GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const HspEntryScreen()),
                  );
                },
                child: Text.rich(
                  TextSpan(
                    text: 'Are you a service provider? ',
                    style: const TextStyle(color: Colors.blue, fontSize: 12),
                    children: [
                      TextSpan(
                        text: 'Click here',
                        style: const TextStyle(
                          decoration: TextDecoration.underline,
                          color: Colors.blue,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const TextSpan(text: ' to start.'),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Profile setup dialog widget (copied from register_screen.dart for reuse)
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