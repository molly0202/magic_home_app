import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/ai_conversation_service.dart';
import '../../config/api_config.dart';

class GeminiTestScreen extends StatefulWidget {
  const GeminiTestScreen({super.key});

  @override
  State<GeminiTestScreen> createState() => _GeminiTestScreenState();
}

class _GeminiTestScreenState extends State<GeminiTestScreen> {
  bool _isLoading = false;
  String _testResult = '';
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _checkConfiguration();
  }

  void _checkConfiguration() {
    setState(() {
      _testResult = '=== GEMINI API CONFIGURATION ===\n';
      if (ApiConfig.isGeminiConfigured) {
        _testResult += '✅ Gemini API Key: CONFIGURED\n';
        _testResult += '🔑 Key Length: ${ApiConfig.geminiApiKey.length} characters\n';
        _testResult += '🔗 Prefix: ${ApiConfig.geminiApiKey.substring(0, 8)}...\n';
      } else {
        _testResult += '❌ Gemini API Key: NOT CONFIGURED\n';
        _testResult += '⚠️  Using placeholder key: ${ApiConfig.geminiApiKey}\n';
      }
      _testResult += '🌐 Base URL: ${ApiConfig.geminiBaseUrl}\n';
      _testResult += '🎯 Max Tokens: ${ApiConfig.maxTokens}\n';
      _testResult += '🔄 Max Retries: ${ApiConfig.maxRetries}\n';
      _testResult += '⏱️  Timeout: ${ApiConfig.apiTimeout.inSeconds}s\n';
      _testResult += '================================\n\n';
    });
  }

  Future<void> _testConnection() async {
    setState(() {
      _isLoading = true;
      _testResult += '🔄 TESTING GEMINI CONNECTION...\n';
      _testResult += 'Timestamp: ${DateTime.now()}\n';
    });

    try {
      final stopwatch = Stopwatch()..start();
      final result = await AIConversationService.testGeminiConnection();
      stopwatch.stop();
      
      setState(() {
        _testResult += '⏱️  Response Time: ${stopwatch.elapsedMilliseconds}ms\n';
        
        if (result) {
          _testResult += '✅ CONNECTION SUCCESSFUL!\n';
          _testResult += '🎉 Gemini API is responding correctly\n';
          _showSnackBar('✅ Gemini API connection successful!', Colors.green);
        } else {
          _testResult += '❌ CONNECTION FAILED\n';
          if (!ApiConfig.isGeminiConfigured) {
            _testResult += '💡 Reason: API key not configured\n';
          } else {
            _testResult += '💡 Reason: Check API key validity or network\n';
          }
          _showSnackBar('❌ Gemini API connection failed', Colors.red);
        }
        _testResult += '================================\n\n';
      });
    } catch (e) {
      setState(() {
        _testResult += '💥 EXCEPTION OCCURRED:\n';
        _testResult += '❌ Error: $e\n';
        _testResult += '================================\n\n';
      });
      _showSnackBar('💥 Connection error: $e', Colors.red);
    } finally {
      setState(() {
        _isLoading = false;
      });
      _scrollToBottom();
    }
  }

  Future<void> _testCustomMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) {
      _showSnackBar('❌ Please enter a test message', Colors.orange);
      return;
    }

    setState(() {
      _isLoading = true;
      _testResult += '🔄 TESTING CUSTOM MESSAGE...\n';
      _testResult += '📤 Input: "$message"\n';
      _testResult += 'Timestamp: ${DateTime.now()}\n';
    });

    try {
      final stopwatch = Stopwatch()..start();
      final aiService = AIConversationService();
      aiService.startConversation();
      final response = await aiService.processUserInput(message);
      stopwatch.stop();
      
      setState(() {
        _testResult += '⏱️  Response Time: ${stopwatch.elapsedMilliseconds}ms\n';
        _testResult += '📥 Response: "$response"\n';
        _testResult += '📊 Response Length: ${response.length} characters\n';
        
        // Check conversation state
        _testResult += '🔍 Conversation Analysis:\n';
        _testResult += '   • Service Category: ${aiService.currentState.serviceCategory ?? "None detected"}\n';
        _testResult += '   • Conversation Step: ${aiService.currentState.conversationStep}\n';
        _testResult += '   • Photo Upload Requested: ${aiService.currentState.photoUploadRequested}\n';
        _testResult += '   • Calendar Requested: ${aiService.currentState.calendarRequested}\n';
        
        _testResult += '✅ CUSTOM MESSAGE TEST SUCCESSFUL!\n';
        _testResult += '================================\n\n';
      });
      
      _showSnackBar('✅ Custom message test successful!', Colors.green);
    } catch (e) {
      setState(() {
        _testResult += '💥 CUSTOM MESSAGE ERROR:\n';
        _testResult += '❌ Error: $e\n';
        _testResult += '================================\n\n';
      });
      _showSnackBar('💥 Custom message error: $e', Colors.red);
    } finally {
      setState(() {
        _isLoading = false;
      });
      _scrollToBottom();
    }
  }

  Future<void> _runFullTest() async {
    setState(() {
      _isLoading = true;
      _testResult += '🚀 RUNNING FULL GEMINI TEST SUITE...\n';
      _testResult += 'Started at: ${DateTime.now()}\n';
      _testResult += '================================\n\n';
    });

    try {
      // Test 1: Connection
      _testResult += '📋 TEST 1: Connection Test\n';
      await _testConnection();
      
      // Test 2: Simple Message
      await Future.delayed(const Duration(seconds: 1));
      _messageController.text = 'Hello, test message';
      _testResult += '📋 TEST 2: Simple Message Test\n';
      await _testCustomMessage();
      
      // Test 3: Service Request
      await Future.delayed(const Duration(seconds: 1));
      _messageController.text = 'I need cleaning service for my house';
      _testResult += '📋 TEST 3: Service Request Test\n';
      await _testCustomMessage();
      
      // Test 4: Follow-up
      await Future.delayed(const Duration(seconds: 1));
      _messageController.text = 'Deep cleaning, the whole house is very dirty';
      _testResult += '📋 TEST 4: Follow-up Message Test\n';
      await _testCustomMessage();

      setState(() {
        _testResult += '🎉 FULL TEST SUITE COMPLETED!\n';
        _testResult += 'Completed at: ${DateTime.now()}\n';
        _testResult += '================================\n\n';
      });
      
      _showSnackBar('🎉 Full test suite completed!', Colors.green);
      
    } catch (e) {
      setState(() {
        _testResult += '💥 FULL TEST SUITE FAILED:\n';
        _testResult += '❌ Error: $e\n';
        _testResult += '================================\n\n';
      });
      _showSnackBar('💥 Full test suite failed: $e', Colors.red);
    } finally {
      setState(() {
        _isLoading = false;
      });
      _scrollToBottom();
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _clearResults() {
    setState(() {
      _testResult = '';
      _messageController.clear();
    });
    _checkConfiguration();
  }

  void _copyResults() {
    Clipboard.setData(ClipboardData(text: _testResult));
    _showSnackBar('📋 Test results copied to clipboard', Colors.blue);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gemini API Functional Test'),
        backgroundColor: const Color(0xFFFBB04C),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.copy),
            onPressed: _copyResults,
            tooltip: 'Copy Results',
          ),
          IconButton(
            icon: const Icon(Icons.clear),
            onPressed: _clearResults,
            tooltip: 'Clear Results',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status Card
            Card(
              color: ApiConfig.isGeminiConfigured ? Colors.green[50] : Colors.red[50],
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Icon(
                      ApiConfig.isGeminiConfigured ? Icons.check_circle : Icons.error,
                      color: ApiConfig.isGeminiConfigured ? Colors.green : Colors.red,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ApiConfig.isGeminiConfigured ? 'API Configured' : 'API Not Configured',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: ApiConfig.isGeminiConfigured ? Colors.green[800] : Colors.red[800],
                            ),
                          ),
                          Text(
                            ApiConfig.isGeminiConfigured 
                                ? 'Ready to test Gemini API' 
                                : 'Add your API key to lib/config/api_config.dart',
                            style: TextStyle(
                              fontSize: 12,
                              color: ApiConfig.isGeminiConfigured ? Colors.green[700] : Colors.red[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Test Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _testConnection,
                    icon: _isLoading 
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.wifi_tethering),
                    label: const Text('Test Connection'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFBB04C),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _runFullTest,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Full Test'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Custom Message Test
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Custom Message Test',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _messageController,
                      decoration: const InputDecoration(
                        hintText: 'Enter your test message here...',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                      enabled: !_isLoading,
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _testCustomMessage,
                      icon: const Icon(Icons.send),
                      label: const Text('Send Test Message'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Results
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Test Results & Logs',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: SingleChildScrollView(
                            controller: _scrollController,
                            child: Text(
                              _testResult.isEmpty ? 'Ready to run tests...\n\nInstructions:\n1. Click "Test Connection" to verify API setup\n2. Enter a message and click "Send Test Message"\n3. Or click "Full Test" to run all tests automatically' : _testResult,
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 11,
                                height: 1.4,
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
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
} 