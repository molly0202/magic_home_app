import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/user_request.dart';
import '../../services/user_task_service.dart';
import '../../widgets/full_screen_media_viewer.dart';

class AssignedTaskDetailScreen extends StatefulWidget {
  final UserRequest task;

  const AssignedTaskDetailScreen({
    Key? key,
    required this.task,
  }) : super(key: key);

  @override
  State<AssignedTaskDetailScreen> createState() => _AssignedTaskDetailScreenState();
}

class _AssignedTaskDetailScreenState extends State<AssignedTaskDetailScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Assigned Task Details',
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
            // Status Header
            _buildStatusHeader(),

            // a. Customer name and contact
            _buildUserContactCard(),

            // b. Final Scheduled time
            if (widget.task.finalServiceSchedule != null && widget.task.finalServiceSchedule!.isNotEmpty)
              _buildFinalScheduleCard(),

            // c. Service address
            _buildAddressCard(),

            // d. Task details (combined with detailed description)
            _buildCombinedTaskDetailsCard(),

            // e. Photos & Videos
            if (widget.task.mediaUrls.isNotEmpty)
              _buildMediaCard(),

            const SizedBox(height: 100), // Bottom padding
          ],
        ),
      ),
    );
  }

  Widget _buildStatusHeader() {
    return Container(
      margin: const EdgeInsets.all(16),
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
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.assignment_turned_in,
              color: Colors.green,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Task Assigned',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
                Text(
                  'Quote accepted',
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
    );
  }

  Widget _buildUserContactCard() {
    return FutureBuilder<Map<String, dynamic>?>(
      future: UserTaskService.getUserDetails(widget.task.userId),
      builder: (context, snapshot) {
        final userData = snapshot.data;
        
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
                'Customer Contact:',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 16),
              
              if (userData != null) ...[
                Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: Center(
                        child: Text(
                          (userData['displayName'] ?? userData['email'] ?? 'U')
                              .substring(0, 1)
                              .toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            userData['displayName'] ?? userData['name'] ?? 'Customer',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          if (userData['email'] != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              userData['email'],
                              style: TextStyle(
                                fontSize: 15,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // Phone number and contact buttons
                if (widget.task.phoneNumber.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.green.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.phone,
                              color: Colors.green[700],
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Phone Number',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  GestureDetector(
                                    onTap: () => _makePhoneCall(widget.task.phoneNumber),
                                    child: Text(
                                      widget.task.phoneNumber,
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green[700],
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => _makePhoneCall(widget.task.phoneNumber),
                                icon: const Icon(Icons.call, size: 20),
                                label: const Text(
                                  'Call',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => _makeVideoCall(widget.task.phoneNumber),
                                icon: const Icon(Icons.videocam, size: 20),
                                label: const Text(
                                  'Video Call',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ] else ...[
                const Center(
                  child: CircularProgressIndicator(
                    color: Colors.green,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildTaskDetailsCard() {
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
            'Task Details:',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          
          _buildDetailRow('Category', widget.task.serviceCategory.replaceAll('_', ' ').toUpperCase()),
          _buildDetailRow('Created', _formatDateTime(widget.task.createdAt)),
          _buildDetailRow('Priority', 'Priority ${widget.task.priority}'),
          
          if (widget.task.preferences != null && widget.task.preferences!['price_range'] != null)
            _buildDetailRow('Budget', widget.task.preferences!['price_range'].toString()),
        ],
      ),
    );
  }

  Widget _buildAddressCard() {
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
            'Service Address:',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.location_on,
                  color: Colors.blue[700],
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.task.address,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.black87,
                    ),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _openMaps(widget.task.address),
                  icon: const Icon(Icons.directions, size: 16),
                  label: const Text('Directions'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvailabilityCard() {
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
            'Customer Availability',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          
          if (widget.task.userAvailability.isNotEmpty) ...[
            if (widget.task.userAvailability['preferredTime'] != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.schedule,
                      color: Colors.orange[700],
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.task.userAvailability['preferredTime'],
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.black87,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            
            if (widget.task.userAvailability['timeSlots'] != null) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: (widget.task.userAvailability['timeSlots'] as List)
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

  Widget _buildFinalScheduleCard() {
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
                'Final Service Schedule',
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
                  'Customer Confirmed Time:',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.task.finalServiceSchedule!,
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
                  Icons.info_outline,
                  color: Colors.blue[700],
                  size: 16,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'This is the final time confirmed by the customer when they accepted your quote.',
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

  Widget _buildCombinedTaskDetailsCard() {
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
            'Task Details:',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          
          // Task metadata
          _buildDetailRow('Category', widget.task.serviceCategory.replaceAll('_', ' ').toUpperCase()),
          _buildDetailRow('Created', _formatDateTime(widget.task.createdAt)),
          _buildDetailRow('Priority', 'Priority ${widget.task.priority}'),
          
          if (widget.task.preferences != null && widget.task.preferences!['budget'] != null)
            _buildDetailRow('Budget', widget.task.preferences!['budget'].toString()),
            
          const SizedBox(height: 16),
          
          // Detailed Description section
          const Text(
            'Detailed Description:',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.withOpacity(0.2)),
            ),
            child: Text(
              widget.task.description,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black87,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDescriptionCard() {
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
            widget.task.description,
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

  Widget _buildMediaCard() {
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
          Row(
            children: [
              const Text(
                'Photos & Videos',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const Spacer(),
              Text(
                'Tap to enlarge',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          SizedBox(
            height: 120,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: widget.task.mediaUrls.length,
              itemBuilder: (context, index) {
                final url = widget.task.mediaUrls[index];
                final isVideo = _isVideoUrl(url);
                
                return Container(
                  width: 120,
                  margin: const EdgeInsets.only(right: 12),
                  child: GestureDetector(
                    onTap: () => _openFullScreenMedia(url, !isVideo, isVideo),
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: Colors.grey.withOpacity(0.3),
                                width: 1,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: isVideo
                                ? Stack(
                                    children: [
                                      Container(
                                        width: 120,
                                        height: 120,
                                        color: Colors.black12,
                                        child: const Icon(
                                          Icons.play_circle_filled,
                                          size: 40,
                                          color: Colors.white70,
                                        ),
                                      ),
                                      const Positioned(
                                        bottom: 8,
                                        right: 8,
                                        child: Icon(
                                          Icons.videocam,
                                          size: 20,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  )
                                : Image.network(
                                    url,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        color: Colors.grey[200],
                                        child: const Icon(
                                          Icons.broken_image,
                                          color: Colors.grey,
                                          size: 30,
                                        ),
                                      );
                                    },
                                  ),
                          ),
                        ),
                        // Tap indicator overlay
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              color: Colors.black.withOpacity(0.1),
                            ),
                            child: const Icon(
                              Icons.zoom_in,
                              color: Colors.white70,
                              size: 24,
                            ),
                          ),
                        ),
                      ],
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

  bool _isVideoUrl(String url) {
    final videoExtensions = ['.mp4', '.mov', '.avi', '.mkv', '.webm'];
    return videoExtensions.any((ext) => url.toLowerCase().endsWith(ext));
  }

  void _openFullScreenMedia(String mediaUrl, bool isImage, bool isVideo) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => FullScreenMediaViewer(
          mediaUrl: mediaUrl,
          isImage: isImage,
          isVideo: isVideo,
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

  void _makeVideoCall(String phoneNumber) async {
    // Try FaceTime first, then fall back to regular call
    final facetimeUri = Uri.parse('facetime:$phoneNumber');
    if (await canLaunchUrl(facetimeUri)) {
      await launchUrl(facetimeUri);
    } else {
      // Fallback to regular phone call if FaceTime isn't available
      _makePhoneCall(phoneNumber);
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
