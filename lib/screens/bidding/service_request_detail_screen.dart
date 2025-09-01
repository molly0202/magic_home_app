import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../models/user_request.dart';
import '../../services/hsp_home_service.dart';

class ServiceRequestDetailScreen extends StatefulWidget {
  final UserRequest userRequest;

  const ServiceRequestDetailScreen({
    Key? key,
    required this.userRequest,
  }) : super(key: key);

  @override
  _ServiceRequestDetailScreenState createState() => _ServiceRequestDetailScreenState();
}

class _ServiceRequestDetailScreenState extends State<ServiceRequestDetailScreen> {
  final _formKey = GlobalKey<FormState>();
  final _priceController = TextEditingController();
  final _dateController = TextEditingController();
  
  bool _isLoadingDetails = true;
  bool _isSubmitting = false;
  UserRequest? _userRequest;
  GoogleMapController? _mapController;
  LatLng? _serviceLocation;

  @override
  void initState() {
    super.initState();
    _loadRequestDetails();
  }

  void _loadRequestDetails() async {
    try {
      // Use the provided UserRequest directly
      _userRequest = widget.userRequest;
      
      // Extract location coordinates if available
      if (_userRequest?.location != null && 
          _userRequest!.location!['lat'] != null && 
          _userRequest!.location!['lng'] != null) {
        _serviceLocation = LatLng(
          _userRequest!.location!['lat'].toDouble(),
          _userRequest!.location!['lng'].toDouble(),
        );
      }
      
      setState(() {
        _isLoadingDetails = false;
      });
    } catch (e) {
      print('Error loading request details: $e');
      setState(() {
        _isLoadingDetails = false;
      });
    }
  }

  void _submitQuote() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      final price = double.parse(_priceController.text);
      final requestId = _userRequest?.requestId ?? '';
      final address = _userRequest?.address ?? '';
      
      // Placeholder for quote submission - integrates with bidding system
      print('Quote submitted: \$${price} for request ${requestId}');
      // TODO: Integrate with bidding system
      // await HSPHomeService.submitQuote(
      //   requestId: requestId,
      //   price: price,
      //   scheduledDate: _dateController.text,
      //   address: address,
      // );
      
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Quote submitted successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error submitting quote: $e')),
      );
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  Widget _buildLocationSection() {
    if (_serviceLocation == null) {
      // Show just address and zip code if no coordinates
      return Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.location_on, color: Colors.red),
                  const SizedBox(width: 8),
                  const Text(
                    'Service Location',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                _userRequest?.address ?? 'Address not available',
                style: const TextStyle(fontSize: 14),
              ),
              if (_userRequest?.location?['formatted_address'] != null) ...[
                const SizedBox(height: 8),
                Text(
                  _userRequest!.location!['formatted_address'],
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    // Show map with location if coordinates available
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.location_on, color: Colors.red),
                const SizedBox(width: 8),
                const Text(
                  'Service Location',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
                          Text(
                _userRequest?.address ?? 'Address not available',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
            const SizedBox(height: 12),
            Container(
              height: 200,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: _serviceLocation!,
                    zoom: 15,
                  ),
                  markers: {
                    Marker(
                      markerId: const MarkerId('service_location'),
                      position: _serviceLocation!,
                      infoWindow: InfoWindow(
                        title: 'Service Location',
                        snippet: _userRequest?.address ?? 'Service address',
                      ),
                    ),
                  },
                  onMapCreated: (GoogleMapController controller) {
                    _mapController = controller;
                  },
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvailabilitySection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.schedule, color: Colors.blue),
                const SizedBox(width: 8),
                const Text(
                  'Customer Availability',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            if (_userRequest?.userAvailability != null) ...[
              // Rich availability data from UserRequest
              if (_userRequest!.userAvailability['preferredDays'] != null) ...[
                _buildAvailabilityRow(
                  'Preferred Days:', 
                  (_userRequest!.userAvailability['preferredDays'] as List).join(', ')
                ),
                const SizedBox(height: 8),
              ],
              if (_userRequest!.userAvailability['preferredTimes'] != null) ...[
                _buildAvailabilityRow(
                  'Preferred Times:', 
                  (_userRequest!.userAvailability['preferredTimes'] as List).join(', ')
                ),
                const SizedBox(height: 8),
              ],
              if (_userRequest!.userAvailability['urgency'] != null) ...[
                Row(
                  children: [
                    const Icon(Icons.priority_high, size: 16, color: Colors.grey),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _userRequest!.userAvailability['urgency'] == 'urgent' 
                            ? Colors.red[100] 
                            : Colors.green[100],
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Urgency: ${_userRequest!.userAvailability['urgency']}',
                        style: TextStyle(
                          fontSize: 12,
                          color: _userRequest!.userAvailability['urgency'] == 'urgent' 
                              ? Colors.red[800] 
                              : Colors.green[800],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ] else ...[
              // Fallback to basic availability from ServiceRequest
              _buildAvailabilityRow('Preferred Time:', 'Not specified'),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAvailabilityRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.access_time, size: 16, color: Colors.grey),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildPriceRangeSection() {
    final aiPrice = _userRequest?.aiPriceEstimation;
    
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.attach_money, color: Colors.green),
                const SizedBox(width: 8),
                const Text(
                  'Market Price Range',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            if (aiPrice != null && aiPrice['suggestedRange'] != null) ...[
              // AI-generated price range
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue[100],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'AI Estimated',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.blue,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '\$${aiPrice['suggestedRange']['min']} - \$${aiPrice['suggestedRange']['max']}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              
              if (aiPrice['marketAverage'] != null) ...[
                Row(
                  children: [
                    const Icon(Icons.trending_up, size: 16, color: Colors.grey),
                    const SizedBox(width: 8),
                    Text(
                      'Market Average: \$${aiPrice['marketAverage']}',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
              ],
              
              if (aiPrice['confidenceLevel'] != null) ...[
                Row(
                  children: [
                    const Icon(Icons.verified, size: 16, color: Colors.grey),
                    const SizedBox(width: 8),
                    Text(
                      'Confidence: ${(aiPrice['confidenceLevel'] * 100).toInt()}%',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ],
            ] else ...[
              // Fallback to customer budget
              Row(
                children: [
                  const Icon(Icons.account_balance_wallet, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text(
                    'Customer Budget: ${_userRequest?.preferences?['price_range'] ?? 'Not specified'}',
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Request Details'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoadingDetails
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Issue Description
                  Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.description, color: Colors.orange),
                              const SizedBox(width: 8),
                              const Text(
                                'Service Description',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _userRequest?.description ?? 'No description available',
                            style: const TextStyle(fontSize: 14, height: 1.4),
                          ),
                          const SizedBox(height: 8),
                          if (_userRequest?.serviceCategory != null) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.orange[100],
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Category: ${_userRequest!.serviceCategory}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.orange[800],
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // 2. User Availability
                  _buildAvailabilitySection(),
                  
                  const SizedBox(height: 16),
                  
                  // 3. Location with Map
                  _buildLocationSection(),
                  
                  const SizedBox(height: 16),
                  
                  // 4. Market Price Range
                  _buildPriceRangeSection(),
                  
                  const SizedBox(height: 16),
                  
                  // Request Metadata
                                      Text(
                      'Request ID: ${_userRequest?.requestId ?? 'Unknown'}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Quote Form (if provider wants to provide quote)
                  Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Submit Your Quote',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            
                            TextFormField(
                              controller: _priceController,
                              decoration: const InputDecoration(
                                labelText: 'Your Price Quote (\$)',
                                prefixIcon: Icon(Icons.attach_money),
                                border: OutlineInputBorder(),
                                hintText: 'Enter your competitive quote',
                              ),
                              keyboardType: TextInputType.number,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter a price';
                                }
                                if (double.tryParse(value) == null) {
                                  return 'Please enter a valid number';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            
                            TextFormField(
                              controller: _dateController,
                              decoration: const InputDecoration(
                                labelText: 'Your Availability',
                                prefixIcon: Icon(Icons.calendar_today),
                                border: OutlineInputBorder(),
                                hintText: 'e.g., Tomorrow 2-5 PM, This weekend',
                              ),
                              maxLines: 2,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your availability';
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 100), // Extra space for bottom button
                ],
              ),
            ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitQuote,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isSubmitting
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'Submit Quote',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Quote submission feature coming soon!',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _priceController.dispose();
    _dateController.dispose();
    super.dispose();
  }
}