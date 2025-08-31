import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/user_request.dart';
import '../../models/bidding_session.dart';
import '../../services/user_task_service.dart';
import 'service_quotes_screen.dart';

class TaskDetailScreen extends StatefulWidget {
  final UserRequest task;
  final User user;

  const TaskDetailScreen({
    Key? key,
    required this.task,
    required this.user,
  }) : super(key: key);

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  UserRequest? _currentTask;

  @override
  void initState() {
    super.initState();
    _currentTask = widget.task;
    _listenToTaskUpdates();
  }

  void _listenToTaskUpdates() {
    if (widget.task.requestId != null) {
      UserTaskService.firestore
          .collection('user_requests')
          .doc(widget.task.requestId!)
          .snapshots()
          .listen((doc) {
        if (doc.exists && mounted) {
          setState(() {
            _currentTask = UserRequest.fromFirestore(doc);
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentTask = _currentTask ?? widget.task;
    
    return FutureBuilder<Map<String, dynamic>>(
      future: _getTaskWithBiddingInfo(currentTask),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            backgroundColor: Colors.grey[50],
            appBar: AppBar(
              title: Text(
                currentTask.serviceCategory.replaceAll('_', ' ').toUpperCase(),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              backgroundColor: Colors.white,
              elevation: 0,
              iconTheme: const IconThemeData(color: Colors.black87),
            ),
            body: const Center(
              child: CircularProgressIndicator(
                color: Color(0xFFFBB04C),
              ),
            ),
          );
        }

        final taskInfo = snapshot.data ?? {
          'actualStatus': widget.task.status,
          'bidCount': 0,
          'biddingSession': null,
        };

        final actualStatus = taskInfo['actualStatus'] as String;
        final bidCount = taskInfo['bidCount'] as int;
        final statusInfo = UserTaskService.getTaskStatusInfo(actualStatus, task: currentTask);

        return Scaffold(
          backgroundColor: Colors.grey[50],
          appBar: AppBar(
            title: Text(
              widget.task.serviceCategory.replaceAll('_', ' ').toUpperCase(),
              style: const TextStyle(
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
                // Status and Action Button
                _buildStatusHeader(statusInfo, actualStatus, bidCount),

                // Request Details Card
                _buildRequestDetailsCard(currentTask),

                // Contact Information (if assigned)
                if (actualStatus == 'assigned' && currentTask.assignedProviderId != null)
                  _buildContactCard(currentTask),

                // Address Card
                _buildAddressCard(currentTask),

                // Availability Card
                _buildAvailabilityCard(currentTask),

                // Final Service Schedule Card (if confirmed)
                if (currentTask.finalServiceSchedule != null && currentTask.finalServiceSchedule!.isNotEmpty)
                  _buildFinalScheduleCard(currentTask),

                // Description Card
                _buildDescriptionCard(currentTask),

                // Media Card (if has media)
                if (currentTask.mediaUrls.isNotEmpty)
                  _buildMediaCard(currentTask),

                const SizedBox(height: 100), // Bottom padding
              ],
            ),
          ),
        );
      },
    );
  }

  Future<Map<String, dynamic>> _getTaskWithBiddingInfo(UserRequest task) async {
    // Only check for bidding info if status is 'matched'
    if (task.status != 'matched') {
      return {
        'actualStatus': task.status,
        'bidCount': 0,
        'biddingSession': null,
      };
    }

    try {
      // Check for active bidding session with bids
      final sessionQuery = await UserTaskService.firestore
          .collection('bidding_sessions')
          .where('requestId', isEqualTo: task.requestId)
          .where('sessionStatus', isEqualTo: 'active')
          .limit(1)
          .get();

      if (sessionQuery.docs.isNotEmpty) {
        final biddingSession = BiddingSession.fromFirestore(sessionQuery.docs.first);
        final bidCount = biddingSession.receivedBids.length;

        // If there are bids, consider this as "bidding" status
        if (bidCount > 0) {
          return {
            'actualStatus': 'bidding',
            'bidCount': bidCount,
            'biddingSession': biddingSession,
          };
        }
      }

      return {
        'actualStatus': task.status,
        'bidCount': 0,
        'biddingSession': null,
      };
    } catch (e) {
      print('❌ Error getting bidding info: $e');
      return {
        'actualStatus': task.status,
        'bidCount': 0,
        'biddingSession': null,
      };
    }
  }

  Widget _buildStatusHeader(Map<String, dynamic> statusInfo, String actualStatus, int bidCount) {
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
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: statusInfo['color'].withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  statusInfo['icon'],
                  color: statusInfo['color'],
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      statusInfo['label'],
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: statusInfo['color'],
                      ),
                    ),
                    Text(
                      actualStatus == 'bidding' 
                        ? '$bidCount ${bidCount == 1 ? 'quote' : 'quotes'} received'
                        : statusInfo['description'],
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Action Button based on status
          if (actualStatus == 'bidding') ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _navigateToQuotes(_currentTask ?? widget.task),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFBB04C),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'View Quotes',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],

          if (actualStatus == 'assigned') ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _navigateToQuotes(_currentTask ?? widget.task),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'View Quote Details',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRequestDetailsCard(UserRequest task) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
          const Text(
            'Request Details:',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          
          _buildDetailRow('Category', task.serviceCategory.replaceAll('_', ' ').toUpperCase()),
          _buildDetailRow('Created', _formatDateTime(task.createdAt)),
          _buildDetailRow('Priority', 'Priority ${task.priority}'),
          
          if (task.preferences != null && task.preferences!['price_range'] != null)
            _buildDetailRow('Budget', task.preferences!['price_range'].toString()),
        ],
      ),
    );
  }

  Widget _buildContactCard(UserRequest task) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: UserTaskService.getProviderDetails(task.assignedProviderId!),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final provider = snapshot.data!;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
              const Text(
                'Contact:',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 16),
              
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          provider['company'] ?? provider['companyName'] ?? 'Provider',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (provider['phone'] != null) ...[
                          const SizedBox(height: 4),
                          GestureDetector(
                            onTap: () => _makePhoneCall(provider['phone']),
                            child: Text(
                              'Phone: ${provider['phone']}',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.blue,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (provider['phone'] != null)
                    IconButton(
                      onPressed: () => _makePhoneCall(provider['phone']),
                      icon: const Icon(
                        Icons.phone,
                        color: Colors.green,
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAddressCard(UserRequest task) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
          const Text(
            'Address:',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          
          Row(
            children: [
              Expanded(
                child: Text(
                                              task.address,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black87,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => _openMaps(task.address),
                icon: const Icon(
                  Icons.directions,
                  color: Colors.blue,
                ),
                tooltip: 'Get Directions',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAvailabilityCard(UserRequest task) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
          const Text(
            'Availability',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          
                      if (task.userAvailability.isNotEmpty) ...[
            if (task.userAvailability['preferredTime'] != null)
              Text(
                task.userAvailability['preferredTime'],
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black87,
                ),
              ),
            
            if (task.userAvailability['timeSlots'] != null) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: (task.userAvailability['timeSlots'] as List)
                    .map((slot) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            slot.toString(),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.blue,
                            ),
                          ),
                        ))
                    .toList(),
              ),
            ],
          ] else ...[
            Text(
              'No specific availability mentioned',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFinalScheduleCard(UserRequest task) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.event_available,
                color: Colors.green[700],
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                'Confirmed Service Time',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your Confirmed Schedule:',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  task.finalServiceSchedule!,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.green[700],
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 12),
          
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.check_circle_outline,
                  color: Colors.blue[700],
                  size: 16,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'This is the final service time you confirmed when accepting the quote. The provider has been notified.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDescriptionCard(UserRequest task) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
          const Text(
            'Detailed Description',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            task.description,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black87,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMediaCard(UserRequest task) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
          const Text(
            'Photos & Videos',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          
          SizedBox(
            height: 100,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: task.mediaUrls.length,
              itemBuilder: (context, index) {
                final url = task.mediaUrls[index];
                return Container(
                  width: 100,
                  margin: const EdgeInsets.only(right: 12),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      url,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.grey[200],
                          child: const Icon(
                            Icons.broken_image,
                            color: Colors.grey,
                          ),
                        );
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToQuotes(UserRequest task) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ServiceQuotesScreen(
          task: task,
          user: widget.user,
        ),
      ),
    );
  }

  void _makePhoneCall(String phoneNumber) async {
    final uri = Uri.parse('tel:$phoneNumber');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _openMaps(String address) async {
    final encodedAddress = Uri.encodeComponent(address);
    final uri = Uri.parse('https://maps.google.com/?q=$encodedAddress');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    
    final hour = dateTime.hour;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    
    return '${months[dateTime.month - 1]} ${dateTime.day}, ${dateTime.year} at $displayHour:$minute $period';
  }
}
