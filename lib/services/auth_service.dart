import 'dart:async';

class User {
  final String id;
  final String name;
  final String email;
  final String phoneNumber;
  
  User({
    required this.id,
    required this.name,
    required this.email,
    this.phoneNumber = '',
  });
}

class AuthService {
  // Singleton pattern
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();
  
  // User stream to notify about authentication changes
  final StreamController<User?> _userController = StreamController<User?>.broadcast();
  Stream<User?> get userStream => _userController.stream;
  
  // Current user
  User? _currentUser;
  User? get currentUser => _currentUser;
  
  // Mock user database
  final Map<String, Map<String, dynamic>> _users = {};
  
  // Login with email and password
  Future<User?> login(String email, String password) async {
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
      );
      _userController.add(_currentUser);
      return _currentUser;
    }
    
    return null;
  }
  
  // Register new user
  Future<User?> register({
    required String name,
    required String email,
    required String password,
    String phoneNumber = '',
  }) async {
    // Simulate network delay
    await Future.delayed(const Duration(seconds: 1));
    
    // Check if email already exists
    if (_users.values.any((user) => user['email'] == email)) {
      return null; // Email already in use
    }
    
    // Create new user
    final userId = 'user_${DateTime.now().millisecondsSinceEpoch}';
    _users[userId] = {
      'name': name,
      'email': email,
      'password': password,
      'phoneNumber': phoneNumber,
    };
    
    // Set as current user
    _currentUser = User(
      id: userId,
      name: name,
      email: email,
      phoneNumber: phoneNumber,
    );
    
    _userController.add(_currentUser);
    return _currentUser;
  }
  
  // Logout current user
  Future<void> logout() async {
    _currentUser = null;
    _userController.add(null);
  }
  
  // Update user phone number
  Future<void> updatePhoneNumber(String phoneNumber) async {
    if (_currentUser != null) {
      final userId = _currentUser!.id;
      _users[userId]?['phoneNumber'] = phoneNumber;
      
      _currentUser = User(
        id: _currentUser!.id,
        name: _currentUser!.name,
        email: _currentUser!.email,
        phoneNumber: phoneNumber,
      );
      
      _userController.add(_currentUser);
    }
  }
  
  // Password reset
  Future<bool> resetPassword(String email) async {
    // Simulate network delay
    await Future.delayed(const Duration(seconds: 1));
    
    // Check if email exists (in a real app, we would send an email)
    return _users.values.any((user) => user['email'] == email);
  }
  
  // Clean up resources
  void dispose() {
    _userController.close();
  }
} 