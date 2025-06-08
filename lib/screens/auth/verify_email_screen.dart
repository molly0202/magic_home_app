import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({Key? key}) : super(key: key);

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  bool _isVerified = false;
  bool _isLoading = false;
  String? _error;

  Future<void> _checkVerification() async {
    setState(() => _isLoading = true);
    await FirebaseAuth.instance.currentUser?.reload();
    final user = FirebaseAuth.instance.currentUser;
    print('User emailVerified: \\${user?.emailVerified}, user: \\${user?.email}');
    setState(() {
      _isVerified = user?.emailVerified ?? false;
      _isLoading = false;
      _error = _isVerified ? null : (user == null ? "You have been signed out. Please log in again." : "Email not verified yet.");
    });
    if (_isVerified && user != null) {
      if (!mounted) return;
      Navigator.pushReplacementNamed(
        context,
        '/home',
        arguments: {'firebaseUser': user},
      );
    }
  }

  Future<void> _resendEmail() async {
    try {
      await FirebaseAuth.instance.currentUser?.sendEmailVerification();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Verification email sent!')),
      );
    } catch (e) {
      setState(() => _error = "Failed to send email: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verify Your Email')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'A verification link has been sent to your email. Please check your inbox and click the link to verify your account.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              if (_error != null)
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ElevatedButton(
                onPressed: _isLoading ? null : _checkVerification,
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : const Text('I have verified'),
              ),
              TextButton(
                onPressed: _resendEmail,
                child: const Text('Resend verification email'),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 