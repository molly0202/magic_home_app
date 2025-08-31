import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/user_request_service.dart';
import '../../services/ai_conversation_service.dart';

class ServiceRequestIntegrationTestScreen extends StatefulWidget {
  const ServiceRequestIntegrationTestScreen({super.key});

  @override
  State<ServiceRequestIntegrationTestScreen> createState() => _ServiceRequestIntegrationTestScreenState();
}

class _ServiceRequestIntegrationTestScreenState extends State<ServiceRequestIntegrationTestScreen> {
  bool _isLoading = false;
  String _testResult = '';
  Map<String, dynamic>? _lastTestResult;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBB04C),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFBB04C),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Service Request Integration Test',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Integration Test: Service Request → User Request → Provider Matching → Bidding',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'This test verifies the complete flow from AI intake completion through provider matching to bidding system activation.',
                      style: TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _runIntegrationTest,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFBB04C),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Run Integration Test'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Test Results',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: SingleChildScrollView(
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _testResult.isEmpty 
                                  ? 'No test results yet. Run the integration test to see results.'
                                  : _testResult,
                              style: TextStyle(
                                fontSize: 12,
                                fontFamily: 'monospace',
                                color: Colors.grey[800],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (_lastTestResult != null) ...[
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _lastTestResult!['testPassed'] == true
                                ? Icons.check_circle
                                : Icons.error,
                            color: _lastTestResult!['testPassed'] == true
                                ? Colors.green
                                : Colors.red,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _lastTestResult!['testPassed'] == true
                                ? 'Test Passed'
                                : 'Test Failed',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: _lastTestResult!['testPassed'] == true
                                  ? Colors.green
                                  : Colors.red,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _lastTestResult!['message'] ?? 'No message',
                        style: const TextStyle(fontSize: 14),
                      ),
                      if (_lastTestResult!['result'] != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Matched Providers: ${_lastTestResult!['result']['matchingSummary']['totalMatches'] ?? 0}',
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _runIntegrationTest() async {
    setState(() {
      _isLoading = true;
      _testResult = 'Starting integration test...\n\n';
      _lastTestResult = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User must be logged in to run test');
      }

      _appendTestResult('🧪 Running Service Request Integration Test');
      _appendTestResult('👤 User ID: ${user.uid}');
      _appendTestResult('');

      // Create mock service request data matching the screenshot
      final mockData = {
        'serviceCategory': 'handyman',
        'description': 'I need handyman service to fix',
        'mediaUrls': ['https://example.com/photo1.jpg'],
        'address': '333 Dexter Ave N, Seattle, WA 98109',
        'phoneNumber': '4128888888',
        'userAvailability': {
          'selectedDate': '2025-08-31',
          'timePreference': 'Evening (5PM - 8PM)',
          'urgency': 'normal'
        },
        'aiPriceEstimation': {
          'suggestedRange': {'min': 95, 'max': 238},
          'aiModel': 'ai-conversation-v1',
          'confidenceLevel': 'medium'
        },
        'serviceRequestSummary': {
          'serviceDescription': 'Sir handle broken on my refrigerator and I need to install a microwave',
          'problemDescription': 'Customer needs handyman service to fix broken refrigerator handle and install a microwave',
          'isComplete': true
        }
      };

      _appendTestResult('📋 Test Data Prepared:');
      _appendTestResult('   - Service: ${mockData['serviceCategory']}');
      _appendTestResult('   - Address: ${mockData['address']}');
      _appendTestResult('   - Phone: ${mockData['phoneNumber']}');
      _appendTestResult('');

      // Run the complete integration test
      _appendTestResult('🚀 Running complete integration flow...');
      final result = await UserRequestService.testCompleteIntegrationFlow(
        userId: user.uid,
        mockServiceRequestData: mockData,
      );

      _appendTestResult('');
      _appendTestResult('📊 Test Results:');
      _appendTestResult('   - Test Passed: ${result['testPassed']}');
      _appendTestResult('   - Message: ${result['message']}');

      if (result['result'] != null) {
        final flowResult = result['result'] as Map<String, dynamic>;
        final summary = flowResult['matchingSummary'] as Map<String, dynamic>;
        
        _appendTestResult('');
        _appendTestResult('🔍 Provider Matching Results:');
        _appendTestResult('   - Total Matches: ${summary['totalMatches']}');
        _appendTestResult('   - Top Score: ${summary['topScore']?.toStringAsFixed(2) ?? 'N/A'}');
        _appendTestResult('   - Has Referrals: ${summary['hasReferrals']}');
        _appendTestResult('   - Avg Distance: ${summary['avgDistance']?.toStringAsFixed(1) ?? 'N/A'} km');
        
        if (flowResult['userRequest'] != null) {
          final userRequest = flowResult['userRequest'] as Map<String, dynamic>;
          _appendTestResult('');
          _appendTestResult('📝 User Request Created:');
          _appendTestResult('   - Request ID: ${userRequest['requestId']}');
          _appendTestResult('   - Status: ${userRequest['status']}');
          _appendTestResult('   - Category: ${userRequest['serviceCategory']}');
          _appendTestResult('   - Description: ${userRequest['description']}');
        }
      }

      if (result['error'] != null) {
        _appendTestResult('');
        _appendTestResult('❌ Error Details:');
        _appendTestResult('   ${result['error']}');
      }

      setState(() {
        _lastTestResult = result;
      });

    } catch (e) {
      _appendTestResult('');
      _appendTestResult('❌ Test Exception: $e');
      setState(() {
        _lastTestResult = {
          'testPassed': false,
          'message': 'Test threw exception: $e',
        };
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _appendTestResult(String message) {
    setState(() {
      _testResult += '$message\n';
    });
  }
}
