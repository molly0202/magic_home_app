import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:google_sign_in/google_sign_in.dart';
import '../../services/auth_service.dart';
import '../../screens/auth/welcome_screen.dart';

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
      margin: const EdgeInsets.all(16),
      height: 180,
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
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [Colors.grey, Colors.white],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'sendhelper',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
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
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    promoText,
                    style: const TextStyle(
                      fontSize: 10,
                      color: Colors.grey,
                    ),
                  ),
                  Text(
                    promoCode,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 10,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: ClipRRect(
              borderRadius: const BorderRadius.horizontal(right: Radius.circular(16)),
              child: Container(
                height: double.infinity,
                decoration: const BoxDecoration(
                  image: DecorationImage(
                    image: NetworkImage('https://images.unsplash.com/photo-1558618666-fcd25c85cd64?w=400'),
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
    final providers = [
      {
        'name': 'Shayla',
        'service': 'SweetHome',
        'rating': '⭐',
        'image': 'https://images.unsplash.com/photo-1560472354-8b77cccf8f59?w=400',
        'beforeImage': 'https://images.unsplash.com/photo-1416879595882-3373a0480b5b?w=400',
        'afterImage': 'https://images.unsplash.com/photo-1558618666-fcd25c85cd64?w=400',
        'review': 'They\'ve really done a great job on my garden!!',
        'avatar': 'https://images.unsplash.com/photo-1494790108755-2616b612e5e3?w=100',
      },
      {
        'name': 'Mikaela',
        'service': 'HomeLovely',
        'rating': '⭐',
        'image': 'https://images.unsplash.com/photo-1600585154340-be6161a56a0c?w=400',
        'beforeImage': 'https://images.unsplash.com/photo-1600585154340-be6161a56a0c?w=400',
        'afterImage': 'https://images.unsplash.com/photo-1600566753151-384129cf4e3e?w=400',
        'review': 'I was recommended by a friend. I can\'t believe the turnout! It\'s so goooood! Definitely would recommend <3',
        'avatar': 'https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=100',
      },
      {
        'name': 'Jiwon',
        'service': 'RoofMaster',
        'rating': '⭐',
        'image': 'https://images.unsplash.com/photo-1580587771525-78b9dba3b914?w=400',
        'beforeImage': 'https://images.unsplash.com/photo-1580587771525-78b9dba3b914?w=400',
        'afterImage': 'https://images.unsplash.com/photo-1580587771525-78b9dba3b914?w=400',
        'review': 'Professional roofing service. Great quality work and attention to detail.',
        'avatar': 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=100',
      },
      {
        'name': 'Liyuan',
        'service': 'PoolCare',
        'rating': '⭐',
        'image': 'https://images.unsplash.com/photo-1571066811602-716837d681de?w=400',
        'beforeImage': 'https://images.unsplash.com/photo-1571066811602-716837d681de?w=400',
        'afterImage': 'https://images.unsplash.com/photo-1571066811602-716837d681de?w=400',
        'review': 'Amazing pool cleaning and maintenance service. Highly recommended!',
        'avatar': 'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=100',
      },
    ];

    return Column(
      children: providers.map((provider) => _buildProviderPost(provider)).toList(),
    );
  }

  Widget _buildProviderPost(Map<String, String> provider) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Provider header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundImage: NetworkImage(provider['avatar']!),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            provider['name']!,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            provider['rating']!,
                            style: const TextStyle(fontSize: 16),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Service image
          ClipRRect(
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
            child: Image.network(
              provider['image']!,
              height: 200,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          
          // Review and service info
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  provider['review']!,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text(
                      'Service by',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
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
                          Container(
                            width: 16,
                            height: 16,
                            decoration: const BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 10,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            provider['service']!,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
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
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 50,
            backgroundImage: widget.googleUser?.photoUrl != null 
                ? NetworkImage(widget.googleUser!.photoUrl!)
                : null,
            child: widget.googleUser?.photoUrl == null 
                ? const Icon(Icons.person, size: 50)
                : null,
          ),
          const SizedBox(height: 16),
          Text(
            _displayName ?? 'User',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          Text(
            _displayEmail ?? 'No email',
            style: const TextStyle(fontSize: 16, color: Colors.grey),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () async {
              await _authService.logout();
              if (!mounted) return;
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const WelcomeScreen()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            child: const Text(
              'Sign Out',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
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