import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/user_request.dart';
import '../../models/service_bid.dart';
import '../../services/user_task_service.dart';
import '../../widgets/translatable_text.dart';
import 'quote_acceptance_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../providers/exact_provider_profile_screen.dart';

class ServiceQuotesScreen extends StatefulWidget {
  final UserRequest task;
  final User user;

  const ServiceQuotesScreen({
    Key? key,
    required this.task,
    required this.user,
  }) : super(key: key);

  @override
  State<ServiceQuotesScreen> createState() => _ServiceQuotesScreenState();
}

class _ServiceQuotesScreenState extends State<ServiceQuotesScreen> {
  bool _isAcceptingBid = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const TranslatableText(
          'Service Quotes',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Price Range Estimation
            _buildPriceRangeCard(),

            // Quotes List
            _buildQuotesSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceRangeCard() {
    if (widget.task.aiPriceEstimation == null) {
      return const SizedBox.shrink();
    }

    final estimation = widget.task.aiPriceEstimation!;
    final suggestedRange = estimation['suggestedRange'];
    
    if (suggestedRange == null) {
      return const SizedBox.shrink();
    }

    final minPrice = (suggestedRange['min'] ?? 0).toDouble();
    final maxPrice = (suggestedRange['max'] ?? 0).toDouble();
    final marketAverage = (estimation['marketAverage'] ?? ((minPrice + maxPrice) / 2)).toDouble();

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const TranslatableText(
            'Estimated Price Range',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFFFBB04C),
            ),
          ),
          const SizedBox(height: 20),
          
          // Price range visualization
          Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    // Price range bar
                    Container(
                      height: 8,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        gradient: const LinearGradient(
                          colors: [
                            Colors.green,
                            Color(0xFFFBB04C),
                            Colors.red,
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    // Price labels
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '\$${minPrice.toInt()}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                        Column(
                          children: [
                            const Icon(
                              Icons.keyboard_arrow_up,
                              color: Color(0xFFFBB04C),
                              size: 20,
                            ),
                            Text(
                              '\$${marketAverage.toInt()}',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFFBB04C),
                              ),
                            ),
                            const TranslatableText(
                              'Market Average',
                              style: TextStyle(
                                fontSize: 10,
                                color: Color(0xFFFBB04C),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '\$${maxPrice.toInt()}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuotesSection() {
    print('🔍 SERVICE_QUOTES: Loading bids for requestId: ${widget.task.requestId}');
    return StreamBuilder<List<ServiceBid>>(
      stream: UserTaskService.getBidsForRequest(widget.task.requestId ?? ''),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            margin: const EdgeInsets.all(16),
            child: const Center(
              child: CircularProgressIndicator(
                color: Color(0xFFFBB04C),
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          print('❌ SERVICE_QUOTES: Error loading bids: ${snapshot.error}');
          return Container(
            margin: const EdgeInsets.all(16),
            child: Center(
              child: Column(
                children: [
                  Text(
                    'Error loading quotes',
                    style: TextStyle(
                      color: Colors.red[600],
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'RequestID: ${widget.task.requestId}',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    'Error: ${snapshot.error}',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final bids = snapshot.data ?? [];

        if (bids.isEmpty) {
          return Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.hourglass_empty,
                    size: 48,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  TranslatableText(
                    'Waiting for Quotes',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Providers are reviewing your request and will submit quotes soon.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return Column(
          children: bids.map((bid) => _buildQuoteCard(bid)).toList(),
        );
      },
    );
  }

  Widget _buildQuoteCard(ServiceBid bid) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: UserTaskService.getProviderDetails(bid.providerId),
      builder: (context, providerSnapshot) {
        final provider = providerSnapshot.data;
        final companyName = provider?['company'] ?? provider?['companyName'] ?? 'Provider';
        final reviewCount = provider?['thumbs_up_count'] ?? 12;
        final distance = '5 miles away'; // This would come from location calculation

        // Calculate match percentage (this would be more sophisticated in real app)
        final matchPercentage = _calculateMatchPercentage(bid, provider);
        
        // Determine price benchmark
        final priceBenchmark = _getPriceBenchmark(bid.priceQuote);

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: bid.bidStatus == 'accepted' 
                ? Border.all(color: Colors.green, width: 2)
                : null,
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              // Provider header with match percentage
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: bid.bidStatus == 'accepted' 
                      ? Colors.green.withOpacity(0.1)
                      : Colors.grey[50],
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                ),
                child: Row(
                  children: [
                    // Provider avatar
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFBB04C),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Center(
                        child: Text(
                          companyName.substring(0, 1).toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    
                    // Provider info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            companyName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          TranslatableText(
                            '$distance • $reviewCount reviews',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Match percentage
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$matchPercentage%',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const TranslatableText(
                            'Excellent Match',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              // Quote details
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Price and benchmark
                    Row(
                      children: [
                        // Show consultation type or price
                        if (_isConsultationBid(bid)) ...[
                          // Show consultation type instead of price
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    bid.bidMessage.contains('PHONE_CONSULTATION') ? Icons.phone : Icons.location_on,
                                    color: Colors.blue,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      bid.bidMessage.contains('PHONE_CONSULTATION') 
                                          ? 'Need Phone Consultation'
                                          : 'Need In-Person Consultation',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  'Consultation Required',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ] else ...[
                          // Show price for regular quotes
                          TranslatableText(
                            'Quote',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '\$${bid.priceQuote.toInt()}',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: priceBenchmark['color'].withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: TranslatableText(
                              priceBenchmark['label'],
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: priceBenchmark['color'],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    
                    const SizedBox(height: 12),
                    
                    // Recommended by network - show actual users
                    if (provider != null) ...[
                      _buildReferralUsersSection(provider),
                      const SizedBox(height: 12),
                    ],
                    
                    // Tags
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        _buildTag('Friend Referral', Colors.blue),
                        _buildTag('Perfect Match', Colors.green),
                        _buildTag('Top Rated', const Color(0xFFFBB04C)),
                      ],
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Availability and message
                    if (bid.availability.isNotEmpty) ...[
                      TranslatableText(
                        'Availability: ${bid.availability}',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    
                    if (bid.bidMessage.isNotEmpty) ...[
                      Text(
                        bid.bidMessage,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[700],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    
                    // View Profile button (always available)
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _viewProviderProfile(bid.providerId, companyName),
                        icon: const Icon(Icons.person, size: 18),
                        label: const TranslatableText('View Provider Profile'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFFBB04C),
                          side: const BorderSide(color: Color(0xFFFBB04C)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    
                    // Action buttons based on status and bid type
                    if (bid.bidStatus == 'pending' && widget.task.status != 'assigned') ...[
                      // Check if this is a consultation bid
                      if (_isConsultationBid(bid)) ...[
                        // Call Provider button for consultations
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () => _callProvider(bid.providerId),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            icon: const Icon(Icons.phone),
                            label: const Text(
                              'Call Service Provider',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ] else ...[
                        // Accept Quote button for price quotes
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isAcceptingBid ? null : () => _navigateToQuoteAcceptance(bid),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: _isAcceptingBid
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const TranslatableText(
                                    'Accept Quote',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ] else if (bid.bidStatus == 'accepted') ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.check_circle,
                              color: Colors.green,
                              size: 20,
                            ),
                            SizedBox(width: 8),
                            TranslatableText(
                              'Quote Accepted',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TranslatableText(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  int _calculateMatchPercentage(ServiceBid bid, Map<String, dynamic>? provider) {
    // This would be a more sophisticated calculation in a real app
    // For now, return a mock percentage based on various factors
    return 98;
  }

  Map<String, dynamic> _getPriceBenchmark(double price) {
    if (widget.task.aiPriceEstimation == null) {
      return {
        'label': 'Normal',
        'color': const Color(0xFFFBB04C),
      };
    }

    final estimation = widget.task.aiPriceEstimation!;
    final suggestedRange = estimation['suggestedRange'];
    
    if (suggestedRange == null) {
      return {
        'label': 'Normal',
        'color': const Color(0xFFFBB04C),
      };
    }

    final minPrice = (suggestedRange['min'] ?? 0).toDouble();
    final maxPrice = (suggestedRange['max'] ?? 0).toDouble();

    if (price < minPrice) {
      return {
        'label': 'Lower',
        'color': Colors.green,
      };
    } else if (price > maxPrice) {
      return {
        'label': 'Higher',
        'color': Colors.red,
      };
    } else {
      return {
        'label': 'Normal',
        'color': const Color(0xFFFBB04C),
      };
    }
  }

  Future<void> _showTimeConfirmationDialog(ServiceBid bid) async {
    final TextEditingController timeController = TextEditingController();
    DateTime? selectedDate;
    TimeOfDay? selectedTime;
    
    final result = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text(
                'Confirm Service Time',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Provider availability section
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.schedule, color: Colors.blue.shade600, size: 16),
                              const SizedBox(width: 6),
                              Text(
                                'Provider Availability',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.blue.shade700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            bid.availability.isNotEmpty ? bid.availability : 'Flexible scheduling available',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.blue.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    const Text(
                      'Please confirm when you\'d like the service to be performed:',
                      style: TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 12),
                    
                    // Quick calendar selection
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final date = await showDatePicker(
                                context: context,
                                initialDate: DateTime.now().add(const Duration(days: 1)),
                                firstDate: DateTime.now(),
                                lastDate: DateTime.now().add(const Duration(days: 30)),
                              );
                              if (date != null) {
                                setDialogState(() {
                                  selectedDate = date;
                                });
                              }
                            },
                            icon: const Icon(Icons.calendar_today, size: 16),
                            label: Text(
                              selectedDate != null 
                                ? '${selectedDate!.month}/${selectedDate!.day}'
                                : 'Select Date',
                              style: const TextStyle(fontSize: 12),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFFBB04C),
                              side: const BorderSide(color: Color(0xFFFBB04C)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final time = await showTimePicker(
                                context: context,
                                initialTime: const TimeOfDay(hour: 10, minute: 0),
                              );
                              if (time != null) {
                                setDialogState(() {
                                  selectedTime = time;
                                });
                              }
                            },
                            icon: const Icon(Icons.access_time, size: 16),
                            label: Text(
                              selectedTime != null 
                                ? '${selectedTime!.format(context)}'
                                : 'Select Time',
                              style: const TextStyle(fontSize: 12),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFFBB04C),
                              side: const BorderSide(color: Color(0xFFFBB04C)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 12),
                    const Text(
                      'OR',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    // Text input for custom time
                    TextField(
                      controller: timeController,
                      decoration: const InputDecoration(
                        labelText: 'Custom Date & Time',
                        hintText: 'e.g., Tomorrow at 2 PM, This weekend',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.edit_calendar),
                        isDense: true,
                      ),
                      textCapitalization: TextCapitalization.sentences,
                      maxLines: 2,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Examples: "Tomorrow at 2 PM", "Sept 7th at 10 AM", "This weekend morning"',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    String finalTime = '';
                    
                    // Use calendar selection if both date and time are selected
                    if (selectedDate != null && selectedTime != null) {
                      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 
                                    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
                      finalTime = '${months[selectedDate!.month - 1]} ${selectedDate!.day} at ${selectedTime!.format(context)}';
                    } 
                    // Use custom text if provided
                    else if (timeController.text.trim().isNotEmpty) {
                      finalTime = timeController.text.trim();
                    }
                    
                    if (finalTime.isNotEmpty) {
                      Navigator.of(context).pop(finalTime);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFBB04C),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Accept Quote'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != null && result.isNotEmpty) {
      await _acceptBidWithTimeText(bid, result);
    }
  }

  Future<void> _acceptBidWithTimeText(ServiceBid bid, String serviceTimeText) async {
    setState(() {
      _isAcceptingBid = true;
    });

    try {
      print('🗓️ Accepting bid with service time: $serviceTimeText');

      // Accept bid with service time text
      final success = await UserTaskService.acceptBidWithScheduleText(
        bid.bidId!,
        widget.user.uid,
        serviceTimeText,
      );
      
      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Quote accepted! Service scheduled for $serviceTimeText'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 4),
            ),
          );
          
          // Navigate back to task detail
          Navigator.pop(context);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to accept quote. Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
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
          _isAcceptingBid = false;
        });
      }
    }
  }

  void _navigateToQuoteAcceptance(ServiceBid bid) async {
    // Navigate to full-screen quote acceptance
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => QuoteAcceptanceScreen(
          bid: bid,
          userId: widget.user.uid,
        ),
      ),
    );
    
    // If quote was accepted successfully, refresh the screen
    if (result == true) {
      setState(() {
        // Refresh bids or navigate back
      });
    }
  }

  bool _isConsultationBid(ServiceBid bid) {
    // Check if this bid is a consultation request
    return bid.bidMessage.contains('PHONE_CONSULTATION:') || 
           bid.bidMessage.contains('IN_PERSON_CONSULTATION:');
  }

  Future<void> _callProvider(String providerId) async {
    try {
      // Get provider's phone number
      final providerDoc = await FirebaseFirestore.instance
          .collection('providers')
          .doc(providerId)
          .get();
      
      if (providerDoc.exists) {
        final data = providerDoc.data() as Map<String, dynamic>;
        final phoneNumber = data['phoneNumber'] ?? data['phone'];
        
        if (phoneNumber != null) {
          // Show phone number and make call
          final shouldCall = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Call Service Provider'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Call ${data['companyName'] ?? 'Provider'}?'),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.phone, color: Colors.blue),
                        const SizedBox(width: 8),
                        Text(
                          phoneNumber,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                  icon: const Icon(Icons.phone, color: Colors.white),
                  label: const Text('Call', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          );
          
          if (shouldCall == true) {
            final uri = Uri.parse('tel:$phoneNumber');
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri);
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Unable to make phone call')),
              );
            }
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Provider phone number not available')),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  void _viewProviderProfile(String providerId, String providerName) {
    // Navigate to dedicated provider profile view screen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ExactProviderProfileScreen(
          providerId: providerId,
          providerName: providerName,
        ),
      ),
    );
  }

  Widget _buildReferralUsersSection(Map<String, dynamic> provider) {
    final referredByUserIds = provider['referred_by_user_ids'] as List<dynamic>? ?? [];
    
    if (referredByUserIds.isEmpty) {
      return const SizedBox.shrink();
    }

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _getNetworkReferralUsers(referredByUserIds.cast<String>()),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Row(
            children: [
              TranslatableText(
                'Loading referrals...',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          );
        }

        final referralUsers = snapshot.data ?? [];
        final displayCount = referralUsers.length;
        
        if (displayCount == 0) {
          return const SizedBox.shrink();
        }

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Colors.orange.shade200,
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with icon wrapped in content
              Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Icon(
                          Icons.people,
                          color: Colors.blue.shade600,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: TranslatableText(
                            'Recommended by $displayCount ${displayCount == 1 ? 'person' : 'people'} in your network',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.blue.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                            softWrap: true,
                            maxLines: 2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
              // User avatars and names
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: referralUsers.map((user) {
                  final userName = user['name'] ?? 'User';
                  final profileImageUrl = user['profileImageUrl'] as String?;
                  
                  return Column(
                    children: [
                      // Larger profile photo
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white,
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: profileImageUrl != null
                              ? Image.network(
                                  profileImageUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Center(
                                      child: Text(
                                        userName.substring(0, 1).toUpperCase(),
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.grey[700],
                                        ),
                                      ),
                                    );
                                  },
                                )
                              : Center(
                                  child: Text(
                                    userName.substring(0, 1).toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      
                      // User name
                      Text(
                        _getShortName(userName),
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.blue.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<List<Map<String, dynamic>>> _getNetworkReferralUsers(List<String> providerReferralIds) async {
    final networkReferrals = <Map<String, dynamic>>[];
    
    try {
      // Get current user's network/friends list
      final currentUser = widget.user;
      final currentUserDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();
      
      if (!currentUserDoc.exists) {
        print('Current user document not found');
        return networkReferrals;
      }
      
      final currentUserData = currentUserDoc.data() as Map<String, dynamic>;
      
      // Build complete network: friends + referral relationships (both directions)
      final userFriends = (currentUserData['friends'] as List<dynamic>?)?.cast<String>() ?? [];
      final usersWhoReferredMe = (currentUserData['referred_by_user_ids'] as List<dynamic>?)?.cast<String>() ?? [];
      final usersIReferred = (currentUserData['referred_user_ids'] as List<dynamic>?)?.cast<String>() ?? [];
      
      // Combine all network connections (remove duplicates)
      final completeNetwork = <String>{};
      completeNetwork.addAll(userFriends);
      completeNetwork.addAll(usersWhoReferredMe);
      completeNetwork.addAll(usersIReferred);
      completeNetwork.add(currentUser.uid); // Include self
      
      print('🔍 Complete user network (${completeNetwork.length} people): $completeNetwork');
      print('🔍 Provider referral IDs: $providerReferralIds');
      
      // Find intersection: users who are both in current user's network AND referred this provider
      final networkReferralIds = providerReferralIds.where((referralId) => 
          completeNetwork.contains(referralId)
      ).toList();
      
      print('🔍 Network referral intersection: $networkReferralIds');
      
      // If no network connections, don't show the section
      if (networkReferralIds.isEmpty) {
        return networkReferrals;
      }
      
      // Fetch user details for network referrals only
      for (final userId in networkReferralIds.take(4)) { // Limit to 4 users for display
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .get();
        
        if (userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>;
          networkReferrals.add({
            'id': userId,
            'name': userData['name'] ?? 'User',
            'profileImageUrl': userData['profileImageUrl'],
          });
        }
      }
      
      print('🔍 Found ${networkReferrals.length} actual network referrals');
    } catch (e) {
      print('Error fetching network referral users: $e');
    }
    
    return networkReferrals;
  }

  String _getShortName(String fullName) {
    final parts = fullName.trim().split(' ');
    if (parts.length == 1) {
      return parts[0].length > 8 ? '${parts[0].substring(0, 8)}...' : parts[0];
    } else {
      return '${parts[0]} ${parts[1].substring(0, 1)}.';
    }
  }

  Future<void> _showProviderInfoDialog(String providerId, String providerName) async {
    try {
      final providerDetails = await UserTaskService.getProviderDetails(providerId);
      
      if (!mounted) return;
      
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text(providerName),
            content: providerDetails != null 
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Rating: ${providerDetails['rating'] ?? 'N/A'}'),
                      Text('Jobs Completed: ${providerDetails['total_jobs_completed'] ?? 0}'),
                      Text('Success Rate: ${_calculateSuccessRate(providerDetails)}%'),
                      if (providerDetails['phone'] != null) ...[
                        const SizedBox(height: 8),
                        Text('Phone: ${providerDetails['phone']}'),
                      ],
                    ],
                  )
                : const Text('Loading provider information...'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          );
        },
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading provider info: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  int _calculateSuccessRate(Map<String, dynamic> providerDetails) {
    final totalJobs = providerDetails['total_jobs_completed'] ?? 0;
    final thumbsUp = providerDetails['thumbs_up_count'] ?? 0;
    
    if (totalJobs == 0) return 0;
    
    return ((thumbsUp / totalJobs) * 100).round();
  }


}
