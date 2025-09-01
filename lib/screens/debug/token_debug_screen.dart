import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/notification_service.dart';

class TokenDebugScreen extends StatefulWidget {
  const TokenDebugScreen({super.key});

  @override
  State<TokenDebugScreen> createState() => _TokenDebugScreenState();
}

class _TokenDebugScreenState extends State<TokenDebugScreen> {
  String _debugInfo = 'Ready to debug FCM tokens...';
  bool _isLoading = false;

  Future<void> _forceTokenRegistration() async {
    setState(() {
      _isLoading = true;
      _debugInfo = 'Starting FCM token registration...\n';
    });

    try {
      // Get current user
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _debugInfo += '❌ No authenticated user found!\n';
        });
        return;
      }

      setState(() {
        _debugInfo += '✅ User authenticated: ${user.uid}\n';
      });

      // Force initialize push notifications
      await NotificationService.initializePushNotifications(user.uid);
      
      // Wait a moment then check what was saved
      await Future.delayed(const Duration(seconds: 2));
      
      // Check Firestore for saved tokens
      final doc = await FirebaseFirestore.instance
          .collection('providers')
          .doc(user.uid)
          .get();
      
      if (doc.exists) {
        final data = doc.data()!;
        final tokens = data['fcmTokens'] as List<dynamic>?;
        setState(() {
          _debugInfo += '📄 Provider document exists\n';
          _debugInfo += '🔑 FCM tokens count: ${tokens?.length ?? 0}\n';
          if (tokens != null && tokens.isNotEmpty) {
            _debugInfo += '🔑 First token: ${tokens.first.toString().substring(0, 50)}...\n';
          }
          _debugInfo += '📊 Full document data: $data\n';
        });
      } else {
        setState(() {
          _debugInfo += '❌ Provider document does NOT exist!\n';
        });
      }

    } catch (e) {
      setState(() {
        _debugInfo += '❌ Error: $e\n';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _checkCurrentStatus() async {
    setState(() {
      _isLoading = true;
      _debugInfo = 'Checking current status...\n';
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _debugInfo += '❌ No authenticated user\n';
        });
        return;
      }

      setState(() {
        _debugInfo += '👤 Current user ID: ${user.uid}\n';
        _debugInfo += '📧 User email: ${user.email}\n';
      });

      // Check provider document
      final doc = await FirebaseFirestore.instance
          .collection('providers')
          .doc(user.uid)
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          _debugInfo += '✅ Provider document exists\n';
          _debugInfo += '📊 Status: ${data['status'] ?? 'unknown'}\n';
          _debugInfo += '🔑 FCM tokens: ${data['fcmTokens'] ?? 'none'}\n';
          _debugInfo += '📅 Last update: ${data['lastTokenUpdate']}\n';
        });
      } else {
        setState(() {
          _debugInfo += '❌ Provider document does NOT exist\n';
        });
      }

      // Test hardcoded provider ID too
      final testDoc = await FirebaseFirestore.instance
          .collection('providers')
          .doc('wDIHYfAmbJgreRJO6gPCobg724h1')
          .get();

      setState(() {
        _debugInfo += '\n🧪 TEST PROVIDER (wDIHYfAmbJgreRJO6gPCobg724h1):\n';
        if (testDoc.exists) {
          final testData = testDoc.data()!;
          _debugInfo += '✅ Test provider exists\n';
          _debugInfo += '🔑 FCM tokens: ${testData['fcmTokens'] ?? 'none'}\n';
          _debugInfo += '📊 Status: ${testData['status'] ?? 'unknown'}\n';
        } else {
          _debugInfo += '❌ Test provider does NOT exist\n';
        }
      });

    } catch (e) {
      setState(() {
        _debugInfo += '❌ Error: $e\n';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('FCM Token Debug'),
        backgroundColor: Colors.deepPurple,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '🔍 FCM Token Debugging',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: _isLoading ? null : _checkCurrentStatus,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
              child: const Text('Check Current Status'),
            ),
            
            ElevatedButton(
              onPressed: _isLoading ? null : _forceTokenRegistration,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: const Text('Force FCM Token Registration'),
            ),

            const SizedBox(height: 20),

            const Text(
              'Debug Information:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.grey[50],
                ),
                child: SingleChildScrollView(
                  child: Text(
                    _debugInfo,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                  ),
                ),
              ),
            ),

            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
      ),
    );
  }
}
