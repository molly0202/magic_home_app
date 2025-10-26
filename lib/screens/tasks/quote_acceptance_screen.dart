import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/service_bid.dart';
import '../../services/user_task_service.dart';
import '../../widgets/translatable_text.dart';

class QuoteAcceptanceScreen extends StatefulWidget {
  final ServiceBid bid;
  final String userId;

  const QuoteAcceptanceScreen({
    super.key,
    required this.bid,
    required this.userId,
  });

  @override
  State<QuoteAcceptanceScreen> createState() => _QuoteAcceptanceScreenState();
}

class _QuoteAcceptanceScreenState extends State<QuoteAcceptanceScreen> {
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  final TextEditingController _customTimeController = TextEditingController();
  bool _isAccepting = false;
  String _selectedTimeOption = 'tomorrow_4pm'; // Default option
  String _providerName = 'Provider';

  @override
  void initState() {
    super.initState();
    _loadProviderName();
  }

  Future<void> _loadProviderName() async {
    try {
      final providerDoc = await FirebaseFirestore.instance
          .collection('providers')
          .doc(widget.bid.providerId)
          .get();
      
      if (providerDoc.exists) {
        final data = providerDoc.data() as Map<String, dynamic>;
        setState(() {
          _providerName = data['companyName'] ?? data['name'] ?? 'Provider';
        });
      }
    } catch (e) {
      print('Error loading provider name: $e');
    }
  }

  @override
  void dispose() {
    _customTimeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Accept Quote'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Quote summary card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.green[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green[600], size: 24),
                      const SizedBox(width: 8),
                      const Text(
                        'Quote Details',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Provider info
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: Colors.grey[300],
                        child: const Icon(Icons.business, color: Colors.grey),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _providerName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              'Professional Service Provider',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Price and availability
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: Column(
                            children: [
                              Text(
                                '\$${widget.bid.priceQuote.toInt()}',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                              const Text(
                                'Total Quote',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: Column(
                            children: [
                              const Icon(Icons.schedule, color: Colors.blue, size: 24),
                              const SizedBox(height: 4),
                              Text(
                                widget.bid.availability ?? 'Available',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.blue,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  // Bid message if available
                  if (widget.bid.bidMessage.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Provider Message:',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.bid.bidMessage,
                            style: TextStyle(color: Colors.grey[700]),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Service time selection
            const Text(
              'When would you like the service?',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Choose a convenient time for the provider to complete your service.',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 24),
            
            // Quick time options
            _buildQuickTimeOptions(),
            
            const SizedBox(height: 24),
            
            // Calendar selection
            _buildCalendarSelection(),
            
            const SizedBox(height: 24),
            
            // Custom time input
            _buildCustomTimeInput(),
            
            const SizedBox(height: 40),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Summary
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.blue),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'By accepting this quote, all other bids will be rejected and $_providerName will be notified to start the job.',
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: const BorderSide(color: Colors.grey),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _isAccepting ? null : _acceptQuote,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isAccepting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'Accept Quote',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickTimeOptions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Options:',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildTimeOption(
                'tomorrow_4pm',
                '10/26',
                '4:00 PM',
                'Tomorrow afternoon',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildTimeOption(
                'weekend',
                'Weekend',
                'Flexible',
                'This weekend',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTimeOption(String value, String date, String time, String description) {
    final isSelected = _selectedTimeOption == value;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTimeOption = value;
          _selectedDate = null;
          _selectedTime = null;
          _customTimeController.clear();
        });
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFBB04C).withOpacity(0.1) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFFFBB04C) : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Text(
              date,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isSelected ? const Color(0xFFFBB04C) : Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              time,
              style: TextStyle(
                fontSize: 14,
                color: isSelected ? const Color(0xFFFBB04C) : Colors.grey[600],
              ),
            ),
            const SizedBox(height: 2),
            Text(
              description,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Checkbox(
              value: _selectedTimeOption == 'calendar',
              onChanged: (value) {
                if (value == true) {
                  setState(() {
                    _selectedTimeOption = 'calendar';
                    _customTimeController.clear();
                  });
                }
              },
              activeColor: const Color(0xFFFBB04C),
            ),
            const Text(
              'Choose specific date & time',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        
        if (_selectedTimeOption == 'calendar') ...[
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: TableCalendar<void>(
              firstDay: DateTime.now(),
              lastDay: DateTime.now().add(const Duration(days: 30)),
              focusedDay: _selectedDate ?? DateTime.now().add(const Duration(days: 1)),
              calendarFormat: CalendarFormat.month,
              selectedDayPredicate: (day) {
                return _selectedDate != null && isSameDay(_selectedDate!, day);
              },
              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  _selectedDate = selectedDay;
                });
              },
              calendarStyle: CalendarStyle(
                outsideDaysVisible: false,
                selectedDecoration: const BoxDecoration(
                  color: Color(0xFFFBB04C),
                  shape: BoxShape.circle,
                ),
                todayDecoration: BoxDecoration(
                  color: Colors.grey[400],
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Time picker
          if (_selectedDate != null)
            GestureDetector(
              onTap: _pickTime,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFBB04C)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.access_time, color: Colors.grey[600]),
                    const SizedBox(width: 12),
                    Text(
                      _selectedTime != null
                          ? 'Time: ${_selectedTime!.format(context)}'
                          : 'Tap to select time',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    Icon(Icons.arrow_forward_ios, color: Colors.grey[400], size: 16),
                  ],
                ),
              ),
            ),
        ],
      ],
    );
  }

  Widget _buildCustomTimeInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Checkbox(
              value: _selectedTimeOption == 'custom',
              onChanged: (value) {
                if (value == true) {
                  setState(() {
                    _selectedTimeOption = 'custom';
                    _selectedDate = null;
                    _selectedTime = null;
                  });
                }
              },
              activeColor: const Color(0xFFFBB04C),
            ),
            const Text(
              'Enter custom time',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        
        if (_selectedTimeOption == 'custom') ...[
          const SizedBox(height: 16),
          TextField(
            controller: _customTimeController,
            decoration: InputDecoration(
              labelText: 'When would you like the service?',
              hintText: 'e.g., "Tomorrow at 2 PM", "This weekend morning", "Next week"',
              border: const OutlineInputBorder(),
              filled: true,
              fillColor: Colors.grey[50],
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 8),
          Text(
            'Examples: "Tomorrow at 2 PM", "This weekend morning", "Next Monday after 10 AM"',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _pickTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? const TimeOfDay(hour: 14, minute: 0),
    );
    
    if (picked != null) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  String _getSelectedTimeText() {
    switch (_selectedTimeOption) {
      case 'tomorrow_4pm':
        final tomorrow = DateTime.now().add(const Duration(days: 1));
        final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 
                       'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
        return '${months[tomorrow.month - 1]} ${tomorrow.day} at 4:00 PM';
      
      case 'weekend':
        return 'This weekend (flexible time)';
      
      case 'calendar':
        if (_selectedDate != null) {
          final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 
                         'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
          final dateStr = '${months[_selectedDate!.month - 1]} ${_selectedDate!.day}';
          final timeStr = _selectedTime?.format(context) ?? 'flexible time';
          return '$dateStr at $timeStr';
        }
        return 'Please select date and time';
      
      case 'custom':
        return _customTimeController.text.trim();
      
      default:
        return '';
    }
  }

  Future<void> _acceptQuote() async {
    final timeText = _getSelectedTimeText();
    
    if (timeText.isEmpty || timeText == 'Please select date and time') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a service time'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isAccepting = true;
    });

    try {
      print('🗓️ Accepting quote with service time: $timeText');

      // Accept bid with service time text
      final success = await UserTaskService.acceptBidWithScheduleText(
        widget.bid.bidId!,
        widget.userId,
        timeText,
      );
      
      if (success && mounted) {
        // Show success and navigate back
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Quote accepted! Service scheduled for $timeText'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
        
        // Navigate back to previous screen
        Navigator.pop(context, true); // Return true to indicate success
        
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to accept quote. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isAccepting = false;
        });
      }
    }
  }
}
