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
  DateTime _selectedDate = DateTime.now();
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
        _showSummary = false;
        
        // Check if we need to show special UI elements based on new 8-step flow
        if (_aiService.currentState.conversationStep == 3 || _aiService.currentState.conversationStep == 4) {
          _showPhotoUpload = true;
        } else if (_aiService.currentState.conversationStep == 5) {
          _showCalendar = true;
        } else if (_aiService.currentState.conversationStep == 8 || _aiService.currentState.conversationStep == 9) {
          _showSummary = true;
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
        _aiService.onPhotoUploaded(downloadUrl);
        
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
          // Check if we need to show next step based on 8-step flow
          if (_aiService.currentState.conversationStep == 4) {
            // After photo upload, move to step 5 (availability)
            _showCalendar = true;
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

  Future<String> _uploadImageToFirebase(File imageFile) async {
    try {
      final String fileName = 'service_attachment_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final Reference ref = FirebaseStorage.instance
          .ref()
          .child('service_attachments')
          .child(widget.user?.uid ?? 'anonymous')
          .child(fileName);
      
      final UploadTask uploadTask = ref.putFile(imageFile);
      final TaskSnapshot snapshot = await uploadTask;
      final String downloadUrl = await snapshot.ref.getDownloadURL();
      
      return downloadUrl;
    } catch (e) {
      print('Error uploading image to Firebase: $e');
      rethrow;
    }
  }

  Future<void> _selectAvailability() async {
    final availabilityData = {
      'selectedDates': _selectedDates.map((date) => date.toIso8601String()).toList(),
      'preferredTime': 'flexible',
      'notes': 'Available on selected dates',
    };
    
    _aiService.onAvailabilitySelected(availabilityData);
    
    setState(() {
      _isLoading = true;
      _showCalendar = false;
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
                return _buildMessageBubble(message);
              },
            ),
          ),
          
          // Special UI elements
          if (_showPhotoUpload) _buildPhotoUploadSection(),
          if (_showCalendar) _buildCalendarSection(),
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
            'Upload Photo',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Take a photo to help service providers understand your needs better.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _isLoading ? null : _uploadPhoto,
            icon: _isLoading 
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.camera_alt),
            label: Text(_isLoading ? 'Uploading...' : 'Upload Photo'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFBB04C),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
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
} 