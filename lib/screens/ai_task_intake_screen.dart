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
  bool _showLocationForm = false;
  bool _showContactForm = false;
  bool _showSummary = false;
  bool _isListening = false;
  bool _speechEnabled = false;
  DateTime _selectedDate = DateTime.now();
  
  // Form controllers to persist data
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _zipcodeController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _stateController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  List<DateTime> _selectedDates = [];

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _initializeSpeech();
    _aiService.startConversation();
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
    _emailController.dispose();
    super.dispose();
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
    if (!_speechEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Speech recognition not available')),
      );
      return;
    }

    if (_isListening) {
      _stopListening();
      return;
    }

    try {
      await _speech.listen(
        onResult: (val) {
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error starting speech recognition: $e')),
      );
    }
  }

  Future<void> _stopListening() async {
    await _speech.stop();
    setState(() {
      _isListening = false;
    });
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
        _showLocationForm = false;
        _showContactForm = false;
        _showSummary = false;
        
        // Check if we need to show special UI elements based on new 8-step flow
        if (_aiService.currentState.conversationStep == 3) {
          _showPhotoUpload = true;
        } else if (_aiService.currentState.conversationStep == 4) {
          _showCalendar = true;
          print('🗓️ Calendar UI should be shown now - Step 4 (Calendar Requested: ${_aiService.currentState.calendarRequested})');
        } else if (_aiService.currentState.conversationStep == 5 && _aiService.currentState.availabilitySet) {
          // Only show location form if availability is actually set
          _showLocationForm = true;
          _showCalendar = false; // Hide calendar when moving to location
          print('📍 Location Form UI should be shown now - Step 5 (Availability Set: ${_aiService.currentState.availabilitySet})');
        } else if (_aiService.currentState.conversationStep == 6 && _aiService.currentState.locationFormCompleted) {
          // Only show contact form if location form is completed
          _showContactForm = true;
          _showLocationForm = false; // Hide location form
          print('📞 Contact Form UI should be shown now - Step 6 (Location Completed: ${_aiService.currentState.locationFormCompleted})');
        } else if (_aiService.currentState.conversationStep >= 8) {
          _showSummary = true;
          print('📋 Summary UI should be shown now - Step 8+');
        }
        
        // CRITICAL: Force calendar to show at step 4, prevent immediate advancement
        if (_aiService.currentState.conversationStep == 4 && !_aiService.currentState.availabilitySet) {
          _showCalendar = true;
          _showLocationForm = false; // Ensure no conflict
          _showContactForm = false;
          print('🔄 FORCE: Calendar UI enabled - Step 4 (Availability NOT set yet)');
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

  Future<void> _uploadPhotos() async {
    try {
      // Show photo source selection dialog
      final ImageSource? source = await showDialog<ImageSource>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Add Photos'),
            content: const Text('How would you like to add photos?'),
            actions: [
              TextButton.icon(
                onPressed: () => Navigator.pop(context, ImageSource.camera),
                icon: const Icon(Icons.camera_alt),
                label: const Text('Take Photo'),
              ),
              TextButton.icon(
                onPressed: () => Navigator.pop(context, ImageSource.gallery),
                icon: const Icon(Icons.photo_library),
                label: const Text('Choose from Gallery'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ],
          );
        },
      );

      if (source == null) return;

      setState(() {
        _isLoading = true;
      });

      XFile? image;
      
      image = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );

      if (image != null) {
        try {
          final String downloadUrl = await _uploadImageToFirebase(File(image.path));
          _aiService.onPhotoUploaded(downloadUrl);
          
          // Add system message
          setState(() {
            _aiService.messages.add(ChatMessage(
              content: "Photo uploaded successfully!",
              type: MessageType.system,
              timestamp: DateTime.now(),
              imageUrl: downloadUrl,
            ));
          });

          _scrollToBottom();

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Photo uploaded successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        } catch (e) {
          print('Error uploading photo: $e');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error uploading photo: $e')),
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
    final availabilityData = {
      'date': _selectedDate.toIso8601String(),
      'preference': 'Selected date: ${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
      'timestamp': DateTime.now().toIso8601String(),
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
      // Continue conversation with availability info
      await _aiService.processUserInput("I've selected my availability.");
      
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
      
      // Create UserRequest object according to new schema
      final userRequest = {
        'userId': widget.user?.uid ?? 'anonymous',
        'serviceCategory': _aiService.currentState.serviceCategory ?? 'General Service',
        'description': _aiService.currentState.description ?? '',
        'mediaUrls': _aiService.currentState.mediaUrls,
        'tags': _aiService.currentState.tags,
        'address': _aiService.currentState.address ?? '',
        'phoneNumber': _aiService.currentState.phoneNumber ?? '',
        'location': _aiService.currentState.location,
        'userAvailability': _aiService.currentState.userAvailability ?? {},
        'preferences': _aiService.currentState.preferences,
        'priority': _aiService.currentState.priority ?? 3,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'pending',
        // Additional fields for backward compatibility
        'customer_name': widget.user?.displayName ?? 'Anonymous User',
        'customer_photo_url': widget.user?.photoURL,
        'service_answers': _aiService.currentState.serviceAnswers,
        'price_estimate': _aiService.currentState.priceEstimate,
      };
      
      // Store in Firebase using the new schema
      await FirebaseFirestore.instance.collection('user_requests').add(userRequest);
      
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Service request submitted successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      
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
      body: Column(
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
              child: Text(
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
          const Text(
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
                  label: Text(_isLoading ? 'Uploading...' : 
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
                    await _aiService.processUserInput("I'm done uploading photos.");
                    
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
            child: Text('Continue (${_selectedDates.length} days selected)'),
          ),
        ],
      ),
    );
  }

  Widget _buildSummarySection() {
    final state = _aiService.currentState;
    final priceEstimate = state.priceEstimate ?? {'min': 100, 'max': 500};
    
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
            'Service Request Summary',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          
          // Service Information
          _buildSummaryItem('Service Type', state.serviceCategory ?? 'General Service'),
          _buildSummaryItem('Description', state.description ?? 'No description provided'),
          
          // Service Details
          if (state.serviceAnswers.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text('Service Details:', style: TextStyle(fontWeight: FontWeight.bold)),
            ...state.serviceAnswers.entries.map((entry) => 
              Padding(
                padding: const EdgeInsets.only(left: 16, top: 4),
                child: Text('• ${entry.value}', style: const TextStyle(fontSize: 14)),
              ),
            ),
          ],
          
          // Media
          if (state.mediaUrls.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('Photos/Videos: ${state.mediaUrls.length} uploaded', 
                 style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
          
          // Availability
          if (state.userAvailability != null) ...[
            const SizedBox(height: 12),
            _buildSummaryItem('Availability', state.userAvailability!['preference']?.toString() ?? 'Not specified'),
          ],
          
          // Location
          if (state.address != null && state.address!.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildSummaryItem('Service Address', state.address!),
          ],
          
          // Contact Information
          if (state.phoneNumber != null && state.phoneNumber!.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildSummaryItem('Phone Number', state.phoneNumber!),
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
                const Text(
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
                : const Text(
                    'Submit Service Request',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildSummaryItem(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
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
  
  Widget _buildLocationFormSection() {
    // Use persistent form controllers
    
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
            child: const Text(
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
    // Use persistent form controllers
    
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
          const SizedBox(height: 12),
          
          // Email Field
          TextField(
            controller: _emailController,
            decoration: const InputDecoration(
              labelText: 'Email Address *',
              hintText: 'your.email@example.com',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.email),
            ),
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 20),
          
          // Submit Button
          ElevatedButton(
            onPressed: () {
              // Validate required fields
              if (_phoneController.text.trim().isEmpty ||
                  _emailController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please fill in all required fields'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              
              // Basic email validation
              if (!_emailController.text.contains('@') || !_emailController.text.contains('.')) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter a valid email address'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              
              // Submit contact data
              final contactData = {
                'tel': _phoneController.text.trim(),
                'email': _emailController.text.trim(),
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
} 