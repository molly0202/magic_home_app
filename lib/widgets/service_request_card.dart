import 'package:flutter/material.dart';
import '../models/user_request.dart';
import 'full_screen_media_viewer.dart';
import 'translatable_text.dart';

class ServiceRequestCard extends StatelessWidget {
  final UserRequest userRequest;

  const ServiceRequestCard({
    Key? key,
    required this.userRequest,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      margin: EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    userRequest.serviceCategory.toUpperCase(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                ),
                Spacer(),
                if (userRequest.priority != null && userRequest.priority! > 3)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.priority_high, size: 14, color: Colors.red),
                        SizedBox(width: 4),
                        Text(
                          'URGENT',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            
            SizedBox(height: 12),
            
            // Service Description
            TranslatableText(
              'Service Details',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            SizedBox(height: 8),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: TranslatableText(
                userRequest.description,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  color: Colors.grey[700],
                ),
              ),
            ),
            
            SizedBox(height: 16),
            
            // Location & Availability
            _buildInfoRow(
              icon: Icons.location_on,
              label: 'Location',
              value: _formatLocation(),
              color: Colors.blue,
            ),
            
            SizedBox(height: 8),
            
            _buildInfoRow(
              icon: Icons.schedule,
              label: 'Customer Availability',
              value: _formatAvailability(),
              color: Colors.green,
            ),
            
            // Media attachments if any
            if (userRequest.mediaUrls.isNotEmpty) ...[
              SizedBox(height: 16),
              TranslatableText(
                'Attachments',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              SizedBox(height: 8),
              _buildMediaPreview(),
            ],
            
            // Customer preferences
            if (userRequest.preferences != null && userRequest.preferences!.isNotEmpty) ...[
              SizedBox(height: 16),
              TranslatableText(
                'Customer Preferences',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              SizedBox(height: 8),
              _buildPreferences(),
            ],
            
            // Tags if available
            if (userRequest.tags != null && userRequest.tags!.isNotEmpty) ...[
              SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: userRequest.tags!.map((tag) => Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TranslatableText(
                    tag,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.blue[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                )).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TranslatableText(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 2),
              TranslatableText(
                value,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[800],
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMediaPreview() {
    return Container(
      height: 80,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: userRequest.mediaUrls.length,
        itemBuilder: (context, index) {
          final url = userRequest.mediaUrls[index];
          final isImage = url.toLowerCase().contains(RegExp(r'\.(jpg|jpeg|png|gif|webp)'));
          final isVideo = url.toLowerCase().contains(RegExp(r'\.(mp4|mov|avi|mkv)'));
          
          return GestureDetector(
            onTap: () => _showFullScreenMedia(context, url, isImage, isVideo),
            child: Container(
              width: 80,
              margin: EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: isImage
                        ? Image.network(
                            url,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                            errorBuilder: (context, error, stackTrace) => 
                                _buildMediaPlaceholder(Icons.broken_image),
                          )
                        : _buildMediaPlaceholder(isVideo ? Icons.play_circle_filled : Icons.attachment),
                  ),
                  // Tap indicator
                  Positioned(
                    bottom: 4,
                    right: 4,
                    child: Container(
                      padding: EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Icon(
                        isVideo ? Icons.play_arrow : Icons.zoom_in,
                        color: Colors.white,
                        size: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showFullScreenMedia(BuildContext context, String url, bool isImage, bool isVideo) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FullScreenMediaViewer(
          mediaUrl: url,
          isImage: isImage,
          isVideo: isVideo,
        ),
      ),
    );
  }

  Widget _buildMediaPlaceholder(IconData icon) {
    return Container(
      color: Colors.grey[200],
      child: Center(
        child: Icon(icon, color: Colors.grey[500], size: 24),
      ),
    );
  }

  Widget _buildPreferences() {
    final preferences = userRequest.preferences!;
    
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.amber.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: preferences.entries.map((entry) {
          return Padding(
            padding: EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                Icon(
                  _getPreferenceIcon(entry.key),
                  size: 14,
                  color: Colors.amber[700],
                ),
                SizedBox(width: 8),
                TranslatableText(
                  '${_formatPreferenceKey(entry.key)}: ',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                  ),
                ),
                Expanded(
                  child: TranslatableText(
                    entry.value.toString(),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  String _formatLocation() {
    if (userRequest.location != null && userRequest.location!['formatted_address'] != null) {
      return userRequest.location!['formatted_address'];
    }
    return userRequest.address.isNotEmpty ? userRequest.address : 'Location provided upon acceptance';
  }

  String _formatAvailability() {
    final availability = userRequest.userAvailability;
    
    // Debug logging
    print('🔍 DEBUG - userAvailability: $availability');
    print('🔍 DEBUG - aiPriceEstimation: ${userRequest.aiPriceEstimation}');
    print('🔍 DEBUG - preferences: ${userRequest.preferences}');
    
    if (availability.isEmpty) return 'Flexible';
    
    // Try to format common availability patterns
    if (availability['preferredTime'] != null) {
      return availability['preferredTime'].toString();
    }
    
    if (availability['timeSlots'] != null) {
      final slots = availability['timeSlots'] as List;
      if (slots.isNotEmpty) {
        return slots.join(', ');
      }
    }
    
    return availability.toString().replaceAll('{', '').replaceAll('}', '');
  }

  IconData _getPreferenceIcon(String key) {
    switch (key.toLowerCase()) {
      case 'urgency':
        return Icons.schedule;
      case 'budget':
      case 'price_range':
        return Icons.attach_money;
      case 'quality':
        return Icons.star;
      case 'experience':
        return Icons.work;
      default:
        return Icons.info;
    }
  }

  String _formatPreferenceKey(String key) {
    return key
        .replaceAll('_', ' ')
        .split(' ')
        .map((word) => word.isEmpty ? '' : word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }
}
