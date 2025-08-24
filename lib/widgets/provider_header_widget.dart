import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ProviderHeaderWidget extends StatelessWidget {
  final String providerId;
  final bool showMatchReasons;
  final bool showContactButton;

  const ProviderHeaderWidget({
    Key? key,
    required this.providerId,
    this.showMatchReasons = false,
    this.showContactButton = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('providers')
          .doc(providerId)
          .get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingState();
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return _buildErrorState();
        }

        final providerData = snapshot.data!.data() as Map<String, dynamic>;
        return _buildProviderHeader(context, providerData);
      },
    );
  }

  Widget _buildLoadingState() {
    return Container(
      padding: EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 16,
                  width: 120,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                SizedBox(height: 8),
                Container(
                  height: 12,
                  width: 80,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Container(
      padding: EdgeInsets.all(16),
      child: Row(
        children: [
          CircleAvatar(
            radius: 25,
            backgroundColor: Colors.grey[300],
            child: Icon(Icons.person, color: Colors.grey[600]),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Provider Information",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  "Unable to load provider details",
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
    );
  }

  Widget _buildProviderHeader(BuildContext context, Map<String, dynamic> providerData) {
    final companyName = providerData['companyName'] ?? 'Service Provider';
    final businessType = providerData['businessType'] ?? 'General Services';
    final rating = (providerData['rating'] ?? 4.5).toDouble();
    final reviewCount = providerData['reviewCount'] ?? 0;
    final yearsInBusiness = providerData['yearsInBusiness'] ?? 1;
    final isVerified = providerData['status'] == 'verified' || providerData['status'] == 'active';
    final profileImageUrl = providerData['profileImageUrl'];
    final serviceAreas = List<String>.from(providerData['serviceAreas'] ?? []);
    final specialties = List<String>.from(providerData['specialties'] ?? []);

    return Container(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Provider avatar
              _buildProviderAvatar(profileImageUrl, isVerified),
              
              SizedBox(width: 12),
              
              // Provider info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            companyName,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.grey[800],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isVerified)
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.verified, size: 12, color: Colors.green),
                                SizedBox(width: 2),
                                Text(
                                  'VERIFIED',
                                  style: TextStyle(
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    
                    SizedBox(height: 4),
                    
                    Text(
                      businessType,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    
                    SizedBox(height: 6),
                    
                    // Rating and experience row
                    Row(
                      children: [
                        _buildRatingWidget(rating, reviewCount),
                        SizedBox(width: 12),
                        _buildExperienceWidget(yearsInBusiness),
                      ],
                    ),
                  ],
                ),
              ),
              
              // Contact button if enabled
              if (showContactButton)
                IconButton(
                  onPressed: () => _showContactOptions(context, providerData),
                  icon: Icon(Icons.message, color: Theme.of(context).primaryColor),
                  tooltip: 'Contact Provider',
                ),
            ],
          ),
          
          // Match reasons if enabled
          if (showMatchReasons) ...[
            SizedBox(height: 12),
            _buildMatchReasons(serviceAreas, specialties),
          ],
          
          // Specialties chips
          if (specialties.isNotEmpty) ...[
            SizedBox(height: 12),
            _buildSpecialtiesChips(specialties),
          ],
        ],
      ),
    );
  }

  Widget _buildProviderAvatar(String? profileImageUrl, bool isVerified) {
    return Stack(
      children: [
        CircleAvatar(
          radius: 25,
          backgroundColor: Colors.grey[300],
          backgroundImage: profileImageUrl != null && profileImageUrl.isNotEmpty
              ? NetworkImage(profileImageUrl)
              : null,
          child: profileImageUrl == null || profileImageUrl.isEmpty
              ? Icon(Icons.business, color: Colors.grey[600], size: 24)
              : null,
        ),
        if (isVerified)
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: Icon(
                Icons.check,
                size: 10,
                color: Colors.white,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildRatingWidget(double rating, int reviewCount) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.star, size: 14, color: Colors.amber),
        SizedBox(width: 2),
        Text(
          rating.toStringAsFixed(1),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.grey[700],
          ),
        ),
        SizedBox(width: 4),
        Text(
          '($reviewCount)',
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildExperienceWidget(int yearsInBusiness) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '${yearsInBusiness}yr${yearsInBusiness != 1 ? 's' : ''} exp',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: Colors.blue,
        ),
      ),
    );
  }

  Widget _buildMatchReasons(List<String> serviceAreas, List<String> specialties) {
    final reasons = <String>[];
    
    if (serviceAreas.isNotEmpty) {
      reasons.add('Serves your area');
    }
    if (specialties.isNotEmpty) {
      reasons.add('Relevant expertise');
    }
    reasons.addAll(['Highly rated', 'Quick response time']);

    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.psychology, size: 14, color: Colors.blue),
              SizedBox(width: 6),
              Text(
                'Why this provider matches:',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.blue[700],
                ),
              ),
            ],
          ),
          SizedBox(height: 6),
          ...reasons.map((reason) => Padding(
            padding: EdgeInsets.only(bottom: 2),
            child: Row(
              children: [
                Icon(Icons.check, size: 12, color: Colors.green),
                SizedBox(width: 6),
                Text(
                  reason,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
          )).toList(),
        ],
      ),
    );
  }

  Widget _buildSpecialtiesChips(List<String> specialties) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Specialties:',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
          ),
        ),
        SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: specialties.take(4).map((specialty) => Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.withOpacity(0.3)),
            ),
            child: Text(
              specialty,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: Colors.orange[700],
              ),
            ),
          )).toList(),
        ),
        if (specialties.length > 4)
          Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text(
              '+${specialties.length - 4} more',
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
      ],
    );
  }

  void _showContactOptions(BuildContext context, Map<String, dynamic> providerData) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Contact ${providerData['companyName'] ?? 'Provider'}',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 20),
            ListTile(
              leading: Icon(Icons.message, color: Colors.blue),
              title: Text('Send Message'),
              subtitle: Text('Chat directly with the provider'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Implement chat functionality
              },
            ),
            ListTile(
              leading: Icon(Icons.phone, color: Colors.green),
              title: Text('Call Provider'),
              subtitle: Text(providerData['phoneNumber'] ?? 'Phone not available'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Implement call functionality
              },
            ),
            ListTile(
              leading: Icon(Icons.email, color: Colors.orange),
              title: Text('Send Email'),
              subtitle: Text('Contact via email'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Implement email functionality
              },
            ),
          ],
        ),
      ),
    );
  }
}
