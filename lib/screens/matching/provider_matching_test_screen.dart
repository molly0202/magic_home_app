import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/user_request.dart';
import '../../models/provider_match.dart';
import '../../services/user_request_service.dart';

class ProviderMatchingTestScreen extends StatefulWidget {
  const ProviderMatchingTestScreen({Key? key}) : super(key: key);

  @override
  State<ProviderMatchingTestScreen> createState() => _ProviderMatchingTestScreenState();
}

class _ProviderMatchingTestScreenState extends State<ProviderMatchingTestScreen> {
  bool _isLoading = false;
  List<ProviderMatch> _matchingResults = [];
  UserRequest? _currentRequest;
  Map<String, dynamic>? _processingSummary;
  
  // Real Firebase user data
  List<Map<String, dynamic>> _availableUsers = [];
  String _selectedUserId = 'user_001';
  bool _loadingUsers = true;

  // Test scenarios with real Seattle addresses
  final List<Map<String, dynamic>> _testScenarios = [
    {
      'name': '🔧 Emergency Plumbing',
      'data': {
        'serviceCategory': 'plumbing',
        'description': 'Emergency! My kitchen sink is flooding and water is everywhere. I need immediate help!',
        'urgency': 'emergency',
        'address': '1500 1st Avenue, Seattle, WA 98101', // Downtown Seattle
        'phoneNumber': '+1-555-0123',
        'mediaUrls': ['https://example.com/flood1.jpg', 'https://example.com/flood2.jpg'],

        'preferredTime': 'ASAP',
      }
    },
    {
      'name': '🏠 Routine House Cleaning',
      'data': {
        'serviceCategory': 'cleaning',
        'description': 'Looking for weekly house cleaning service. Standard 3-bedroom apartment cleaning.',
        'urgency': 'normal',
        'address': '1200 Pine Street, Seattle, WA 98101', // Capitol Hill
        'phoneNumber': '+1-555-0124',
        'mediaUrls': [],

        'preferredTime': 'Weekends',
        'schedule': 'weekly',
      }
    },
    {
      'name': '⚡ Electrical Installation',
      'data': {
        'serviceCategory': 'electrical',
        'description': 'Need to install new outlets and upgrade electrical panel. Professional electrician required.',
        'urgency': 'high',
        'address': '2000 NE 8th Street, Bellevue, WA 98004', // Bellevue
        'phoneNumber': '+1-555-0125',
        'mediaUrls': ['https://example.com/electrical1.jpg'],

        'preferredTime': 'Weekdays',
        'tags': ['professional_required', 'licensed'],
      }
    },
    {
      'name': '🌿 Garden Landscaping',
      'data': {
        'serviceCategory': 'landscaping',
        'description': 'Looking to redesign my backyard garden. Want both design and installation.',
        'urgency': 'low',
        'address': '2500 NW Market Street, Seattle, WA 98107', // Ballard
        'phoneNumber': '+1-555-0126',
        'mediaUrls': ['https://example.com/garden1.jpg', 'https://example.com/garden2.jpg'],

        'preferredTime': 'Spring/Summer',
        'tags': ['design', 'installation'],
      }
    },
    {
      'name': '🔨 General Handyman',
      'data': {
        'serviceCategory': 'handyman',
        'description': 'Multiple small repairs: fix door handle, patch wall holes, replace light fixtures.',
        'urgency': 'normal',
        'address': '1500 15th Avenue E, Seattle, WA 98112', // Capitol Hill
        'phoneNumber': '+1-555-0127',
        'mediaUrls': ['https://example.com/repairs1.jpg'],

        'preferredTime': 'This weekend, 10am',
        'availability': ['This weekend', 'Available today', 'Available tomorrow'],
        'tags': ['multiple_tasks'],
        'aiPriceEstimation': {
          'suggestedRange': {'min': 180.0, 'max': 280.0},
          'marketAverage': 230.0,
          'confidenceLevel': 'high',
          'pricingFactors': ['Multiple tasks', 'Standard difficulty', 'Flexible timing'],
          'generatedAt': DateTime.now().toIso8601String(),
          'aiModel': 'test-scenario-v1',
        }
      }
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadUsersFromFirebase();
  }

  Future<void> _loadUsersFromFirebase() async {
    try {
      final usersSnapshot = await FirebaseFirestore.instance.collection('users').get();
      final users = <Map<String, dynamic>>[];
      
      for (final doc in usersSnapshot.docs) {
        final userData = doc.data();
        users.add({
          'id': doc.id,
          'name': userData['name'] ?? userData['displayName'] ?? 'User ${doc.id.substring(0, 8)}',
          'email': userData['email'] ?? '',
          'friends': List<String>.from(userData['friends'] ?? []),
          'referredProviders': List<String>.from(userData['referred_provider_ids'] ?? []),
        });
      }
      
      setState(() {
        _availableUsers = users;
        _loadingUsers = false;
        if (users.isNotEmpty) {
          _selectedUserId = users.first['id'];
        }
      });
      
      print('📊 Loaded ${users.length} users from Firebase');
      for (final user in users) {
        print('  - ${user['name']} (${user['id']}) - ${user['referredProviders'].length} referrals');
      }
    } catch (e) {
      print('❌ Error loading users: $e');
      setState(() {
        _loadingUsers = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🎯 Provider Matching Test'),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeaderSection(),
            const SizedBox(height: 24),
            _buildUserSelectionSection(),
            const SizedBox(height: 24),
            _buildTestScenariosSection(),
            const SizedBox(height: 24),
            if (_currentRequest != null) _buildRequestDetails(),
            if (_processingSummary != null) _buildProcessingSummary(),
            if (_matchingResults.isNotEmpty) _buildMatchingResults(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.science, color: Colors.blue[700], size: 28),
                const SizedBox(width: 12),
                const Text(
                  'Provider Matching Test Lab',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Test the AI intake → Provider matching pipeline with realistic scenarios. '
              'Each test simulates different service categories, urgency levels, and user preferences.',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserSelectionSection() {
    if (_loadingUsers) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(width: 16),
              const Text('Loading users from Firebase...'),
            ],
          ),
        ),
      );
    }

    if (_availableUsers.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.warning, color: Colors.orange[700]),
                  const SizedBox(width: 8),
                  const Text(
                    'No Users Found',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text('No users found in Firebase. Friend referrals will not be visible.'),
            ],
          ),
        ),
      );
    }

    final selectedUser = _availableUsers.firstWhere(
      (user) => user['id'] == _selectedUserId,
      orElse: () => _availableUsers.first,
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.person, color: Colors.green[700]),
                const SizedBox(width: 8),
                const Text(
                  'Test as User',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _selectedUserId,
              decoration: const InputDecoration(
                labelText: 'Select User',
                border: OutlineInputBorder(),
              ),
              items: _availableUsers.map((user) {
                return DropdownMenuItem<String>(
                  value: user['id'],
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        user['name'],
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      Text(
                        '${user['friends'].length} friends • ${user['referredProviders'].length} referrals',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (String? newValue) {
                if (newValue != null) {
                  setState(() {
                    _selectedUserId = newValue;
                    _matchingResults.clear();
                    _currentRequest = null;
                    _processingSummary = null;
                  });
                }
              },
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '👤 ${selectedUser['name']}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text('📧 ${selectedUser['email']}'),
                  Text('👥 ${selectedUser['friends'].length} friends'),
                  Text('🤝 ${selectedUser['referredProviders'].length} provider referrals'),
                  if (selectedUser['referredProviders'].isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Referred: ${(selectedUser['referredProviders'] as List).join(', ')}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTestScenariosSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '🧪 Test Scenarios',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        ...(_testScenarios.map((scenario) => _buildScenarioCard(scenario))),
      ],
    );
  }

  Widget _buildScenarioCard(Map<String, dynamic> scenario) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    scenario['name'],
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                ElevatedButton(
                  onPressed: _isLoading ? null : () => _runTest(scenario['data']),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[700],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  child: _isLoading ? 
                    const SizedBox(
                      width: 16, 
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    ) : 
                    const Text('Test'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              scenario['data']['description'],
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                _buildTag('Category: ${scenario['data']['serviceCategory']}', Colors.blue),
                _buildTag('Urgency: ${scenario['data']['urgency']}', 
                  scenario['data']['urgency'] == 'emergency' ? Colors.red : 
                  scenario['data']['urgency'] == 'high' ? Colors.orange : Colors.green),
                _buildTag('Location: ${scenario['data']['address']}', Colors.purple),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 12, color: Colors.grey[700]),
      ),
    );
  }

  Widget _buildRequestDetails() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.description, color: Colors.green[700]),
                const SizedBox(width: 8),
                const Text(
                  'Created Request',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildInfoRow('Request ID', _currentRequest!.requestId ?? 'N/A'),
            _buildInfoRow('Service Category', _currentRequest!.serviceCategory),
            _buildInfoRow('Status', _currentRequest!.status),
            _buildInfoRow('Priority', '${_currentRequest!.priority}/5'),
            _buildInfoRow('Address', _currentRequest!.address),
            if (_currentRequest!.tags?.isNotEmpty == true)
              _buildInfoRow('Tags', _currentRequest!.tags!.join(', ')),
          ],
        ),
      ),
    );
  }

  Widget _buildProcessingSummary() {
    final summary = _processingSummary!['matchingSummary'] as Map<String, dynamic>;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.analytics, color: Colors.orange[700]),
                const SizedBox(width: 8),
                const Text(
                  'Processing Summary',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildInfoRow('Total Matches', '${summary['totalMatches']}'),
            _buildInfoRow('Top Score', '${(summary['topScore'] as double).toStringAsFixed(2)}'),
            _buildInfoRow('Has Referrals', summary['hasReferrals'] ? 'Yes' : 'No'),
            _buildInfoRow('Has Previous Work', summary['hasPreviousWork'] ? 'Yes' : 'No'),
            _buildInfoRow('Avg Distance', '${(summary['avgDistance'] as double).toStringAsFixed(1)} km'),
          ],
        ),
      ),
    );
  }

  Widget _buildMatchingResults() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.people, color: Colors.purple[700]),
                const SizedBox(width: 8),
                Text(
                  'Matching Results (${_matchingResults.length})',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ..._matchingResults.asMap().entries.map((entry) {
              final index = entry.key;
              final match = entry.value;
              return _buildProviderMatchCard(match, index + 1);
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildProviderMatchCard(ProviderMatch match, int rank) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
        color: rank <= 3 ? Colors.blue[50] : Colors.grey[50],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: rank <= 3 ? Colors.blue[700] : Colors.grey[600],
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text(
                    '#$rank',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      match.name,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      match.company,
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${(match.overallScore * 100).round()}%',
                    style: TextStyle(
                      fontSize: 16, 
                      fontWeight: FontWeight.bold,
                      color: match.overallScore >= 0.8 ? Colors.green[700] : 
                             match.overallScore >= 0.6 ? Colors.orange[700] : Colors.red[700],
                    ),
                  ),
                  Text(
                    match.matchQuality,
                    style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            match.matchReason,
            style: TextStyle(fontSize: 12, color: Colors.grey[700]),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildScoreChip('⭐ ${match.rating}', Colors.amber),
              const SizedBox(width: 8),
              _buildScoreChip('📍 ${match.formattedDistance}', Colors.blue),
              const SizedBox(width: 8),
              _buildScoreChip('\$${match.hourlyRate}/hr', Colors.green),
            ],
          ),
          if (match.priorityTags.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: match.priorityTags.map((tag) => _buildPriorityTag(tag)).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildScoreChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 10, color: Colors.grey[700]),
      ),
    );
  }

  Widget _buildPriorityTag(String tag) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.purple[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.purple[300]!),
      ),
      child: Text(
        tag,
        style: TextStyle(fontSize: 10, color: Colors.purple[700], fontWeight: FontWeight.w500),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: Colors.grey[700]),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _runTest(Map<String, dynamic> testData) async {
    setState(() {
      _isLoading = true;
      _matchingResults.clear();
      _currentRequest = null;
      _processingSummary = null;
    });

    try {
      // Use the selected real user from Firebase
      final testUserId = _selectedUserId;
      
      print('🧪 Running test as user: $testUserId');
      print('🧪 Test data: $testData');
      
      // Process the request through the complete pipeline
      final result = await UserRequestService.processUserRequest(
        userId: testUserId,
        aiIntakeData: testData,
        maxProviders: 10,
      );
      
      if (result['success'] == true) {
        // Extract results
        final requestData = result['userRequest'] as Map<String, dynamic>;
        _currentRequest = UserRequest(
          requestId: requestData['requestId'] ?? (throw Exception('Missing requestId in response')),
          userId: requestData['userId'] ?? '',
          serviceCategory: requestData['serviceCategory'] ?? '',
          description: requestData['description'] ?? '',
          mediaUrls: List<String>.from(requestData['mediaUrls'] ?? []),
          userAvailability: Map<String, dynamic>.from(requestData['userAvailability'] ?? {}),
          address: requestData['address'] ?? '',
          phoneNumber: requestData['phoneNumber'] ?? '',
          location: requestData['location'] != null ? Map<String, dynamic>.from(requestData['location']) : null,
          preferences: requestData['preferences'] != null ? Map<String, dynamic>.from(requestData['preferences']) : null,
          createdAt: DateTime.now(),
          status: 'matched', // Show correct final status after processing
          tags: requestData['tags'] != null ? List<String>.from(requestData['tags']) : null,
          priority: requestData['priority'] ?? 3,
          aiPriceEstimation: requestData['aiPriceEstimation'] != null ? Map<String, dynamic>.from(requestData['aiPriceEstimation']) : null,
        );
        
        final matchingData = result['matchingProviders'] as List;
        _matchingResults = matchingData.map((data) => _createProviderMatchFromMap(data)).toList();
        
        _processingSummary = result;
        
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Found ${_matchingResults.length} matching providers!'),
            backgroundColor: Colors.green[700],
          ),
        );
      } else {
        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: ${result['error']}'),
            backgroundColor: Colors.red[700],
          ),
        );
      }
    } catch (e) {
      print('❌ Test failed: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Test failed: $e'),
          backgroundColor: Colors.red[700],
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Helper to create ProviderMatch from map data
  ProviderMatch _createProviderMatchFromMap(Map<String, dynamic> data) {
    return ProviderMatch(
      providerId: data['providerId'] ?? '',
      name: data['name'] ?? '',
      company: data['company'] ?? '',
      serviceCategories: List<String>.from(data['serviceCategories'] ?? []),
      location: data['location'] ?? '',
      email: data['email'] ?? '',
      phone: data['phone'] ?? '',
      rating: (data['rating'] as num?)?.toDouble() ?? 0.0,
      totalJobsCompleted: data['totalJobsCompleted'] ?? 0,
      hourlyRate: data['hourlyRate'] ?? 0,
      isActive: data['isActive'] ?? false,
      acceptingNewRequests: data['acceptingNewRequests'] ?? false,
      overallScore: (data['overallScore'] as num?)?.toDouble() ?? 0.0,
      serviceCategoryMatch: (data['serviceCategoryMatch'] as num?)?.toDouble() ?? 0.0,
      locationProximityScore: (data['locationProximityScore'] as num?)?.toDouble() ?? 0.0,
      ratingScore: (data['ratingScore'] as num?)?.toDouble() ?? 0.0,
      availabilityScore: (data['availabilityScore'] as num?)?.toDouble() ?? 0.0,
      referralBonus: (data['referralBonus'] as num?)?.toDouble() ?? 0.0,
      collectedWorkBonus: (data['collectedWorkBonus'] as num?)?.toDouble() ?? 0.0,
      distanceKm: (data['distanceKm'] as num?)?.toDouble() ?? 0.0,
      isReferredByFriend: data['isReferredByFriend'] ?? false,
      hasCollectedWork: data['hasCollectedWork'] ?? false,
      referralSourceUserIds: List<String>.from(data['referralSourceUserIds'] ?? []),
      collectedWorkIds: List<String>.from(data['collectedWorkIds'] ?? []),
      matchReason: data['matchReason'] ?? '',
      matchDetails: Map<String, dynamic>.from(data['matchDetails'] ?? {}),
    );
  }
} 