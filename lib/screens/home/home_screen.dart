import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../services/auth_service.dart';
import '../../screens/auth/welcome_screen.dart';
import '../../screens/ai_task_intake_screen.dart';
import '../matching/provider_matching_test_screen.dart';
import '../bidding/bid_comparison_screen.dart';
import '../../services/bidding_service.dart';
import '../../models/user_request.dart';
import '../../models/bidding_session.dart';
import '../tasks/my_tasks_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../services/reviews_service.dart';
import '../../widgets/translatable_text.dart';
import '../../services/in_app_notification_service.dart';
import '../../services/notification_service.dart';
import '../social/full_screen_post_screen.dart';
import 'dart:io';

class HomeScreen extends StatefulWidget {
  final firebase_auth.User? firebaseUser;
  final GoogleSignInAccount? googleUser;
  final GoogleSignIn? googleSignIn;

  const HomeScreen({
    super.key,
    this.firebaseUser,
    this.googleUser,
    this.googleSignIn,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  final AuthService _authService = AuthService();
  final ImagePicker _picker = ImagePicker();
  bool _isUpdatingPhoto = false;

  @override
  void initState() {
    super.initState();
    // Initialize in-app notifications when home screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      InAppNotificationService().initialize(context);
      
      // Save FCM token for authenticated user
      if (widget.firebaseUser != null) {
        NotificationService.saveFCMTokenForUser(widget.firebaseUser!.uid);
      }
    });
  }
  
  String? get _displayName {
    if (widget.googleUser != null) {
      return widget.googleUser!.displayName ?? 'User';
    } else if (widget.firebaseUser != null) {
      return widget.firebaseUser!.displayName ?? 'User';
    }
    return 'User';
  }

  String? get _displayEmail {
    if (widget.googleUser != null) {
      return widget.googleUser!.email;
    } else if (widget.firebaseUser != null) {
      return widget.firebaseUser!.email;
    }
    return null;
  }

  Future<String> _getUserDisplayName() async {
    try {
      if (widget.firebaseUser != null) {
        // Get user's actual name from Firebase
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.firebaseUser!.uid)
            .get();
        
        if (userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>;
          final name = userData['name'] as String?;
          if (name != null && name.isNotEmpty) {
            return name;
          }
        }
      }
      
      // Fallback to display name or email
      return _displayName ?? widget.firebaseUser?.email?.split('@')[0] ?? 'User';
    } catch (e) {
      print('Error getting user display name: $e');
      return _displayName ?? 'User';
    }
  }



  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = [
      _buildHomeScreen(),      // 0: Home
      _buildDiscoverScreen(),  // 1: Discover  
      _buildTasksScreen(),     // 2: Tasks
      _buildFriendsScreen(),   // 3: Friends (My Connections)
      _buildProfileScreen(),   // 4: Profile
    ];

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        backgroundColor: Colors.white,
        selectedItemColor: const Color(0xFFFBB04C),
        unselectedItemColor: Colors.grey[600],
        selectedFontSize: 12,
        unselectedFontSize: 11,
        iconSize: 26,
        elevation: 10,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.explore),
            label: 'Discover',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.assignment),
            label: 'Tasks',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people),
            label: 'Friends',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavItem(int index, IconData icon, String label) {
    final isSelected = _selectedIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedIndex = index),
        child: SizedBox(
          height: 72, // Fixed height that definitely fits
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Simple icon with background
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFFFBB04C).withOpacity(0.15) : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  icon,
                  color: isSelected ? const Color(0xFFFBB04C) : Colors.grey[600],
                  size: 24,
                ),
              ),
              const SizedBox(height: 4),
              // Compact label
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? const Color(0xFFFBB04C) : Colors.grey[600],
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
                maxLines: 1,
                overflow: TextOverflow.clip,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingFAB() {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFFBB04C),
            const Color(0xFFFBB04C).withOpacity(0.9),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFBB04C).withOpacity(0.4),
            blurRadius: 12,
            offset: const Offset(0, 6),
            spreadRadius: 1,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(30),
        child: InkWell(
          borderRadius: BorderRadius.circular(30),
          onTap: _onCreateServiceRequest,
          child: const Icon(
            Icons.add,
            color: Colors.white,
            size: 32,
          ),
        ),
      ),
    );
  }

  Widget _buildHomeScreen() {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Column(
        children: [
          // Sticky/frozen header on top
          _buildHeader(),
          
          // Scrollable content below header
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _buildPromotionalCarousel(),
                  const SizedBox(height: 12), // Reduced spacing
                  
                  // Prominent "Start a New Task" button
                  _buildStartNewTaskButton(),
                  
                  const SizedBox(height: 0), // No gap - posts directly below button
                  _buildServiceProviderFeed(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12), // Better positioning - less top padding
      decoration: const BoxDecoration(
        color: Colors.white,
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Simple user greeting
            FutureBuilder<String>(
              future: _getUserDisplayName(),
              builder: (context, snapshot) {
                final userName = snapshot.data ?? _displayName ?? 'User';
                return Text(
                  'Hello, $userName',
                  style: const TextStyle(
                    color: Color(0xFFFBB04C), // Orange/yellow color
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                );
              },
            ),
            
            // + button for creating posts
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFFFBB04C), // Orange/yellow background
                borderRadius: BorderRadius.circular(18),
              ),
              child: IconButton(
                onPressed: () {
                  // Navigate to create post screen (placeholder for now)
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Create post feature coming soon!'),
                      backgroundColor: Color(0xFFFBB04C),
                    ),
                  );
                },
                icon: const Icon(
                  Icons.add,
                  color: Colors.white, // White icon on orange background
                  size: 20,
                ),
                padding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPromotionalCarousel() {
    final promoData = [
      {
        'title': 'DEEP CLEANING SERVICE',
        'discount': '10% OFF',
        'promoCode': 'DCFS',
        'description': 'Professional deep cleaning for your home',
        'image': 'https://images.unsplash.com/photo-1581578731548-c64695cc6952?w=400',
      },
      {
        'title': 'HANDYMAN SERVICES', 
        'discount': '15% OFF',
        'promoCode': 'HANDY15',
        'description': 'Expert handyman for all your home repairs',
        'image': 'https://images.unsplash.com/photo-1621905251918-48416bd8575a?w=400',
      },
      {
        'title': 'GARDEN MAINTENANCE',
        'discount': '20% OFF', 
        'promoCode': 'GARDEN20',
        'description': 'Keep your garden beautiful year-round',
        'image': 'https://images.unsplash.com/photo-1416879595882-3373a0480b5b?w=400',
      },
    ];

    return Column(
      children: [
        Container(
          height: 140, // Smaller height
          margin: const EdgeInsets.symmetric(vertical: 16),
          child: PageView.builder(
            controller: PageController(viewportFraction: 0.75), // Show 1.5 banners
            itemCount: promoData.length,
            itemBuilder: (context, index) {
              final promo = promoData[index];
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: const LinearGradient(
                colors: [Color(0xFFF5F5F5), Colors.white],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  spreadRadius: 0,
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Row(
              children: [
                // Left side - Text content
                Expanded(
                  flex: 3,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'sendhelper',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          promo['title']!,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          promo['discount']!,
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'ENTER PROMO CODE',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          promo['promoCode']!,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFFBB04C),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Right side - Image
                Expanded(
                  flex: 2,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.horizontal(right: Radius.circular(20)),
                    child: Image.network(
                      promo['image']!,
                      fit: BoxFit.cover,
                      height: double.infinity,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: Colors.grey[300],
                        child: const Icon(Icons.image, size: 40, color: Colors.grey),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    ),
    
    // Gray dots indicator
    const SizedBox(height: 12),
    Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        promoData.length,
        (index) => Container(
          width: 8,
          height: 8,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: Colors.grey[400], // Gray dots
            shape: BoxShape.circle,
          ),
        ),
      ),
    ),
    ],
    );
  }

  Widget _buildPromotionalBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      height: 200,
      child: PageView(
        children: [
          _buildPromoBanner(
            'DEEP CLEANING SERVICE',
            '10% OFF',
            'ENTER PROMO CODE',
            'DCFS',
            'Book to 30th July 2024\nService period: 21th July - 31st August 2024',
            'https://images.unsplash.com/photo-1558618666-fcd25c85cd64?w=400',
          ),
          _buildPromoBanner(
            'GARDEN MAINTENANCE',
            '15% OFF',
            'ENTER PROMO CODE',
            'GARDEN15',
            'Professional landscaping services\nTransform your outdoor space',
            'https://images.unsplash.com/photo-1416879595882-3373a0480b5b?w=400',
          ),
        ],
      ),
    );
  }

  Widget _buildPromoBanner(String title, String discount, String promoText, 
                          String promoCode, String description, String imageUrl) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFFF5F5F5), Colors.white],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            spreadRadius: 0,
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.all(16), // Reduced padding
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const TranslatableText(
                      'sendhelper',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    TranslatableText(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    TranslatableText(
                      discount,
                      style: const TextStyle(
                        fontSize: 32, // Reduced from 36
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    TranslatableText(
                      promoText,
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    TranslatableText(
                      promoCode,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFFBB04C),
                      ),
                    ),
                    const SizedBox(height: 6),
                    TranslatableText(
                      description,
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.grey,
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: ClipRRect(
              borderRadius: const BorderRadius.horizontal(right: Radius.circular(20)),
              child: Container(
                height: double.infinity,
                decoration: BoxDecoration(
                  image: DecorationImage(
                    image: NetworkImage(imageUrl),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStartNewTaskButton() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFBB04C), Color(0xFFFF8C42)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFBB04C).withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
            spreadRadius: 2,
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        height: 60,
        child: ElevatedButton.icon(
          onPressed: _onCreateServiceRequest,
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.smart_toy, // Robot icon
              color: Colors.white,
              size: 24,
            ),
          ),
          label: const TranslatableText(
            'Start a New Task',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildServiceProviderFeed() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _loadRecentReviews(),
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
            margin: const EdgeInsets.symmetric(horizontal: 20),
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
                  'Be the first to share your experience!',
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

        return _build2ColumnPostsGrid(snapshot.data!);
      },
    );
  }

  Widget _build2ColumnPostsGrid(List<Map<String, dynamic>> reviews) {
    return Transform.translate(
      offset: const Offset(0, -8), // Pull posts up by 8px to eliminate gap
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 0), // No top padding - connect directly to button
        child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 6, // Reduced from 8 to 6
          mainAxisSpacing: 8,  // Reduced from 12 to 8
          childAspectRatio: 0.55, // Even taller cards for portrait photos
        ),
        itemCount: reviews.length,
        itemBuilder: (context, index) {
          return _buildCompactPostCard(reviews[index]);
        },
      ),
    ),
    );
  }

  Widget _buildCompactPostCard(Map<String, dynamic> review) {
    return GestureDetector(
      onTap: () => _openFullScreenPost(review),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image section with proper aspect ratio
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: AspectRatio(
              aspectRatio: 3/4, // Portrait ratio (width smaller than height)
              child: Container(
                width: double.infinity,
                child: review['photoUrls'] != null && 
                       (review['photoUrls'] as List).isNotEmpty
                    ? Image.network(
                        (review['photoUrls'] as List)[0],
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: Colors.grey[200],
                          child: const Icon(Icons.image, size: 40, color: Colors.grey),
                        ),
                      )
                    : Container(
                        color: Colors.grey[200],
                        child: const Icon(Icons.image, size: 40, color: Colors.grey),
                      ),
              ),
            ),
          ),
          
          // Content section
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // User info
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 12,
                        backgroundImage: review['customerAvatar'] != null
                            ? NetworkImage(review['customerAvatar'])
                            : null,
                        backgroundColor: Colors.grey[300],
                        child: review['customerAvatar'] == null
                            ? Icon(Icons.person, color: Colors.grey[600], size: 14)
                            : null,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          review['customerName'] ?? 'Anonymous',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      FutureBuilder<int>(
                        future: _getPostLikeCount(review['reviewId'] ?? review['id']),
                        builder: (context, snapshot) {
                          final likeCount = snapshot.data ?? 0;
                          return Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.favorite_border,
                                color: Colors.grey[600],
                                size: 14,
                              ),
                              if (likeCount > 0) ...[
                                const SizedBox(width: 2),
                                Text(
                                  '$likeCount',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // Review text
                  Expanded(
                    child: Text(
                      review['reviewText'] ?? review['review'] ?? 'Great service!',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.black87,
                        height: 1.3,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  
                  const SizedBox(height: 4),
                  
                  // Service provider
                  Text(
                    'Service by ${review['providerName'] ?? 'Provider'}',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
    );
  }

  void _openFullScreenPost(Map<String, dynamic> review) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FullScreenPostScreen(
          review: review,
          currentUser: widget.firebaseUser,
        ),
      ),
    );
  }

  Future<int> _getPostLikeCount(String? reviewId) async {
    if (reviewId == null) return 0;
    
    try {
      final likesQuery = await FirebaseFirestore.instance
          .collection('post_likes')
          .where('reviewId', isEqualTo: reviewId)
          .get();
      
      return likesQuery.docs.length;
    } catch (e) {
      return 0;
    }
  }

  Future<List<Map<String, dynamic>>> _loadRecentReviews() async {
    try {
      // Get current user's location for distance calculation
      String? userLocation;
      if (widget.firebaseUser != null) {
        userLocation = await ReviewsService.getCurrentUserLocation(widget.firebaseUser!.uid);
      }

      // Fetch recent reviews with distance sorting
      return await ReviewsService.getRecentReviewsWithDistance(
        currentUserLocation: userLocation,
        limit: 10,
      );
    } catch (e) {
      print('Error loading recent reviews: $e');
      return [];
    }
  }

  Widget _buildInstagramStylePost(Map<String, dynamic> review) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header - User info and location
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                // Profile picture
                CircleAvatar(
                  radius: 18,
                  backgroundImage: review['customerAvatar'] != null
                      ? NetworkImage(review['customerAvatar'])
                      : null,
                  backgroundColor: Colors.grey[300],
                  child: review['customerAvatar'] == null
                      ? Icon(Icons.person, color: Colors.grey[600], size: 20)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        review['customerName'] ?? 'Anonymous',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      if (review['distanceText'] != null)
                        Text(
                          review['distanceText'],
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                    ],
                  ),
                ),
                const Spacer(),
                // Heart icon (like mockup)
                Icon(
                  Icons.favorite_border,
                  color: Colors.grey[600],
                  size: 24,
                ),
              ],
            ),
          ),
          
                        // Photos section (Instagram style)
              Builder(
                builder: (context) {
                  print('🖼️ UI Check - photoUrls: ${review['photoUrls']}, hasPhotos: ${review['hasPhotos']}');
                  if (review['photoUrls'] != null && 
                      review['photoUrls'] is List && 
                      (review['photoUrls'] as List).isNotEmpty) {
                    print('✅ UI: Showing photos for review ${review['reviewId']}');
                    return _buildPhotoGrid(review['photoUrls'] as List<dynamic>);
                  } else {
                    print('❌ UI: No photos condition failed for review ${review['reviewId']}');
                    return Container(
                      height: 200,
                      color: Colors.grey[100],
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.image_outlined,
                              size: 48,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'No photos',
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                },
              ),
          
          // Review text and service attribution (clean, single section)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Review text
                if (review['reviewText'] != null && review['reviewText'].isNotEmpty)
                  Text(
                    review['reviewText'],
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.black87,
                      height: 1.4,
                    ),
                  ),
                
                const SizedBox(height: 12),
                
                // Service provider attribution (like mockup)
                Row(
                  children: [
                    Text(
                      'Service by',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.verified,
                            color: Colors.green,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            review['providerName'] ?? 'Provider',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildPhotoGrid(List<dynamic> photoUrls) {
    try {
      final urls = photoUrls.cast<String>();
      
      if (urls.isEmpty) return const SizedBox.shrink();
    } catch (e) {
      print('Error casting photoUrls: $e');
      return const SizedBox.shrink();
    }
    
    final urls = photoUrls.cast<String>();
    
    // Instagram-style photo layout (full width, no border radius)
    if (urls.length == 1) {
      return AspectRatio(
        aspectRatio: 1.0, // Square aspect ratio like Instagram
        child: Image.network(
          urls[0],
          fit: BoxFit.cover,
          width: double.infinity,
          errorBuilder: (context, error, stackTrace) => Container(
            color: Colors.grey[300],
            child: const Icon(Icons.image_not_supported),
          ),
        ),
      );
    } else if (urls.length == 2) {
      return SizedBox(
        height: 300,
        child: Row(
          children: [
            Expanded(
              child: Image.network(
                urls[0],
                fit: BoxFit.cover,
                height: 300,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: Colors.grey[300],
                  child: const Icon(Icons.image_not_supported),
                ),
              ),
            ),
            const SizedBox(width: 1),
            Expanded(
              child: Image.network(
                urls[1],
                fit: BoxFit.cover,
                height: 300,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: Colors.grey[300],
                  child: const Icon(Icons.image_not_supported),
                ),
              ),
            ),
          ],
        ),
      );
    } else if (urls.length == 3) {
      return SizedBox(
        height: 300,
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: Image.network(
                urls[0],
                fit: BoxFit.cover,
                height: 300,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: Colors.grey[300],
                  child: const Icon(Icons.image_not_supported),
                ),
              ),
            ),
            const SizedBox(width: 1),
            Expanded(
              child: Column(
                children: [
                  Expanded(
                    child: Image.network(
                      urls[1],
                      fit: BoxFit.cover,
                      width: double.infinity,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: Colors.grey[300],
                        child: const Icon(Icons.image_not_supported),
                      ),
                    ),
                  ),
                  const SizedBox(height: 1),
                  Expanded(
                    child: Image.network(
                      urls[2],
                      fit: BoxFit.cover,
                      width: double.infinity,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: Colors.grey[300],
                        child: const Icon(Icons.image_not_supported),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    } else {
      // 4+ photos: show first 3 and "+X more" overlay
      return SizedBox(
        height: 300,
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: Image.network(
                urls[0],
                fit: BoxFit.cover,
                height: 300,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: Colors.grey[300],
                  child: const Icon(Icons.image_not_supported),
                ),
              ),
            ),
            const SizedBox(width: 1),
            Expanded(
              child: Column(
                children: [
                  Expanded(
                    child: Image.network(
                      urls[1],
                      fit: BoxFit.cover,
                      width: double.infinity,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: Colors.grey[300],
                        child: const Icon(Icons.image_not_supported),
                      ),
                    ),
                  ),
                  const SizedBox(height: 1),
                  Expanded(
                    child: Stack(
                      children: [
                        Image.network(
                          urls[2],
                          fit: BoxFit.cover,
                          width: double.infinity,
                          errorBuilder: (context, error, stackTrace) => Container(
                            color: Colors.grey[300],
                            child: const Icon(Icons.image_not_supported),
                          ),
                        ),
                        if (urls.length > 3)
                          Container(
                            color: Colors.black.withOpacity(0.6),
                            child: Center(
                              child: Text(
                                '+${urls.length - 3}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildProviderPost(Map<String, dynamic> post) {
    final isProvider = post['type'] == 'provider';
    final images = post['images'] as List<String>;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFFFBB04C).withOpacity(0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFBB04C).withOpacity(0.1),
            spreadRadius: 0,
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // User/Provider header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Row(
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isProvider ? const Color(0xFFFBB04C) : const Color(0xFF4CAF50),
                      width: 2,
                    ),
                  ),
                  child: CircleAvatar(
                    radius: 22,
                    backgroundImage: NetworkImage(post['avatar']!),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              post['name']!,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.thumb_up,
                                  color: Colors.green,
                                  size: 14,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '👍',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isProvider ? 'Home Service Provider' : 'Customer Review',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  post['time']!,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),
          
          // Service images carousel
          _buildImageCarousel(images),
          
          // Review and service info
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  post['review']!,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.black87,
                    height: 1.4,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Text(
                      'Service by',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4CAF50).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFF4CAF50).withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 20,
                            height: 20,
                            decoration: const BoxDecoration(
                              color: Color(0xFF4CAF50),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.verified,
                              color: Colors.white,
                              size: 12,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            post['service']!,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF4CAF50),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Engagement buttons
                Row(
                  children: [
                    _buildEngagementButton(Icons.thumb_up_outlined, '12', Colors.blue),
                    const SizedBox(width: 20),
                    _buildEngagementButton(Icons.chat_bubble_outline, '3', Colors.grey),
                    const SizedBox(width: 20),
                    _buildEngagementButton(Icons.share_outlined, 'Share', Colors.grey),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageCarousel(List<String> images) {
    if (images.isEmpty) return const SizedBox.shrink();
    
    return Container(
      height: 300,
      child: images.length == 1 
        ? ClipRRect(
            borderRadius: BorderRadius.circular(0),
            child: Image.network(
              images[0],
              width: double.infinity,
              height: 300,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                width: double.infinity,
                height: 300,
                color: Colors.grey[200],
                child: const Icon(Icons.image_not_supported, size: 50, color: Colors.grey),
              ),
            ),
          )
        : PageView.builder(
            itemCount: images.length,
            itemBuilder: (context, index) {
              return Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(0),
                    child: Image.network(
                      images[index],
                      width: double.infinity,
                      height: 300,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        width: double.infinity,
                        height: 300,
                        color: Colors.grey[200],
                        child: const Icon(Icons.image_not_supported, size: 50, color: Colors.grey),
                      ),
                    ),
                  ),
                  // Image counter
                  Positioned(
                    top: 16,
                    right: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${index + 1}/${images.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
    );
  }

  Widget _buildEngagementButton(IconData icon, String label, Color color) {
    return GestureDetector(
      onTap: () {
        // Handle engagement action
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$label feature coming soon!')),
        );
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTasksScreen() {
    // Use the dedicated My Tasks screen
    if (widget.firebaseUser != null) {
      // Wrap in error boundary to catch any issues
      return Builder(
        builder: (context) {
          try {
            return MyTasksScreen(user: widget.firebaseUser!);
          } catch (e) {
            print('Error loading MyTasksScreen: $e');
            // Fallback to original tasks screen
            return _buildOriginalTasksScreen();
          }
        },
      );
    }
    
    // Fallback for when user is not authenticated
    return const Center(
      child: Text(
        'Please log in to view your tasks',
        style: TextStyle(
          fontSize: 16,
          color: Colors.grey,
        ),
      ),
    );
  }

  Widget _buildOriginalTasksScreen() {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6B73FF), Color(0xFF000DFF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.assignment,
                    color: Colors.white,
                    size: 32,
                  ),
                  const SizedBox(width: 16),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'My Tasks',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Manage your service requests',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.pending_actions, color: Colors.white, size: 16),
                        SizedBox(width: 4),
                        Text(
                          '0',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Active Bidding Sessions
            _buildActiveBiddingSessions(),
            
            const SizedBox(height: 24),
            
            // Provider Matching Test Lab
            _buildMatchingTestSection(),
            
            const SizedBox(height: 24),
            
            // Recent Tasks Section
            _buildRecentTasksSection(),
            
            const SizedBox(height: 24),
            
            // Quick Actions
            _buildQuickActionsSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveBiddingSessions() {
    if (widget.firebaseUser == null) {
      return SizedBox.shrink();
    }

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: BiddingService.getUserBidHistory(widget.firebaseUser!.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildBiddingSectionHeader('⏰ Active Bidding', 0, true);
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildNoBiddingSessionsCard();
        }

        // Filter for active sessions only
        final activeSessions = snapshot.data!
            .where((item) => item['session'].sessionStatus == 'active')
            .toList();

        if (activeSessions.isEmpty) {
          return _buildNoBiddingSessionsCard();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildBiddingSectionHeader('⏰ Active Bidding', activeSessions.length, false),
            const SizedBox(height: 12),
            
            // Active bidding sessions list
            ...activeSessions.map((sessionData) {
              final session = sessionData['session'] as BiddingSession;
              final request = sessionData['request'] as UserRequest;
              final bids = sessionData['bids'] as List;
              final bidCount = sessionData['bidCount'] as int;
              
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                child: _buildBiddingSessionCard(session, request, bidCount),
              );
            }).toList(),
          ],
        );
      },
    );
  }

  Widget _buildBiddingSectionHeader(String title, int count, bool isLoading) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2D3748),
          ),
        ),
        const Spacer(),
        if (isLoading)
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFBB04C)),
            ),
          )
        else if (count > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Color(0xFFFBB04C),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$count active',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildNoBiddingSessionsCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildBiddingSectionHeader('⏰ Active Bidding', 0, false),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
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
              Icon(
                Icons.gavel_outlined,
                size: 48,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 12),
              Text(
                'No Active Bidding Sessions',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Create a service request to start receiving bids',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBiddingSessionCard(BiddingSession session, UserRequest request, int bidCount) {
    final timeRemaining = session.timeRemaining;
    final isExpiring = timeRemaining.inHours < 1;
    final hasNewBids = bidCount > 0;

    return GestureDetector(
      onTap: () => _navigateToBidComparison(request),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isExpiring ? Colors.orange : Colors.grey[200]!,
            width: isExpiring ? 2 : 1,
          ),
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
            // Header row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Color(0xFFFBB04C).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    request.serviceCategory.toUpperCase(),
                    style: const TextStyle(
                      color: Color(0xFFFBB04C),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Spacer(),
                if (hasNewBids)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.fiber_new, size: 12, color: Colors.white),
                        const SizedBox(width: 4),
                        Text(
                          '$bidCount bid${bidCount != 1 ? 's' : ''}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Request description
            Text(
              request.description,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[800],
                height: 1.3,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            
            const SizedBox(height: 12),
            
            // Status row
            Row(
              children: [
                // Time remaining
                Expanded(
                  child: Row(
                    children: [
                      Icon(
                        Icons.schedule,
                        size: 16,
                        color: isExpiring ? Colors.orange : Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        BiddingService.formatTimeRemaining(timeRemaining),
                        style: TextStyle(
                          fontSize: 12,
                          color: isExpiring ? Colors.orange : Colors.grey[600],
                          fontWeight: isExpiring ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Action button
                ElevatedButton(
                  onPressed: () => _navigateToBidComparison(request),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: hasNewBids ? Colors.green : Color(0xFFFBB04C),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    minimumSize: const Size(0, 0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    hasNewBids ? 'VIEW BIDS' : 'WAITING',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToBidComparison(UserRequest request) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BidComparisonScreen(
          requestId: request.requestId!,
          userRequest: request,
        ),
      ),
    );
  }

  Widget _buildDiscoverScreen() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const TranslatableText(
            'Discover',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 40),
          
          // Test notification button (for development)
          ElevatedButton.icon(
            onPressed: () {
              InAppNotificationService().showTestNotification(context);
            },
            icon: const Icon(Icons.notifications_active),
            label: const TranslatableText('Test Quote Notification'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Test FCM button (for debugging push notifications)
          ElevatedButton.icon(
            onPressed: () async {
              print('🧪 Manual FCM Test Started...');
              try {
                await NotificationService.initializeFCM();
                print('🧪 Manual FCM initialization completed');
                
                if (widget.firebaseUser != null) {
                  await NotificationService.saveFCMTokenForUser(widget.firebaseUser!.uid);
                  print('🧪 Manual FCM token save completed');
                }
                
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('FCM test completed - check console logs'),
                    backgroundColor: Colors.blue,
                  ),
                );
              } catch (e) {
                print('🧪 Manual FCM test failed: $e');
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('FCM test failed: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            icon: const Icon(Icons.cloud_sync),
            label: const TranslatableText('Test FCM Setup'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFriendsScreen() {
    // Show My Connections page
    if (widget.firebaseUser != null) {
      return MyConnectionsScreen();
    }
    
    return const Center(
      child: Text(
        'Please log in to view your connections',
        style: TextStyle(
          fontSize: 16,
          color: Colors.grey,
        ),
      ),
    );
  }

  Future<void> _updateProfilePhoto() async {
    if (widget.firebaseUser == null) {
      print('Error: No Firebase user found');
      return;
    }

    try {
      print('Starting profile photo update...');
      print('User ID: ${widget.firebaseUser!.uid}');
      print('User email: ${widget.firebaseUser!.email}');
      print('User auth token: ${await widget.firebaseUser!.getIdToken()}');

      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 500,
        maxHeight: 500,
        imageQuality: 85,
      );

      if (pickedFile == null) {
        print('No file selected');
        return;
      }

      print('File selected: ${pickedFile.path}');
      
      setState(() {
        _isUpdatingPhoto = true;
      });

      // Upload to Firebase Storage
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('profile_pictures')
          .child(widget.firebaseUser!.uid)
          .child('profile.jpg');

      print('Storage path: profile_pictures/${widget.firebaseUser!.uid}/profile.jpg');
      
      final uploadTask = storageRef.putFile(File(pickedFile.path));
      print('Starting upload...');
      final snapshot = await uploadTask;
      print('Upload completed');
      final downloadUrl = await snapshot.ref.getDownloadURL();
      print('Download URL obtained: $downloadUrl');

      // Update Firestore document
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.firebaseUser!.uid)
          .update({
        'profileImageUrl': downloadUrl,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile photo updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Error updating profile photo: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update profile photo: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingPhoto = false;
        });
      }
    }
  }

  Widget _buildProfileImage(Map<String, dynamic> data) {
    final profileImageUrl = data['profileImageUrl'] as String?;
    final googlePhotoUrl = widget.googleUser?.photoUrl;
    final firebasePhotoUrl = widget.firebaseUser?.photoURL;
    
    print('Building profile image - profileImageUrl: $profileImageUrl, googlePhotoUrl: $googlePhotoUrl, firebasePhotoUrl: $firebasePhotoUrl');
    
    return GestureDetector(
      onTap: _isUpdatingPhoto ? null : _updateProfilePhoto,
      child: Stack(
        children: [
          // Profile image
          _buildImageWidget(profileImageUrl, googlePhotoUrl, firebasePhotoUrl),
          // Loading overlay
          if (_isUpdatingPhoto)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFFFBB04C),
                  ),
                ),
              ),
            ),
          // Camera icon overlay
          if (!_isUpdatingPhoto)
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFFBB04C),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const Icon(
                  Icons.camera_alt,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildImageWidget(String? profileImageUrl, String? googlePhotoUrl, String? firebasePhotoUrl) {
    // Try profile image first
    if (profileImageUrl != null && profileImageUrl.isNotEmpty) {
      return ClipOval(
        child: Image.network(
          profileImageUrl,
          width: 114,
          height: 114,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return CircleAvatar(
              radius: 57,
              backgroundColor: Colors.grey[200],
              child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded / 
                      loadingProgress.expectedTotalBytes!
                    : null,
                color: const Color(0xFFFBB04C),
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            print('Error loading uploaded profile image: $error');
            // Fall back to Google or Firebase photo if uploaded image fails
            return _buildFallbackImage(googlePhotoUrl, firebasePhotoUrl);
          },
        ),
      );
    } 
    // Try Google photo
    else if (googlePhotoUrl != null && googlePhotoUrl.isNotEmpty) {
      return ClipOval(
        child: Image.network(
          googlePhotoUrl,
          width: 114,
          height: 114,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            print('Error loading Google profile image: $error');
            return _buildFallbackImage(firebasePhotoUrl, null);
          },
        ),
      );
    }
    // Try Firebase photo
    else if (firebasePhotoUrl != null && firebasePhotoUrl.isNotEmpty) {
      return ClipOval(
        child: Image.network(
          firebasePhotoUrl,
          width: 114,
          height: 114,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            print('Error loading Firebase profile image: $error');
            return _buildDefaultAvatar();
          },
        ),
      );
    } 
    // Default avatar
    else {
      return _buildDefaultAvatar();
    }
  }

  Widget _buildFallbackImage(String? primaryUrl, String? secondaryUrl) {
    if (primaryUrl != null && primaryUrl.isNotEmpty) {
      return ClipOval(
        child: Image.network(
          primaryUrl,
          width: 114,
          height: 114,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            print('Error loading fallback image: $error');
            if (secondaryUrl != null && secondaryUrl.isNotEmpty) {
              return ClipOval(
                child: Image.network(
                  secondaryUrl,
                  width: 114,
                  height: 114,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    print('Error loading secondary fallback image: $error');
                    return _buildDefaultAvatar();
                  },
                ),
              );
            } else {
              return _buildDefaultAvatar();
            }
          },
        ),
      );
    } else {
      return _buildDefaultAvatar();
    }
  }

  Widget _buildDefaultAvatar() {
    return const CircleAvatar(
      radius: 57,
      backgroundColor: Colors.grey,
      child: Icon(Icons.person, size: 60, color: Colors.white),
    );
  }

  int _getConnectionCount(Map<String, dynamic> data) {
    // Count unique connections properly (same logic as debug script)
    final friends = (data['friends'] as List<dynamic>?)?.cast<String>() ?? [];
    final referredBy = (data['referred_by_user_ids'] as List<dynamic>?)?.cast<String>() ?? [];
    final referredUsers = (data['referred_user_ids'] as List<dynamic>?)?.cast<String>() ?? [];
    final referredProviders = (data['referred_provider_ids'] as List<dynamic>?)?.cast<String>() ?? [];
    
    // Combine all connections and remove duplicates
    final allConnections = <String>{};
    allConnections.addAll(friends);
    allConnections.addAll(referredBy);
    allConnections.addAll(referredUsers);
    allConnections.addAll(referredProviders);
    
    return allConnections.length;
  }

  int _getTaskCount(Map<String, dynamic> data) {
    // This will be calculated dynamically from actual completed tasks
    // For now, return 0 and let the FutureBuilder handle the real count
    return 0; // Will be replaced with real-time data
  }

  Future<int> _getCompletedTasksCount(String userId) async {
    try {
      final completedTasksQuery = await FirebaseFirestore.instance
          .collection('user_requests')
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: 'completed')
          .get();
      
      return completedTasksQuery.docs.length;
    } catch (e) {
      print('Error getting completed tasks count: $e');
      return 0;
    }
  }

  Widget _buildProfileScreen() {
    final user = widget.firebaseUser;
    if (user == null) {
      return const Center(child: Text('No user logged in'));
    }
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Center(child: Text('Profile data not found'));
        }
        final data = snapshot.data!.data() as Map<String, dynamic>;
        
        // Debug logging
        print('Profile data: $data');
        print('profileImageUrl: ${data['profileImageUrl']}');
        print('Google photo URL: ${widget.googleUser?.photoUrl}');
        
        return Scaffold(
          backgroundColor: Colors.grey[50],
          body: SingleChildScrollView(
            child: Column(
              children: [
                // Profile Header
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(24, 60, 24, 32),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                  ),
                  child: Column(
                    children: [
                      // Profile Avatar
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
                        child: _buildProfileImage(data),
                      ),
                      const SizedBox(height: 8),
                      // Tap to change text
                      Text(
                        'Tap to change photo',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Name
                      Text(
                        data['name'] ?? 'User',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Email
                      Text(
                        user.email ?? '',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Stats Section
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  padding: const EdgeInsets.all(24),
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
                      const Text(
                        'My Stats',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFFBB04C),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              children: [
                                Text(
                                  '${_getConnectionCount(data)}',
                                  style: const TextStyle(
                                    fontSize: 36,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFFFBB04C),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Connections',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey[700],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 60,
                            color: Colors.grey[300],
                          ),
                          Expanded(
                            child: Column(
                              children: [
                                FutureBuilder<int>(
                                  future: _getCompletedTasksCount(user.uid),
                                  builder: (context, snapshot) {
                                    final count = snapshot.data ?? 0;
                                    return Text(
                                      '$count',
                                      style: const TextStyle(
                                        fontSize: 36,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFFFBB04C),
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Tasks',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey[700],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Referral Code Section
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFBB04C),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Your referral code',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              data['referralCode'] ?? 'QMP45FAF',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 2,
                              ),
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () async {
                          // Copy referral code to clipboard
                          await Clipboard.setData(ClipboardData(text: data['referralCode'] ?? 'QMP45FAF'));
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Referral code copied to clipboard!'),
                                backgroundColor: Color(0xFFFBB04C),
                              ),
                            );
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.copy,
                            color: Color(0xFFFBB04C),
                            size: 24,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 32),
                
                // Menu Items
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24),
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
                    children: [
                      _buildMenuTile(
                        icon: Icons.person_outline,
                        title: 'Account Settings',
                        onTap: () => _showAccountSettingsDialog(data),
                      ),
                      _buildMenuDivider(),
                      _buildMenuTile(
                        icon: Icons.settings_outlined,
                        title: 'App Settings',
                        onTap: () => _showAppSettingsDialog(),
                      ),
                      _buildMenuDivider(),
                      _buildMenuTile(
                        icon: Icons.people_outline,
                        title: 'My Connections',
                        onTap: () => _showMyConnectionsScreen(),
                      ),
                      _buildMenuDivider(),
                      _buildMenuTile(
                        icon: Icons.folder_outlined,
                        title: 'My Collection',
                        onTap: () => _showMyCollectionScreen(),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 32),
                
                // Sign Out Button
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      await _authService.logout();
                      if (!mounted) return;
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => const WelcomeScreen()),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[400],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Sign Out',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 32),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMenuTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFFFBB04C).withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          color: const Color(0xFFFBB04C),
          size: 24,
        ),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: Colors.black87,
        ),
      ),
      trailing: const Icon(
        Icons.chevron_right,
        color: Colors.grey,
        size: 24,
      ),
      onTap: onTap,
    );
  }

  Widget _buildMenuDivider() {
    return Divider(
      height: 1,
      thickness: 1,
      color: Colors.grey[200],
      indent: 24,
      endIndent: 24,
    );
  }

  void _showAccountSettingsDialog(Map<String, dynamic> data) {
    final nameController = TextEditingController(text: data['name'] ?? '');
    final phoneController = TextEditingController(text: data['phone'] ?? '');
    final addressController = TextEditingController(text: data['address'] ?? '');
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Account Settings'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: phoneController,
                  decoration: const InputDecoration(
                    labelText: 'Phone',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: addressController,
                  decoration: const InputDecoration(
                    labelText: 'Address',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      setState(() => isSaving = true);
                      await FirebaseFirestore.instance
                          .collection('users')
                          .doc(widget.firebaseUser!.uid)
                          .update({
                        'name': nameController.text.trim(),
                        'phone': phoneController.text.trim(),
                        'address': addressController.text.trim(),
                      });
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Profile updated successfully')),
                        );
                        // Refresh the profile screen
                        this.setState(() {});
                      }
                    },
              child: isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAppSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('App Settings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.notifications_outlined),
              title: const Text('Notifications'),
              trailing: Switch(
                value: true,
                onChanged: (value) {
                  // Handle notification toggle
                },
              ),
            ),
            ListTile(
              leading: const Icon(Icons.dark_mode_outlined),
              title: const Text('Dark Mode'),
              trailing: Switch(
                value: false,
                onChanged: (value) {
                  // Handle dark mode toggle
                },
              ),
            ),
            ListTile(
              leading: const Icon(Icons.language_outlined),
              title: const Text('Language'),
              trailing: const Text('English'),
              onTap: () {
                // Handle language selection
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showMyConnectionsScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const MyConnectionsScreen(),
      ),
    );
  }

  void _showMyCollectionScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const MyCollectionScreen(),
      ),
    );
  }

  void _onCreateServiceRequest() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AITaskIntakeScreen(
          user: widget.firebaseUser,
        ),
      ),
    );
  }

  Widget _buildRecentTasksSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Recent Requests',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Column(
            children: [
              Icon(
                Icons.inbox_outlined,
                size: 48,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 12),
              Text(
                'No recent tasks',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Your service requests will appear here',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[500],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildQuickActionCard(
                icon: Icons.add_circle_outline,
                title: 'New Request',
                subtitle: 'Create service request',
                color: Colors.blue,
                onTap: _onCreateServiceRequest,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildQuickActionCard(
                icon: Icons.history,
                title: 'View History',
                subtitle: 'Past requests',
                color: Colors.green,
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Request history feature coming soon!')),
                  );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildServiceRequestModal() {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
      children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
        ),
          const Padding(
            padding: EdgeInsets.all(20),
            child: Text(
              'What service do you need?',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: GridView.count(
              padding: const EdgeInsets.all(20),
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              children: [
                _buildServiceCard('Cleaning', Icons.cleaning_services, Colors.blue),
                _buildServiceCard('Plumbing', Icons.plumbing, Colors.orange),
                _buildServiceCard('Electrical', Icons.electrical_services, Colors.yellow),
                _buildServiceCard('Gardening', Icons.grass, Colors.green),
                _buildServiceCard('Painting', Icons.format_paint, Colors.purple),
                _buildServiceCard('Carpentry', Icons.carpenter, Colors.brown),
                _buildServiceCard('HVAC', Icons.ac_unit, Colors.cyan),
                _buildServiceCard('Other', Icons.more_horiz, Colors.grey),
              ],
            ),
        ),
        ],
      ),
    );
  }

  Widget _buildQuickActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: color,
                size: 24,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: color.withOpacity(0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServiceCard(String title, IconData icon, Color color) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$title service selected!')),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 48,
              color: color,
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMatchingTestSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: Card(
        elevation: 4,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.science,
                      color: Colors.blue[700],
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '🎯 Provider Matching Test Lab',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        Text(
                          'Test AI intake → Provider matching pipeline',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'Test the complete workflow from AI service intake to provider matching with realistic scenarios. Perfect for testing different service categories, urgency levels, and referral systems.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const ProviderMatchingTestScreen(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[700],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.play_arrow, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Open Test Lab',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }


}

class MyConnectionsScreen extends StatefulWidget {
  const MyConnectionsScreen({super.key});

  @override
  State<MyConnectionsScreen> createState() => _MyConnectionsScreenState();
}

class _MyConnectionsScreenState extends State<MyConnectionsScreen> {
  final TextEditingController _usernameController = TextEditingController();
  bool _isLoading = false;
  bool _showSearchInput = false;
  Map<String, dynamic>? _pendingConnection;
  List<Map<String, dynamic>> _connections = [];

  @override
  void initState() {
    super.initState();
    _loadConnections();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _loadConnections() async {
    setState(() => _isLoading = true);
    
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      // Get current user's data
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();

      if (!userDoc.exists) return;

      final userData = userDoc.data()!;
      final friends = List<String>.from(userData['friends'] ?? []);
      final referredByUserIds = List<String>.from(userData['referred_by_user_ids'] ?? []);
      final referredUserIds = List<String>.from(userData['referred_user_ids'] ?? []);
      final referredProviderIds = List<String>.from(userData['referred_provider_ids'] ?? []);

      List<Map<String, dynamic>> connections = [];

      // Add friends (actual social connections)
      for (String userId in friends) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .get();
        if (userDoc.exists) {
          final data = userDoc.data()!;
          connections.add({
            'id': userId,
            'name': data['name'] ?? 'User',
            'email': data['email'] ?? '',
            'avatar': data['profileImageUrl'] ?? 'https://picsum.photos/100/100?random=${userId.hashCode}',
            'type': 'user',
            'relationship': 'friend',
            'referralCode': data['referralCode'] ?? '',
          });
        }
      }

      // Add users who referred this user (skip if already added as friend)
      for (String userId in referredByUserIds) {
        if (friends.contains(userId)) continue; // Avoid duplicates
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .get();
        if (userDoc.exists) {
          final data = userDoc.data()!;
          connections.add({
            'id': userId,
            'name': data['name'] ?? 'User',
            'email': data['email'] ?? '',
            'avatar': data['profileImageUrl'] ?? 'https://picsum.photos/100/100?random=${userId.hashCode}',
            'type': 'user',
            'relationship': 'referred_by',
            'referralCode': data['referralCode'] ?? '',
          });
        }
      }

      // Add users referred by this user (skip duplicates)
      for (String userId in referredUserIds) {
        if (friends.contains(userId) || referredByUserIds.contains(userId)) continue; // Avoid duplicates
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .get();
        if (userDoc.exists) {
          final data = userDoc.data()!;
          connections.add({
            'id': userId,
            'name': data['name'] ?? 'User',
            'email': data['email'] ?? '',
            'avatar': data['profileImageUrl'] ?? 'https://picsum.photos/100/100?random=${userId.hashCode}',
            'type': 'user',
            'relationship': 'referred_user',
            'referralCode': data['referralCode'] ?? '',
          });
        }
      }

      // Add providers referred by this user
      for (String providerId in referredProviderIds) {
        final providerDoc = await FirebaseFirestore.instance
            .collection('providers')
            .doc(providerId)
            .get();
        if (providerDoc.exists) {
          final data = providerDoc.data()!;
          connections.add({
            'id': providerId,
            'name': data['companyName'] ?? data['legalRepresentativeName'] ?? 'Provider',
            'email': data['email'] ?? '',
            'avatar': data['profileImageUrl'] ?? 'https://picsum.photos/100/100?random=${providerId.hashCode}',
            'type': 'provider',
            'relationship': 'referred_provider',
            'referralCode': data['referralCode'] ?? '',
          });
        }
      }

      setState(() {
        _connections = connections;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading connections: $e');
      setState(() => _isLoading = false);
    }
  }


  Future<void> _lookupUsername() async {
    final username = _usernameController.text.trim();
    if (username.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      // Check in users collection by name (case-insensitive)
      final usersQuery = await FirebaseFirestore.instance
          .collection('users')
          .get();

      // Filter by name (case-insensitive search)
      final userDocs = usersQuery.docs.where((doc) {
        final data = doc.data();
        final name = (data['name'] ?? '').toString().toLowerCase();
        return name.contains(username.toLowerCase());
      }).toList();

      if (userDocs.isNotEmpty) {
        // If multiple matches, take the first exact match or the first partial match
        final exactMatch = userDocs.where((doc) {
          final data = doc.data();
          final name = (data['name'] ?? '').toString().toLowerCase();
          return name == username.toLowerCase();
        }).toList();

        final doc = exactMatch.isNotEmpty ? exactMatch.first : userDocs.first;
        final data = doc.data();
        
        setState(() {
          _pendingConnection = {
            'id': doc.id,
            'name': data['name'] ?? 'User',
            'email': data['email'] ?? '',
            'avatar': data['profileImageUrl'] ?? 'https://picsum.photos/100/100?random=${doc.id.hashCode}',
            'type': 'user',
            'referralCode': data['referralCode'] ?? '',
          };
          _showSearchInput = false;
          _isLoading = false;
        });
        return;
      }

      // Check in providers collection by company name (case-insensitive)
      final providersQuery = await FirebaseFirestore.instance
          .collection('providers')
          .get();

      final providerDocs = providersQuery.docs.where((doc) {
        final data = doc.data();
        final companyName = (data['companyName'] ?? '').toString().toLowerCase();
        final legalName = (data['legalRepresentativeName'] ?? '').toString().toLowerCase();
        return companyName.contains(username.toLowerCase()) || 
               legalName.contains(username.toLowerCase());
      }).toList();

      if (providerDocs.isNotEmpty) {
        final doc = providerDocs.first;
        final data = doc.data();
        setState(() {
          _pendingConnection = {
            'id': doc.id,
            'name': data['companyName'] ?? data['legalRepresentativeName'] ?? 'Provider',
            'email': data['email'] ?? '',
            'avatar': data['profileImageUrl'] ?? 'https://picsum.photos/100/100?random=${doc.id.hashCode}',
            'type': 'provider',
            'referralCode': data['referralCode'] ?? '',
          };
          _showSearchInput = false;
          _isLoading = false;
        });
        return;
      }

      // Not found
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Username not found. Please check and try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('Error looking up username: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error looking up username. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _confirmConnection() async {
    if (_pendingConnection == null) return;

    setState(() => _isLoading = true);

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      final connectionId = _pendingConnection!['id'];
      final connectionType = _pendingConnection!['type'];

      // Create bidirectional relationship
      final batch = FirebaseFirestore.instance.batch();

      if (connectionType == 'user') {
        // Add connection to current user's referred_by_user_ids
        batch.update(
          FirebaseFirestore.instance.collection('users').doc(currentUser.uid),
          {
            'referred_by_user_ids': FieldValue.arrayUnion([connectionId]),
          },
        );

        // Add current user to connection's referred_user_ids
        batch.update(
          FirebaseFirestore.instance.collection('users').doc(connectionId),
          {
            'referred_user_ids': FieldValue.arrayUnion([currentUser.uid]),
          },
        );
      } else {
        // For providers, add to current user's referred_provider_ids
        batch.update(
          FirebaseFirestore.instance.collection('users').doc(currentUser.uid),
          {
            'referred_provider_ids': FieldValue.arrayUnion([connectionId]),
          },
        );

        // Add current user to provider's referred_by_user_ids
        batch.update(
          FirebaseFirestore.instance.collection('providers').doc(connectionId),
          {
            'referred_by_user_ids': FieldValue.arrayUnion([currentUser.uid]),
          },
        );
      }

      await batch.commit();

      setState(() {
        _pendingConnection = null;
        _usernameController.clear();
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Connection added successfully!'),
            backgroundColor: Color(0xFFFBB04C),
          ),
        );
      }

      // Reload connections
      _loadConnections();
    } catch (e) {
      print('Error confirming connection: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error adding connection. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteConnection(Map<String, dynamic> connection) async {
    setState(() => _isLoading = true);

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      final connectionId = connection['id'];
      final connectionType = connection['type'];
      final relationship = connection['relationship'];

      final batch = FirebaseFirestore.instance.batch();

      if (connectionType == 'user') {
        if (relationship == 'referred_by') {
          // Remove from current user's referred_by_user_ids
          batch.update(
            FirebaseFirestore.instance.collection('users').doc(currentUser.uid),
            {
              'referred_by_user_ids': FieldValue.arrayRemove([connectionId]),
            },
          );
          // Remove from other user's referred_user_ids
          batch.update(
            FirebaseFirestore.instance.collection('users').doc(connectionId),
            {
              'referred_user_ids': FieldValue.arrayRemove([currentUser.uid]),
            },
          );
        } else if (relationship == 'referred_user') {
          // Remove from current user's referred_user_ids
          batch.update(
            FirebaseFirestore.instance.collection('users').doc(currentUser.uid),
            {
              'referred_user_ids': FieldValue.arrayRemove([connectionId]),
            },
          );
          // Remove from other user's referred_by_user_ids
          batch.update(
            FirebaseFirestore.instance.collection('users').doc(connectionId),
            {
              'referred_by_user_ids': FieldValue.arrayRemove([currentUser.uid]),
            },
          );
        }
      } else if (connectionType == 'provider') {
        // Remove from current user's referred_provider_ids
        batch.update(
          FirebaseFirestore.instance.collection('users').doc(currentUser.uid),
          {
            'referred_provider_ids': FieldValue.arrayRemove([connectionId]),
          },
        );
        // Remove from provider's referred_by_user_ids
        batch.update(
          FirebaseFirestore.instance.collection('providers').doc(connectionId),
          {
            'referred_by_user_ids': FieldValue.arrayRemove([currentUser.uid]),
          },
        );
      }

      await batch.commit();

      setState(() => _isLoading = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${connection['name']} removed from connections'),
            backgroundColor: Color(0xFFFBB04C),
          ),
        );
      }

      // Reload connections
      _loadConnections();
    } catch (e) {
      print('Error deleting connection: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error removing connection. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showDeleteDialog(Map<String, dynamic> connection) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Connection'),
        content: Text('Are you sure you want to remove ${connection['name']} from your connections?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteConnection(connection);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: Navigator.canPop(context) ? IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFFFBB04C)),
          onPressed: () => Navigator.pop(context),
        ) : null,
        title: const Text(
          'My Connections',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Color(0xFFFBB04C)),
            onPressed: () {
              setState(() {
                _showSearchInput = true;
                _pendingConnection = null;
              });
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Add connection search section (moved to top)
                  if (_showSearchInput) ...[
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(24),
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
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Add Connection',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 20),
                          // Username input
                          TextField(
                            controller: _usernameController,
                            decoration: const InputDecoration(
                              hintText: 'Enter username',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.all(Radius.circular(12)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.all(Radius.circular(12)),
                                borderSide: BorderSide(color: Color(0xFFFBB04C), width: 2),
                              ),
                            ),
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 16),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _lookupUsername,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFBB04C),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 32),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'Search',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  
                  // Pending connection confirmation (moved to top after search)
                  if (_pendingConnection != null) ...[
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(24),
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
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'You\'re Adding',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Center(
                            child: Column(
                              children: [
                                CircleAvatar(
                                  radius: 40,
                                  backgroundImage: NetworkImage(_pendingConnection!['avatar']!),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  _pendingConnection!['name']!,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _pendingConnection!['type'] == 'user' ? 'User' : 'Provider',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: _pendingConnection!['type'] == 'user' ? Colors.blue : Colors.green,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton(
                            onPressed: _confirmConnection,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFBB04C),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'Confirm',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  
                  // Existing connections (moved after add connection panel)
                  if (_connections.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _connections.length,
                      itemBuilder: (context, index) {
                        final connection = _connections[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            leading: CircleAvatar(
                              radius: 24,
                              backgroundImage: NetworkImage(connection['avatar']!),
                            ),
                            title: Text(
                              connection['name']!,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  connection['type'] == 'user' ? 'User' : 'Provider',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: connection['type'] == 'user' ? Colors.blue : Colors.green,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  connection['relationship'] == 'referred_by' 
                                      ? 'You were referred by this person'
                                      : 'You referred this person',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ),
                            trailing: PopupMenuButton(
                              icon: const Icon(Icons.more_vert, color: Colors.grey),
                              itemBuilder: (context) => [
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      const Icon(Icons.delete_outline, color: Colors.red),
                                      const SizedBox(width: 8),
                                      Text('Delete', style: TextStyle(color: Colors.red[700])),
                                    ],
                                  ),
                                ),
                              ],
                              onSelected: (value) {
                                if (value == 'delete') {
                                  _showDeleteDialog(connection);
                                }
                              },
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                  
                  // Empty state
                  if (_connections.isEmpty && !_showSearchInput && _pendingConnection == null) ...[
                    const SizedBox(height: 40),
                    Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.people_outline,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No connections yet',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Add connections using referral codes or usernames',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[500],
                            ),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: () {
                              setState(() {
                                _showSearchInput = true;
                              });
                            },
                            icon: const Icon(Icons.add),
                            label: const Text('Add Connection'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFBB04C),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
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
}

class MyCollectionScreen extends StatefulWidget {
  const MyCollectionScreen({super.key});

  @override
  State<MyCollectionScreen> createState() => _MyCollectionScreenState();
}

class _MyCollectionScreenState extends State<MyCollectionScreen> {
  final List<Map<String, dynamic>> collections = [
    {
      'name': 'Shayla',
      'service': 'SweetHome',
      'image': 'https://images.unsplash.com/photo-1416879595882-3373a0480b5b?w=400',
      'review': 'They\'ve really done a great job on my garden!!',
      'rating': 5,
    },
    {
      'name': 'Mikaela',
      'service': 'HomeLovely',
      'image': 'https://images.unsplash.com/photo-1600585154340-be6161a56a0c?w=400',
      'review': 'I was recommended by a friend. I can\'t believe the turnout! It\'s so goooood! Definitely would recommend <3',
      'rating': 5,
    },
    {
      'name': 'Jiwon',
      'service': 'RoofMaster',
      'image': 'https://images.unsplash.com/photo-1558618666-fcd25c85cd64?w=400',
      'review': 'I contracted them to reroof my house and I have to say it was meticulously done. I have also approached others but in terms of price and everything, they really outdid themselves! Very pleased.',
      'rating': 5,
    },
    {
      'name': 'Liyuan',
      'service': 'PoolClean Pro',
      'image': 'https://images.unsplash.com/photo-1571902943202-507ec2618e8f?w=400',
      'review': 'The pool was cleaned out very nicely and they even went above and beyond! It was a real pleasure to work with them.',
      'rating': 5,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFFFBB04C)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'My Collection',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              // Edit collection functionality
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Edit collection feature coming soon!')),
              );
            },
            child: const Text(
              'Edit',
              style: TextStyle(
                color: Color(0xFFFBB04C),
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Collection Counter
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            color: Colors.white,
            child: const Text(
              '14/50',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Color(0xFFFBB04C),
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Collection Grid
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.75,
              ),
              itemCount: collections.length,
              itemBuilder: (context, index) {
                final item = collections[index];
                return Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Service Image
                      Expanded(
                        flex: 3,
                        child: Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                            image: DecorationImage(
                              image: NetworkImage(item['image']),
                              fit: BoxFit.cover,
                            ),
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withOpacity(0.3),
                                ],
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.9),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.person, size: 12, color: Color(0xFFFBB04C)),
                                            const SizedBox(width: 4),
                                            Text(
                                              item['name'],
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.black87,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const Spacer(),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFBB04C),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Text(
                                          '⭐',
                                          style: TextStyle(fontSize: 12),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      
                      // Service Info
                      Expanded(
                        flex: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item['review'],
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.black87,
                                  height: 1.3,
                                ),
                              ),
                              const Spacer(),
                              Row(
                                children: [
                                  const Text(
                                    'Service by',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[100],
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      item['service'],
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

}