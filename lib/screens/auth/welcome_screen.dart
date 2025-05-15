import 'package:flutter/material.dart';
import '../../widgets/auth_logo_header.dart';
import '../../widgets/logo_with_text.dart';
import 'login_screen.dart';
import 'register_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBB04C), // Orange background color
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 2),
              
              // Logo area with Chinese text
              Column(
                children: [
                  // Logo without text - increased size by 1.5x (from 150 to 225)
                  const LogoWithText(
                    logoSize: 225,
                    fontSize: 40,
                    includeText: false,
                  ),
                  const SizedBox(height: 15),
                  // Chinese text 美家 - increased size by 1.5x (from 40 to 60)
                  const Text(
                    '美家',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 60,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              
              const Spacer(flex: 3),
              
              // Sign in button - colors reversed: white background with orange text
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 75),
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white, // Changed to white
                    foregroundColor: const Color(0xFFFBB04C), // Changed to orange
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: const BorderSide(color: Colors.white, width: 1.5), // Kept white border
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    elevation: 5,
                    minimumSize: const Size(double.infinity, 55),
                  ),
                  child: const Text(
                    'Sign in',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFFBB04C), // Fixed const error
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 30),
              
              // Sign up text button - updated to match the image
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const RegisterScreen()),
                  );
                },
                child: const Text(
                  'Sign up',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              
              const Spacer(flex: 2),
            ],
          ),
        ),
      ),
    );
  }
} 