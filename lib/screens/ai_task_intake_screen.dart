import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:table_calendar/table_calendar.dart';
import 'dart:io';
import 'dart:async';
import '../services/ai_conversation_service.dart';
import '../services/user_request_service.dart';
import '../services/elevenlabs_conversation_service.dart';
import '../widgets/translatable_text.dart';

class AITaskIntakeScreen extends StatefulWidget {
  final User? user;

  const AITaskIntakeScreen({
    super.key,
    this.user,
  });

  @override
  State<AITaskIntakeScreen> createState() => _AITaskIntakeScreenState();
}

class _AITaskIntakeScreenState extends State<AITaskIntakeScreen> with TickerProviderStateMixin {
  final AIConversationService _aiService = AIConversationService();
  final ElevenLabsConversationService _elevenLabsService = ElevenLabsConversationService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _picker = ImagePicker();
  
  bool _isLoading = false;
  bool _isTyping = false;
  bool _isListening = false;
  bool _showPhotoUpload = false;
  bool _showCalendar = false;
  bool _showLocationForm = false;
  bool _showContactForm = false;
  bool _showSummary = false;
  bool _isPhoneCallActive = false;
  bool _isConnectingToCall = false;
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  String _selectedTimePreference = 'Any time';
  
  // Phone button floating position
  bool _isDraggingPhone = false;
  Offset _phonePosition = const Offset(20, 350); // Middle left side of screen
  late AnimationController _phoneAnimationController;
  
  // Photo upload floating button
  bool _isDraggingPhoto = false;
  Offset _photoButtonPosition = const Offset(20, 270); // Above phone button
  late AnimationController _photoAnimationController;
  List<String> _uploadedPhotosInSession = []; // Track uploaded photos
  
  // Form controllers to persist data
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _zipcodeController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _stateController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  List<DateTime> _selectedDates = [];
  List<String> _timePreferenceOptions = [
    'Any time',
    'Morning (8AM - 12PM)',
    'Afternoon (12PM - 5PM)', 
    'Evening (5PM - 8PM)',
    'Specific time'
  ];

  @override
  void initState() {
    super.initState();
    // Local speech-to-text removed - using ElevenLabs only
    _aiService.startConversation();
    
    // Initialize phone button animation
    _phoneAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    // Initialize photo button animation
    _photoAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    // Initialize ElevenLabs for text mode
    _initializeElevenLabsForTextMode();
    
    // Test ElevenLabs connection after a delay
    Future.delayed(const Duration(seconds: 3), () {
      _testElevenLabsConnection();
    });
    
    // Listen to ElevenLabs error messages for user feedback
    _elevenLabsService.errorStream.listen((errorMessage) {
      _showInfoSnackBar(errorMessage);
    });
    
    // Listen to ElevenLabs status changes
    _elevenLabsService.statusStream.listen((status) {
      _handleElevenLabsStatusChange(status);
    });
    
    // Photo upload button is now always shown (no need to listen for keywords)
    
    // Listen to AI service message changes
    _aiService.messagesStream.listen((messages) {
      if (mounted) {
        setState(() {});
        _scrollToBottom();
      }
    });
    
    // Listen to conversation state changes to auto-show summary
    _aiService.conversationStateStream.listen((state) {
      if (mounted && state.conversationStep == 8 && !_showSummary) {
        // Conversation reached summary step - show summary
        setState(() {
          _showSummary = true;
          // Hide other UI elements
          _showPhotoUpload = false;
          _showCalendar = false;
          _showLocationForm = false;
          _showContactForm = false;
        });
        _scrollToBottom();
      }
    });
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    // Dispose form controllers
    _addressController.dispose();
    _zipcodeController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _phoneController.dispose();
    _nameController.dispose();
    // Dispose animation controllers
    _phoneAnimationController.dispose();
    _photoAnimationController.dispose();
    // Dispose ElevenLabs service
    _elevenLabsService.dispose();
    super.dispose();
  }

  /// Handle ElevenLabs status changes
  /// Initialize ElevenLabs for text mode
  Future<void> _initializeElevenLabsForTextMode() async {
    try {
      print('🔧 Initializing ElevenLabs for text mode...');
      final initialized = await _elevenLabsService.initialize();
      print('🔍 Initialize result: $initialized');
      if (initialized) {
        print('✅ ElevenLabs initialized for text mode');
        // Set mode to text for text-only responses
        _elevenLabsService.setMode(ConversationMode.text);
        print('🔍 Mode set to text');
        print('✅ ElevenLabs ready for text mode (using TTS API)');
      } else {
        print('❌ Failed to initialize ElevenLabs for text mode');
      }
    } catch (e) {
      print('❌ Error initializing ElevenLabs for text mode: $e');
    }
  }

  /// Test ElevenLabs connection
  Future<void> _testElevenLabsConnection() async {
    print('🧪 Testing ElevenLabs connection...');
    print('🔍 Status: ${_elevenLabsService.status}');
    print('🔍 Mode: ${_elevenLabsService.mode}');
    
    // For text mode, we don't need WebSocket to be active
    if (_elevenLabsService.mode == ConversationMode.text) {
      print('✅ ElevenLabs initialized for text mode');
    } else if (_elevenLabsService.status == ConversationStatus.active) {
      print('✅ ElevenLabs is connected and active for voice mode');
    } else {
      print('⚠️ ElevenLabs voice mode not active. Status: ${_elevenLabsService.status}');
    }
  }

  void _handleElevenLabsStatusChange(ConversationStatus status) {
    if (status == ConversationStatus.error) {
      _showErrorSnackBar('Connection error. Please try again.');
    } else if (status == ConversationStatus.disconnected) {
      // Don't show message for normal disconnection
    } else if (status == ConversationStatus.connecting) {
      // Only show connecting message if starting a phone call
      if (_isPhoneCallActive || _isConnectingToCall) {
        _showInfoSnackBar('Connecting to voice service, please wait...');
      }
    } else if (status == ConversationStatus.connected) {
      // Text mode connected - no message needed
    } else if (status == ConversationStatus.active) {
      // Only show active message for voice mode
      if (_isPhoneCallActive) {
        _showInfoSnackBar('Voice call connected.');
      }
    }
  }

  /// Initialize speech recognition
  // Local speech-to-text methods removed - using ElevenLabs only

  /// Handle microphone button tap - for speech-to-text
  Future<void> _handleMicrophoneButtonTap() async {
    if (_isLoading) return;

    // Microphone button only sends text, doesn't trigger speech recognition
    if (_messageController.text.trim().isNotEmpty) {
      print('📤 Sending message...');
      await _sendMessage();
    } else {
      print('ℹ️ No text to send. Use phone button for voice mode.');
      _showInfoSnackBar('Type a message or use phone button for voice');
    }
  }

  /// Handle "Done" button tap - confirms completion and proceeds to next step
  Future<void> _handleDoneButtonTap() async {
    if (_isLoading) return;
    
    print('✅ Done button tapped');
    
    // Send "Done" message to ElevenLabs
    _messageController.text = "Done";
    await _sendMessage();
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Marked as complete! The agent will proceed.'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }


  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    final message = _messageController.text.trim();
    _messageController.clear();
    
    
    setState(() {
      _isLoading = true;
      _isTyping = true;
    });

    try {
      // Add user message to transcript first
      _aiService.messages.add(ChatMessage(
        content: message,
        type: MessageType.user,
        timestamp: DateTime.now(),
      ));
      
      // Always use ElevenLabs for ALL responses (text and voice)
      print('🤖 Sending message to ElevenLabs for AI response');
      print('🔍 ElevenLabs status: ${_elevenLabsService.status}');
      
      // CRITICAL: Always set mode to TEXT when sending typed messages
      // This ensures voice mode doesn't stay active from previous phone call
      if (!_isPhoneCallActive) {
        _elevenLabsService.setMode(ConversationMode.text);
        print('✅ Mode set to TEXT (no audio) for typed message');
      }
      
      // If not connected, connect first (for text mode)
      if (_elevenLabsService.status != ConversationStatus.active) {
        print('🔌 ElevenLabs not connected - connecting now for text mode...');
        
        try {
          await _elevenLabsService.connect();
          print('✅ WebSocket connected');
          
          // For text mode, we MUST call startSession() to activate the conversation
          // But mode is already set to TEXT, so it won't start the microphone
          await _elevenLabsService.startSession();
          print('✅ Session started for text mode');
          
          // Wait a moment for the session to be ready
          await Future.delayed(const Duration(milliseconds: 500));
          
          print('✅ ElevenLabs connected and ready for text mode (microphone OFF)');
        } catch (e) {
          print('❌ Failed to connect ElevenLabs: $e');
          throw Exception('Failed to connect to voice service');
        }
      }
      
      // Verify connection before sending
      // Text mode needs at least 'connected' status, voice mode needs 'active'
      if (_elevenLabsService.status != ConversationStatus.active && 
          _elevenLabsService.status != ConversationStatus.connected) {
        throw Exception('Voice service not connected - cannot send message');
      }
      
      final timestamp = DateTime.now().toIso8601String();
      print('📨 [$timestamp] UI calling _elevenLabsService.sendMessage()');
      print('   Message: "$message"');
      await _elevenLabsService.sendMessage(message);
      print('✅ [$timestamp] sendMessage() returned successfully');
      
    } catch (e) {
      print('Error sending message: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
        _isTyping = false;
      });
      
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });
      
    }
  }

  Future<void> _uploadPhotos({bool fromFloatingButton = false}) async {
    try {
      // Show photo source selection dialog
      final String? action = await showDialog<String>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Add Photos'),
            content: const Text('How would you like to add photos?'),
            actions: [
              TextButton.icon(
                onPressed: () => Navigator.pop(context, 'camera'),
                icon: const Icon(Icons.camera_alt),
                label: const Text('Take Photo'),
              ),
              TextButton.icon(
                onPressed: () => Navigator.pop(context, 'gallery_single'),
                icon: const Icon(Icons.photo_library),
                label: const Text('Choose One Photo'),
              ),
              TextButton.icon(
                onPressed: () => Navigator.pop(context, 'gallery_multiple'),
                icon: const Icon(Icons.photo_library),
                label: const Text('Choose Multiple Photos'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ],
          );
        },
      );

      if (action == null) return;

      setState(() {
        _isLoading = true;
      });

      List<XFile> images = [];
      
      if (action == 'camera') {
        final XFile? image = await _picker.pickImage(
          source: ImageSource.camera,
          maxWidth: 1024,
          maxHeight: 1024,
          imageQuality: 80,
        );
        if (image != null) images.add(image);
      } else if (action == 'gallery_single') {
        final XFile? image = await _picker.pickImage(
          source: ImageSource.gallery,
          maxWidth: 1024,
          maxHeight: 1024,
          imageQuality: 80,
        );
        if (image != null) images.add(image);
      } else if (action == 'gallery_multiple') {
        final List<XFile> pickedImages = await _picker.pickMultiImage(
          maxWidth: 1024,
          maxHeight: 1024,
          imageQuality: 80,
        );
        images.addAll(pickedImages);
      }

      if (images.isNotEmpty) {
        int successCount = 0;
        int failCount = 0;
        
        for (final image in images) {
          try {
            final String downloadUrl = await _uploadImageToFirebase(File(image.path));
            _aiService.onPhotoUploaded(downloadUrl);
            _uploadedPhotosInSession.add(downloadUrl);
            successCount++;
            
            // Add system message for each photo
            setState(() {
              _aiService.messages.add(ChatMessage(
                content: "Photo ${successCount} uploaded successfully!",
                type: MessageType.system,
                timestamp: DateTime.now(),
                imageUrl: downloadUrl,
              ));
            });
          } catch (e) {
            print('Error uploading photo: $e');
            failCount++;
          }
        }

        _scrollToBottom();

        // Show summary message
        if (successCount > 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$successCount photo(s) uploaded successfully!${failCount > 0 ? ' ($failCount failed)' : ''}'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
          
          // If from floating button, send confirmation message to ElevenLabs
          if (fromFloatingButton && successCount > 0) {
            final message = successCount == 1 
                ? "I've uploaded 1 photo" 
                : "I've uploaded $successCount photos";
            
            // Add user message to transcript
            _aiService.messages.add(ChatMessage(
              content: message,
              type: MessageType.user,
              timestamp: DateTime.now(),
            ));
            
            // Force send text message even in voice mode (photo upload confirmation)
            await _elevenLabsService.sendMessage(message, forceTextInVoiceMode: true);
          }
        } else if (failCount > 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to upload $failCount photo(s)'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print('Error uploading photos: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error uploading photos: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }



  Future<String> _uploadImageToFirebase(File imageFile) async {
    try {
      final String? uid = widget.user?.uid ?? FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        throw Exception('Please sign in to upload photos');
      }

      final String fileName = 'service_attachment_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final Reference ref = FirebaseStorage.instance
          .ref()
          .child('service_attachments')
          .child(uid)
          .child(fileName);

      // Debug diagnostics
      final int fileSizeBytes = await imageFile.length();
      // ignore: avoid_print
      print('Uploading to Firebase Storage path: ${ref.fullPath} (bucket: ${ref.bucket}), uid: $uid, size: ${fileSizeBytes}B');
      if (fileSizeBytes <= 0) {
        throw Exception('Selected image file is empty');
      }

      final SettableMetadata metadata = SettableMetadata(contentType: 'image/jpeg');

      // Read bytes explicitly to avoid platform-specific file handle issues
      final Uint8List bytes = await imageFile.readAsBytes();
      final UploadTask uploadTask = ref.putData(bytes, metadata);

      TaskSnapshot snapshot = await uploadTask;
      // ignore: avoid_print
      print('Upload completed. State: ${snapshot.state}, bytesTransferred: ${snapshot.bytesTransferred}');

      // Retry getDownloadURL a few times in case of eventual consistency
      String? downloadUrl;
      for (int attempt = 1; attempt <= 5; attempt++) {
        try {
          downloadUrl = await ref.getDownloadURL();
          // ignore: avoid_print
          print('getDownloadURL succeeded on attempt $attempt');
          break;
        } catch (e) {
          // ignore: avoid_print
          print('getDownloadURL failed (attempt $attempt): $e');
          await Future.delayed(const Duration(milliseconds: 700));
        }
      }

      if (downloadUrl == null) {
        // List objects under the user's folder to aid debugging
        try {
          final ListResult listing = await ref.parent!.listAll();
          final names = listing.items.map((i) => i.name).toList();
          // ignore: avoid_print
          print('Folder listing for service_attachments/$uid: ${names.isEmpty ? '[empty]' : names}');
        } catch (_) {}
        throw Exception('Failed to retrieve download URL after upload');
      }

      return downloadUrl;
    } catch (e) {
      // ignore: avoid_print
      print('Error uploading image to Firebase: $e');
      rethrow;
    }
  }

  Future<void> _selectAvailability() async {
    // Submit availability and trigger next step
    String timeInfo = _selectedTimePreference;
    if (_selectedTimePreference == 'Specific time') {
      timeInfo = 'Specific time: ${_selectedTime.format(context)}';
    }
    
    // Format all selected dates
    List<String> dateStrings = _selectedDates.map((date) => 
      _formatDateForDisplay(date)
    ).toList();
    
    String datesText = _selectedDates.length == 1 
        ? dateStrings.first
        : dateStrings.join(', ');
    
    final availabilityData = {
      'dates': _selectedDates.map((date) => date.toIso8601String()).toList(),
      'selectedDatesCount': _selectedDates.length,
      'timePreference': _selectedTimePreference,
      'specificTime': _selectedTimePreference == 'Specific time' ? _selectedTime.format(context) : null,
      'preference': '$datesText at $timeInfo',
      'timestamp': DateTime.now().toIso8601String(),
      // Keep the single date for backward compatibility
      'date': _selectedDates.isNotEmpty ? _selectedDates.first.toIso8601String() : DateTime.now().toIso8601String(),
    };
    
    _aiService.onAvailabilitySelected(availabilityData);
    
    setState(() {
      _isLoading = true;
      _showCalendar = false;
      // Check if location form should show next
      if (_aiService.currentState.conversationStep == 5) {
        _showLocationForm = true;
        print('📍 Showing location form after calendar submission');
      }
    });
    
    try {
      // Continue conversation with clean availability info
      String availabilityMessage = _selectedDates.length == 1 
          ? "${dateStrings.first} at $timeInfo"
          : "${dateStrings.join(', ')} at $timeInfo";
          
      // If ElevenLabs phone call is active, don't use local AI
      if (!_isPhoneCallActive) {
        await _aiService.processUserInput(availabilityMessage);
      }
      
      setState(() {
        _isLoading = false;
        // Summary will show at step 8 via the main UI logic
      });
      
    } catch (e) {
      print('Error processing availability: $e');
      setState(() {
        _isLoading = false;
      });
    }
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });
  }

  Future<void> _submitServiceRequest() async {
    try {
      setState(() {
        _isLoading = true;
      });
      
      if (widget.user?.uid == null) {
        throw Exception('User must be logged in to submit a request');
      }
      
      // Prepare AI intake data in the format expected by UserRequestService
      // Get the complete service request summary for proper description
      final serviceRequestSummary = _aiService.getServiceRequestSummary();
      
      // Extract data from Service Request Summary structure (not currentState)
      final locationForm = serviceRequestSummary['locationForm'] as Map<String, dynamic>? ?? {};
      final contactForm = serviceRequestSummary['contactForm'] as Map<String, dynamic>? ?? {};
      
      final aiIntakeData = {
        'serviceCategory': serviceRequestSummary['serviceCategory'] ?? 'general',
        'description': serviceRequestSummary['serviceDescription'] ?? 
                      serviceRequestSummary['problemDescription'] ?? 
                      _aiService.currentState.description ?? '',
        'mediaUrls': serviceRequestSummary['mediaUrls'] ?? [],
        
        // Extract from locationForm (not currentState.address)
        'address': _buildFullAddress(locationForm),
        'zipcode': locationForm['zipcode'] ?? '',
        'city': locationForm['city'] ?? '',
        'state': locationForm['state'] ?? '',
        
        // Extract from contactForm (not currentState.phoneNumber)
        'phoneNumber': contactForm['tel'] ?? _aiService.currentState.phoneNumber ?? '',
        'email': contactForm['email'] ?? _aiService.currentState.email ?? '',
        
        // Use 'availability' from summary (not userAvailability from currentState)
        'userAvailability': serviceRequestSummary['availability'] ?? _aiService.currentState.userAvailability ?? {},
        
        'location': _aiService.currentState.location,
        'preferences': _aiService.currentState.preferences ?? {},
        'tags': serviceRequestSummary['tags'] ?? _aiService.currentState.tags ?? [],
        'priority': _aiService.currentState.priority ?? 3,
        
        // Extract price estimation from summary
        'aiPriceEstimation': serviceRequestSummary['priceEstimate'] != null ? {
          'suggestedRange': serviceRequestSummary['priceEstimate'],
          'aiModel': 'ai-conversation-v1',
          'confidenceLevel': 'medium',
          'generatedAt': DateTime.now().toIso8601String(),
        } : null,
        
        // Additional metadata for debugging and provider matching
        'serviceAnswers': _aiService.currentState.serviceAnswers,
        'conversationStep': serviceRequestSummary['conversationStep'] ?? _aiService.currentState.conversationStep,
        'extractedInfo': serviceRequestSummary['extractedInfo'] ?? _aiService.currentState.extractedInfo,
        'customerName': serviceRequestSummary['customerName'] ?? '',
        'isComplete': serviceRequestSummary['isComplete'] ?? false,
        'serviceRequestSummary': serviceRequestSummary, // Include full summary for reference
      };
      
      print('🚀 Submitting service request via UserRequestService...');
      print('📋 AI Intake Data: $aiIntakeData');
      
      // Use the proper UserRequestService to process the request
      final result = await UserRequestService.processUserRequest(
        userId: widget.user!.uid,
        aiIntakeData: aiIntakeData,
      );
      
      print('✅ Service request processed successfully: $result');
      
      // Debug: Show detailed result information
      if (result['userRequest'] != null) {
        final userRequest = result['userRequest'] as Map<String, dynamic>;
        print('🔍 DEBUG: Created User Request:');
        print('   - Request ID: ${userRequest['requestId']}');
        print('   - User ID: ${userRequest['userId']}');
        print('   - Status: ${userRequest['status']}');
        print('   - Service Category: ${userRequest['serviceCategory']}');
        print('   - Description: ${userRequest['description']}');
        print('   - Address: ${userRequest['address']}');
        print('   - Phone: ${userRequest['phoneNumber']}');
        print('   - Created At: ${userRequest['createdAt']}');
        print('   - Matched Providers: ${userRequest['matchedProviders']}');
      }
      
      // Show success message with request ID
      final requestId = result['userRequest']?['requestId'] ?? 'unknown';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Service request submitted successfully!\nRequest ID: $requestId'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 4),
        ),
      );
      
      // Close the screen
      Navigator.pop(context);
      
    } catch (e) {
      print('❌ Error submitting service request: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error submitting request: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Build voice mode UI
  Widget _buildVoiceModeUI() {
    return StreamBuilder<bool>(
      stream: _elevenLabsService.speakingStream,
      initialData: false,
      builder: (context, speakingSnapshot) {
        final isSpeaking = speakingSnapshot.data ?? false;
        
        return StreamBuilder<bool>(
          stream: _elevenLabsService.listeningStream,
          initialData: false,
          builder: (context, listeningSnapshot) {
            final isListening = listeningSnapshot.data ?? false;
            
            return StreamBuilder<bool>(
              stream: _elevenLabsService.bufferingStream,
              initialData: false,
              builder: (context, bufferingSnapshot) {
                final isBuffering = bufferingSnapshot.data ?? false;
            
            // Get recent conversation messages (last 5 for rolling window)
            final messages = _aiService.messages;
            final recentMessages = messages.length > 5 
                ? messages.sublist(messages.length - 5) 
                : messages;
            
            return Container(
              width: double.infinity,
              height: double.infinity,
              color: const Color(0xFFFBB04C),
              child: SafeArea(
                child: Column(
                  children: [
                    // Top section with pulse animation
                    const SizedBox(height: 40),
                    _buildPulseVisualization(isSpeaking, isListening),
                    
                    // Buffering indicator
                    if (isBuffering)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white.withOpacity(0.8)),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Buffering...',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white.withOpacity(0.8),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    
                    const SizedBox(height: 30),
                    
                    // Rolling conversation window
                    Expanded(
                      child: _buildRollingConversationWindow(recentMessages),
                    ),
                    
                    // Bottom section with Upload Photo button
                    Padding(
                      padding: const EdgeInsets.only(top: 20, bottom: 40),
                      child: ElevatedButton(
                        onPressed: () {
                          _uploadPhotos(fromFloatingButton: true);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFFFBB04C),
                          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          elevation: 4,
                        ),
                        child: const Text(
                          'Upload Photo',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
              },
            );
          },
        );
      },
    );
  }
  
  /// Build rolling conversation window
  Widget _buildRollingConversationWindow(List<ChatMessage> recentMessages) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: NotificationListener<ScrollNotification>(
        child: ListView.builder(
          reverse: false, // Start from top, scroll to show newest at bottom
          padding: const EdgeInsets.only(bottom: 20),
          itemCount: recentMessages.length,
          itemBuilder: (context, index) {
            final message = recentMessages[index];
            final isAI = message.type == MessageType.ai;
            final isUser = message.type == MessageType.user;
            
            // Skip system messages in voice mode
            if (message.type == MessageType.system) {
              return const SizedBox.shrink();
            }
            
            // Skip service boxes in voice mode
            if (message.metadata?['isServiceBox'] == true) {
              return const SizedBox.shrink();
            }
            
            // Skip service options message in voice mode
            if (message.metadata?['isServiceOptions'] == true) {
              return const SizedBox.shrink();
            }
            
            // Skip the initial "select a service" message in voice mode
            if (isAI && (message.content.toLowerCase().contains('select a service') || 
                         message.content.toLowerCase().contains('which service do you need'))) {
              return const SizedBox.shrink();
            }
            
            return AnimatedOpacity(
              duration: const Duration(milliseconds: 300),
              opacity: 1.0,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (isAI) ...[
                      // AI message - prominent display
                      Text(
                        message.content,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          height: 1.4,
                        ),
                      ),
                    ] else if (isUser) ...[
                      // User message - lighter style
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          message.content,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w400,
                            color: Colors.white.withOpacity(0.95),
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
  
  /// Build pulse visualization widget
  Widget _buildPulseVisualization(bool isSpeaking, bool isListening) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 1500),
      builder: (context, value, child) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: isSpeaking || isListening ? 120 : 100,
          height: isSpeaking || isListening ? 120 : 100,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withOpacity(0.3),
            boxShadow: [
              if (isSpeaking || isListening)
                BoxShadow(
                  color: Colors.white.withOpacity(0.4 * value),
                  blurRadius: 40 * value,
                  spreadRadius: 20 * value,
                ),
            ],
          ),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.5),
            ),
            child: Center(
              child: Container(
                width: 60,
                height: 60,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                ),
                child: Icon(
                  isSpeaking ? Icons.volume_up : (isListening ? Icons.mic : Icons.graphic_eq),
                  color: const Color(0xFFFBB04C),
                  size: 32,
                ),
              ),
            ),
          ),
        );
      },
      onEnd: () {
        // Restart animation for continuous pulse
        if (mounted && (isSpeaking || isListening)) {
          setState(() {});
        }
      },
    );
  }

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
          'Service Request',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () {
              _aiService.resetConversation();
              _aiService.startConversation();
              setState(() {
                _showPhotoUpload = false;
                _showCalendar = false;
                _showLocationForm = false;
                _showContactForm = false;
                _showSummary = false;
              });
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // Show voice mode UI when phone call is active
          if (_isPhoneCallActive)
            _buildVoiceModeUI()
          else
            // Show normal chat UI when in text mode
            Column(
              children: [
                // Chat messages
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _aiService.messages.length + (_isTyping ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (_isTyping && index == _aiService.messages.length) {
                        return _buildTypingIndicator();
                      }
                      
                      final message = _aiService.messages[index];
                      
                      // Check if this is the start of service boxes and we haven't rendered them yet
                      if (message.metadata?['isServiceBox'] == true && _isFirstServiceBox(index)) {
                        return _buildServiceBoxesGrid(index);
                      }
                      
                      // Skip service boxes that are already handled in the grid
                      if (message.metadata?['isServiceBox'] == true && !_isFirstServiceBox(index)) {
                        return const SizedBox.shrink();
                      }
                      
                      return _buildMessageBubble(message);
                    },
                  ),
                ),
                
                // Special UI elements
                if (_showPhotoUpload) _buildPhotoUploadSection(),
                if (_showCalendar) _buildCalendarSection(),
                if (_showLocationForm) _buildLocationFormSection(),
                if (_showContactForm) _buildContactFormSection(),
                if (_showSummary) _buildSummarySection(),
                
                // Input area
                _buildInputArea(),
              ],
            ),
          
          // Floating phone button (always show for mode switching)
          _buildFloatingPhoneButton(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    final isUser = message.type == MessageType.user;
    final isSystem = message.type == MessageType.system;
    final isServiceOptions = message.metadata?['isServiceOptions'] == true;
    final isServiceBox = message.metadata?['isServiceBox'] == true;
    
    // If it's a service box, render it as a horizontal card
    if (isServiceBox) {
      return _buildServiceBox(message);
    }
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) _buildAvatarIcon(),
          if (!isUser) const SizedBox(width: 8),
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * (isServiceOptions ? 0.9 : 0.75),
              ),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isUser 
                    ? Colors.white.withOpacity(0.9)
                    : isSystem 
                        ? Colors.green.withOpacity(0.8)
                        : isServiceOptions
                            ? Colors.blue.withOpacity(0.05) // Light floating background
                            : Colors.white.withOpacity(0.95),
                borderRadius: BorderRadius.circular(isServiceOptions ? 16 : 20),
                border: isServiceOptions 
                    ? Border.all(color: Colors.blue.withOpacity(0.2), width: 1)
                    : null,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isServiceOptions ? 0.08 : 0.1),
                    blurRadius: isServiceOptions ? 8 : 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (message.imageUrl != null) ...[
                    Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            message.imageUrl!,
                            width: double.infinity,
                            height: 200,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                width: double.infinity,
                                height: 200,
                                color: Colors.grey[300],
                                child: const Icon(Icons.image_not_supported, size: 50),
                              );
                            },
                          ),
                        ),
                        // Done button at bottom right of photo
                        Positioned(
                          bottom: 8,
                          right: 8,
                          child: GestureDetector(
                            onTap: _handleDoneButtonTap,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.green,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.3),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.check_circle, color: Colors.white, size: 16),
                                  SizedBox(width: 4),
                                  Text(
                                    'Done',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                  TranslatableText(
                    message.content,
                    style: TextStyle(
                      fontSize: isServiceOptions ? 15 : 16,
                      color: isUser ? Colors.black87 : (isServiceOptions ? Colors.black87 : Colors.black),
                      fontWeight: isSystem ? FontWeight.w600 : (isServiceOptions ? FontWeight.w500 : FontWeight.normal),
                      height: isServiceOptions ? 1.4 : 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isUser) const SizedBox(width: 8),
          if (isUser) _buildUserAvatar(),
        ],
      ),
    );
  }

  // Check if this is the first service box in a sequence
  bool _isFirstServiceBox(int index) {
    if (index == 0) return true;
    
    final currentMessage = _aiService.messages[index];
    final previousMessage = _aiService.messages[index - 1];
    
    return currentMessage.metadata?['isServiceBox'] == true && 
           previousMessage.metadata?['isServiceBox'] != true;
  }

  // Build a grid of service boxes (2 columns)
  Widget _buildServiceBoxesGrid(int startIndex) {
    List<ChatMessage> serviceBoxes = [];
    
    // Collect all consecutive service boxes starting from startIndex
    for (int i = startIndex; i < _aiService.messages.length; i++) {
      final message = _aiService.messages[i];
      if (message.metadata?['isServiceBox'] == true) {
        serviceBoxes.add(message);
      } else {
        break;
      }
    }
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16, left: 44, right: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Create rows of 2 service boxes each
          for (int i = 0; i < serviceBoxes.length; i += 2)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: _buildServiceBoxWidget(serviceBoxes[i]),
                  ),
                  const SizedBox(width: 8),
                  if (i + 1 < serviceBoxes.length)
                    Expanded(
                      child: _buildServiceBoxWidget(serviceBoxes[i + 1]),
                    )
                  else
                    const Expanded(child: SizedBox()),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // Build individual service box widget for grid layout
  Widget _buildServiceBoxWidget(ChatMessage message) {
    final serviceType = message.metadata?['serviceType'] ?? message.content;
    
    // Define service icons
    Map<String, IconData> serviceIcons = {
      'Plumbing': Icons.plumbing,
      'Electrical': Icons.electrical_services,
      'HVAC': Icons.ac_unit,
      'Appliance Repair': Icons.kitchen,
      'Cleaning': Icons.cleaning_services,
      'Handyman': Icons.handyman,
      'Landscaping': Icons.grass,
      'Pest Control': Icons.bug_report,
      'Roofing': Icons.roofing,
      'Painting': Icons.format_paint,
    };
    
    // Define service colors
    Map<String, Color> serviceColors = {
      'Plumbing': Colors.blue,
      'Electrical': Colors.orange,
      'HVAC': Colors.cyan,
      'Appliance Repair': Colors.purple,
      'Cleaning': Colors.green,
      'Handyman': Colors.brown,
      'Landscaping': Colors.lightGreen,
      'Pest Control': Colors.red,
      'Roofing': Colors.grey,
      'Painting': Colors.pink,
    };
    
    IconData icon = serviceIcons[serviceType] ?? Icons.home_repair_service;
    Color color = serviceColors[serviceType] ?? Colors.blue;
    
    return GestureDetector(
      onTap: () {
        _messageController.text = serviceType;
        _sendMessage();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.withOpacity(0.2), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: color,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: TranslatableText(
                serviceType,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServiceBox(ChatMessage message) {
    // This method is now deprecated in favor of the grid layout
    // But keeping it for backward compatibility
    return _buildServiceBoxWidget(message);
  }

  Widget _buildAvatarIcon() {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: const Icon(
        Icons.smart_toy,
        color: Color(0xFFFBB04C),
        size: 20,
      ),
    );
  }

  Widget _buildUserAvatar() {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipOval(
        child: widget.user?.photoURL != null
            ? Image.network(
                widget.user!.photoURL!,
                width: 36,
                height: 36,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(Icons.person, color: Color(0xFFFBB04C), size: 20);
                },
              )
            : const Icon(Icons.person, color: Color(0xFFFBB04C), size: 20),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _buildAvatarIcon(),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.95),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildTypingDot(0),
                const SizedBox(width: 4),
                _buildTypingDot(1),
                const SizedBox(width: 4),
                _buildTypingDot(2),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingDot(int index) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.7),
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _buildPhotoUploadSection() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const TranslatableText(
            'Upload Photos',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Take photos or select images to help service providers understand your needs better.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _uploadPhotos,
                  icon: _isLoading 
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.camera_alt),
                  label: TranslatableText(_isLoading ? 'Uploading...' : 
                    (_aiService.currentState.mediaUrls.isEmpty ? 'Add Photos' : 'Add More')),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFBB04C),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              if (_aiService.currentState.mediaUrls.isNotEmpty) ...[
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () async {
                    setState(() {
                      _showPhotoUpload = false;
                    });
                    
                    // Trigger AI to ask about availability after photos are done
                    // If ElevenLabs phone call is active, don't use local AI
                    if (!_isPhoneCallActive) {
                      await _aiService.processUserInput("I'm done uploading photos.");
                    }
                    
                    setState(() {
                      // Show calendar UI for the next step
                      if (_aiService.currentState.conversationStep >= 4) {
                        _showCalendar = true;
                        print('🗓️ Moving to calendar after photos are done');
                      }
                    });
                    
                    _scrollToBottom();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Done'),
                ),
              ],
            ],
          ),
          
          // Show uploaded photos
          if (_aiService.currentState.mediaUrls.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            Text(
              'Uploaded Photos (${_aiService.currentState.mediaUrls.length})',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 80,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _aiService.currentState.mediaUrls.length,
                itemBuilder: (context, index) {
                  return Container(
                    margin: const EdgeInsets.only(right: 8),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        _aiService.currentState.mediaUrls[index],
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                            width: 80,
                            height: 80,
                            color: Colors.grey[200],
                            child: const Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: 80,
                            height: 80,
                            color: Colors.grey[200],
                            child: const Icon(Icons.error_outline, color: Colors.grey),
                          );
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCalendarSection() {
    return Container(
      margin: const EdgeInsets.all(16),
      constraints: const BoxConstraints(maxHeight: 600), // Limit height to prevent overflow
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
          const Text(
            'What is your availability?',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Select your preferred date(s) and time:',
            style: TextStyle(
              fontSize: 14,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap dates to select multiple days. ${_selectedDates.isEmpty ? 'Select at least one date.' : '${_selectedDates.length} date${_selectedDates.length == 1 ? '' : 's'} selected.'}',
            style: TextStyle(
              fontSize: 12,
              color: _selectedDates.isEmpty ? Colors.red.shade600 : Colors.green.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          TableCalendar<DateTime>(
            firstDay: DateTime.now(),
            lastDay: DateTime.now().add(const Duration(days: 60)),
            focusedDay: _selectedDate,
            calendarFormat: CalendarFormat.month,
            startingDayOfWeek: StartingDayOfWeek.sunday,
            selectedDayPredicate: (day) {
              return _selectedDates.any((selectedDate) =>
                  selectedDate.year == day.year &&
                  selectedDate.month == day.month &&
                  selectedDate.day == day.day);
            },
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDate = focusedDay;
                if (_selectedDates.any((date) =>
                    date.year == selectedDay.year &&
                    date.month == selectedDay.month &&
                    date.day == selectedDay.day)) {
                  _selectedDates.removeWhere((date) =>
                      date.year == selectedDay.year &&
                      date.month == selectedDay.month &&
                      date.day == selectedDay.day);
                } else {
                  _selectedDates.add(selectedDay);
                }
              });
            },
            calendarStyle: CalendarStyle(
              outsideDaysVisible: false,
              selectedDecoration: const BoxDecoration(
                color: Color(0xFFFBB04C),
                shape: BoxShape.circle,
              ),
              todayDecoration: BoxDecoration(
                color: const Color(0xFFFBB04C).withOpacity(0.5),
                shape: BoxShape.circle,
              ),
              weekendTextStyle: const TextStyle(color: Colors.red),
            ),
            headerStyle: const HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
              titleTextStyle: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          
          // Display selected dates
          if (_selectedDates.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.calendar_today, size: 16, color: Colors.green.shade600),
                      const SizedBox(width: 8),
                      Text(
                        'Selected Date${_selectedDates.length == 1 ? '' : 's'}:',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.green.shade600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: _selectedDates.map((date) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.green.withOpacity(0.3)),
                        ),
                        child: Text(
                          _formatDateForDisplay(date),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ],
          
          const SizedBox(height: 24),
          
          // Time Preference Section
          const Text(
            'Time Preference:',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          
          // Time preference dropdown
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.withOpacity(0.3)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedTimePreference,
                isExpanded: true,
                items: _timePreferenceOptions.map((String option) {
                  return DropdownMenuItem<String>(
                    value: option,
                    child: Text(
                      option,
                      style: const TextStyle(fontSize: 14),
                    ),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedTimePreference = newValue!;
                  });
                },
              ),
            ),
          ),
          
          // Specific time picker (only show if "Specific time" is selected)
          if (_selectedTimePreference == 'Specific time') ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.access_time, color: Colors.black54),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Selected Time: ${_selectedTime.format(context)}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      final TimeOfDay? picked = await showTimePicker(
                        context: context,
                        initialTime: _selectedTime,
                      );
                      if (picked != null && picked != _selectedTime) {
                        setState(() {
                          _selectedTime = picked;
                        });
                      }
                    },
                    child: const Text('Change'),
                  ),
                ],
              ),
            ),
          ],
          
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _selectedDates.isEmpty ? null : _selectAvailability,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFBB04C),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: TranslatableText('Continue (${_selectedDates.length} date${_selectedDates.length == 1 ? '' : 's'} selected)'),
          ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummarySection() {
    final state = _aiService.currentState;
    final summary = _aiService.getServiceRequestSummary();
    final priceEstimate = state.priceEstimate ?? {'min': 100, 'max': 500};
    final locationForm = summary['locationForm'] as Map<String, dynamic>? ?? {};
    final contactForm = summary['contactForm'] as Map<String, dynamic>? ?? {};
    final availability = summary['availability'] as Map<String, dynamic>? ?? state.userAvailability ?? {};
    
    return Container(
      margin: const EdgeInsets.all(16),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFBB04C).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.summarize, color: Color(0xFFFBB04C), size: 24),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: TranslatableText(
                  'Service Request Summary',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          // Service Information Section
          _buildSummaryCategorySection(
            'Service Details',
            Icons.home_repair_service,
            [
              if (state.serviceCategory != null)
                _buildSummaryItem('Service Type', state.serviceCategory!),
              if (state.description != null && state.description!.isNotEmpty)
                _buildSummaryItem('Description', state.description!),
            ],
          ),
          
          // Service Details/Answers
          if (state.serviceAnswers.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildSummaryCategorySection(
              'Additional Details',
              Icons.info_outline,
              state.serviceAnswers.entries.map((entry) => 
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('• ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      Expanded(child: Text(entry.value, style: const TextStyle(fontSize: 14))),
                    ],
                  ),
                ),
              ).toList(),
            ),
          ],
          
          // Photos Section
          if (state.mediaUrls.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildSummaryCategorySection(
              'Photos',
              Icons.photo_library,
              [
                Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green, size: 18),
                    const SizedBox(width: 8),
                    Text('${state.mediaUrls.length} photo${state.mediaUrls.length == 1 ? '' : 's'} uploaded', 
                         style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                  ],
                ),
              ],
            ),
          ],
          
          // Availability Section
          if (availability.isNotEmpty && availability['preference'] != null) ...[
            const SizedBox(height: 16),
            _buildSummaryCategorySection(
              'Availability',
              Icons.calendar_today,
              [
                _buildSummaryItem('Preferred Time', availability['preference']?.toString() ?? 'Not specified'),
                if (availability['dates'] != null && (availability['dates'] as List).isNotEmpty)
                  _buildSummaryItem('Selected Dates', (availability['dates'] as List).join(', ')),
              ],
            ),
          ],
          
          // Location Section
          if (locationForm.isNotEmpty || (state.address != null && state.address!.isNotEmpty)) ...[
            const SizedBox(height: 16),
            _buildSummaryCategorySection(
              'Service Location',
              Icons.location_on,
              [
                if (locationForm['address'] != null && locationForm['address'].toString().isNotEmpty)
                  _buildSummaryItem('Address', locationForm['address'].toString()),
                if (locationForm['city'] != null && locationForm['city'].toString().isNotEmpty)
                  _buildSummaryItem('City', locationForm['city'].toString()),
                if (locationForm['state'] != null && locationForm['state'].toString().isNotEmpty)
                  _buildSummaryItem('State', locationForm['state'].toString()),
                if (locationForm['zipcode'] != null && locationForm['zipcode'].toString().isNotEmpty)
                  _buildSummaryItem('Zip Code', locationForm['zipcode'].toString()),
                // Fallback to state.address if locationForm is empty
                if (locationForm.isEmpty && state.address != null && state.address!.isNotEmpty)
                  _buildSummaryItem('Address', state.address!),
              ],
            ),
          ],
          
          // Contact Information Section
          if (contactForm.isNotEmpty || (state.phoneNumber != null && state.phoneNumber!.isNotEmpty)) ...[
            const SizedBox(height: 16),
            _buildSummaryCategorySection(
              'Contact Information',
              Icons.contact_phone,
              [
                if (contactForm['name'] != null && contactForm['name'].toString().isNotEmpty)
                  _buildSummaryItem('Name', contactForm['name'].toString()),
                if (contactForm['tel'] != null && contactForm['tel'].toString().isNotEmpty)
                  _buildSummaryItem('Phone', contactForm['tel'].toString()),
                if (contactForm['email'] != null && contactForm['email'].toString().isNotEmpty)
                  _buildSummaryItem('Email', contactForm['email'].toString()),
                // Fallback to state.phoneNumber if contactForm is empty
                if (contactForm.isEmpty && state.phoneNumber != null && state.phoneNumber!.isNotEmpty)
                  _buildSummaryItem('Phone', state.phoneNumber!),
              ],
            ),
          ],
          
          // Price Estimate
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const TranslatableText(
                  'Estimated Price Range',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '\$${priceEstimate['min']} - \$${priceEstimate['max']}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          const Text(
            'Please review the information above. You can make changes by typing corrections or submit the request as is.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
          
          const SizedBox(height: 16),
          
          ElevatedButton(
            onPressed: _isLoading ? null : _submitServiceRequest,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFBB04C),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const TranslatableText(
                    'Submit Service Request',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ],
        ),
      ),
    );
  }
  
  Widget _buildSummaryItem(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TranslatableText(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            content,
            style: const TextStyle(fontSize: 14),
          ),
        ],
      ),
    );
  }
  
  Widget _buildSummaryCategorySection(String title, IconData icon, List<Widget> children) {
    if (children.isEmpty) return const SizedBox.shrink();
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: const Color(0xFFFBB04C)),
              const SizedBox(width: 8),
              TranslatableText(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: 'Type your response here',
                hintStyle: TextStyle(color: Colors.grey[400]),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey[100],
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              maxLines: null,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _isLoading ? null : _handleMicrophoneButtonTap,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _isLoading 
                    ? Colors.grey 
                    : _isListening 
                        ? Colors.red 
                        : const Color(0xFFFBB04C),
                shape: BoxShape.circle,
                boxShadow: _isListening ? [
                  BoxShadow(
                    color: Colors.red.withOpacity(0.3),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ] : null,
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : _isListening
                      ? const Icon(
                          Icons.mic_off,
                          color: Colors.white,
                          size: 24,
                        )
                      : _messageController.text.trim().isNotEmpty
                          ? const Icon(
                              Icons.send,
                              color: Colors.white,
                              size: 24,
                            )
                          : const Icon(
                              Icons.mic,
                              color: Colors.white,
                              size: 24,
                            ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildLocationFormSection() {
    // Use persistent form controllers - Make scrollable and more compact to prevent overflow
    
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '📍 Service Location Details',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          
          // Address Field
          TextField(
            controller: _addressController,
            decoration: const InputDecoration(
              labelText: 'Street Address *',
              hintText: '123 Main Street',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.home),
            ),
          ),
          const SizedBox(height: 12),
          
          // City and State Row
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _cityController,
                  decoration: const InputDecoration(
                    labelText: 'City *',
                    hintText: 'San Francisco',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.location_city),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _stateController,
                  decoration: const InputDecoration(
                    labelText: 'State *',
                    hintText: 'CA',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.map),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Zipcode Field
          TextField(
            controller: _zipcodeController,
            decoration: const InputDecoration(
              labelText: 'Zipcode *',
              hintText: '94102',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.local_post_office),
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 20),
          
          // Submit Button
          ElevatedButton(
            onPressed: () {
              // Validate required fields
              if (_addressController.text.trim().isEmpty ||
                  _cityController.text.trim().isEmpty ||
                  _stateController.text.trim().isEmpty ||
                  _zipcodeController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please fill in all required fields'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              
              // Submit location data
              final locationData = {
                'address': _addressController.text.trim(),
                'city': _cityController.text.trim(),
                'state': _stateController.text.trim(),
                'zipcode': _zipcodeController.text.trim(),
              };
              
              _aiService.onLocationFormCompleted(locationData);
              
              setState(() {
                _showLocationForm = false;
                _showContactForm = true; // Show contact form next
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFBB04C),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const TranslatableText(
              'Continue to Contact Info',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildContactFormSection() {
    // Use persistent form controllers - Make scrollable and compact to prevent overflow
    
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '📞 Contact Information',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          
          // Name Field
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Full Name *',
              hintText: 'John Smith',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.person),
            ),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 12),
          
          // Phone Field
          TextField(
            controller: _phoneController,
            decoration: const InputDecoration(
              labelText: 'Phone Number *',
              hintText: '+1 (555) 123-4567',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.phone),
            ),
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 20),
          
          // Submit Button
          ElevatedButton(
            onPressed: () {
              // Validate required fields
              if (_nameController.text.trim().isEmpty ||
                  _phoneController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please fill in all required fields'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              
              // Submit contact data
              final contactData = {
                'name': _nameController.text.trim(),
                'tel': _phoneController.text.trim(),
              };
              
              _aiService.onContactFormCompleted(contactData);
              
              setState(() {
                _showContactForm = false;
                _showSummary = true; // Show summary next
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFBB04C),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Complete Service Request',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build full address from location form components
  String _buildFullAddress(Map<String, dynamic> locationForm) {
    final address = locationForm['address']?.toString() ?? '';
    final city = locationForm['city']?.toString() ?? '';
    final state = locationForm['state']?.toString() ?? '';
    final zipcode = locationForm['zipcode']?.toString() ?? '';
    
    // If we have a complete address, use it
    if (address.isNotEmpty) {
      List<String> parts = [address];
      if (city.isNotEmpty) parts.add(city);
      if (state.isNotEmpty) parts.add(state);
      if (zipcode.isNotEmpty) parts.add(zipcode);
      return parts.join(', ');
    }
    
    // Fallback to currentState address if locationForm is empty
    return _aiService.currentState.address ?? '';
  }

  /// Format date for clear display (e.g., "Sept 7th, 2025")
  String _formatDateForDisplay(DateTime date) {
    const monthNames = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sept', 'Oct', 'Nov', 'Dec'
    ];
    
    String day = date.day.toString();
    String suffix = _getDaySuffix(date.day);
    String month = monthNames[date.month - 1];
    String year = date.year.toString();
    
    return '$month $day$suffix, $year';
  }

  /// Get ordinal suffix for day (1st, 2nd, 3rd, 4th, etc.)
  String _getDaySuffix(int day) {
    if (day >= 11 && day <= 13) {
      return 'th';
    }
    switch (day % 10) {
      case 1:
        return 'st';
      case 2:
        return 'nd';
      case 3:
        return 'rd';
      default:
        return 'th';
    }
  }

  /// Build floating draggable phone call button
  Widget _buildFloatingPhoneButton() {
    return StreamBuilder<ConversationStatus>(
      stream: _elevenLabsService.statusStream,
      initialData: _elevenLabsService.status,
      builder: (context, statusSnapshot) {
        final status = statusSnapshot.data ?? ConversationStatus.disconnected;
        
        return StreamBuilder<bool>(
          stream: _elevenLabsService.speakingStream,
          initialData: false,
          builder: (context, speakingSnapshot) {
            final isSpeaking = speakingSnapshot.data ?? false;
            
            return StreamBuilder<bool>(
              stream: _elevenLabsService.listeningStream,
              initialData: false,
              builder: (context, listeningSnapshot) {
                final isListening = listeningSnapshot.data ?? false;
                
                return Positioned(
                  left: _phonePosition.dx,
                  top: _phonePosition.dy,
                  child: GestureDetector(
                    onPanStart: (details) {
                      setState(() {
                        _isDraggingPhone = true;
                      });
                    },
                    onPanUpdate: (details) {
                      if (_isDraggingPhone) {
                        setState(() {
                          final buttonSize = _isPhoneCallActive ? 60.0 : 52.0;
                          _phonePosition = Offset(
                            (_phonePosition.dx + details.delta.dx).clamp(0.0, MediaQuery.of(context).size.width - buttonSize),
                            (_phonePosition.dy + details.delta.dy).clamp(0.0, MediaQuery.of(context).size.height - buttonSize),
                          );
                        });
                      }
                    },
                    onPanEnd: (details) {
                      setState(() {
                        _isDraggingPhone = false;
                      });
                    },
                    onTap: _handlePhoneButtonPressed,
                    child: AnimatedBuilder(
                      animation: _phoneAnimationController,
                      builder: (context, child) {
                        final buttonSize = _isPhoneCallActive ? 60.0 : 52.0;
                        final borderRadius = _isPhoneCallActive ? 30.0 : 26.0;
                        
                        return Material(
                          elevation: 8,
                          borderRadius: BorderRadius.circular(borderRadius),
                          child: Container(
                            width: buttonSize,
                            height: buttonSize,
                            decoration: BoxDecoration(
                              color: _getPhoneButtonColor(status, isSpeaking, isListening),
                              borderRadius: BorderRadius.circular(borderRadius),
                              boxShadow: [
                                BoxShadow(
                                  color: _getPhoneButtonColor(status, isSpeaking, isListening).withOpacity(0.4),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Center(
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 300),
                                child: _getPhoneButtonIcon(status, isSpeaking, isListening),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  /// Get phone button color based on status
  Color _getPhoneButtonColor(ConversationStatus status, bool isSpeaking, bool isListening) {
    if (status == ConversationStatus.error) {
      return Colors.red;
    } else if (status == ConversationStatus.active && (isSpeaking || isListening)) {
      return Colors.green;
    } else if (status == ConversationStatus.active || status == ConversationStatus.connected) {
      return const Color(0xFF1976D2);
    } else if (status == ConversationStatus.connecting) {
      return Colors.orange;
    } else {
      return const Color(0xFF1976D2);
    }
  }

  /// Get phone button icon based on status
  Widget _getPhoneButtonIcon(ConversationStatus status, bool isSpeaking, bool isListening) {
    final iconSize = _isPhoneCallActive ? 28.0 : 24.0;
    
    if (status == ConversationStatus.error) {
      return Icon(
        Icons.error,
        color: Colors.white,
        size: iconSize,
        key: const ValueKey('error'),
      );
    } else if (status == ConversationStatus.connecting) {
      return SizedBox(
        width: iconSize - 4,
        height: iconSize - 4,
        child: const CircularProgressIndicator(
          color: Colors.white,
          strokeWidth: 2.5,
          key: ValueKey('connecting'),
        ),
      );
    } else if (_isPhoneCallActive && isSpeaking) {
      // Voice mode active and AI is speaking
      return Icon(
        Icons.volume_up,
        color: Colors.white,
        size: iconSize,
        key: const ValueKey('speaking'),
      );
    } else if (_isPhoneCallActive && isListening) {
      // Voice mode active and listening to user
      return Icon(
        Icons.mic,
        color: Colors.white,
        size: iconSize,
        key: const ValueKey('listening'),
      );
    } else if (_isPhoneCallActive) {
      // Voice mode active - show horizontal phone (end call)
      return Icon(
        Icons.call_end,
        color: Colors.white,
        size: iconSize,
        key: const ValueKey('active_call_end'),
      );
    } else {
      // Text mode - show vertical phone (start call)
      return Icon(
        Icons.call,
        color: Colors.white,
        size: iconSize,
        key: const ValueKey('call'),
      );
    }
  }

  /// Handle phone button press
  Future<void> _handlePhoneButtonPressed() async {
    // Use _isPhoneCallActive to determine current mode instead of status
    // This correctly tracks whether we're in voice mode or text mode
    if (_isPhoneCallActive) {
      // Currently in voice mode - end it and switch to text mode
      await _endPhoneCall();
    } else {
      // Currently in text mode or disconnected - start voice mode
      await _startPhoneCall();
    }
  }

  /// Start phone call with ElevenLabs
  Future<void> _startPhoneCall() async {
    try {
      print('🎤 Starting ElevenLabs phone call...');
      setState(() {
        _isConnectingToCall = true;
      });

      // Test ElevenLabs connection first
      print('🧪 Testing ElevenLabs connection...');
      final testResult = await _elevenLabsService.testConnection();
      if (!testResult) {
        print('❌ ElevenLabs connection test failed');
        _showErrorSnackBar('ElevenLabs connection test failed. Please check your API key.');
        setState(() {
          _isConnectingToCall = false;
        });
        return;
      }

      // Initialize ElevenLabs service
      print('🔧 Initializing ElevenLabs service...');
      final initialized = await _elevenLabsService.initialize();
      if (!initialized) {
        print('❌ ElevenLabs initialization failed');
        _showErrorSnackBar('Voice service initialization failed. Please check microphone permissions in Settings.');
        setState(() {
          _isConnectingToCall = false;
        });
        return;
      }

      print('✅ ElevenLabs service initialized, checking connection...');
      
      // Only connect if not already connected (check for both 'connected' and 'active')
      if (_elevenLabsService.status != ConversationStatus.active && 
          _elevenLabsService.status != ConversationStatus.connected) {
        print('🔌 Not connected - establishing connection...');
        
        // Set mode to voice BEFORE connecting
        _elevenLabsService.setMode(ConversationMode.voice);
        print('✅ Mode set to VOICE before connecting');
        
        // Connect to ElevenLabs with timeout
        final connected = await _elevenLabsService.connect().timeout(
          const Duration(seconds: 15),
          onTimeout: () {
            print('⏰ ElevenLabs connection timed out after 15s');
            return false;
          },
        );
        
        if (!connected) {
          print('❌ ElevenLabs connection failed');
          _showErrorSnackBar('Voice service connection failed. Please try again or use text chat.');
          setState(() {
            _isConnectingToCall = false;
          });
          return;
        }

        print('🚀 Starting ElevenLabs session...');
        await _elevenLabsService.startSession();
      } else {
        print('✅ Already connected - reusing existing connection');
        // Set mode to voice for phone call
        _elevenLabsService.setMode(ConversationMode.voice);
        print('✅ Mode set to VOICE');
        
        // Always call startSession when switching to voice mode
        // This ensures the microphone is properly initialized
        print('🚀 Starting ElevenLabs session for voice mode...');
        await _elevenLabsService.startSession();
      }
      
      // Start ElevenLabs voice listening (not regular speech-to-text)
      print('🎤 Starting ElevenLabs voice listening...');
      await _elevenLabsService.startListening();
      
      setState(() {
        _isPhoneCallActive = true;
        _isConnectingToCall = false;
      });

      print('✅ Voice call connected successfully');
      // Show phone call started message
      _showInfoSnackBar('📞 Voice call started! Start speaking...');
      
    } catch (e) {
      print('❌ Error starting phone call: $e');
      _showErrorSnackBar('Failed to start phone call: ${e.toString()}');
      setState(() {
        _isConnectingToCall = false;
      });
    }
  }

  /// End phone call - but keep connection alive for text mode
  Future<void> _endPhoneCall() async {
    try {
      print('📞 Ending voice conversation...');
      
      // Set mode back to text
      _elevenLabsService.setMode(ConversationMode.text);
      
      // DON'T disconnect - just stop listening so we can continue in text mode
      // The WebSocket stays alive for text-based conversation
      await _elevenLabsService.stopListening();
      print('🛑 Voice input stopped - ready for text mode');
      
      setState(() {
        _isPhoneCallActive = false;
        _isConnectingToCall = false;
      });

      print('✅ Voice conversation ended - continuing in text mode');
      _showInfoSnackBar('📞 Voice ended - you can now type messages');
      
    } catch (e) {
      print('❌ Error ending phone call: $e');
      _showErrorSnackBar('Failed to end voice call: ${e.toString()}');
    }
  }

  /// Show error snack bar
  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  /// Show info snack bar
  void _showInfoSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.blue,
        duration: const Duration(seconds: 3),
      ),
    );
  }
  
  /// Build floating photo upload button
  Widget _buildFloatingPhotoButton() {
    return Positioned(
      left: _photoButtonPosition.dx,
      top: _photoButtonPosition.dy,
      child: GestureDetector(
        onPanStart: (details) {
          setState(() {
            _isDraggingPhoto = true;
          });
        },
        onPanUpdate: (details) {
          if (_isDraggingPhoto) {
            setState(() {
              _photoButtonPosition = Offset(
                (_photoButtonPosition.dx + details.delta.dx).clamp(0.0, MediaQuery.of(context).size.width - 60),
                (_photoButtonPosition.dy + details.delta.dy).clamp(0.0, MediaQuery.of(context).size.height - 60),
              );
            });
          }
        },
        onPanEnd: (details) {
          setState(() {
            _isDraggingPhoto = false;
          });
        },
        onTap: () {
          _uploadPhotos(fromFloatingButton: true);
        },
        child: AnimatedBuilder(
          animation: _photoAnimationController,
          builder: (context, child) {
            return Transform.scale(
              scale: 1.0 + (_photoAnimationController.value * 0.2),
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(28),
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.orange.shade400,
                        Colors.orange.shade600,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.orange.withOpacity(0.5),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      Center(
                        child: Icon(
                          Icons.camera_alt,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      if (_uploadedPhotosInSession.isNotEmpty)
                        Positioned(
                          right: 4,
                          top: 4,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '${_uploadedPhotosInSession.length}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
} 