import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../main.dart'; // Import main.dart for HomeScreen
import 'register_screen.dart';
import 'forgot_password_screen.dart';
import 'package:google_sign_in/google_sign_in.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final AuthService _authService = AuthService();
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: '441732602904-ib5itb3on72gkv6qffdjv6g58kgvmpnf.apps.googleusercontent.com',
  );
  
  bool _isPasswordVisible = false;
  bool _isLoading = false;
  bool _isGoogleSigningIn = false;
  String? _googleSignInError;
  
  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
  
  Future<void> _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    
    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter both email and password')),
      );
      return;
    }
    
    setState(() => _isLoading = true);
    
    try {
      final user = await _authService.login(email, password);
      
      if (!mounted) return;
      
      if (user != null) {
        // Create a mock GoogleSignInAccount from the regular user
        final mockGoogleUser = MockGoogleSignInAccount(
          id: user.id,
          displayName: user.name,
          email: user.email,
          photoUrl: null, // No photo for email login users
          phoneNumber: user.phoneNumber,
        );
        
        // Navigate to HomeScreen with the mock user
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => HomeScreen(
              user: mockGoogleUser,
              googleSignIn: _googleSignIn,
              onSignOut: (user) {
                // Handle sign out by returning to the LoginScreen
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              },
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid email or password')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Login failed: ${e.toString()}')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isGoogleSigningIn = true;
      _googleSignInError = null;
    });
    
    try {
      final account = await _googleSignIn.signIn();
      
      if (!mounted) return;
      
      if (account == null) {
        // User canceled sign-in
        setState(() {
          _isGoogleSigningIn = false;
          _googleSignInError = 'Sign in was canceled';
        });
        return;
      }
      
      print('Successfully signed in with Google: ${account.displayName}');
      
      // Navigate to the HomeScreen from main.dart
      // We need to import the HomeScreen, GoogleSignInAccount and GoogleSignIn types from main.dart
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) {
            // HomeScreen requires user, googleSignIn, and onSignOut parameters
            return HomeScreen(
              user: account,
              googleSignIn: _googleSignIn,
              onSignOut: (user) {
                // Handle sign out by returning to the LoginScreen
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              },
            );
          },
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isGoogleSigningIn = false;
        _googleSignInError = 'Sign in error: $error';
      });
      print('Error signing in with Google: $error');
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Google Sign-In failed: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Orange header with logo
              Container(
                width: double.infinity,
                height: 270,
                decoration: const BoxDecoration(
                  color: Color(0xFFFBB04C),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(40),
                    bottomRight: Radius.circular(40),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x40000000),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 20),
                      // Logo image
                      Container(
                        width: 240,
                        height: 240,
                        padding: const EdgeInsets.all(45),
                        decoration: const BoxDecoration(
                          color: Colors.transparent,
                          shape: BoxShape.circle,
                        ),
                        child: Image.asset(
                          'assets/images/logo.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              // Login form
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Test user credentials hint
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Test User Credentials:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text('Email: test@example.com'),
                          Text('Password: password123'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    // Email field
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        hintText: 'Email',
                        hintStyle: TextStyle(color: Colors.black.withOpacity(0.7)),
                        enabledBorder: const UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.grey),
                        ),
                        focusedBorder: const UnderlineInputBorder(
                          borderSide: BorderSide(color: Color(0xFFFBB04C)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    // Password field
                    TextField(
                      controller: _passwordController,
                      obscureText: !_isPasswordVisible,
                      decoration: InputDecoration(
                        hintText: 'Password',
                        hintStyle: TextStyle(color: Colors.black.withOpacity(0.7)),
                        enabledBorder: const UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.grey),
                        ),
                        focusedBorder: const UnderlineInputBorder(
                          borderSide: BorderSide(color: Color(0xFFFBB04C)),
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
                    const SizedBox(height: 40),
                    
                    // Login button
                    ElevatedButton(
                      onPressed: _isLoading ? null : _login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFBB04C),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        elevation: 2,
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
                            'Login',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                    ),
                    
                    // Forgot Password
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()),
                        );
                      },
                      child: const Text(
                        'Forgot password?',
                        style: TextStyle(
                          color: Colors.grey,
                          fontWeight: FontWeight.normal,
                        ),
                      ),
                    ),
                    
                    // Or divider
                    const Row(
                      children: [
                        Expanded(child: Divider(color: Colors.grey, thickness: 0.5)),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 10),
                          child: Text('or', style: TextStyle(color: Colors.grey)),
                        ),
                        Expanded(child: Divider(color: Colors.grey, thickness: 0.5)),
                      ],
                    ),
                    const SizedBox(height: 20),
                    
                    // Social login buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildGoogleSignInButton(),
                        const SizedBox(width: 20),
                        _buildSocialButton(Icons.facebook, Colors.blue),
                        const SizedBox(width: 20),
                        _buildSocialButton(Icons.apple, Colors.black),
                      ],
                    ),
                    
                    if (_googleSignInError != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          _googleSignInError!,
                          style: const TextStyle(color: Colors.red, fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    
                    // Registration link
                    const SizedBox(height: 40),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Don't have an account? ",
                          style: TextStyle(
                            color: Colors.grey.shade600,
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const RegisterScreen()),
                            );
                          },
                          child: Text(
                            "Sign up",
                            style: TextStyle(
                              color: const Color(0xFFFBB04C),
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
      ),
    );
  }
  
  Widget _buildGoogleSignInButton() {
    return InkWell(
      onTap: _isGoogleSigningIn ? null : _handleGoogleSignIn,
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          shape: BoxShape.circle,
        ),
        child: _isGoogleSigningIn
          ? const Padding(
              padding: EdgeInsets.all(12),
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.red,
              ),
            )
          : Center(
              child: Icon(
                Icons.g_mobiledata,
                size: 28,
                color: Colors.red,
              ),
            ),
      ),
    );
  }
  
  Widget _buildSocialButton(IconData icon, Color iconColor) {
    return InkWell(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Social login not implemented yet')),
        );
      },
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Icon(
            icon,
            size: 28,
            color: iconColor,
          ),
        ),
      ),
    );
  }
}

// Mock GoogleSignInAccount for email login users
class MockGoogleSignInAccount implements GoogleSignInAccount {
  @override
  final String? displayName;
  
  @override
  final String email;
  
  @override
  final String id;
  
  @override
  final String? photoUrl;
  
  // Additional fields not in GoogleSignInAccount interface
  final String? phoneNumber;
  
  // Required constructor fields
  MockGoogleSignInAccount({
    required this.id,
    required this.email,
    this.displayName,
    this.photoUrl,
    this.phoneNumber,
  });
  
  // Implement remaining required methods with stub implementations
  @override
  Future<Map<String, String>> get authHeaders async => {};
  
  @override
  Future<GoogleSignInAuthentication> get authentication async =>
      throw UnimplementedError();
  
  @override
  String? get serverAuthCode => null;
  
  @override
  Future<void> clearAuthCache() async {}
} 