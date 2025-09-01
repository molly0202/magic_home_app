import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'screens/auth/welcome_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/home/hsp_home_screen.dart';
import 'screens/bidding/provider_bid_screen.dart';
import 'screens/bidding/bid_comparison_screen.dart';
import 'services/notification_service.dart';
import 'services/translation_service.dart';
import 'services/in_app_notification_service.dart';
import 'models/user_request.dart';
import 'widgets/floating_translation_widget.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:cloud_firestore/cloud_firestore.dart';

// Top-level function to handle background messages
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Initialize Firebase in background handler
  await Firebase.initializeApp();
  print('Handling a background message: ${message.messageId}');
  print('Background message data: ${message.data}');
  
  // You can perform additional background processing here
  // For example, update local database, show notification, etc.
}

// Global navigator key for navigation from anywhere
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  print('Initializing Firebase...');
  await Firebase.initializeApp();
  print('Firebase initialized successfully');
  
  // Initialize translation service
  await TranslationService().initialize();
  print('Translation service initialized');
  
  // Set the background messaging handler early on
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  
  // Set up notification navigation callback
  NotificationService.setNavigationCallback(_handleNotificationNavigation);
  
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
      navigatorKey: navigatorKey,
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
      home: _isLoading ? const LoadingScreen() : const WelcomeScreen(),
      builder: (context, child) {
        // Initialize in-app notifications when the app is built
        WidgetsBinding.instance.addPostFrameCallback((_) {
          InAppNotificationService().initialize(context);
        });
        
        // Wrap the entire app with translation widget
        return FloatingTranslationWidget(child: child!);
      },
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

// Handle notification navigation
void _handleNotificationNavigation(String notificationType, Map<String, dynamic> data) async {
  print('🔔 Handling notification navigation: $notificationType');
  
  final context = navigatorKey.currentContext;
  if (context == null) {
    print('❌ No navigator context available');
    return;
  }

  try {
    switch (notificationType) {
      case 'bidding_opportunity':
        await _navigateToProviderBidScreen(context, data);
        break;
      case 'new_bid_received':
        await _navigateToBidComparisonScreen(context, data);
        break;
      case 'bid_result':
        await _handleBidResultNavigation(context, data);
        break;
      case 'status_update':
        await _handleStatusUpdateNavigation(context, data);
        break;
      default:
        print('🤷 Unknown notification type: $notificationType');
    }
  } catch (e) {
    print('❌ Error handling notification navigation: $e');
  }
}

Future<void> _navigateToProviderBidScreen(BuildContext context, Map<String, dynamic> data) async {
  final requestId = data['request_id'];
  if (requestId == null) {
    print('❌ Missing request_id for bidding opportunity');
    return;
  }

  try {
    // Get the UserRequest from Firestore
    final doc = await FirebaseFirestore.instance
        .collection('user_requests')
        .doc(requestId)
        .get();
    
    if (!doc.exists) {
      print('❌ UserRequest not found: $requestId');
      return;
    }

    final userRequest = UserRequest.fromFirestore(doc);
    final deadlineTimestamp = data['deadline_timestamp'];
    DateTime? deadline;
    
    if (deadlineTimestamp != null) {
      deadline = DateTime.fromMillisecondsSinceEpoch(int.parse(deadlineTimestamp) * 1000);
    }

    navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (context) => ProviderBidScreen(
          requestId: requestId,
          userRequest: userRequest,
          deadline: deadline,
        ),
      ),
    );
  } catch (e) {
    print('❌ Error navigating to bid screen: $e');
  }
}

Future<void> _navigateToBidComparisonScreen(BuildContext context, Map<String, dynamic> data) async {
  final requestId = data['request_id'];
  if (requestId == null) {
    print('❌ Missing request_id for bid comparison');
    return;
  }

  try {
    // Get the UserRequest from Firestore
    final doc = await FirebaseFirestore.instance
        .collection('user_requests')
        .doc(requestId)
        .get();
    
    if (!doc.exists) {
      print('❌ UserRequest not found: $requestId');
      return;
    }

    final userRequest = UserRequest.fromFirestore(doc);

    navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (context) => BidComparisonScreen(
          requestId: requestId,
          userRequest: userRequest,
        ),
      ),
    );
  } catch (e) {
    print('❌ Error navigating to bid comparison: $e');
  }
}

Future<void> _handleBidResultNavigation(BuildContext context, Map<String, dynamic> data) async {
  final isWinner = data['is_winner'] == 'true';
  
  if (isWinner) {
    print('🎉 Bid won! Would navigate to job details screen');
    // TODO: Navigate to job details/management screen
  } else {
    print('😔 Bid not selected. Staying on current screen');
    // Maybe show a snackbar or dialog
  }
}

Future<void> _handleStatusUpdateNavigation(BuildContext context, Map<String, dynamic> data) async {
  final status = data['status'];
  
  if (status == 'verified' || status == 'active') {
    print('🎉 Account verified! Would navigate to provider dashboard');
    // TODO: Navigate to provider dashboard
  } else if (status == 'rejected') {
    print('❌ Application rejected. Would navigate to support');
    // TODO: Navigate to support/help screen
  }
}
