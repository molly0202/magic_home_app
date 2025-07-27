import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'dart:io';
import '../services/ai_conversation_service.dart';
import '../models/service_request.dart';

class AITaskIntakeScreen extends StatefulWidget {
  final User? user;

  const AITaskIntakeScreen({
    super.key,
    this.user,
  });

  @override
  State<AITaskIntakeScreen> createState() => _AITaskIntakeScreenState();
}

class _AITaskIntakeScreenState extends State<AITaskIntakeScreen> {
  final AIConversationService _aiService = AIConversationService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _picker = ImagePicker();
  late stt.SpeechToText _speech;
  
  bool _isLoading = false;
  bool _isTyping = false;
  bool _showPhotoUpload = false;
  bool _showCalendar = false;
  bool _showSummary = false;
  bool _isListening = false;
  bool _speechEnabled = false;
  bool _keyboardVisible = false;
  DateTime _selectedDate = DateTime.now();
  List<DateTime> _selectedDates = [];
  
  // Time selection variables
  Map<DateTime, List<String>> _selectedTimeSlots = {};
  String _selectedTimeSlot = '';
  List<String> _availableTimeSlots = [
    'Morning (8:00 AM - 12:00 PM)',
    'Afternoon (12:00 PM - 4:00 PM)',
    'Evening (4:00 PM - 8:00 PM)',
    'Flexible (Any time)',
  ];

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _initializeSpeech();
    
    // Load existing conversation or start new one
    _aiService.loadConversationState();
    if (_aiService.messages.isEmpty) {
      _aiService.startConversation();
    }
    
    // Listen for keyboard visibility changes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
      _checkKeyboardVisibility();
    });
    
    // Add listener for text field focus changes
    _messageController.addListener(_onTextChanged);
    
    // Add listener for scroll controller
    _scrollController.addListener(() {
      // Update keyboard visibility check when scrolling
      _checkKeyboardVisibility();
    });
    
    // Test Firebase Storage connectivity
    _testFirebaseStorage();
  }

  void _checkKeyboardVisibility() {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final isKeyboardVisible = bottomInset > 0;
    
    if (isKeyboardVisible != _keyboardVisible) {
      setState(() {
        _keyboardVisible = isKeyboardVisible;
        
        // Dismiss calendar and other UI elements when keyboard becomes visible
        if (isKeyboardVisible) {
          _showCalendar = false;
          _showPhotoUpload = false;
          _showSummary = false;
        }
      });
      
      if (isKeyboardVisible) {
        // Scroll to bottom when keyboard appears with a slight delay
        Future.delayed(const Duration(milliseconds: 100), () {
          _scrollToBottom();
        });
      }
    }
  }

  @override
  void dispose() {
    _messageController.removeListener(_onTextChanged);
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    // Dismiss calendar and other UI elements when user starts typing
    if (_messageController.text.isNotEmpty && (_showCalendar || _showPhotoUpload || _showSummary)) {
      setState(() {
        _showCalendar = false;
        _showPhotoUpload = false;
        _showSummary = false;
      });
    }
  }

  Future<void> _testFirebaseStorage() async {
    try {
      print('Testing Firebase Storage connectivity...');
      print('Storage bucket: ${FirebaseStorage.instance.app.options.storageBucket}');
      
      // Test if we can access the storage reference
      final testRef = FirebaseStorage.instance.ref().child('test_connection.txt');
      print('Test reference created successfully');
      
      // Check if user is authenticated
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        print('User authenticated: ${currentUser.uid}');
        print('User email: ${currentUser.email}');
      } else {
        print('No authenticated user found');
      }
      
      print('Firebase Storage test completed successfully');
    } catch (e) {
      print('Firebase Storage test failed: $e');
    }
  }

  Future<void> _initializeSpeech() async {
    try {
      _speechEnabled = await _speech.initialize(
        onStatus: (val) {
          setState(() {
            _isListening = val == 'listening';
          });
        },
        onError: (val) {
          print('Speech recognition error: $val');
          setState(() {
            _isListening = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Speech recognition error: ${val.errorMsg}')),
          );
        },
      );
    } catch (e) {
      print('Speech initialization error: $e');
      _speechEnabled = false;
    }
  }

  Future<void> _startListening() async {
    print('Starting speech recognition...');
    print('Speech enabled: $_speechEnabled');
    print('Currently listening: $_isListening');
    
    if (!_speechEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Speech recognition not available')),
      );
      return;
    }

    if (_isListening) {
      print('Already listening, stopping...');
      _stopListening();
      return;
    }

    try {
      setState(() {
        _isListening = true;
        // Dismiss calendar and other UI elements when starting voice input
        _showCalendar = false;
        _showPhotoUpload = false;
        _showSummary = false;
      });
      print('Set listening state to true');
      
      await _speech.listen(
        onResult: (val) {
          print('Speech result: ${val.recognizedWords}');
          setState(() {
            _messageController.text = val.recognizedWords;
          });
          
          // Auto-send if speech is final and not empty
          if (val.hasConfidenceRating && val.confidence > 0.8) {
            if (val.recognizedWords.isNotEmpty) {
              _sendMessage();
            }
          }
        },
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 5),
        partialResults: true,
        localeId: 'en_US',
        onSoundLevelChange: (level) {
          // Could add visual feedback for sound level
        },
      );
    } catch (e) {
      print('Error starting speech recognition: $e');
      setState(() {
        _isListening = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error starting speech recognition: $e')),
      );
    }
  }

  Future<void> _stopListening() async {
    print('Stopping speech recognition...');
    await _speech.stop();
    setState(() {
      _isListening = false;
    });
    print('Set listening state to false');
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 50, // Extra padding
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    final message = _messageController.text.trim();
    _messageController.clear();
    
    // Stop listening if active
    if (_isListening) {
      _stopListening();
    }
    
    setState(() {
      _isLoading = true;
      _isTyping = true;
    });

    try {
      await _aiService.processUserInput(message);
      
      setState(() {
        // Reset all special UI states first
        _showPhotoUpload = false;
        _showCalendar = false;
        _showSummary = false;
        
        // Check LLM response for UI trigger keywords
        final lastMessage = _aiService.messages.isNotEmpty ? _aiService.messages.last : null;
        if (lastMessage != null && lastMessage.type == MessageType.ai) {
          final response = lastMessage.content.toLowerCase();
          print('Checking LLM response for UI triggers: $response');
          
          // Check for photo/video upload triggers
          if (response.contains('photo') || response.contains('picture') || response.contains('video') || 
              response.contains('upload') || response.contains('image')) {
            print('Showing photo upload UI');
            _showPhotoUpload = true;
          }
          
          // Check for calendar/availability triggers
          if (response.contains('availability') || response.contains('schedule') || response.contains('calendar') ||
              response.contains('when') || response.contains('time') || response.contains('appointment')) {
            print('Showing calendar UI');
            _showCalendar = true;
          }
          
          // Check for summary triggers
          if (response.contains('summary') || response.contains('review') || response.contains('confirm') ||
              response.contains('all the information') || response.contains('comprehensive summary')) {
            print('Showing summary UI');
            _showSummary = true;
          }
        }
      });
      
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

  Future<void> _uploadPhoto() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );
      
      if (image != null) {
        setState(() {
          _isLoading = true;
        });
        
        final String downloadUrl = await _uploadImageToFirebase(File(image.path));
        _aiService.addMediaUrl(downloadUrl);
        
        // Add system message about photo upload
        setState(() {
          _aiService.messages.add(ChatMessage(
            content: "Photo uploaded successfully!",
            type: MessageType.system,
            timestamp: DateTime.now(),
            imageUrl: downloadUrl,
          ));
        });
        
        // Continue conversation
        await _aiService.processUserInput("I've uploaded a photo.");
        
        setState(() {
          _showPhotoUpload = false;
          _isLoading = false;
          // Check LLM response for next UI triggers
          final lastMessage = _aiService.messages.isNotEmpty ? _aiService.messages.last : null;
          if (lastMessage != null && lastMessage.type == MessageType.ai) {
            final response = lastMessage.content.toLowerCase();
            
            // Check for calendar/availability triggers
            if (response.contains('availability') || response.contains('schedule') || response.contains('calendar') ||
                response.contains('when') || response.contains('time') || response.contains('appointment')) {
              _showCalendar = true;
            }
            
            // Check for summary triggers
            if (response.contains('summary') || response.contains('review') || response.contains('confirm') ||
                response.contains('all the information') || response.contains('comprehensive summary')) {
              _showSummary = true;
            }
          }
        });
        
        _scrollToBottom();
      }
    } catch (e) {
      print('Error uploading photo: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error uploading photo: $e')),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _uploadVideo() async {
    try {
      final XFile? video = await _picker.pickVideo(
        source: ImageSource.camera,
        maxDuration: const Duration(seconds: 30),
      );
      
      if (video != null) {
        setState(() {
          _isLoading = true;
        });
        
        final String downloadUrl = await _uploadVideoToFirebase(File(video.path));
        _aiService.addMediaUrl(downloadUrl);
        
        // Add system message about video upload
        setState(() {
          _aiService.messages.add(ChatMessage(
            content: "Video uploaded successfully!",
            type: MessageType.system,
            timestamp: DateTime.now(),
            imageUrl: downloadUrl, // Using imageUrl field for video URL
          ));
        });
        
        // Continue conversation
        await _aiService.processUserInput("I've uploaded a video.");
        
        setState(() {
          _showPhotoUpload = false;
          _isLoading = false;
          // Check LLM response for next UI triggers
          final lastMessage = _aiService.messages.isNotEmpty ? _aiService.messages.last : null;
          if (lastMessage != null && lastMessage.type == MessageType.ai) {
            final response = lastMessage.content.toLowerCase();
            
            // Check for calendar/availability triggers
            if (response.contains('availability') || response.contains('schedule') || response.contains('calendar') ||
                response.contains('when') || response.contains('time') || response.contains('appointment')) {
              _showCalendar = true;
            }
            
            // Check for summary triggers
            if (response.contains('summary') || response.contains('review') || response.contains('confirm') ||
                response.contains('all the information') || response.contains('comprehensive summary')) {
              _showSummary = true;
            }
          }
        });
        
        _scrollToBottom();
      }
    } catch (e) {
      print('Error uploading video: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error uploading video: $e')),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<String> _uploadImageToFirebase(File imageFile) async {
    try {
      // Check if user is authenticated
      if (widget.user?.uid == null) {
        throw Exception('User not authenticated. Please sign in again.');
      }
      
      print('User ID: ${widget.user!.uid}');
      print('User email: ${widget.user!.email}');
      print('User display name: ${widget.user!.displayName}');
      
      // Check if user is still authenticated with Firebase
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('Firebase authentication lost. Please sign in again.');
      }
      
      print('Current Firebase user: ${currentUser.uid}');
      print('Firebase Storage bucket: ${FirebaseStorage.instance.app.options.storageBucket}');
      
      final String fileName = 'service_attachment_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final String uploadPath = 'service_attachments/${widget.user!.uid}/$fileName';
      
      print('Upload path: $uploadPath');
      print('File size: ${await imageFile.length()} bytes');
      
      final Reference ref = FirebaseStorage.instance.ref().child(uploadPath);
      
      // Add metadata for better security
      final UploadTask uploadTask = ref.putFile(
        imageFile,
        SettableMetadata(
          contentType: 'image/jpeg',
          customMetadata: {
            'uploadedBy': widget.user!.uid,
            'uploadedAt': DateTime.now().toIso8601String(),
            'fileType': 'service_attachment',
          },
        ),
      );
      
      final TaskSnapshot snapshot = await uploadTask;
      final String downloadUrl = await snapshot.ref.getDownloadURL();
      
      print('Image uploaded successfully: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      print('Error uploading image to Firebase: $e');
      if (e.toString().contains('unauthorized')) {
        throw Exception('Upload failed: Please make sure you are signed in and try again. Error: $e');
      }
      rethrow;
    }
  }

  Future<String> _uploadVideoToFirebase(File videoFile) async {
    try {
      // Check if user is authenticated
      if (widget.user?.uid == null) {
        throw Exception('User not authenticated. Please sign in again.');
      }
      
      print('User ID: ${widget.user!.uid}');
      print('User email: ${widget.user!.email}');
      print('User display name: ${widget.user!.displayName}');
      
      // Check if user is still authenticated with Firebase
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('Firebase authentication lost. Please sign in again.');
      }
      
      final String fileName = 'service_video_${DateTime.now().millisecondsSinceEpoch}.mp4';
      final String uploadPath = 'service_attachments/${widget.user!.uid}/$fileName';
      
      print('Upload path: $uploadPath');
      print('File size: ${await videoFile.length()} bytes');
      
      final Reference ref = FirebaseStorage.instance.ref().child(uploadPath);
      
      // Add metadata for better security
      final UploadTask uploadTask = ref.putFile(
        videoFile,
        SettableMetadata(
          contentType: 'video/mp4',
          customMetadata: {
            'uploadedBy': widget.user!.uid,
            'uploadedAt': DateTime.now().toIso8601String(),
            'fileType': 'service_video',
            'maxDuration': '30',
          },
        ),
      );
      
      final TaskSnapshot snapshot = await uploadTask;
      final String downloadUrl = await snapshot.ref.getDownloadURL();
      
      print('Video uploaded successfully: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      print('Error uploading video to Firebase: $e');
      if (e.toString().contains('unauthorized')) {
        throw Exception('Upload failed: Please make sure you are signed in and try again. Error: $e');
      }
      rethrow;
    }
  }

  Future<void> _skipMediaUpload() async {
    try {
      setState(() {
        _isLoading = true;
      });
      
      // Add system message about skipping media upload
      setState(() {
        _aiService.messages.add(ChatMessage(
          content: "Media upload skipped. Continuing with text description only.",
          type: MessageType.system,
          timestamp: DateTime.now(),
        ));
      });
      
      // Continue conversation
      await _aiService.processUserInput("I'll skip the photo/video for now.");
      
      setState(() {
        _showPhotoUpload = false;
        _isLoading = false;
        // Check LLM response for next UI triggers
        final lastMessage = _aiService.messages.isNotEmpty ? _aiService.messages.last : null;
        if (lastMessage != null && lastMessage.type == MessageType.ai) {
          final response = lastMessage.content.toLowerCase();
          
          // Check for calendar/availability triggers
          if (response.contains('availability') || response.contains('schedule') || response.contains('calendar') ||
              response.contains('when') || response.contains('time') || response.contains('appointment')) {
            _showCalendar = true;
          }
          
          // Check for summary triggers
          if (response.contains('summary') || response.contains('review') || response.contains('confirm') ||
              response.contains('all the information') || response.contains('comprehensive summary')) {
            _showSummary = true;
          }
        }
      });
      
      _scrollToBottom();
    } catch (e) {
      print('Error skipping media upload: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _selectAvailability() async {
    // Convert time slots to a more readable format
    final timeSlotDetails = _selectedTimeSlots.entries.map((entry) {
      final date = entry.key;
      final slots = entry.value;
      return {
        'date': date.toIso8601String(),
        'timeSlots': slots,
        'formattedDate': _formatDate(date),
      };
    }).toList();
    
    final availabilityData = {
      'selectedDates': _selectedDates.map((date) => date.toIso8601String()).toList(),
      'timeSlots': timeSlotDetails,
      'preferredTime': _selectedTimeSlots.isNotEmpty ? 'specific' : 'flexible',
      'notes': _selectedTimeSlots.isNotEmpty 
          ? 'Available on selected dates with specific time preferences'
          : 'Available on selected dates with flexible timing',
    };
    
    _aiService.setAvailability(availabilityData);
    
    setState(() {
      _isLoading = true;
      _showCalendar = false;
    });
    
    try {
      // Continue conversation with availability info
      await _aiService.processUserInput("I've selected my availability.");
      
      setState(() {
        _isLoading = false;
        // Check LLM response for summary triggers
        final lastMessage = _aiService.messages.isNotEmpty ? _aiService.messages.last : null;
        if (lastMessage != null && lastMessage.type == MessageType.ai) {
          final response = lastMessage.content.toLowerCase();
          
          // Check for summary triggers
          if (response.contains('summary') || response.contains('review') || response.contains('confirm') ||
              response.contains('all the information') || response.contains('comprehensive summary')) {
            _showSummary = true;
          }
        }
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
      
      final summary = await _aiService.generateServiceRequestSummary();
      
      // Create service request in Firestore
      await FirebaseFirestore.instance.collection('service_requests').add({
        'user_id': widget.user?.uid ?? 'anonymous',
        'description': summary['description'],
        'details': summary['details'],
        'category': summary['category'],
        'service_type': summary['serviceType'],
        'tags': summary['tags'],
        'media_urls': summary['mediaUrls'],
        'availability': summary['availability'],
        'price_estimate': summary['priceEstimate'],
        'priority': summary['priority'],
        'status': 'pending',
        'created_at': FieldValue.serverTimestamp(),
        'location_masked': 'User location', // Will be updated with actual location
        'customer_name': widget.user?.displayName ?? 'Anonymous User',
        'customer_photo_url': widget.user?.photoURL,
      });
      
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Service request submitted successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      
      // Clear conversation cache after successful submission
      _aiService.clearConversation();
      
      // Close the screen
      Navigator.pop(context);
      
    } catch (e) {
      print('Error submitting service request: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error submitting request: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // Dismiss calendar and other UI elements when tapping outside
        if (_showCalendar || _showPhotoUpload || _showSummary) {
          setState(() {
            _showCalendar = false;
            _showPhotoUpload = false;
            _showSummary = false;
          });
        }
        // Unfocus text field
        FocusScope.of(context).unfocus();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFFBB04C),
        resizeToAvoidBottomInset: false,
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
              _aiService.clearConversation();
              _aiService.startConversation();
              setState(() {
                _showPhotoUpload = false;
                _showCalendar = false;
                _showSummary = false;
                _isListening = false;
                _selectedDates.clear();
                _selectedTimeSlots.clear();
              });
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Chat messages and special UI elements in scrollable area
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Chat messages
                    ...List.generate(_aiService.messages.length + (_isTyping ? 1 : 0), (index) {
                      if (_isTyping && index == _aiService.messages.length) {
                        return _buildTypingIndicator();
                      }
                      
                      final message = _aiService.messages[index];
                      return _buildMessageBubble(message);
                    }),
                    
                    // Special UI elements
                    if (_showPhotoUpload) _buildPhotoUploadSection(),
                    if (_showCalendar) _buildCalendarSection(),
                    if (_showSummary) _buildSummarySection(),
                    
                    // Add extra bottom padding to ensure content doesn't get hidden behind input area
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
            
            // Input area - always at the bottom
            _buildInputArea(),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    final isUser = message.type == MessageType.user;
    final isSystem = message.type == MessageType.system;
    
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
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isUser 
                    ? Colors.white.withOpacity(0.9)
                    : isSystem 
                        ? Colors.green.withOpacity(0.8)
                        : Colors.white.withOpacity(0.95),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (message.imageUrl != null) ...[
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
                    const SizedBox(height: 8),
                  ],
                  Text(
                    message.content,
                    style: TextStyle(
                      fontSize: 16,
                      color: isUser ? Colors.black87 : Colors.black,
                      fontWeight: isSystem ? FontWeight.w600 : FontWeight.normal,
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
    return GestureDetector(
      onTap: () {
        // Prevent photo upload section from being dismissed when tapping on it
      },
      child: Container(
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
            'Upload Photo or Video',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Take a photo or record a short video (under 30 seconds) to help service providers understand your needs better.',
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
                  onPressed: _isLoading ? null : _uploadPhoto,
                  icon: _isLoading 
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.camera_alt),
                  label: Text(_isLoading ? 'Uploading...' : 'Take Photo'),
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
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _uploadVideo,
                  icon: _isLoading 
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.videocam),
                  label: Text(_isLoading ? 'Uploading...' : 'Record Video'),
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
            ],
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: _isLoading ? null : _skipMediaUpload,
            child: const Text(
              'Skip for now',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildCalendarSection() {
    return GestureDetector(
      onTap: () {
        // Prevent calendar from being dismissed when tapping on it
      },
      child: Container(
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
            'What is your availability?',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
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
          const SizedBox(height: 16),
          
          // Time selection section
          if (_selectedDates.isNotEmpty) ...[
            const Text(
              'Select preferred time slots:',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            
            // Time slots for each selected date
            ..._selectedDates.map((date) => _buildTimeSlotSelector(date)),
            
            const SizedBox(height: 16),
          ],
          
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
            child: Text(_selectedTimeSlots.isNotEmpty 
                ? 'Continue (${_selectedDates.length} days, ${_selectedTimeSlots.values.expand((slots) => slots).length} time slots)'
                : 'Continue (${_selectedDates.length} days selected)'),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildTimeSlotSelector(DateTime date) {
    final dateKey = DateTime(date.year, date.month, date.day);
    final selectedSlots = _selectedTimeSlots[dateKey] ?? [];
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${_formatDate(date)}:',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: _availableTimeSlots.map((timeSlot) {
              final isSelected = selectedSlots.contains(timeSlot);
              return GestureDetector(
                onTap: () {
                  setState(() {
                    if (isSelected) {
                      selectedSlots.remove(timeSlot);
                    } else {
                      selectedSlots.add(timeSlot);
                    }
                    _selectedTimeSlots[dateKey] = List.from(selectedSlots);
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected 
                        ? const Color(0xFFFBB04C) 
                        : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected 
                          ? const Color(0xFFFBB04C) 
                          : Colors.grey[300]!,
                    ),
                  ),
                  child: Text(
                    timeSlot,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final dateOnly = DateTime(date.year, date.month, date.day);
    
    if (dateOnly == today) {
      return 'Today';
    } else if (dateOnly == tomorrow) {
      return 'Tomorrow';
    } else {
      return '${date.month}/${date.day}/${date.year}';
    }
  }

  Widget _buildSummarySection() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _aiService.generateServiceRequestSummary(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
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
            child: const Column(
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Analyzing service request and generating price estimate...'),
              ],
            ),
          );
        }
        
        if (snapshot.hasError) {
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
              children: [
                const Icon(Icons.error, color: Colors.red, size: 48),
                const SizedBox(height: 16),
                const Text('Error generating summary'),
                const SizedBox(height: 8),
                Text('${snapshot.error}'),
              ],
            ),
          );
        }
        
        final summary = snapshot.data!;
        final priceEstimate = summary['priceEstimate'] as Map<String, dynamic>;
    
    return GestureDetector(
      onTap: () {
        // Prevent summary section from being dismissed when tapping on it
      },
      child: Container(
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
            'Thank you for the information. Here\'s a summary of your request.',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          
          // Problem Summary
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Problem Summary',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  summary['description'] ?? 'No description provided',
                  style: const TextStyle(fontSize: 14),
                ),
                if (summary['details'] != null && summary['details'].isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    summary['details'],
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Tags
          if (summary['tags'] != null && (summary['tags'] as List).isNotEmpty) ...[
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: (summary['tags'] as List<String>).map((tag) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFBB04C).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    tag,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFFBB04C),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
          ],
          
          // Images
          if (summary['mediaUrls'] != null && (summary['mediaUrls'] as List).isNotEmpty) ...[
            const Text(
              'Images',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 80,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: (summary['mediaUrls'] as List).length,
                itemBuilder: (context, index) {
                  final url = (summary['mediaUrls'] as List)[index];
                  return Container(
                    margin: const EdgeInsets.only(right: 8),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        url,
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: 80,
                            height: 80,
                            color: Colors.grey[300],
                            child: const Icon(Icons.image_not_supported),
                          );
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
          ],
          
          // Estimated Price
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'AI-Generated Price Estimate',
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
                Text(
                  'Average: \$${priceEstimate['average']}',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
                if (priceEstimate['reasoning'] != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Analysis: ${priceEstimate['reasoning']}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
                if (priceEstimate['factors'] != null) ...[
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 4,
                    runSpacing: 2,
                    children: (priceEstimate['factors'] as List<String>).map((factor) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          factor,
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.green,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
                if (priceEstimate['confidence'] != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Confidence: ${(priceEstimate['confidence'] * 100).round()}%',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          const Text(
            'Is there anything you\'d like to correct in the summary? You can click next if everything looks correct.',
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
                : const Text(
                    'Submit Request',
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
      },
    );
  }

  Widget _buildInputArea() {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;
    final isKeyboardVisible = bottomPadding > 0;
    
    return Container(
      padding: EdgeInsets.fromLTRB(
        16, 
        12, 
        16, 
        isKeyboardVisible ? bottomPadding + 12 : 16,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
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
              minLines: 1,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendMessage(),
              onTap: () {
                // Dismiss calendar and other UI elements when user starts typing
                setState(() {
                  _showCalendar = false;
                  _showPhotoUpload = false;
                  _showSummary = false;
                });
                
                // Scroll to bottom when keyboard appears
                Future.delayed(const Duration(milliseconds: 300), () {
                  _scrollToBottom();
                });
              },
              onChanged: (value) {
                // Dismiss calendar and other UI elements when user starts typing
                if (value.isNotEmpty && (_showCalendar || _showPhotoUpload || _showSummary)) {
                  setState(() {
                    _showCalendar = false;
                    _showPhotoUpload = false;
                    _showSummary = false;
                  });
                }
              },
              onEditingComplete: () {
                // Dismiss calendar and other UI elements when user finishes editing
                setState(() {
                  _showCalendar = false;
                  _showPhotoUpload = false;
                  _showSummary = false;
                });
              },
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _isLoading ? null : (_messageController.text.trim().isNotEmpty ? _sendMessage : _startListening),
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
} 