import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import '../../models/user_request.dart';
import '../../services/bidding_service.dart';
import '../../services/price_benchmark_service.dart';
import '../../widgets/price_benchmark_widget.dart';
import '../../widgets/market_price_guidance_card.dart';
import '../../widgets/service_request_card.dart';

class ProviderBidScreen extends StatefulWidget {
  final String requestId;
  final UserRequest userRequest;
  final DateTime? deadline;

  const ProviderBidScreen({
    Key? key,
    required this.requestId,
    required this.userRequest,
    this.deadline,
  }) : super(key: key);

  @override
  _ProviderBidScreenState createState() => _ProviderBidScreenState();
}

class _ProviderBidScreenState extends State<ProviderBidScreen> {
  final _formKey = GlobalKey<FormState>();
  final _priceController = TextEditingController();
  final _availabilityController = TextEditingController();
  final _messageController = TextEditingController();

  Timer? _deadlineTimer;
  String _timeRemaining = "";
  bool _isSubmitting = false;
  Map<String, dynamic>? _currentBenchmark;
  bool _canBid = true;
  String? _eligibilityMessage;
  
  // New consultation options
  String _quoteType = 'price'; // 'price', 'phone_consultation', 'in_person_consultation'

  @override
  void initState() {
    super.initState();
    _checkBidEligibility();
    _startDeadlineTimer();
    _setupDefaultValues();
  }

  @override
  void dispose() {
    _deadlineTimer?.cancel();
    _priceController.dispose();
    _availabilityController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  void _checkBidEligibility() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final eligibility = await BiddingService.canProviderBid(
      widget.requestId,
      currentUser.uid,
    );

    setState(() {
      _canBid = eligibility['canBid'] ?? false;
      _eligibilityMessage = eligibility['reason'];
    });
  }

  void _setupDefaultValues() {
    // Set default availability
    _availabilityController.text = "Available today";
    
    // Remove default message - let providers write their own
    _messageController.text = "";
  }

  void _startDeadlineTimer() {
    if (widget.deadline == null) return;

    _deadlineTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      final now = DateTime.now();
      final difference = widget.deadline!.difference(now);

      if (difference.isNegative) {
        setState(() {
          _timeRemaining = "EXPIRED";
          _canBid = false;
        });
        timer.cancel();
      } else {
        setState(() {
          _timeRemaining = BiddingService.formatTimeRemaining(difference);
        });
      }
    });
  }

  void _onPriceChanged(String value) async {
    if (value.isEmpty) {
      setState(() => _currentBenchmark = null);
      return;
    }

    final price = double.tryParse(value);
    if (price != null && price > 0) {
      try {
        final benchmark = await PriceBenchmarkService.calculateBenchmark(
          requestId: widget.requestId,
          proposedPrice: price,
        );
        setState(() => _currentBenchmark = benchmark);
      } catch (e) {
        print('Error calculating benchmark: $e');
      }
    }
  }

  void _submitBid() async {
    // For consultation options, skip form validation since no price is required
    if (_quoteType == 'price' && !_formKey.currentState!.validate()) return;
    if (!_canBid) return;

    setState(() => _isSubmitting = true);

    try {
      print('🔍 PROVIDER_BID_SCREEN: Starting bid submission...');
      print('🔍 Quote type: $_quoteType');
      
      // Handle different quote types
      double priceQuote;
      String bidMessage = _messageController.text.trim();
      
      if (_quoteType == 'phone_consultation') {
        priceQuote = 1.0; // Use minimal price for consultation (system requirement)
        bidMessage = 'PHONE_CONSULTATION: $bidMessage';
      } else if (_quoteType == 'in_person_consultation') {
        priceQuote = 1.0; // Use minimal price for consultation (system requirement)
        bidMessage = 'IN_PERSON_CONSULTATION: $bidMessage';
      } else {
        priceQuote = double.parse(_priceController.text);
        bidMessage = 'PRICE_QUOTE: $bidMessage';
      }
      
      final result = await BiddingService.submitBid(
        requestId: widget.requestId,
        priceQuote: priceQuote,
        availability: _availabilityController.text.trim(),
        bidMessage: bidMessage,
      );

      print('🔍 PROVIDER_BID_SCREEN: Bid submission result: $result');

      if (result['success']) {
        _showSuccessDialog(result['priceBenchmark']);
      } else {
        _showErrorDialog(result['message'] ?? 'Unknown error occurred');
      }
    } catch (e) {
      print('🔍 PROVIDER_BID_SCREEN: Exception during bid submission: $e');
      _showErrorDialog('Failed to submit bid: $e');
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  void _showSuccessDialog(String benchmark) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 28),
            SizedBox(width: 8),
            Text('Bid Submitted!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Your bid has been submitted successfully.'),
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _getBenchmarkColor(benchmark).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _getBenchmarkColor(benchmark)),
              ),
              child: Row(
                children: [
                  Icon(_getBenchmarkIcon(benchmark), 
                       color: _getBenchmarkColor(benchmark)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Price Assessment: ${benchmark.toUpperCase()}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _getBenchmarkColor(benchmark),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 12),
            Text(
              'The customer will be notified and you\'ll receive an update once they review all bids.',
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog only
              // Don't navigate back automatically - let user see the result
            },
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.error, color: Colors.red, size: 28),
            SizedBox(width: 8),
            Text('Error'),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  Color _getBenchmarkColor(String benchmark) {
    switch (benchmark.toLowerCase()) {
      case 'low':
        return Colors.green;
      case 'high':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  IconData _getBenchmarkIcon(String benchmark) {
    switch (benchmark.toLowerCase()) {
      case 'low':
        return Icons.trending_down;
      case 'high':
        return Icons.trending_up;
      default:
        return Icons.check_circle;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Service Opportunity', style: TextStyle(fontSize: 18)),
            if (widget.deadline != null)
              Text(
                _timeRemaining.isNotEmpty ? _timeRemaining : 'Loading...',
                style: TextStyle(
                  fontSize: 12,
                  color: _timeRemaining.contains("EXPIRED") 
                      ? Colors.red 
                      : Colors.white70,
                ),
              ),
          ],
        ),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: !_canBid ? _buildNotEligibleScreen() : _buildBidForm(),
    );
  }

  Widget _buildNotEligibleScreen() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.block,
              size: 64,
              color: Colors.grey,
            ),
            SizedBox(height: 16),
            Text(
              'Cannot Submit Bid',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            SizedBox(height: 8),
            Text(
              _eligibilityMessage ?? 'You are not eligible to bid on this request',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Go Back'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBidForm() {
    // Debug the UserRequest being passed to ServiceRequestCard
    print('🔍 PROVIDER_BID_SCREEN DEBUG:');
    print('🔍 RequestId: ${widget.userRequest.requestId}');
    print('🔍 UserAvailability: ${widget.userRequest.userAvailability}');
    print('🔍 AiPriceEstimation: ${widget.userRequest.aiPriceEstimation}');
    print('🔍 Preferences: ${widget.userRequest.preferences}');
    print('🔍 Status: ${widget.userRequest.status}');
    
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Service Request Details
            ServiceRequestCard(userRequest: widget.userRequest),
            
            SizedBox(height: 16),
            
            // Market Price Guidance
            MarketPriceGuidanceCard(
              aiPriceEstimation: widget.userRequest.aiPriceEstimation,
              serviceCategory: widget.userRequest.serviceCategory,
            ),
            
            SizedBox(height: 24),
            
            // Bid Form Section
            Text(
              'Submit Your Bid',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            
            // Price Input with Real-time Benchmark
            _buildPriceInputSection(),
            
            SizedBox(height: 16),
            
            // Availability Input
            _buildAvailabilitySection(),
            
            SizedBox(height: 16),
            
            // Message Input
            _buildMessageSection(),
            
            SizedBox(height: 24),
            
            // Submit Button
            _buildSubmitButton(),
            
            SizedBox(height: 16),
            
            // Terms & Conditions
            _buildTermsSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceInputSection() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your Quote',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            
            // Quote type selection
            Column(
              children: [
                // Direct price quote option
                GestureDetector(
                  onTap: () => setState(() => _quoteType = 'price'),
                  child: Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _quoteType == 'price' ? const Color(0xFFFBB04C).withOpacity(0.1) : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _quoteType == 'price' ? const Color(0xFFFBB04C) : Colors.grey[300]!,
                        width: _quoteType == 'price' ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.attach_money,
                          color: _quoteType == 'price' ? const Color(0xFFFBB04C) : Colors.grey[600],
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Provide Direct Quote',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: _quoteType == 'price' ? const Color(0xFFFBB04C) : Colors.black87,
                                ),
                              ),
                              Text(
                                'I can provide a price estimate now',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Radio<String>(
                          value: 'price',
                          groupValue: _quoteType,
                          onChanged: (value) => setState(() => _quoteType = value!),
                          activeColor: const Color(0xFFFBB04C),
                        ),
                      ],
                    ),
                  ),
                ),
                
                SizedBox(height: 12),
                
                // Phone consultation option
                GestureDetector(
                  onTap: () => setState(() => _quoteType = 'phone_consultation'),
                  child: Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _quoteType == 'phone_consultation' ? Colors.blue.withOpacity(0.1) : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _quoteType == 'phone_consultation' ? Colors.blue : Colors.grey[300]!,
                        width: _quoteType == 'phone_consultation' ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.phone,
                          color: _quoteType == 'phone_consultation' ? Colors.blue : Colors.grey[600],
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Need Phone Consultation',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: _quoteType == 'phone_consultation' ? Colors.blue : Colors.black87,
                                ),
                              ),
                              Text(
                                'I need to discuss details before pricing',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Radio<String>(
                          value: 'phone_consultation',
                          groupValue: _quoteType,
                          onChanged: (value) => setState(() => _quoteType = value!),
                          activeColor: Colors.blue,
                        ),
                      ],
                    ),
                  ),
                ),
                
                SizedBox(height: 12),
                
                // In-person consultation option
                GestureDetector(
                  onTap: () => setState(() => _quoteType = 'in_person_consultation'),
                  child: Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _quoteType == 'in_person_consultation' ? Colors.purple.withOpacity(0.1) : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _quoteType == 'in_person_consultation' ? Colors.purple : Colors.grey[300]!,
                        width: _quoteType == 'in_person_consultation' ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.person_pin_circle,
                          color: _quoteType == 'in_person_consultation' ? Colors.purple : Colors.grey[600],
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Need In-Person Consultation',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: _quoteType == 'in_person_consultation' ? Colors.purple : Colors.black87,
                                ),
                              ),
                              Text(
                                'I need to visit the location before pricing',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Radio<String>(
                          value: 'in_person_consultation',
                          groupValue: _quoteType,
                          onChanged: (value) => setState(() => _quoteType = value!),
                          activeColor: Colors.purple,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            
            SizedBox(height: 16),
            
            // Price input - only show for direct quote
            if (_quoteType == 'price')
              Column(
                children: [
                  TextFormField(
                    controller: _priceController,
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Price Quote (\$)',
                      hintText: 'Enter your price',
                      prefixIcon: Icon(Icons.attach_money),
                      border: OutlineInputBorder(),
                      suffixIcon: _currentBenchmark != null 
                          ? Icon(
                              _currentBenchmark!['icon'],
                              color: _currentBenchmark!['color'],
                            )
                          : null,
                    ),
                    validator: (value) {
                      // Only validate price for direct quote option
                      if (_quoteType == 'price') {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a price';
                        }
                        final price = double.tryParse(value);
                        if (price == null || price <= 0) {
                          return 'Please enter a valid price';
                        }
                      }
                      // No validation needed for consultation options
                      return null;
                    },
                    onChanged: _onPriceChanged,
                  ),
                  
                  // Real-time price benchmark feedback
                  if (_currentBenchmark != null) ...[
                    SizedBox(height: 12),
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _currentBenchmark!['color'].withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _currentBenchmark!['color'],
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _currentBenchmark!['icon'],
                            color: _currentBenchmark!['color'],
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _currentBenchmark!['message'],
                                  style: TextStyle(
                                    fontWeight: FontWeight.w500,
                                    color: _currentBenchmark!['color'],
                                  ),
                                ),
                                if (_currentBenchmark!['isAIGenerated'] == true)
                                  Text(
                                    'AI-powered analysis',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            
            // Consultation message
            if (_quoteType != 'price') ...[
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _quoteType == 'phone_consultation' ? Icons.phone : Icons.location_on,
                          color: Colors.blue[600],
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Text(
                          _quoteType == 'phone_consultation' 
                              ? 'Phone Consultation Required'
                              : 'In-Person Consultation Required',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[700],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(
                      _quoteType == 'phone_consultation'
                          ? 'Customer will be able to call you directly to discuss the project details and get a quote.'
                          : 'Customer will be able to schedule an in-person consultation to assess the project and provide an accurate quote.',
                      style: TextStyle(
                        color: Colors.blue[600],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAvailabilitySection() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Availability',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 12),
            
            TextFormField(
              controller: _availabilityController,
              decoration: InputDecoration(
                labelText: 'When can you start?',
                hintText: 'e.g., Available today 2-5 PM',
                prefixIcon: Icon(Icons.schedule),
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please specify your availability';
                }
                return null;
              },
              maxLines: 2,
            ),
            
            SizedBox(height: 8),
            
            // Quick availability options
            Wrap(
              spacing: 8,
              children: [
                'Available today',
                'Available tomorrow',
                'This weekend',
                'Within 24 hours',
              ].map((option) => ActionChip(
                label: Text(option, style: TextStyle(fontSize: 12)),
                onPressed: () {
                  _availabilityController.text = option;
                },
              )).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageSection() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Message to Customer',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 12),
            
            TextFormField(
              controller: _messageController,
              decoration: InputDecoration(
                labelText: 'Your message',
                hintText: 'Tell the customer why you\'re the right choice...',
                prefixIcon: Icon(Icons.message),
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please add a message for the customer';
                }
                if (value.trim().length < 10) {
                  return 'Message should be at least 10 characters';
                }
                return null;
              },
              maxLines: 4,
              maxLength: 500,
            ),
          ],
        ),
      ),
    );
  }

  String _getSubmitButtonText() {
    switch (_quoteType) {
      case 'phone_consultation':
        return 'Request Phone Consultation';
      case 'in_person_consultation':
        return 'Request In-Person Consultation';
      default:
        return 'Submit Bid';
    }
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: _isSubmitting ? null : _submitBid,
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).primaryColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: _isSubmitting
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  SizedBox(width: 12),
                  Text('Submitting Bid...'),
                ],
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.send),
                  SizedBox(width: 8),
                  Text(
                    _getSubmitButtonText(),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildTermsSection() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, size: 16, color: Colors.blue),
              SizedBox(width: 8),
              Text(
                'Important Notes',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            '• You have ${_timeRemaining} to submit your bid\n'
            '• Your bid is binding once submitted\n'
            '• The customer will review all bids before deciding\n'
            '• You\'ll be notified of the outcome regardless of selection',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[700],
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
