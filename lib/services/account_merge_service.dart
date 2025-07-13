import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/material.dart';

class AccountMergeService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final firebase_auth.FirebaseAuth _auth = firebase_auth.FirebaseAuth.instance;

  /// Check if an email already exists in any Firebase Auth provider
  static Future<List<String>> getExistingAuthProviders(String email) async {
    try {
      final methods = await _auth.fetchSignInMethodsForEmail(email);
      return methods;
    } catch (e) {
      print('Error checking existing auth providers: $e');
      return [];
    }
  }

  /// Check if email exists in Firestore users or providers collections
  static Future<Map<String, dynamic>?> checkExistingFirestoreAccount(String email) async {
    try {
      // Check users collection
      final usersQuery = await _firestore
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();
      
      if (usersQuery.docs.isNotEmpty) {
        return {
          'collection': 'users',
          'doc': usersQuery.docs.first,
          'role': 'user',
        };
      }

      // Check providers collection
      final providersQuery = await _firestore
          .collection('providers')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();
      
      if (providersQuery.docs.isNotEmpty) {
        return {
          'collection': 'providers',
          'doc': providersQuery.docs.first,
          'role': 'provider',
        };
      }

      return null;
    } catch (e) {
      print('Error checking existing Firestore account: $e');
      return null;
    }
  }

  /// Show dialog asking user if they want to link accounts
  static Future<bool> showAccountLinkDialog(BuildContext context, String email, String existingMethod, String newMethod) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Account Already Exists'),
        content: Text(
          'An account with $email already exists using $existingMethod.\n\n'
          'Would you like to link your $newMethod account to your existing account?'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFBB04C),
              foregroundColor: Colors.white,
            ),
            child: const Text('Link Accounts'),
          ),
        ],
      ),
    );
    
    return result ?? false;
  }

  /// Link Google account to existing email/password account
  static Future<firebase_auth.UserCredential?> linkGoogleToExistingAccount(
    String email, 
    String password, 
    firebase_auth.AuthCredential googleCredential
  ) async {
    try {
      // First sign in with email/password
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Then link Google credential
      final linkedCredential = await userCredential.user!.linkWithCredential(googleCredential);
      
      print('Successfully linked Google account to existing email/password account');
      return linkedCredential;
    } catch (e) {
      print('Error linking Google account: $e');
      return null;
    }
  }

  /// Link email/password to existing Google account
  static Future<firebase_auth.UserCredential?> linkEmailPasswordToExistingAccount(
    firebase_auth.AuthCredential emailCredential
  ) async {
    try {
      // Current user should be the Google-signed-in user
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('No current user to link to');
      }

      // Link email/password credential
      final linkedCredential = await currentUser.linkWithCredential(emailCredential);
      
      print('Successfully linked email/password to existing Google account');
      return linkedCredential;
    } catch (e) {
      print('Error linking email/password account: $e');
      return null;
    }
  }

  /// Show dialog asking for password to link accounts
  static Future<String?> showPasswordDialog(BuildContext context, String email) async {
    final passwordController = TextEditingController();
    bool isPasswordVisible = false;

    final result = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Link Accounts'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Enter your password for $email to link your accounts:'),
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                obscureText: !isPasswordVisible,
                decoration: InputDecoration(
                  labelText: 'Password',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(
                      isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() {
                        isPasswordVisible = !isPasswordVisible;
                      });
                    },
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final password = passwordController.text.trim();
                if (password.isNotEmpty) {
                  Navigator.pop(context, password);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFBB04C),
                foregroundColor: Colors.white,
              ),
              child: const Text('Link Accounts'),
            ),
          ],
        ),
      ),
    );

    passwordController.dispose();
    return result;
  }

  /// Get human-readable auth method name
  static String getAuthMethodName(String method) {
    switch (method) {
      case 'password':
        return 'email and password';
      case 'google.com':
        return 'Google';
      case 'apple.com':
        return 'Apple';
      default:
        return method;
    }
  }
} 