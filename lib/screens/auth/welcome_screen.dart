import 'package:flutter/material.dart';
import '../../widgets/auth_logo_header.dart';
import '../../widgets/logo_with_text.dart';
import 'login_screen.dart';
import 'register_screen.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'hsp_entry_screen.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  bool _isLoading = false;
  String? _errorMessage;

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
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final credential = firebase_auth.GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final userCredential = await firebase_auth.FirebaseAuth.instance.signInWithCredential(credential);
      if (!mounted) return;
      Navigator.pushReplacementNamed(
        context,
        '/home',
        arguments: {'firebaseUser': userCredential.user, 'googleUser': googleUser, 'googleSignIn': GoogleSignIn()},
      );
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
              logoSize: 120,
              fontSize: 40,
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
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  child: const Text('Sign in'),
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
              child: const Text(
                'Sign up',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 28,
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
                    child: Text(
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
                    style: const TextStyle(color: Colors.blue, fontSize: 20),
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