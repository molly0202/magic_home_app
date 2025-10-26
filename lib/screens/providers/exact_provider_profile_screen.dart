import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/reviews_service.dart';
import '../../widgets/translatable_text.dart';

class ExactProviderProfileScreen extends StatefulWidget {
  final String providerId;
  final String? providerName;

  const ExactProviderProfileScreen({
    super.key,
    required this.providerId,
    this.providerName,
  });

  @override
  State<ExactProviderProfileScreen> createState() => _ExactProviderProfileScreenState();
}

class _ExactProviderProfileScreenState extends State<ExactProviderProfileScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('providers').doc(widget.providerId).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Scaffold(
              appBar: AppBar(
                backgroundColor: const Color(0xFFFBB04C),
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                title: Text(
                  widget.providerName ?? 'Provider Profile',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              body: const Center(
                child: CircularProgressIndicator(color: Color(0xFFFBB04C)),
              ),
            );
          }
          
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return Scaffold(
              appBar: AppBar(
                backgroundColor: const Color(0xFFFBB04C),
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                title: const Text('Provider Profile'),
              ),
              body: const Center(child: Text('Provider not found')),
            );
          }
          
          final data = snapshot.data!.data() as Map<String, dynamic>;
          
          return SafeArea(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // Storefront Header (exactly like HSP)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(20),
                        bottomRight: Radius.circular(20),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 10,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Back button
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.arrow_back, color: Colors.black87),
                              onPressed: () => Navigator.pop(context),
                            ),
                            const Spacer(),
                          ],
                        ),
                        
                        // Profile Photo (exactly like HSP)
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFFFBB04C),
                              width: 3,
                            ),
                          ),
                          child: ClipOval(
                            child: data['profileImageUrl'] != null
                                ? Image.network(
                                    data['profileImageUrl'],
                                    width: 120,
                                    height: 120,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        color: Colors.grey[300],
                                        child: const Icon(
                                          Icons.business,
                                          size: 50,
                                          color: Colors.grey,
                                        ),
                                      );
                                    },
                                  )
                                : Container(
                                    color: Colors.grey[300],
                                    child: const Icon(
                                      Icons.business,
                                      size: 50,
                                      color: Colors.grey,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        // Company Name
                        Text(
                          data['companyName'] ?? 'Business Name',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),
                        
                        // Legal Representative
                        Text(
                          data['legalRepresentativeName'] ?? 'Representative Name',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        // Rating and Stats (using thumbs up system)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildStatItem('${data['thumbs_up_count'] ?? 0}', 'Thumbs Up', Icons.thumb_up, Colors.green),
                            _buildStatItem('${data['total_jobs_completed'] ?? 0}', 'Jobs Done', Icons.work, Colors.blue),
                            _buildStatItem('${_calculateSuccessRate(data)}%', 'Success Rate', Icons.trending_up, Colors.orange),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Services Offered Section
                  _buildServicesOffered(data),
                  
                  const SizedBox(height: 20),
                  
                  // Team Members Section
                  _buildTeamMembers(data),
                  
                  const SizedBox(height: 20),
                  
                  // Recommended Users Section
                  _buildRecommendedUsers(data),
                  
                  const SizedBox(height: 20),
                  
                  // Work Showcase Section
                  _buildWorkShowcase(data),
                  
                  const SizedBox(height: 20),
                  
                  // Company Description Section
                  _buildCompanyDescription(data),
                  
                  const SizedBox(height: 20),
                  
                  // Reviews Section
                  _buildReviews(),
                  
                  const SizedBox(height: 40),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatItem(String value, String label, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        TranslatableText(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildServicesOffered(Map<String, dynamic> data) {
    final services = data['services'] as List<dynamic>? ?? [];
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.build, color: Color(0xFFFBB04C), size: 24),
              SizedBox(width: 8),
              Text(
                'Services Offered',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          if (services.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: Text(
                  'No services listed yet',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: services.map<Widget>((service) {
                final serviceName = service['name'] ?? 'Service';
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFBB04C).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFFBB04C).withOpacity(0.3)),
                  ),
                  child: Text(
                    serviceName,
                    style: const TextStyle(
                      color: Color(0xFFFBB04C),
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildTeamMembers(Map<String, dynamic> data) {
    final employees = data['employees'] as List<dynamic>? ?? [];
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.group, color: Color(0xFFFBB04C), size: 24),
              SizedBox(width: 8),
              Text(
                'Our Team',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          if (employees.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: Text(
                  'No team members listed yet',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            )
          else
            Column(
              children: employees.map<Widget>((employee) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Row(
                    children: [
                      // Employee photo
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFFFBB04C), width: 2),
                        ),
                        child: ClipOval(
                          child: employee['photoUrl'] != null
                              ? Image.network(
                                  employee['photoUrl'],
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      color: Colors.grey[300],
                                      child: const Icon(Icons.person, color: Colors.grey),
                                    );
                                  },
                                )
                              : Container(
                                  color: Colors.grey[300],
                                  child: const Icon(Icons.person, color: Colors.grey),
                                ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      
                      // Employee info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              employee['name'] ?? 'Team Member',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            if (employee['role'] != null)
                              Text(
                                employee['role'],
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                ),
                              ),
                            if (employee['bio'] != null && employee['bio'].isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  employee['bio'],
                                  style: TextStyle(
                                    color: Colors.grey[700],
                                    fontSize: 12,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildRecommendedUsers(Map<String, dynamic> data) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const TranslatableText(
            'Recommended by',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          
          // Use actual referral data from Magic Home
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _getReferralUsers(data['referred_by_user_ids']),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: Color(0xFFFBB04C)));
              }
              
              final referralUsers = snapshot.data ?? [];
              
              if (referralUsers.isEmpty) {
                return Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.people_outline,
                        size: 48,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'No recommendations yet',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                );
              }
              
              return SizedBox(
                height: 80,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: referralUsers.length,
                  itemBuilder: (context, index) {
                    final user = referralUsers[index];
                    final displayName = user['displayName'] ?? user['name'] ?? 'User';
                    final photoUrl = user['photoURL'] ?? user['profileImageUrl'];
                    
                    return Container(
                      width: 80,
                      margin: const EdgeInsets.only(right: 12),
                      child: Column(
                        children: [
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: const Color(0xFFFBB04C), width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: ClipOval(
                              child: photoUrl != null
                                  ? Image.network(
                                      photoUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) {
                                        return Container(
                                          color: const Color(0xFFFBB04C).withOpacity(0.1),
                                          child: Icon(
                                            Icons.person,
                                            color: const Color(0xFFFBB04C),
                                            size: 30,
                                          ),
                                        );
                                      },
                                    )
                                  : Container(
                                      color: const Color(0xFFFBB04C).withOpacity(0.1),
                                      child: Icon(
                                        Icons.person,
                                        color: const Color(0xFFFBB04C),
                                        size: 30,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _getShortName(displayName),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildWorkShowcase(Map<String, dynamic> data) {
    final showcasePhotos = data['workShowcasePhotos'] as List<dynamic>? ?? [];
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.photo_library, color: Color(0xFFFBB04C), size: 24),
              SizedBox(width: 8),
              Text(
                'Our Work',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          if (showcasePhotos.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: Text(
                  'No work photos available yet',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 1,
              ),
              itemCount: showcasePhotos.length,
              itemBuilder: (context, index) {
                final photoUrl = showcasePhotos[index];
                return GestureDetector(
                  onTap: () {
                    // Show full screen image
                    _showFullScreenImage(context, photoUrl);
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        photoUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Colors.grey[200],
                            child: const Icon(
                              Icons.image,
                              color: Colors.grey,
                              size: 40,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  void _showFullScreenImage(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            Center(
              child: Image.network(
                imageUrl,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return const Text(
                    'Failed to load image',
                    style: TextStyle(color: Colors.white),
                  );
                },
              ),
            ),
            Positioned(
              top: 40,
              right: 20,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompanyDescription(Map<String, dynamic> data) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const TranslatableText(
            'About Our Service',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            data['companyDescription'] ?? 'No description available.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }



  Widget _buildReviews() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const TranslatableText(
            'Customer Reviews',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          
          // Load actual reviews from database (same as HSP)
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _loadProviderReviews(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(
                      color: Color(0xFFFBB04C),
                    ),
                  ),
                );
              }

              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.rate_review_outlined,
                        size: 48,
                        color: Colors.grey[500],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No Reviews Yet',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[700],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Customer reviews will appear here',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                );
              }

              return Column(
                children: snapshot.data!
                    .map((review) => _buildReviewCard(review))
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _loadProviderReviews() async {
    try {
      print('🔍 Loading reviews for provider: ${widget.providerId}');
      
      // First, try to get reviews using the ReviewsService (same as HSP)
      final reviews = await ReviewsService.getRecentReviewsWithDistance(
        currentUserLocation: null, // Customer doesn't need distance sorting
        limit: 10,
      );
      
      // Convert to thumbs up/down format
      final convertedReviews = reviews.map((review) {
        return {
          ...review,
          'thumbsUp': review['thumbsUp'] ?? review['rating'] != 1, // Convert rating to thumbs
        };
      }).toList();
      
      print('✅ Loaded ${convertedReviews.length} reviews from ReviewsService');
      return convertedReviews;
      
    } catch (e) {
      print('❌ Error loading provider reviews: $e');
      
      // Fallback: Try to get reviews from service_orders collection
      try {
        print('🔄 Fallback: Loading reviews from service_orders...');
        
        final ordersSnapshot = await FirebaseFirestore.instance
            .collection('service_orders')
            .where('provider_id', isEqualTo: widget.providerId)
            .where('status', isEqualTo: 'completed')
            .orderBy('created_at', descending: true)
            .limit(5)
            .get();
        
        final orderReviews = ordersSnapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'customerName': data['customer_name'] ?? 'Customer',
            'reviewText': data['review_text'] ?? data['feedback'] ?? '',
            'thumbsUp': data['thumbs_up'] ?? data['rating'] != 1, // Assume thumbs up unless explicitly thumbs down
            'serviceCategory': data['service_category'] ?? 'Service',
            'createdAt': data['created_at'],
            'photoUrls': data['photo_urls'] ?? [],
          };
        }).toList();
        
        print('✅ Loaded ${orderReviews.length} reviews from service_orders');
        return orderReviews;
        
      } catch (e2) {
        print('❌ Fallback also failed: $e2');
        return [];
      }
    }
  }

  Widget _buildReviewCard(Map<String, dynamic> review) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with customer info and rating
          Row(
            children: [
              // Customer avatar
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.grey[300],
                ),
                child: Icon(
                  Icons.person,
                  color: Colors.grey[600],
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              
              // Customer name and service
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      review['customerName'] ?? 'Customer',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    if (review['serviceCategory'] != null)
                      Text(
                        review['serviceCategory'],
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                  ],
                ),
              ),
              
              // Thumbs up/down (using app's actual rating system)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: (review['thumbsUp'] == true ? Colors.green : Colors.red).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      review['thumbsUp'] == true ? Icons.thumb_up : Icons.thumb_down,
                      color: review['thumbsUp'] == true ? Colors.green : Colors.red,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      review['thumbsUp'] == true ? 'Thumbs Up' : 'Thumbs Down',
                      style: TextStyle(
                        fontSize: 12,
                        color: review['thumbsUp'] == true ? Colors.green : Colors.red,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Review text
          if (review['reviewText'] != null && review['reviewText'].isNotEmpty)
            Text(
              review['reviewText'],
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[800],
                height: 1.4,
              ),
            ),
          
          // Photos if available
          if (review['photoUrls'] != null && (review['photoUrls'] as List).isNotEmpty) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 80,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: (review['photoUrls'] as List).length,
                itemBuilder: (context, index) {
                  final photoUrl = (review['photoUrls'] as List)[index];
                  return Container(
                    width: 80,
                    margin: const EdgeInsets.only(right: 8),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        photoUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Colors.grey[200],
                            child: const Icon(Icons.image, color: Colors.grey),
                          );
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
          
          const SizedBox(height: 8),
          
          // Footer with date
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatReviewDate(review['createdAt']),
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[500],
                ),
              ),
              if (review['photoUrls'] != null && (review['photoUrls'] as List).isNotEmpty)
                Text(
                  '${(review['photoUrls'] as List).length} photo${(review['photoUrls'] as List).length > 1 ? 's' : ''}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatReviewDate(dynamic createdAt) {
    if (createdAt == null) return 'Recently';
    
    try {
      DateTime date;
      if (createdAt is Timestamp) {
        date = createdAt.toDate();
      } else if (createdAt is DateTime) {
        date = createdAt;
      } else {
        return 'Recently';
      }
      
      final now = DateTime.now();
      final difference = now.difference(date);
      
      if (difference.inDays > 0) {
        return '${difference.inDays}d ago';
      } else if (difference.inHours > 0) {
        return '${difference.inHours}h ago';
      } else {
        return 'Recently';
      }
    } catch (e) {
      return 'Recently';
    }
  }

  Future<List<Map<String, dynamic>>> _getReferralUsers(dynamic referredByUserIds) async {
    if (referredByUserIds == null) return [];
    
    final userIds = List<String>.from(referredByUserIds);
    if (userIds.isEmpty) return [];
    
    try {
      final users = <Map<String, dynamic>>[];
      
      print('🔍 Loading referral users for Magic Home: $userIds');
      
      for (final userId in userIds.take(10)) { // Limit to 10 users
        try {
          final userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
          if (userDoc.exists) {
            final userData = userDoc.data() as Map<String, dynamic>;
            users.add({
              'id': userId,
              'displayName': userData['displayName'] ?? userData['name'] ?? 'User',
              'photoURL': userData['photoURL'] ?? userData['profileImageUrl'],
              'email': userData['email'],
            });
            print('✅ Loaded user: ${userData['displayName'] ?? 'User'}');
          } else {
            print('❌ User not found: $userId');
            // Add placeholder for missing users
            users.add({
              'id': userId,
              'displayName': 'User',
              'photoURL': null,
            });
          }
        } catch (e) {
          print('❌ Error loading user $userId: $e');
          // Add placeholder for error cases
          users.add({
            'id': userId,
            'displayName': 'User',
            'photoURL': null,
          });
        }
      }
      
      print('✅ Total referral users loaded: ${users.length}');
      return users;
    } catch (e) {
      print('❌ Error loading referral users: $e');
      return [];
    }
  }

  String _getShortName(String fullName) {
    final parts = fullName.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0]} ${parts[1].substring(0, 1)}.';
    }
    return parts[0].length > 8 ? '${parts[0].substring(0, 8)}...' : parts[0];
  }

  int _calculateSuccessRate(Map<String, dynamic> data) {
    final totalJobs = data['total_jobs_completed'] ?? 0;
    final thumbsUp = data['thumbs_up_count'] ?? 0;
    
    if (totalJobs == 0) return 0;
    
    return ((thumbsUp / totalJobs) * 100).round();
  }

  void _makePhoneCall(String phoneNumber) async {
    final uri = Uri.parse('tel:$phoneNumber');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }
}
