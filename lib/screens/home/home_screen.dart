import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:google_sign_in/google_sign_in.dart';
import '../../services/auth_service.dart';
import '../../screens/auth/welcome_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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

  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = [
      _buildHomeScreen(),
      _buildTasksScreen(),
      _buildDiscoverScreen(),
      _buildProfileScreen(),
    ];

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: screens[_selectedIndex],
      floatingActionButton: _selectedIndex == 0 ? FloatingActionButton(
        onPressed: _onCreateServiceRequest,
        backgroundColor: const Color(0xFFFBB04C),
        elevation: 8,
        child: const Icon(Icons.add, color: Colors.white, size: 28),
      ) : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        color: Colors.white,
        elevation: 8,
        child: SizedBox(
          height: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildBottomNavItem(0, Icons.home, 'Home'),
              _buildBottomNavItem(1, Icons.assignment, 'Tasks'),
              const SizedBox(width: 40), // Space for FAB
              _buildBottomNavItem(2, Icons.explore, 'Discover'),
              _buildBottomNavItem(3, Icons.person, 'Profile'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavItem(int index, IconData icon, String label) {
    final isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: isSelected ? const Color(0xFFFBB04C) : Colors.grey,
            size: 24,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: isSelected ? const Color(0xFFFBB04C) : Colors.grey,
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHomeScreen() {
    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          children: [
            _buildHeader(),
            _buildPromotionalBanner(),
            const SizedBox(height: 20),
            _buildServiceProviderFeed(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFFBB04C), Color(0xFFFF8C42)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hello, ${_displayName ?? 'User'}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Text(
                'Find your perfect home service',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
          ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '50',
                  style: TextStyle(
                    color: Color(0xFFFBB04C),
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 4),
                Container(
                  width: 20,
                  height: 20,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFBB04C),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.star,
                    color: Colors.white,
                    size: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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
              padding: const EdgeInsets.all(24),
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
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    discount,
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    promoText,
                    style: const TextStyle(
                      fontSize: 10,
                      color: Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    promoCode,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFFBB04C),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 10,
                      color: Colors.grey,
                      height: 1.2,
                    ),
                  ),
                ],
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

  Widget _buildServiceProviderFeed() {
    final posts = [
      {
        'name': 'Shayla',
        'service': 'SweetHome',
        'rating': '⭐⭐⭐⭐⭐',
        'type': 'provider', // provider or user
        'images': [
          'https://images.unsplash.com/photo-1560472354-8b77cccf8f59?w=400',
          'https://images.unsplash.com/photo-1416879595882-3373a0480b5b?w=400',
          'https://images.unsplash.com/photo-1558618666-fcd25c85cd64?w=400',
        ],
        'review': 'They\'ve really done a great job on my garden!!',
        'avatar': 'https://images.unsplash.com/photo-1494790108755-2616b612e5e3?w=100',
        'time': '2 hours ago',
      },
      {
        'name': 'Mike Johnson',
        'service': 'CleanPro',
        'rating': '⭐⭐⭐⭐⭐',
        'type': 'user', // This is a customer post
        'images': [
          'https://images.unsplash.com/photo-1600585154340-be6161a56a0c?w=400',
          'https://images.unsplash.com/photo-1600566753151-384129cf4e3e?w=400',
        ],
        'review': 'Amazing cleaning service! My house has never looked better. The team was professional and thorough.',
        'avatar': 'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=100',
        'time': '5 hours ago',
      },
      {
        'name': 'Mikaela',
        'service': 'HomeLovely',
        'rating': '⭐⭐⭐⭐⭐',
        'type': 'provider',
        'images': [
          'https://images.unsplash.com/photo-1600585154340-be6161a56a0c?w=400',
          'https://images.unsplash.com/photo-1600566753151-384129cf4e3e?w=400',
          'https://images.unsplash.com/photo-1560472354-8b77cccf8f59?w=400',
        ],
        'review': 'I was recommended by a friend. I can\'t believe the turnout! It\'s so goooood! Definitely would recommend <3',
        'avatar': 'https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=100',
        'time': '1 day ago',
      },
      {
        'name': 'Sarah Chen',
        'service': 'GreenThumb',
        'rating': '⭐⭐⭐⭐⭐',
        'type': 'user',
        'images': [
          'https://images.unsplash.com/photo-1416879595882-3373a0480b5b?w=400',
        ],
        'review': 'Fantastic landscaping work! They transformed my backyard into a beautiful garden paradise.',
        'avatar': 'https://images.unsplash.com/photo-1494790108755-2616b612e5e3?w=100',
        'time': '2 days ago',
      },
      {
        'name': 'Jiwon',
        'service': 'RoofMaster',
        'rating': '⭐⭐⭐⭐⭐',
        'type': 'provider',
        'images': [
          'https://images.unsplash.com/photo-1580587771525-78b9dba3b914?w=400',
          'https://images.unsplash.com/photo-1571066811602-716837d681de?w=400',
        ],
        'review': 'Professional roofing service. Great quality work and attention to detail.',
        'avatar': 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=100',
        'time': '3 days ago',
      },
      {
        'name': 'David Kim',
        'service': 'PoolCare',
        'rating': '⭐⭐⭐⭐⭐',
        'type': 'user',
        'images': [
          'https://images.unsplash.com/photo-1571066811602-716837d681de?w=400',
          'https://images.unsplash.com/photo-1600566753151-384129cf4e3e?w=400',
          'https://images.unsplash.com/photo-1560472354-8b77cccf8f59?w=400',
          'https://images.unsplash.com/photo-1416879595882-3373a0480b5b?w=400',
        ],
        'review': 'Amazing pool cleaning and maintenance service. My pool is crystal clear now! Highly recommended!',
        'avatar': 'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=100',
        'time': '1 week ago',
      },
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: posts.map((post) => _buildProviderPost(post)).toList(),
      ),
    );
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
                          Text(
                            post['rating']!,
                            style: const TextStyle(fontSize: 16),
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
    return const Center(
      child: Text(
        'Tasks',
        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildDiscoverScreen() {
    return const Center(
      child: Text(
        'Discover',
        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildProfileScreen() {
    final user = widget.firebaseUser;
    if (user == null) {
      return const Center(child: Text('No user logged in'));
    }
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(user.uid).get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Center(child: Text('Profile data not found'));
        }
        final data = snapshot.data!.data() as Map<String, dynamic>;
        
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
                        child: CircleAvatar(
                          radius: 57,
                          backgroundImage: widget.googleUser?.photoUrl != null 
                              ? NetworkImage(widget.googleUser!.photoUrl!)
                              : null,
                          child: widget.googleUser?.photoUrl == null 
                              ? const Icon(Icons.person, size: 60, color: Colors.grey)
                              : null,
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
                                const Text(
                                  '5',
                                  style: TextStyle(
                                    fontSize: 36,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFFFBB04C),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Referrals',
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
                                const Text(
                                  '12',
                                  style: TextStyle(
                                    fontSize: 36,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFFFBB04C),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Tasks Completed',
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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildServiceRequestModal(),
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

  Widget _buildServiceCard(String title, IconData icon, Color color) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$title service request will be implemented soon')),
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
            Icon(icon, size: 48, color: color),
            const SizedBox(height: 8),
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
}

class MyConnectionsScreen extends StatefulWidget {
  const MyConnectionsScreen({super.key});

  @override
  State<MyConnectionsScreen> createState() => _MyConnectionsScreenState();
}

class _MyConnectionsScreenState extends State<MyConnectionsScreen> {
  final List<Map<String, String>> connections = [
    {
      'name': 'Anne',
      'avatar': 'https://images.unsplash.com/photo-1494790108755-2616b612e5e3?w=100',
    },
    {
      'name': 'Bethany',
      'avatar': 'https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=100',
    },
    {
      'name': 'Derek',
      'avatar': 'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=100',
    },
    {
      'name': 'Dianne',
      'avatar': 'https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=100',
    },
    {
      'name': 'Emma',
      'avatar': 'https://images.unsplash.com/photo-1517841905240-472988babdf9?w=100',
    },
    {
      'name': 'Mary',
      'avatar': 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=100',
    },
    {
      'name': 'Penny',
      'avatar': 'https://images.unsplash.com/photo-1508214751196-bcfd4ca60f91?w=100',
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
              // Add new connection functionality
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Add connection feature coming soon!')),
              );
            },
          ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: connections.length,
        itemBuilder: (context, index) {
          final connection = connections[index];
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
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.message_outlined, color: Color(0xFFFBB04C)),
                    onPressed: () {
                      // Message functionality
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Message ${connection['name']} feature coming soon!')),
                      );
                    },
                  ),
                  PopupMenuButton(
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
                        _showDeleteDialog(connection['name']!);
                      }
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showDeleteDialog(String name) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Connection'),
        content: Text('Are you sure you want to remove $name from your connections?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('$name removed from connections')),
              );
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
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