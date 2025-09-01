import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'screens/auth/welcome_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home/home_screen.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    print('Initializing Firebase...');
    await Firebase.initializeApp();
    print('Firebase initialized successfully');
  } catch (e) {
    print('Firebase initialization failed: $e');
    // Continue anyway - app might work without Firebase for basic UI
  }
  
  runApp(const MagicHomeApp());
}

class MagicHomeApp extends StatefulWidget {
  const MagicHomeApp({super.key});

  @override
  State<MagicHomeApp> createState() => _MagicHomeAppState();
}

class _MagicHomeAppState extends State<MagicHomeApp> {
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: '441732602904-ib5itb3on72gkv6qffdjv6g58kgvmpnf.apps.googleusercontent.com',
  );
  GoogleSignInAccount? _user;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    print('MagicHomeApp initState called');
    // Check if user is already signed in
    _checkCurrentUser();
  }

  Future<void> _checkCurrentUser() async {
    print('Checking current user...');
    try {
      _user = await _googleSignIn.signInSilently();
      print('User already signed in: ${_user?.displayName}');
    } catch (error) {
      print('Error checking current user: $error');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void updateUser(GoogleSignInAccount? user) {
    setState(() {
      _user = user;
    });
  }

  @override
  Widget build(BuildContext context) {
    print('Building MagicHomeApp');
    return MaterialApp(
      title: 'Magic Home',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFFBB04C)),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFFBB04C),
          foregroundColor: Colors.white,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFBB04C),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
          ),
        ),
      ),
      home: _isLoading 
        ? const LoadingScreen() 
        : (_user != null 
          ? HomeScreen(
              firebaseUser: firebase_auth.FirebaseAuth.instance.currentUser,
              googleUser: _user,
              googleSignIn: _googleSignIn,
            )
          : const WelcomeScreen()),
      onGenerateRoute: (settings) {
        print('Generating route for: ${settings.name}');
        if (settings.name == '/home') {
          final args = settings.arguments as Map<String, dynamic>?;
          print('Home route args: $args');
          return MaterialPageRoute(
            builder: (context) => HomeScreen(
              firebaseUser: args?['firebaseUser'],
              googleUser: args?['googleUser'],
              googleSignIn: args?['googleSignIn'],
            ),
          );
        }
        // Add other routes as needed
        return null;
      },
    );
  }
}

class LoadingScreen extends StatelessWidget {
  const LoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(
          color: Color(0xFFFBB04C),
        ),
      ),
    );
  }
}

class AuthScreen extends StatefulWidget {
  final GoogleSignIn googleSignIn;
  final Function(GoogleSignInAccount?) onSignIn;

  const AuthScreen({
    super.key,
    required this.googleSignIn,
    required this.onSignIn,
  });

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _isSigningIn = false;
  String? _errorMessage;

  Future<void> _handleSignIn() async {
    setState(() {
      _isSigningIn = true;
      _errorMessage = null;
    });
    
    try {
      final account = await widget.googleSignIn.signIn();
      
      if (account == null) {
        // User canceled sign-in
        setState(() {
          _isSigningIn = false;
          _errorMessage = 'Sign in was canceled';
        });
        return;
      }
      
      widget.onSignIn(account);
      
      print('Successfully signed in: ${account.displayName}');
      
    } catch (error) {
      setState(() {
        _isSigningIn = false;
        _errorMessage = 'Sign in error: $error';
      });
      print('Error signing in with Google: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const Icon(
                Icons.home,
                size: 120,
                color: Color(0xFFFBB04C),
              ),
              const SizedBox(height: 20),
              const Text(
                'Magic Home',
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              const Text(
                'Your Smart Home Solution',
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
              const SizedBox(height: 60),
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 10),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _isSigningIn ? null : _handleSignIn,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                ),
                child: _isSigningIn
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.login),
                      SizedBox(width: 8),
                      Text('Sign in with Google'),
                    ],
                  ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


