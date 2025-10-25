import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'ai_conversation_service.dart';
import '../config/elevenlabs_config.dart';

/// ElevenLabs Conversation Service
/// Handles real-time voice conversations using ElevenLabs Conversation API
/// Reference: https://elevenlabs.io/app/developers
class ElevenLabsConversationService {
  static final ElevenLabsConversationService _instance = ElevenLabsConversationService._internal();
  factory ElevenLabsConversationService() => _instance;
  ElevenLabsConversationService._internal();

  // ElevenLabs API Configuration (using config)
  static String get _baseUrl => ElevenLabsConfig.baseUrl;
  static String get _apiKey => ElevenLabsConfig.apiKey;
  static String get _agentId => ElevenLabsConfig.agentId;
  
  // WebSocket and Audio
  WebSocketChannel? _channel;
  final AudioPlayer _audioPlayer = AudioPlayer();
  final AudioRecorder _audioRecorder = AudioRecorder();
  StreamSubscription<Uint8List>? _audioStreamSubscription;
  Timer? _silentAudioTimer;
  
  // Conversation State
  ConversationStatus _status = ConversationStatus.disconnected;
  ConversationMode _mode = ConversationMode.voice;
  bool _isSpeaking = false;
  bool _isListening = false;
  String _conversationId = '';
  bool _isVoiceMode = false; // Track if we're in voice mode for audio playback
  bool _conversationReady = false; // Track if conversation is ready to receive messages
  bool _hasReceivedFirstMessage = false; // Track if we've received the initial greeting
  int _responseCounter = 0; // Track number of responses per request for debugging
  bool _hasReceivedResponseForCurrentTurn = false; // Track if we've already received a response for current user message
  
  // Audio playback tracking (NO accumulation needed)
  Timer? _resumeListeningTimer; // Timer to resume listening after audio finishes
  int _audioChunkCount = 0; // Track number of audio chunks received
  DateTime? _lastAudioChunkTime; // Track when last audio chunk arrived
  String? _lastAgentResponseText; // Track last response to prevent duplicates
  DateTime? _lastAgentResponseTime; // Track when last response was added
  
  // Audio Buffer Queue System
  final List<Uint8List> _audioQueue = []; // Queue of audio chunks to play
  bool _isPlayingFromQueue = false; // Track if queue playback is active
  bool _isBuffering = false; // Track if we're buffering initial chunks
  final int _minBufferChunks = 1; // Minimum chunks to buffer before starting (reduced for faster start)
  Timer? _bufferTimeoutTimer; // Timeout for buffering
  int _playedChunkCount = 0; // Track chunks played
  int _droppedChunkCount = 0; // Track dropped chunks for debugging
  
  // Stream Controllers for UI updates
  final StreamController<ConversationStatus> _statusController = StreamController<ConversationStatus>.broadcast();
  final StreamController<String> _transcriptController = StreamController<String>.broadcast();
  final StreamController<bool> _listeningController = StreamController<bool>.broadcast();
  final StreamController<bool> _speakingController = StreamController<bool>.broadcast();
  final StreamController<String> _errorController = StreamController<String>.broadcast();
  final StreamController<bool> _photoRequestController = StreamController<bool>.broadcast();
  final StreamController<bool> _bufferingController = StreamController<bool>.broadcast();
  
  // Getters for UI
  Stream<ConversationStatus> get statusStream => _statusController.stream;
  Stream<String> get transcriptStream => _transcriptController.stream;
  Stream<bool> get listeningStream => _listeningController.stream;
  Stream<bool> get speakingStream => _speakingController.stream;
  Stream<String> get errorStream => _errorController.stream;
  Stream<bool> get photoRequestStream => _photoRequestController.stream;
  Stream<bool> get bufferingStream => _bufferingController.stream;
  
  ConversationStatus get status => _status;
  bool get isSpeaking => _isSpeaking;
  bool get isListening => _isListening;
  ConversationMode get mode => _mode;
  bool get isBuffering => _isBuffering;

  /// Test ElevenLabs connection and audio playback
  Future<bool> testConnection() async {
    try {
      print('🧪 Testing ElevenLabs connection...');
      print('🧪 API Key: ${_apiKey.substring(0, 10)}...');
      print('🧪 Agent ID: $_agentId');
      
      // Test configuration first
      if (!ElevenLabsConfig.isConfigured) {
        print('❌ ElevenLabs not configured properly');
        return false;
      }
      
      print('✅ ElevenLabs configuration valid');
      
      // Test audio player initialization (without playing)
      print('🎵 Testing audio player initialization...');
      try {
        await _audioPlayer.setPlayerMode(PlayerMode.mediaPlayer);
        print('✅ Audio player configured');
      } catch (e) {
        print('⚠️ Audio player configuration warning: $e');
        // Don't fail the test for audio player issues
      }
      
      // Test WebSocket URL generation
      print('🔗 Testing WebSocket URL generation...');
      final url = ElevenLabsConfig.getWebSocketUrl(null);
      print('🌐 WebSocket URL: $url');
      
      // Test TTS API call (without playing audio)
      print('🗣️ Testing TTS API call...');
      try {
        final response = await http.post(
          Uri.parse('https://api.elevenlabs.io/v1/text-to-speech/pNInz6obpgDQGcFmaJgB'),
          headers: {
            'xi-api-key': _apiKey,
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'text': 'Test',
            'model_id': 'eleven_monolingual_v1',
            'voice_settings': {
              'stability': 0.5,
              'similarity_boost': 0.5,
            },
          }),
        );
        
        if (response.statusCode == 200) {
          print('✅ TTS API test successful');
          print('📊 Audio data size: ${response.bodyBytes.length} bytes');
        } else {
          print('❌ TTS API test failed: ${response.statusCode}');
          print('❌ Response: ${response.body}');
          return false;
        }
      } catch (e) {
        print('❌ TTS API test error: $e');
        return false;
      }
      
      print('✅ All ElevenLabs tests passed');
      return true;
      
    } catch (e) {
      print('❌ ElevenLabs connection test failed: $e');
      return false;
    }
  }

  /// Initialize the service and request permissions
  Future<bool> initialize() async {
    try {
      print('🎤 Initializing ElevenLabs Conversation Service...');
      
      // Check configuration
      if (!ElevenLabsConfig.isConfigured) {
        print('❌ ElevenLabs configuration not properly set. Please update lib/config/elevenlabs_config.dart');
        return false;
      }
      
      // Check microphone permission status
      print('🔍 Checking microphone permission...');
      final currentStatus = await Permission.microphone.status;
      print('🎤 Current microphone status: $currentStatus');
      
      final micPermission = await Permission.microphone.request();
      print('🎤 After request - microphone status: $micPermission');
      
      if (micPermission != PermissionStatus.granted) {
        print('⚠️ Microphone permission not granted: $micPermission');
        print('ℹ️ Note: If you granted permission in Settings, try restarting the app');
      } else {
        print('✅ Microphone permission granted successfully');
      }
      
      // Local speech-to-text disabled - using ElevenLabs WebSocket for voice
      print('ℹ️ Local speech-to-text disabled');
      
      // Configure audio player for voice chat (one-time setup)
      try {
        print('🔧 Configuring audio player for voice mode...');
        await _audioPlayer.setPlayerMode(PlayerMode.mediaPlayer);
        await _audioPlayer.setVolume(1.0);
        await _audioPlayer.setAudioContext(AudioContext(
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.playAndRecord,
            options: [
              AVAudioSessionOptions.defaultToSpeaker,
              AVAudioSessionOptions.allowBluetooth,
              AVAudioSessionOptions.allowBluetoothA2DP,
              AVAudioSessionOptions.duckOthers,
            ],
          ),
          android: AudioContextAndroid(
            isSpeakerphoneOn: true,
            stayAwake: true,
            contentType: AndroidContentType.speech,
            usageType: AndroidUsageType.voiceCommunication,
            audioFocus: AndroidAudioFocus.gain,
          ),
        ));
        print('✅ Audio player configured for voice chat');
      } catch (e) {
        print('⚠️ Audio configuration warning: $e (will retry during playback)');
      }
      
      print('✅ ElevenLabs service initialized successfully');
      
      // IMPORTANT: Always return true to allow voice mode to try
      // Even if permission check fails, it might be a caching issue
      // The actual microphone access will be tested when recording starts
      return true;
    } catch (e) {
      print('❌ Failed to initialize ElevenLabs service: $e');
      return false;
    }
  }

  /// Connect to ElevenLabs Conversation API
  Future<bool> connect({String? customAgentId}) async {
    try {
      print('🔗 Connecting to ElevenLabs...');
      _updateStatus(ConversationStatus.connecting);
      
      final agentId = customAgentId ?? _agentId;
      final wsUrl = ElevenLabsConfig.getWebSocketUrl(agentId);
      print('🌐 WebSocket URL: ${wsUrl.replaceAll(_apiKey, '[REDACTED]')}');
      
      final uri = Uri.parse(wsUrl);
      print('📡 Attempting WebSocket connection...');
      
      _channel = WebSocketChannel.connect(
        uri,
        protocols: null,
      );
      
      print('🎯 WebSocket channel created, waiting for server confirmation...');
      print('📡 No auth message needed - agent_id in URL is the authentication');
      
      // Wait for connection confirmation with timeout
      print('⏳ Waiting for connection confirmation (20s timeout)...');
      
      final completer = Completer<bool>();
      Timer? timeoutTimer;
      
      // Set up timeout - increased to 20 seconds to handle slow connections
      timeoutTimer = Timer(const Duration(seconds: 20), () {
        if (!completer.isCompleted) {
          print('⏰ ElevenLabs connection timeout after 20 seconds');
          _updateStatus(ConversationStatus.error);
          _channel?.sink.close();
          _channel = null;
          completer.complete(false);
        }
      });
      
      // Set up the main message listener with connection confirmation
      _channel!.stream.listen(
        (message) {
          // First message confirms connection
          if (!completer.isCompleted) {
            print('🎉 First message received - connection established!');
            timeoutTimer?.cancel();
            _updateStatus(ConversationStatus.connected);
            // Don't set _conversationReady here - it will be set after completer finishes
            completer.complete(true);
          }
          
          // Handle all messages normally
          _handleWebSocketMessage(message);
        },
        onError: (error) {
          print('❌ WebSocket connection error: $error');
          timeoutTimer?.cancel();
          if (!completer.isCompleted) {
            _updateStatus(ConversationStatus.error);
            completer.complete(false);
          } else {
            _updateStatus(ConversationStatus.error);
          }
        },
        onDone: () async {
          print('🔚 WebSocket connection closed');
          
          // Don't auto-reconnect - just update status
          // The user can manually reconnect by pressing the phone button if needed
          _updateStatus(ConversationStatus.disconnected);
          
          // Stop listening to prevent microphone issues
          if (_isListening) {
            await stopListening();
          }
        },
      );
      
      final connected = await completer.future;
      
      if (connected) {
        print('✅ Successfully connected to ElevenLabs');
        
        // For TEXT mode, mark as ready immediately (no session needed)
        // For VOICE mode, startSession() will mark as ready
        if (_mode == ConversationMode.text) {
          _conversationReady = true;
          print('✅ Text mode: Conversation ready for messages (no session required)');
        }
        
        return true;
      } else {
        print('❌ Failed to establish ElevenLabs connection');
        return false;
      }
      
    } catch (e) {
      print('❌ Failed to connect to ElevenLabs: $e');
      _updateStatus(ConversationStatus.error);
      return false;
    }
  }

  /// Start a new conversation session
  Future<void> startSession() async {
    // Allow starting session if connected OR already active (for mode switching)
    if (_status != ConversationStatus.connected && _status != ConversationStatus.active) {
      throw Exception('Not connected to ElevenLabs');
    }
    
    print('🎬 Starting conversation session...');
    _updateStatus(ConversationStatus.active);
    
    // Reset conversation state for new session
    _hasReceivedResponseForCurrentTurn = false;
    _responseCounter = 0;
    print('🔄 Conversation state reset for new session - ready for agent responses');
    
    // Set voice mode based on current mode
    _isVoiceMode = (_mode == ConversationMode.voice || _mode == ConversationMode.hybrid);
    
    // Send session configuration to control turn detection
    try {
      final sessionConfig = {
        'type': 'session_settings',
        'settings': {
          'turn_detection': {
            'type': 'server_vad', // Use server-side Voice Activity Detection
            'threshold': 0.5, // Sensitivity (0.0 - 1.0)
            'prefix_padding_ms': 300, // Include 300ms before speech starts
            'silence_duration_ms': 800, // Wait 800ms of USER silence before ending turn
            // IMPORTANT: This should only detect silence in USER audio, not during agent speech
            'detect_speech_only_when_not_speaking': true, // Only detect when agent is quiet
          },
          'input_audio_transcription': {
            'model': 'whisper-1'
          }
        }
      };
      
      if (_channel != null) {
        _channel!.sink.add(json.encode(sessionConfig));
        print('✅ Session configuration sent - turn detection enabled');
        print('   - Silence threshold: 800ms (user silence only)');
        print('   - Agent speech does NOT count toward silence timeout');
      }
    } catch (e) {
      print('⚠️ Could not send session config (may not be supported): $e');
    }
    
    // Mark conversation as ready - we can start sending messages
    _conversationReady = true;
    print('✅ Conversation ready for messages (mode: $_mode)');
    
    // Only start listening in voice mode
    // Text mode doesn't need continuous audio - it sends TTS audio per message
    if (_mode == ConversationMode.voice || _mode == ConversationMode.hybrid) {
      await startListening();
    } else {
      print('📝 Text mode: Ready for text messages (no microphone needed)');
    }
  }

  /// Send a text message to the agent
  Future<void> sendTextMessage(String message) async {
    if (_status != ConversationStatus.active) {
      throw Exception('Conversation not active');
    }
    
    print('💬 Sending text message: $message');
    _transcriptController.add('You: $message');
    
    // Send as user_transcript - this is how text input works in WebSocket mode
    final textMessage = {
      'user_transcript': message,
    };
    
    _channel?.sink.add(json.encode(textMessage));
    print('✅ Text sent as user_transcript to ElevenLabs WebSocket');
  }

  /// Start listening for voice input
  /// Captures raw audio and streams it to ElevenLabs WebSocket
  Future<void> startListening() async {
    try {
      print('🎤 Starting audio recording for ElevenLabs...');
      
      // Check if WebSocket is connected
      if (_channel == null || _status != ConversationStatus.active) {
        print('❌ Cannot start listening: WebSocket not connected');
      return;
    }
    
      // Check if already listening
    if (_isListening) {
        print('⚠️ Already listening');
      return;
    }
    
      // VOICE MODE: Check microphone permission
      final hasPermission = await _audioRecorder.hasPermission();
      if (!hasPermission) {
        print('⚠️ Microphone permission not granted - voice mode will use text input only');
        // Still set listening state so UI shows we're "ready"
        // But we won't actually capture audio - user can send text instead
    _isListening = true;
        _safeAdd(_listeningController, true);
      return;
    }
    
      // Set listening state
    _isListening = true;
      _safeAdd(_listeningController, true);
      
      // CRITICAL: Enable echo cancellation to prevent feedback loop
      // This filters out speaker output from microphone input
      print('🔧 Configuring echo cancellation...');
      
      // Start recording audio stream with echo cancellation
      // Using PCM16 format at 16kHz as recommended by ElevenLabs
      final stream = await _audioRecorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: 16000,
          numChannels: 1,
          bitRate: 256000,
          echoCancel: true, // CRITICAL: Enable echo cancellation
          autoGain: true, // Enable automatic gain control
          noiseSuppress: true, // Enable noise suppression
        ),
      );
      
      print('✅ Echo cancellation enabled');
      
      print('✅ Audio stream started, sending to ElevenLabs...');
      
      // Listen to the audio stream and send chunks to ElevenLabs
      _audioStreamSubscription = stream.listen(
        (audioChunk) {
          // CRITICAL: Only send user audio when agent is NOT speaking
          // This prevents silence timeout from counting agent speech time
          if (_channel != null && _status == ConversationStatus.active && _conversationReady) {
            // Skip sending audio while agent is speaking to avoid confusion
            if (_isSpeaking) {
              // Optionally log that we're skipping (but not too often to avoid spam)
              if (DateTime.now().millisecondsSinceEpoch % 1000 == 0) {
                print('🔇 Skipping user audio while agent is speaking');
              }
              return;
            }
            
            try {
              // Convert audio bytes to base64
              final base64Audio = base64Encode(audioChunk);
              
              // Send user_audio_chunk message to ElevenLabs
              final message = {
                'user_audio_chunk': base64Audio,
              };
              
              _channel!.sink.add(json.encode(message));
              
              // Optional: log every 10th chunk to avoid spam
              if (DateTime.now().millisecondsSinceEpoch % 100 == 0) {
                print('🎵 Sent audio chunk: ${audioChunk.length} bytes (agent quiet)');
              }
            } catch (e) {
              print('❌ Error sending audio chunk: $e');
            }
          }
        },
        onError: (error) {
          print('❌ Audio stream error: $error');
          stopListening();
        },
        onDone: () {
          print('✅ Audio stream completed');
          stopListening();
        },
      );
      
    } catch (e) {
      print('❌ Error starting audio recording: $e');
      _isListening = false;
      _safeAdd(_listeningController, false);
      _errorController.add('Failed to start recording: $e');
    }
  }

  /// Process voice input and handle the conversation flow
  Future<void> _processVoiceInput(String transcript) async {
    try {
      print('🧠 Processing voice input: "$transcript"');
      
      // According to ElevenLabs WebSocket docs:
      // https://elevenlabs.io/docs/agents-platform/libraries/web-sockets
      // Send user_audio_chunk (for audio) or contextual_update (for text/background info)
      if (_channel != null && _status == ConversationStatus.active) {
        print('📤 Sending voice input to ElevenLabs WebSocket...');
        
        // Since we have text (not audio), send as contextual_update
        // This provides the text to the agent without requiring audio
        final messageData = {
          'type': 'contextual_update',
          'text': 'User said: $transcript'
        };
        
        print('📦 Sending contextual_update: ${json.encode(messageData)}');
        _channel!.sink.add(json.encode(messageData));
        print('✅ Voice input sent to ElevenLabs WebSocket');
        
        // Add the user message to the conversation UI
        final aiService = AIConversationService();
        aiService.addMessage(ChatMessage(
          content: transcript,
          type: MessageType.user,
          timestamp: DateTime.now(),
        ));
        
      } else {
        print('❌ ElevenLabs WebSocket not ready for voice input');
      }
      
    } catch (error) {
      print('❌ Error processing voice input: $error');
      
      // If there's an error, continue listening after a brief pause
      if (_status == ConversationStatus.active) {
        await Future.delayed(const Duration(seconds: 1));
        await startListening();
      }
    }
  }

  /// Continue listening after a brief pause (for error recovery or short inputs)
  // Local speech-to-text helper methods removed - no longer needed

  /// Stop listening for voice input
  Future<void> stopListening() async {
    try {
      print('🛑 Stopping audio recording...');
      
      // Cancel silent audio timer if active
      _silentAudioTimer?.cancel();
      _silentAudioTimer = null;
      
      // Cancel audio stream subscription
      await _audioStreamSubscription?.cancel();
      _audioStreamSubscription = null;
      
      // Stop the audio recorder
      await _audioRecorder.stop();
      
      // Update listening state
    _isListening = false;
      _safeAdd(_listeningController, false);
      
      print('✅ Audio recording stopped');
    } catch (e) {
      print('❌ Error stopping audio recording: $e');
      _isListening = false;
      _safeAdd(_listeningController, false);
    }
  }

  /// Add AI message to the conversation
  void _addAIMessage(String text) {
    try {
      // Use the singleton instance to add messages
      final aiService = AIConversationService();
      aiService.addMessage(ChatMessage(
        content: text,
        type: MessageType.ai,
        timestamp: DateTime.now(),
      ));
      print('✅ Added AI message to conversation: $text');
      
      // NOTE: Voice playback is handled by the WebSocket audio chunks in _handleAgentResponse
      // We do NOT need to call TTS API here since ElevenLabs sends audio via WebSocket!
      } catch (e) {
      print('❌ Error adding AI message: $e');
    }
  }

  
  /// Send text message to ElevenLabs via WebSocket
  /// Works for BOTH text mode and voice mode - only difference is audio output
  /// 
  /// [forceTextInVoiceMode] - If true, sends text message even in voice mode (e.g., for photo upload confirmations)
  Future<void> sendMessage(String message, {bool forceTextInVoiceMode = false}) async {
    try {
      print('📤 Sending message to ElevenLabs via WebSocket');
      print('🔍 Mode: ${_isVoiceMode ? "Voice" : "Text"} (audio output: $_isVoiceMode)');
      
      // BOTH modes use WebSocket! Check connection
      // Text mode: status is 'connected', Voice mode: status is 'active'
      if (_channel == null || 
          (_status != ConversationStatus.active && _status != ConversationStatus.connected) || 
          !_conversationReady) {
        print('❌ ElevenLabs WebSocket not ready:');
        print('   - Channel: ${_channel != null ? "connected" : "null"}');
        print('   - Status: $_status');
        print('   - Ready: $_conversationReady');
        return;
      }
      
      print('✅ WebSocket ready - sending message...');
      
      // CRITICAL: Stop any ongoing audio playback when user sends new message (interruption)
      if (_isSpeaking) {
        print('🛑 User interrupted - stopping current audio playback');
        try {
          // Send interruption message to ElevenLabs
          if (_channel != null) {
            _channel!.sink.add(json.encode({
              'type': 'interruption',
            }));
            print('📤 Sent interruption signal to ElevenLabs');
          }
          
          // Stop local audio playback
          await _audioPlayer.stop();
          _isSpeaking = false;
          _safeAdd(_speakingController, false);
          
          // Clear audio queue to prevent old audio from playing
          _audioQueue.clear();
          _audioChunkCount = 0;
          _isPlayingFromQueue = false;
          _isBuffering = false;
          _bufferTimeoutTimer?.cancel();
          
          print('✅ Audio playback stopped and chunks cleared');
        } catch (e) {
          print('⚠️ Error stopping audio: $e');
        }
      }
      
      // Reset the flag to allow ONE response for this new message
      print('🔄 Starting new message - resetting response flag');
      print('   Previous response: $_lastAgentResponseText');
      _responseCounter = 0; // Reset counter for new request
      _hasReceivedResponseForCurrentTurn = false; // Allow ONE response for this turn
      
      // For TEXT mode: Send a silent audio chunk followed by user_transcript to trigger response
      // For VOICE mode: The microphone is already streaming audio, just let it continue
      
      // BOTH text and voice mode need to send user_transcript
      // The difference is:
      // - Text mode: We send user_transcript with the typed text
      // - Voice mode: user_transcript comes from actual audio transcription
      
      if (!_isVoiceMode || forceTextInVoiceMode) {
        // Text mode: Use user_message event - the CORRECT way to send text input
        // Reference: https://elevenlabs.io/docs/agents-platform/customization/events/client-to-server-events
        // "User messages allow you to send text directly to the conversation as if the user had spoken it"
        // "Triggers the same response flow as spoken user input"
        // 
        // forceTextInVoiceMode: Also send in voice mode for special cases like photo upload confirmations
        // NOTE: We DON'T pause the microphone - echo cancellation handles it
        
        final textMessage = {
          'type': 'user_message',
          'text': message,
        };
        final jsonMessage = json.encode(textMessage);
        final timestamp = DateTime.now().toIso8601String();
        _channel!.sink.add(jsonMessage);
        
      } else {
        // Voice mode: The user_transcript will come from the microphone audio
        // We don't send text messages in voice mode - the audio is already streaming
      }
      
      // NOTE: User message is already added by the caller (ai_task_intake_screen.dart)
      // We don't need to add it again here to avoid duplicates
      
    } catch (e) {
      print('❌ Error sending message to ElevenLabs: $e');
    }
  }

  // ========================================
  // DEPRECATED HTTP API METHODS - NO LONGER USED
  // All communication now uses WebSocket ONLY
  // ========================================
  
  /// [DEPRECATED] Convert text to speech using ElevenLabs TTS API
  /// NOTE: This method is no longer used. All communication is via WebSocket.
  Future<void> _convertTextToSpeech(String text) async {
    try {
      print('🔊 Converting text to speech via TTS API...');
      
      final url = Uri.parse('https://api.elevenlabs.io/v1/text-to-speech/pNInz6obpgDQGcFmaJgB');
      
      final response = await http.post(
        url,
        headers: {
          'xi-api-key': _apiKey,
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'text': text,
          'model_id': 'eleven_multilingual_v2',
          'voice_settings': {
            'stability': 0.5,
            'similarity_boost': 0.5,
          }
        }),
      );
      
      if (response.statusCode == 200) {
        print('✅ TTS API response received');
        // In text mode, we don't play audio, just show the text response
        print('📝 Text response: $text');
      } else {
        print('❌ TTS API error: ${response.statusCode} - ${response.body}');
      }
      
    } catch (e) {
      print('❌ Error converting text to speech: $e');
    }
  }

  /// Convert text response to speech using ElevenLabs TTS
  Future<void> _speakResponse(String text) async {
    try {
      print('🗣️ Converting text to speech: "${text.substring(0, text.length.clamp(0, 50))}..."');
      print('🗣️ Full text: $text');
      
      _isSpeaking = true;
      _safeAdd(_speakingController, true);
      
      // Use ElevenLabs TTS API
      final response = await http.post(
        Uri.parse('https://api.elevenlabs.io/v1/text-to-speech/pNInz6obpgDQGcFmaJgB'), // Default voice
        headers: {
          'xi-api-key': _apiKey,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'text': text,
          'model_id': 'eleven_monolingual_v1',
          'voice_settings': {
            'stability': 0.5,
            'similarity_boost': 0.5,
          },
        }),
      );

      if (response.statusCode == 200) {
        print('✅ TTS API call successful');
        
        // Play the audio and wait for completion
        await _playAudioBytes(response.bodyBytes);
        print('✅ Audio playback completed');
        
        // After AI finishes speaking, automatically start listening again for continuous conversation
        if (_status == ConversationStatus.active) {
          print('🔄 AI finished speaking, starting to listen again...');
          await Future.delayed(const Duration(milliseconds: 500)); // Brief pause
          await startListening();
        }
        
      } else {
        print('❌ TTS API error: ${response.statusCode} - ${response.body}');
      }
      
    } catch (e) {
      print('❌ Error converting text to speech: $e');
    } finally {
      _isSpeaking = false;
      _safeAdd(_speakingController, false);
    }
  }

  /// Handle incoming WebSocket messages
  void _handleWebSocketMessage(dynamic message) {
    try {
      final data = json.decode(message as String);
      final messageType = data['type'] as String?;
      
      switch (messageType) {
        case 'conversation_initiation_metadata':
          final metadata = data['conversation_initiation_metadata_event'] as Map<String, dynamic>?;
          _conversationId = metadata?['conversation_id'] ?? '';
          break;
          
        case 'agent_response':
          _handleAgentResponse(data);
          break;
          
        case 'agent_response_correction':
          _handleAgentResponseCorrection(data);
          break;
          
        case 'user_transcript':
          _handleUserTranscript(data);
          break;
          
        case 'audio':
          _handleAudioResponse(data);
          break;
          
        case 'conversation_item_created':
          _handleConversationItem(data);
          break;
          
        case 'conversation_item_updated':
          _handleConversationItem(data);
          break;
          
        case 'conversation_metadata':
          // Metadata received
          break;
          
        case 'interruption':
          _handleInterruption();
          break;
          
        case 'ping':
          // Handle ping events to keep connection alive
          final pingEvent = data['ping_event'] as Map<String, dynamic>?;
          if (pingEvent != null) {
            final eventId = pingEvent['event_id'] as int?;
            final pingMs = pingEvent['ping_ms'] as int?;
            
            // Wait ping_ms milliseconds before responding (if specified)
            if (pingMs != null && pingMs > 0) {
              Timer(Duration(milliseconds: pingMs), () {
                _channel?.sink.add(json.encode({
                  'type': 'pong',
                  'event_id': eventId,
                }));
              });
            } else {
              _channel?.sink.add(json.encode({
                'type': 'pong',
                'event_id': eventId,
              }));
            }
          }
          break;
          
        default:
          // Unknown message type
          break;
      }
    } catch (e) {
      print('❌ Error handling WebSocket message: $e');
    }
  }


  /// Handle conversation item (from ElevenLabs)
  void _handleConversationItem(Map<String, dynamic> data) async {
    try {
      final item = data['conversation_item'] as Map<String, dynamic>?;
      if (item == null) return;
      
      final itemType = item['item_type'] as String?;
      
      if (itemType == 'agent_message') {
        // SKIP: Agent messages are already handled by _handleAgentResponse
        return;
      } else if (itemType == 'user_message') {
        final body = item['body'] as Map<String, dynamic>?;
        if (body != null) {
          final text = body['text'] as String?;
          if (text != null && text.isNotEmpty) {
            print('👤 User message: $text');
            _safeAdd(_transcriptController, 'User: $text');
          }
        }
      }
    } catch (e) {
      print('❌ Error handling conversation item: $e');
    }
  }

  /// Handle agent response (text or audio)
  void _handleAgentResponse(Map<String, dynamic> data) async {
    try {
      _responseCounter++;
      final callerLocation = StackTrace.current.toString().split('\n')[1];
      print('🤖 Processing agent response #$_responseCounter from: $callerLocation');
      print('🤖 Response data: $data');
      
      // According to ElevenLabs Agent WebSocket docs:
      // https://elevenlabs.io/docs/agents-platform/api-reference/agents-platform/websocket
      // The format is: { "type": "agent_response", "agent_response_event": { "agent_response": "text..." } }
      
      String? text;
      
      // Check for agent_response_event (correct format)
      if (data.containsKey('agent_response_event')) {
        final responseEvent = data['agent_response_event'] as Map<String, dynamic>?;
        if (responseEvent != null && responseEvent.containsKey('agent_response')) {
          text = responseEvent['agent_response'] as String?;
        }
      }
      // Fallback: Direct text field
      else if (data.containsKey('text')) {
        text = data['text'] as String?;
      }
      // Fallback: Agent response field
      else if (data.containsKey('agent_response')) {
        final agentResponse = data['agent_response'];
        if (agentResponse is String) {
          text = agentResponse;
        } else if (agentResponse is Map<String, dynamic>) {
          text = agentResponse['text'] as String?;
        }
      }
      // Fallback: Body field
      else if (data.containsKey('body')) {
        final body = data['body'] as Map<String, dynamic>?;
        text = body?['text'] as String?;
      }
      
      if (text != null && text.isNotEmpty) {
        // DEDUPLICATION: Check if this is a refinement/correction of the previous response
        // Check if we've already received a response for this turn
        if (_hasReceivedResponseForCurrentTurn && _lastAgentResponseText != null) {
          print('🔄 Additional response received - checking if it\'s a continuation...');
          print('   First part: "$_lastAgentResponseText"');
          print('   Additional part: "$text"');
          
          // If the new text is different and not contained in the previous, it might be a continuation
          if (_lastAgentResponseText != text && !_lastAgentResponseText!.contains(text) && !text.contains(_lastAgentResponseText!)) {
            print('✅ This appears to be a CONTINUATION - replacing with complete version');
            
            // Update the existing message with the new text (replace, don't append)
            // ElevenLabs sends progressive updates: first partial, then complete
            _lastAgentResponseText = text;
            _lastAgentResponseTime = DateTime.now();
            
            // IMPORTANT: Check for photo request in the updated text!
            _checkForPhotoRequest(text);
            
            // Update the UI message - remove old one and add new complete one
            final aiService = AIConversationService();
            if (aiService.messages.isNotEmpty && aiService.messages.last.type == MessageType.ai) {
              // Remove the incomplete message
              aiService.messages.removeLast();
            }
            
            // Add the complete message
            _addAIMessage(text);
            _safeAdd(_transcriptController, 'Assistant (updated): $text');
            
            // IMPORTANT: Return here to prevent double-adding the message
            // The message has been updated and added, we're done
            return;
          } else {
            print('🚫 BLOCKING: Duplicate/refinement detected');
            print('   Event ID: ${data['agent_response_event']?['event_id']}');
            return; // Block true duplicates
          }
        } else if (_hasReceivedResponseForCurrentTurn && _lastAgentResponseText == null) {
          // Edge case: flag is set but text is null - this shouldn't happen but handle it
          print('⚠️ WARNING: Response flag set but no previous text - treating as first response');
          _hasReceivedResponseForCurrentTurn = false;
        }
        
        print('✅ This is the FIRST response for current turn - accepting it');
        
        // Check if this is the initial greeting in text mode
        // Only skip if: 1) haven't received first message yet, 2) in text mode, 3) response counter is 0
        // This is to skip the "Hello, how can I help?" greeting when first connecting
        // We use _responseCounter == 0 to detect if this is truly the first ever response
        if (!_hasReceivedFirstMessage && !_isVoiceMode && _responseCounter == 1) {
          // Check if this looks like a generic greeting (contains "help" or "assist")
          final lowerText = text.toLowerCase();
          if (lowerText.contains('help') || lowerText.contains('assist') || lowerText.contains('hello')) {
            print('⏭️ Skipping initial greeting in text mode: "$text"');
            _hasReceivedFirstMessage = true;
            _hasReceivedResponseForCurrentTurn = true; // Mark as received so no more responses accepted
            // Store this as last response
            _lastAgentResponseText = text;
            _lastAgentResponseTime = DateTime.now();
            return;
          } else {
            print('✅ First response but not a greeting - showing it');
          }
        }
        
        // This is a genuinely new response - show it
        print('📝 Agent text response: $text (voice mode: $_isVoiceMode, first message: $_hasReceivedFirstMessage)');
        _hasReceivedFirstMessage = true; // Mark that we've received at least one message
        _hasReceivedResponseForCurrentTurn = true; // Mark that we've received response for this turn
        _lastAgentResponseText = text; // Store for deduplication
        _lastAgentResponseTime = DateTime.now(); // Store timestamp
        _safeAdd(_transcriptController, 'Assistant: $text');
        
        // Check if the response is asking for photos
        _checkForPhotoRequest(text);
        
        // Add to AI service messages for display
        _addAIMessage(text);
        
        // IMPORTANT: agent_response marks the END of the agent's text
        // BUT audio chunks are still arriving! Don't resume mic yet.
        // The _handleAudioResponse will handle resuming after the last chunk
        print('📝 Agent text response complete - waiting for audio to finish...');
        
        return;
      }
      
      // Check for audio response
      final audioData = data['audio'] as Map<String, dynamic>?;
      if (audioData != null) {
        final audioBase64 = audioData['audio'] as String?;
        if (audioBase64 != null) {
          print('🔊 Playing audio response...');
          _isSpeaking = true;
          _safeAdd(_speakingController, true);
          
          // Decode and play audio
          final audioBytes = base64Decode(audioBase64);
          await _playAudioBytes(audioBytes);
          
          _isSpeaking = false;
          _safeAdd(_speakingController, false);
        }
      }
      
      // If no text or audio found, log the structure
      print('⚠️ No recognizable text or audio in agent response');
    } catch (e) {
      print('❌ Error handling agent response: $e');
      _isSpeaking = false;
      _safeAdd(_speakingController, false);
    }
  }

  /// Handle agent response correction
  void _handleAgentResponseCorrection(Map<String, dynamic> data) async {
    try {
      print('🔄 Processing agent response correction...');
      
      final correctionData = data['agent_response_correction_event'] as Map<String, dynamic>?;
      if (correctionData != null) {
        final correctedResponse = correctionData['corrected_agent_response'] as String?;
        if (correctedResponse != null && correctedResponse.isNotEmpty) {
          // DEDUPLICATION: Check if this correction is different from last response
          final now = DateTime.now();
          if (_lastAgentResponseText == correctedResponse && 
              _lastAgentResponseTime != null && 
              now.difference(_lastAgentResponseTime!).inMilliseconds < 1000) {
            print('⏭️ Duplicate corrected response - skipping');
            return;
          }
          
          print('📝 Corrected agent response: $correctedResponse');
          _lastAgentResponseText = correctedResponse;
          _lastAgentResponseTime = now;
          _safeAdd(_transcriptController, 'Assistant (corrected): $correctedResponse');
          
          // Check if the corrected response is asking for photos
          _checkForPhotoRequest(correctedResponse);
          
          // Add to AI service messages for display
          _addAIMessage(correctedResponse);
        }
      }
      
    } catch (e) {
      print('❌ Error handling agent response correction: $e');
    }
  }

  /// Handle user transcript
  void _handleUserTranscript(Map<String, dynamic> data) async {
    try {
      print('👤 Processing user transcript...');
      
      final transcriptData = data['user_transcription_event'] as Map<String, dynamic>?;
      if (transcriptData != null) {
        final userTranscript = transcriptData['user_transcript'] as String?;
        if (userTranscript != null && userTranscript.isNotEmpty) {
          print('📝 User transcript: $userTranscript');
          _safeAdd(_transcriptController, 'You: $userTranscript');
          
          // IMPORTANT: Add user transcript to chat UI so it's visible on screen
          // This shows what ElevenLabs heard from the user's voice
          final aiService = AIConversationService();
          aiService.addMessage(ChatMessage(
            content: userTranscript,
            type: MessageType.user,
            timestamp: DateTime.now(),
          ));
          print('✅ User transcript added to chat UI: $userTranscript');
        }
      }
      
    } catch (e) {
      print('❌ Error handling user transcript: $e');
    }
  }

  /// Handle audio response from agent
  /// Handle incoming audio response with improved buffering and error recovery
  void _handleAudioResponse(Map<String, dynamic> data) async {
    try {
      final audioData = data['audio_event'] as Map<String, dynamic>?;
      if (audioData != null) {
        final audioBase64 = audioData['audio_base_64'] as String? ?? audioData['audio'] as String?;
        if (audioBase64 != null) {
          _audioChunkCount++;
          _lastAudioChunkTime = DateTime.now();
          
          if (_isVoiceMode) {
            final audioBytes = base64Decode(audioBase64);
            _audioQueue.add(audioBytes);
            
            // If this is the first chunk, start buffering
            if (_audioQueue.length == 1 && !_isPlayingFromQueue && !_isBuffering) {
              _isBuffering = true;
              _safeAdd(_bufferingController, true);
              
              // Mark as speaking
              if (!_isSpeaking) {
                _isSpeaking = true;
                _safeAdd(_speakingController, true);
              }
              
              // Start buffer timeout (in case we don't get enough chunks)
              _bufferTimeoutTimer?.cancel();
              _bufferTimeoutTimer = Timer(const Duration(milliseconds: 300), () {
                if (_isBuffering && _audioQueue.isNotEmpty) {
                  _startQueuePlayback();
                }
              });
            }
            
            // If we have enough chunks buffered, start playback
            if (_isBuffering && _audioQueue.length >= _minBufferChunks) {
              _bufferTimeoutTimer?.cancel();
              _startQueuePlayback();
            }
          }
          
          // Update last chunk time for timeout detection
          _lastAudioChunkTime = DateTime.now();
        }
      }
    } catch (e) {
      print('❌ Error handling audio response: $e');
      _isBuffering = false;
      _safeAdd(_bufferingController, false);
    }
  }
  
  /// Start queue playback after buffering
  void _startQueuePlayback() {
    if (_isPlayingFromQueue) return; // Already playing
    
    _isBuffering = false;
    _safeAdd(_bufferingController, false);
    _isPlayingFromQueue = true;
    _playedChunkCount = 0;
    
    // Start queue playback (don't await - let it run in background)
    _playAudioQueueImproved().catchError((error) {
      print('❌ Queue playback error: $error');
      _isPlayingFromQueue = false;
    });
  }
  
  /// Play audio queue with optimized speed and reliability
  Future<void> _playAudioQueueImproved() async {
    while (_isPlayingFromQueue) {
      // Check if there are chunks to play
      if (_audioQueue.isEmpty) {
        // Wait briefly for more chunks
        await Future.delayed(const Duration(milliseconds: 50));
        
        // If still empty, check if we should stop
        if (_audioQueue.isEmpty) {
          final timeSinceLastChunk = _lastAudioChunkTime != null
              ? DateTime.now().difference(_lastAudioChunkTime!)
              : Duration.zero;
          
          // If no new chunks for 1.5 seconds, stop playback
          if (timeSinceLastChunk > const Duration(milliseconds: 1500)) {
            _isPlayingFromQueue = false;
            break;
          }
        }
        continue;
      }
      
      // Get the next chunk
      final chunk = _audioQueue.removeAt(0);
      _playedChunkCount++;
      
      // Play the chunk - no retry, just continue on error
      try {
        await _playAudioBytes(chunk);
      } catch (e) {
        print('⚠️ Audio chunk playback error: $e');
        _droppedChunkCount++;
      }
    }
    
    // Wait a moment to ensure all audio playback is complete
    await Future.delayed(const Duration(milliseconds: 300));
    
    if (_audioQueue.isEmpty) {
      _isSpeaking = false;
      _audioChunkCount = 0;
      _playedChunkCount = 0;
      _isPlayingFromQueue = false;
      _safeAdd(_speakingController, false);
    } else {
      _isPlayingFromQueue = false;
    }
  }

  /// Handle conversation interruption
  void _handleInterruption() {
    print('⚠️ Conversation interrupted');
    _audioPlayer.stop();
    _isSpeaking = false;
    _speakingController.add(false);
  }

  /// Create a proper WAV file from raw PCM data
  Uint8List _createWavFile(Uint8List pcmData) {
    // ElevenLabs sends PCM16 at 16kHz mono
    final int sampleRate = 16000;
    final int numChannels = 1;
    final int bitsPerSample = 16;
    final int byteRate = sampleRate * numChannels * bitsPerSample ~/ 8;
    final int blockAlign = numChannels * bitsPerSample ~/ 8;
    final int dataSize = pcmData.length;
    
    // WAV file structure:
    // RIFF header (12 bytes)
    // fmt chunk (24 bytes)
    // data chunk header (8 bytes)
    // audio data
    
    final List<int> header = [];
    
    // RIFF header
    header.addAll('RIFF'.codeUnits);
    header.addAll(_int32ToBytes(36 + dataSize)); // File size - 8
    header.addAll('WAVE'.codeUnits);
    
    // fmt chunk
    header.addAll('fmt '.codeUnits);
    header.addAll(_int32ToBytes(16)); // fmt chunk size
    header.addAll(_int16ToBytes(1)); // Audio format (1 = PCM)
    header.addAll(_int16ToBytes(numChannels));
    header.addAll(_int32ToBytes(sampleRate));
    header.addAll(_int32ToBytes(byteRate));
    header.addAll(_int16ToBytes(blockAlign));
    header.addAll(_int16ToBytes(bitsPerSample));
    
    // data chunk
    header.addAll('data'.codeUnits);
    header.addAll(_int32ToBytes(dataSize));
    
    // Combine header and data
    return Uint8List.fromList([...header, ...pcmData]);
  }
  
  /// Convert int32 to little-endian bytes
  List<int> _int32ToBytes(int value) {
    return [
      value & 0xFF,
      (value >> 8) & 0xFF,
      (value >> 16) & 0xFF,
      (value >> 24) & 0xFF,
    ];
  }
  
  /// Convert int16 to little-endian bytes
  List<int> _int16ToBytes(int value) {
    return [
      value & 0xFF,
      (value >> 8) & 0xFF,
    ];
  }

  
  /// Play audio bytes using AudioPlayer (iOS compatible)
  Future<void> _playAudioBytes(Uint8List audioBytes) async {
    try {
      // Check if data is already in WAV format or needs wrapping
      Uint8List wavData;
      if (audioBytes.length >= 4) {
        final firstBytes = audioBytes.sublist(0, 4);
        // Check for WAV format: 'RIFF' (52 49 46 46)
        if (firstBytes[0] == 0x52 && firstBytes[1] == 0x49 && firstBytes[2] == 0x46 && firstBytes[3] == 0x46) {
          wavData = audioBytes;
        } else {
          wavData = _createWavFile(audioBytes);
        }
      } else {
        wavData = _createWavFile(audioBytes);
      }
      
      // For iOS, we need to save to a temporary file
      if (Platform.isIOS) {
        final tempDir = await getTemporaryDirectory();
        final tempFile = File('${tempDir.path}/elevenlabs_audio_${DateTime.now().millisecondsSinceEpoch}.wav');
        
        await tempFile.writeAsBytes(wavData);
        
        try {
        await _audioPlayer.play(DeviceFileSource(tempFile.path));
          
          // CRITICAL: AWAIT for audio playback to complete!
          try {
            await _audioPlayer.onPlayerComplete.first.timeout(
              const Duration(seconds: 30),
            );
          } on TimeoutException {
            print('⏰ Audio playback timeout');
          }
          
          // Clean up the temporary file after playback
        try {
          if (tempFile.existsSync()) {
            tempFile.deleteSync();
          }
        } catch (e) {
          print('⚠️ Could not clean up temporary file: $e');
          }
        } catch (e) {
          print('❌ Audio playback error: $e');
          // Clean up file even on error
          try {
            if (tempFile.existsSync()) {
              tempFile.deleteSync();
            }
          } catch (_) {}
          throw e;
        }
        
      } else {
        // For other platforms, try bytes directly
        try {
        await _audioPlayer.play(BytesSource(wavData));
        } catch (e) {
          print('❌ Audio play command failed: $e');
          throw e;
        }
        
        try {
          _audioPlayer.onPlayerComplete.first.timeout(const Duration(seconds: 30)).then((_) {
            // Audio completed
          }).catchError((e) {
            print('⏰ Audio playback timeout or error: $e');
          });
        } catch (e) {
          print('⏰ Audio playback setup error: $e');
        }
      }
      
    } catch (e) {
      print('❌ Error playing audio: $e');
      print('❌ Error type: ${e.runtimeType}');
      print('❌ Stack trace: ${StackTrace.current}');
    }
  }

  /// Build system prompt for the agent based on current conversation context
  Future<String> _buildSystemPrompt() async {
    final aiService = AIConversationService();
    final currentState = aiService.currentState;
    
    String basePrompt = '''
You're a home services assistant. Keep it brief - ask one simple question at a time.

Current info:
- Service: ${currentState.serviceCategory ?? 'Unknown'}
- Step: ${currentState.conversationStep}

Be friendly but concise. One sentence responses only.
''';

    return basePrompt;
  }

  /// Safely add to stream controller
  void _safeAdd<T>(StreamController<T> controller, T value) {
    if (!controller.isClosed) {
      controller.add(value);
    }
  }
  
  /// Check if agent is requesting photos
  void _checkForPhotoRequest(String text) {
    final lowerText = text.toLowerCase();
    final photoKeywords = [
      'photo', 'picture', 'image', 'upload', 
      'take a photo', 'send a photo', 'show me',
      'can you send', 'could you send', 'attach',
      'visual', 'see it', 'look like', 'send me',
      'share a', 'provide a', 'add a', 'add some',
      'snap', 'capture', 'take some', 'send some',
      'would help if', 'it would be helpful', 'documentation',
      'provide some', 'helpful to see', 'send along',
      'pictures', 'images', 'photos', 'pics'
    ];
    
    // Debug: Log what the agent said
    print('🔍 Checking for photo request in: "$text"');
    
    final isAskingForPhoto = photoKeywords.any((keyword) {
      final found = lowerText.contains(keyword);
      if (found) {
        print('✅ Found photo keyword: "$keyword"');
      }
      return found;
    });
    
    if (isAskingForPhoto) {
      print('📸 Agent is requesting photos! Showing upload button...');
      _safeAdd(_photoRequestController, true);
    } else {
      print('❌ No photo keywords found in this message');
    }
  }

  /// Update conversation status and notify listeners
  void _updateStatus(ConversationStatus newStatus) {
    _status = newStatus;
    _safeAdd(_statusController, newStatus);
    print('📊 Status updated to: $newStatus');
  }

  /// End the conversation session
  Future<void> endSession() async {
    print('🛑 Ending conversation session...');
    
    try {
    await stopListening();
    await _audioPlayer.stop();
    
    _updateStatus(ConversationStatus.disconnected);
    _isSpeaking = false;
    _isListening = false;
    
      _safeAdd(_speakingController, false);
      _safeAdd(_listeningController, false);
    } catch (e) {
      print('❌ Error ending session: $e');
    }
  }

  /// Disconnect from ElevenLabs
  Future<void> disconnect() async {
    print('🔌 Disconnecting from ElevenLabs...');
    
    try {
    // Stop audio recording if active
    await stopListening();
    
    // Stop audio playback
    await _audioPlayer.stop();
    
    // Send close_socket message to gracefully end conversation
    if (_channel != null && _status != ConversationStatus.disconnected) {
      print('📤 Sending close_socket message...');
      try {
        _channel!.sink.add(json.encode({
          'type': 'close_socket'
        }));
        // Give server time to process
        await Future.delayed(const Duration(milliseconds: 500));
      } catch (e) {
        print('⚠️ Error sending close_socket: $e');
      }
    }
    
    // Close WebSocket connection
    try {
    await _channel?.sink.close();
    } catch (e) {
      print('⚠️ Error closing WebSocket: $e');
    }
    
    // Cancel any pending timers
    _resumeListeningTimer?.cancel();
    _resumeListeningTimer = null;
    
    // Reset all state flags
    _channel = null;
    _conversationId = '';
    _conversationReady = false;
    _isVoiceMode = false;
    _isSpeaking = false;
    _isListening = false;
    _audioChunkCount = 0;
    _lastAudioChunkTime = null;
    _lastAgentResponseText = null; // Reset response tracking
    _lastAgentResponseTime = null;
    _audioQueue.clear(); // Clear any queued audio
    _isPlayingFromQueue = false;
    _isBuffering = false;
    _bufferTimeoutTimer?.cancel();
    _playedChunkCount = 0;
    _droppedChunkCount = 0;
    _hasReceivedFirstMessage = false; // Reset greeting flag
    
    // Notify listeners
    _safeAdd(_speakingController, false);
    _safeAdd(_listeningController, false);
    _updateStatus(ConversationStatus.disconnected);
    
    print('✅ Disconnected successfully - ready for next connection');
    } catch (e) {
      print('❌ Error disconnecting: $e');
      // Force reset status even on error
    _updateStatus(ConversationStatus.disconnected);
    }
  }

  /// Set conversation mode
  void setMode(ConversationMode mode) {
    _mode = mode;
    _isVoiceMode = (_mode == ConversationMode.voice || _mode == ConversationMode.hybrid);
    print('🔄 Conversation mode set to: $mode (voice mode: $_isVoiceMode)');
  }

  /// Get signed URL for private agents (if needed)
  Future<String?> _getSignedUrl(String agentId) async {
    try {
      final response = await http.post(
        Uri.parse('https://api.elevenlabs.io/v1/convai/conversation/get_signed_url'),
        headers: ElevenLabsConfig.headers,
        body: json.encode({'agent_id': agentId}),
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['signed_url'] as String?;
      }
    } catch (e) {
      print('❌ Error getting signed URL: $e');
    }
    return null;
  }

  /// Dispose resources
  void dispose() {
    try {
    disconnect();
    _audioPlayer.dispose();
    _audioRecorder.dispose();
    _audioStreamSubscription?.cancel();
      
      // Close all stream controllers
      if (!_statusController.isClosed) {
    _statusController.close();
      }
      if (!_transcriptController.isClosed) {
    _transcriptController.close();
      }
      if (!_listeningController.isClosed) {
    _listeningController.close();
      }
      if (!_speakingController.isClosed) {
    _speakingController.close();
      }
      if (!_errorController.isClosed) {
    _errorController.close();
      }
      if (!_photoRequestController.isClosed) {
    _photoRequestController.close();
      }
      if (!_bufferingController.isClosed) {
    _bufferingController.close();
      }
      
      // Cancel timers
      _bufferTimeoutTimer?.cancel();
      _resumeListeningTimer?.cancel();
    } catch (e) {
      print('❌ Error disposing ElevenLabs service: $e');
    }
  }
}

/// Conversation status enum
enum ConversationStatus {
  disconnected,
  connecting,
  connected,
  active,
  error,
}

/// Conversation mode enum
enum ConversationMode {
  voice,    // Voice input/output only
  text,     // Text input/output only  
  hybrid,   // Both voice and text
}

