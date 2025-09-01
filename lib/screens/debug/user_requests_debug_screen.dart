import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/user_request.dart';

class UserRequestsDebugScreen extends StatefulWidget {
  const UserRequestsDebugScreen({super.key});

  @override
  State<UserRequestsDebugScreen> createState() => _UserRequestsDebugScreenState();
}

class _UserRequestsDebugScreenState extends State<UserRequestsDebugScreen> {
  List<UserRequest> _allRequests = [];
  bool _isLoading = true;
  String _filterStatus = 'all';

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not logged in');
      }

      final query = await FirebaseFirestore.instance
          .collection('user_requests')
          .where('userId', isEqualTo: user.uid)
          .orderBy('createdAt', descending: true)
          .get();

      final requests = query.docs.map((doc) => UserRequest.fromFirestore(doc)).toList();

      setState(() {
        _allRequests = requests;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading requests: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  List<UserRequest> get _filteredRequests {
    if (_filterStatus == 'all') {
      return _allRequests;
    }
    return _allRequests.where((r) => r.status == _filterStatus).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: const Color(0xFFFBB04C),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'User Requests Debug',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadRequests,
          ),
        ],
      ),
      body: Column(
        children: [
          // Status Filter
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Total Requests: ${_allRequests.length}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('all', 'All (${_allRequests.length})'),
                      const SizedBox(width: 8),
                      _buildFilterChip('pending', 'Pending (${_allRequests.where((r) => r.status == 'pending').length})'),
                      const SizedBox(width: 8),
                      _buildFilterChip('matched', 'Matched (${_allRequests.where((r) => r.status == 'matched').length})'),
                      const SizedBox(width: 8),
                      _buildFilterChip('assigned', 'Assigned (${_allRequests.where((r) => r.status == 'assigned').length})'),
                      const SizedBox(width: 8),
                      _buildFilterChip('completed', 'Completed (${_allRequests.where((r) => r.status == 'completed').length})'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Requests List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredRequests.isEmpty
                    ? const Center(
                        child: Text('No requests found'),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _filteredRequests.length,
                        itemBuilder: (context, index) {
                          final request = _filteredRequests[index];
                          return _buildRequestCard(request);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String status, String label) {
    final isSelected = _filterStatus == status;
    return FilterChip(
      selected: isSelected,
      label: Text(label),
      onSelected: (selected) {
        setState(() {
          _filterStatus = status;
        });
      },
      selectedColor: const Color(0xFFFBB04C),
      backgroundColor: Colors.grey[200],
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.black87,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  Widget _buildRequestCard(UserRequest request) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor(request.status),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    request.status.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  _formatDate(request.createdAt),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            
            // Request ID
            Text(
              'ID: ${request.requestId ?? 'N/A'}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(height: 4),
            
            // Service Category
            Text(
              request.serviceCategory,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            
            // Description
            Text(
              request.description.isNotEmpty 
                  ? (request.description.length > 100 
                      ? '${request.description.substring(0, 100)}...' 
                      : request.description)
                  : 'No description',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            
            // Details
            Row(
              children: [
                Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    request.address.isNotEmpty ? request.address : 'No address',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            if (request.phoneNumber.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.phone, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    request.phoneNumber,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ],
            
            // Media and Matching Info
            const SizedBox(height: 8),
            Row(
              children: [
                if (request.mediaUrls.isNotEmpty) ...[
                  Icon(Icons.photo, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    '${request.mediaUrls.length} photo(s)',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(width: 16),
                ],
                if (request.aiPriceEstimation != null) ...[
                  Icon(Icons.attach_money, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    'Price estimate',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'matched':
        return Colors.blue;
      case 'assigned':
        return Colors.green;
      case 'completed':
        return Colors.grey;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}
