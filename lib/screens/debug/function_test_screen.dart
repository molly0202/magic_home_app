import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';

class FunctionTestScreen extends StatefulWidget {
  const FunctionTestScreen({super.key});

  @override
  State<FunctionTestScreen> createState() => _FunctionTestScreenState();
}

class _FunctionTestScreenState extends State<FunctionTestScreen> {
  String _lastResult = '';
  bool _isLoading = false;

  // Test basic notification function
  Future<void> _testBasicNotification() async {
    setState(() {
      _isLoading = true;
      _lastResult = 'Testing basic notification...';
    });

    try {
      // Use current user ID
      final user = FirebaseAuth.instance.currentUser;
      final providerId = user?.uid ?? 'wDIHYfAmbJgreRJO6gPCobg724h1';
      
      setState(() {
        _lastResult += '\nUsing provider ID: $providerId';
      });

      final response = await http.post(
        Uri.parse('https://test-notification-24e4euigxq-uc.a.run.app'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'provider_id': providerId,
          'status': 'verified',
        }),
      );

      setState(() {
        _lastResult = 'Basic Notification Response: ${response.statusCode}\n${response.body}';
      });
    } catch (e) {
      setState(() {
        _lastResult = 'Error: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Test bidding notification with different urgency levels
  Future<void> _testBiddingNotification(String urgency) async {
    setState(() {
      _isLoading = true;
      _lastResult = 'Testing $urgency bidding notification...';
    });

    String taskDescription;
    String priceRange;
    
    switch (urgency) {
      case 'critical':
        taskDescription = 'EMERGENCY: Gas leak detected in kitchen';
        priceRange = '200-400';
        break;
      case 'high':
        taskDescription = 'Electrical outlet sparking - safety concern';
        priceRange = '100-180';
        break;
      default:
        taskDescription = 'Bathroom faucet repair needed';
        priceRange = '80-120';
    }

    try {
      // Use current user ID
      final user = FirebaseAuth.instance.currentUser;
      final providerId = user?.uid ?? 'wDIHYfAmbJgreRJO6gPCobg724h1';
      
      setState(() {
        _lastResult += '\nUsing provider ID: $providerId';
      });

      final response = await http.post(
        Uri.parse('https://us-central1-magic-home-01.cloudfunctions.net/send_bidding_notification'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'provider_ids': [providerId],
          'request_id': 'test_${urgency}_${DateTime.now().millisecondsSinceEpoch}',
          'task_description': taskDescription,
          'suggested_price': priceRange,
          'urgency': urgency,
          'deadline_hours': urgency == 'critical' ? 1 : 2,
        }),
      );

      setState(() {
        _lastResult = '$urgency Bidding Notification Response: ${response.statusCode}\n${response.body}';
      });
    } catch (e) {
      setState(() {
        _lastResult = 'Error: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Test provider status update (triggers Firestore notification)
  Future<void> _testStatusUpdate() async {
    setState(() {
      _isLoading = true;
      _lastResult = 'Testing status update...';
    });

    try {
      // Use current user ID
      final user = FirebaseAuth.instance.currentUser;
      final providerId = user?.uid ?? 'wDIHYfAmbJgreRJO6gPCobg724h1';
      
      setState(() {
        _lastResult += '\nUsing provider ID: $providerId';
      });

      final response = await http.post(
        Uri.parse('https://update-provider-status-24e4euigxq-uc.a.run.app'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'provider_id': providerId,
          'status': 'verified',
        }),
      );

      setState(() {
        _lastResult = 'Status Update Response: ${response.statusCode}\n${response.body}';
      });
    } catch (e) {
      setState(() {
        _lastResult = 'Error: $e';
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
        title: const Text('Function Testing'),
        backgroundColor: Colors.purple,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '🧪 Firebase Function Testing',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),

            // Basic Tests Section
            const Text(
              'Basic Function Tests:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            
            ElevatedButton(
              onPressed: _isLoading ? null : _testBasicNotification,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
              child: const Text('Test Basic Notification'),
            ),
            
            ElevatedButton(
              onPressed: _isLoading ? null : _testStatusUpdate,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: const Text('Test Status Update'),
            ),

            const SizedBox(height: 20),

            // Bidding Notification Tests
            const Text(
              'Bidding Notification Tests:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),

            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : () => _testBiddingNotification('normal'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                    child: const Text('Normal Urgency'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : () => _testBiddingNotification('high'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                    child: const Text('High Urgency'),
                  ),
                ),
              ],
            ),

            ElevatedButton(
              onPressed: _isLoading ? null : () => _testBiddingNotification('critical'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[900],
                foregroundColor: Colors.white,
              ),
              child: const Text('🚨 CRITICAL URGENCY'),
            ),

            const SizedBox(height: 20),

            // Results section
            const Text(
              'Results:',
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
                    _lastResult.isEmpty ? 'No tests run yet...' : _lastResult,
                    style: const TextStyle(fontFamily: 'monospace'),
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
