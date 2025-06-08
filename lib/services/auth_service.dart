import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
// Remove Firebase imports
// import 'package:firebase_core/firebase_core.dart';
// import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;

class User {
  final String id;
  final String name;
  final String email;
  final String phoneNumber;
  final String role;
  
  User({
    required this.id,
    required this.name,
    required this.email,
    this.phoneNumber = '',
    this.role = 'user',
  });
  
  // Create a User from a Google Sign In account
  factory User.fromGoogleAccount(dynamic googleUser) {
    return User(
      id: googleUser.id ?? '',
      name: googleUser.displayName ?? 'User',
      email: googleUser.email ?? '',
      phoneNumber: '',
      role: 'user',
    );
  }
}

// Add logging for auth service
void log(String message) {
  // ignore: avoid_print
  print('[MAGIC_HOME_AUTH] $message');
}

class AuthService {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;

  // Singleton pattern
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  
  // Private constructor with initialization
  AuthService._internal() {
    _initializeService();
  }
  
  // Mock mode only
  bool _useFirebase = false;
  // firebase_auth.FirebaseAuth? _firebaseAuth;
  
  // User stream to notify about authentication changes
  final StreamController<User?> _userController = StreamController<User?>.broadcast();
  Stream<User?> get userStream => _userController.stream;
  
  // Verification ID for phone auth
  String? _verificationId;
  
  // Current user
  User? _currentUser;
  User? get currentUser => _currentUser;
  
  // Mock user database
  final Map<String, Map<String, dynamic>> _users = {};
  
  // Initialize the service
  void _initializeService() {
    _setupMockAuth();
  }
  
  // Set up mock authentication when Firebase is unavailable
  void _setupMockAuth() {
    log('Using mock authentication');
    
    // Add a test user account for easy login
    const testUserId = 'test_user_123';
    _users[testUserId] = {
      'name': 'Test User',
      'email': 'test@example.com',
      'password': 'password123',
      'phoneNumber': '+1234567890',
    };
    
    log('Created test user with email: test@example.com and password: password123');
  }
  
  // Login with email and password
  Future<User?> login(String email, String password) async {
    log('Attempting login with email: $email');
    
    if (_useFirebase) {
      try {
        // Mock Firebase login response since Firebase is removed
        log('Firebase login failed: Firebase is not available');
        return null;
      } catch (e) {
        log('Firebase login error: $e');
        return null;
      }
    } else {
      // Use mock implementation
      // Simulate network delay
      await Future.delayed(const Duration(seconds: 1));
      
      // Check if user exists
      final userEntry = _users.entries.where((entry) => 
        entry.value['email'] == email && entry.value['password'] == password
      ).toList();
      
      if (userEntry.isNotEmpty) {
        final userData = userEntry.first.value;
        _currentUser = User(
          id: userEntry.first.key,
          name: userData['name'],
          email: userData['email'],
          phoneNumber: userData['phoneNumber'] ?? '',
          role: userData['role'] ?? 'user',
        );
        _userController.add(_currentUser);
        log('Mock login successful for user: ${_currentUser!.name}');
        return _currentUser;
      }
      
      log('Mock login failed: user not found or incorrect password');
      return null;
    }
  }
  
  // Register new user
  Future<User?> register({
    required String name,
    required String email,
    required String password,
    String phoneNumber = '',
  }) async {
    log('Attempting to register user with email: $email');
    
    if (_useFirebase) {
      try {
        // Mock Firebase registration since Firebase is removed
        log('Firebase registration failed: Firebase is not available');
        return null;
      } catch (e) {
        log('Firebase registration error: $e');
        return null;
      }
    } else {
      // Use mock implementation
      // Simulate network delay
      await Future.delayed(const Duration(seconds: 1));
      
      // Check if email already exists
      if (_users.values.any((user) => user['email'] == email)) {
        log('Registration failed: email already in use');
        return null; // Email already in use
      }
      
      // Create new user
      final userId = 'user_${DateTime.now().millisecondsSinceEpoch}';
      _users[userId] = {
        'name': name,
        'email': email,
        'password': password,
        'phoneNumber': phoneNumber,
        'role': 'user',
      };
      
      // Set as current user
      _currentUser = User(
        id: userId,
        name: name,
        email: email,
        phoneNumber: phoneNumber,
        role: 'user',
      );
      
      _userController.add(_currentUser);
      log('Mock registration successful for user: $name');
      return _currentUser;
    }
  }
  
  // Logout current user
  Future<void> logout() async {
    log('Logging out user');
    
    if (_useFirebase) {
      try {
        // Mock Firebase logout since Firebase is removed
        log('Firebase logout failed: Firebase is not available');
      } catch (e) {
        log('Firebase logout error: $e');
      }
    } else {
      // Mock implementation
      _currentUser = null;
      _userController.add(null);
      log('Mock logout successful');
    }
  }
  
  // Start phone verification
  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required Function(String verificationId, int? resendToken) onCodeSent,
    required Function(FirebaseAuthException error) onVerificationFailed,
    required Function(PhoneAuthCredential credential) onVerificationCompleted,
    int? forceResendingToken,
  }) async {
    await _firebaseAuth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      timeout: const Duration(seconds: 60),
      verificationCompleted: onVerificationCompleted,
      verificationFailed: onVerificationFailed,
      codeSent: onCodeSent,
      codeAutoRetrievalTimeout: (String verificationId) {},
      forceResendingToken: forceResendingToken,
    );
  }

  // Create credential from code
  PhoneAuthCredential getCredential({
    required String verificationId,
    required String smsCode,
  }) {
    return PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );
  }

  // Link phone credential to current user
  Future<void> linkWithPhoneCredential(PhoneAuthCredential credential) async {
    await _firebaseAuth.currentUser?.linkWithCredential(credential);
  }

  // Sign in with phone credential (if not already signed in)
  Future<UserCredential> signInWithPhoneCredential(PhoneAuthCredential credential) async {
    return await _firebaseAuth.signInWithCredential(credential);
  }
  
  // Update user phone number
  Future<void> updatePhoneNumber(String phoneNumber) async {
    log('Updating phone number to: $phoneNumber');
    
    if (_currentUser != null) {
      final userId = _currentUser!.id;
      _users[userId]?['phoneNumber'] = phoneNumber;
      
      _currentUser = User(
        id: _currentUser!.id,
        name: _currentUser!.name,
        email: _currentUser!.email,
        phoneNumber: phoneNumber,
        role: _currentUser!.role,
      );
      
      _userController.add(_currentUser);
      log('Phone number updated successfully');
    }
  }
  
  // Password reset (mock implementation)
  Future<bool> resetPassword(String email) async {
    log('Attempting to reset password for email: $email');
    
    // Simulate network delay
    await Future.delayed(const Duration(seconds: 1));
    
    // Check if email exists
    bool exists = _users.values.any((user) => user['email'] == email);
    
    if (exists) {
      log('Mock password reset email sent successfully');
    } else {
      log('Mock password reset failed: email not found');
    }
    
    return exists;
  }
  
  // Clean up resources
  void dispose() {
    log('Disposing AuthService');
    _userController.close();
  }
} 