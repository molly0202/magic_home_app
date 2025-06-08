import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../auth/welcome_screen.dart';
import '../auth/hsp_verification_screen.dart';

class HspHomeScreen extends StatefulWidget {
  final firebase_auth.User user;

  const HspHomeScreen({super.key, required this.user});

  @override
  State<HspHomeScreen> createState() => _HspHomeScreenState();
}

class _HspHomeScreenState extends State<HspHomeScreen> {
  int _selectedIndex = 0;

  void _navigateToVerification() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => HspVerificationScreen(
          user: widget.user,
          email: widget.user.email ?? '',
        ),
      ),
    );
  }

  String _getStatusText(Map<String, dynamic>? providerData) {
    if (providerData == null) return 'Loading...';
    
    final status = (providerData['status'] as String?)?.toLowerCase();
    final verificationStep = providerData['verificationStep'] as String?;
    
    switch (status) {
      case 'pending_verification':
        return 'Pending Verification';
      case 'under_review':
        return 'Under Review';
      case 'verified':
      case 'active':
        return 'Verified';
      case 'rejected':
        return 'Application Rejected';
      default:
        // Check if user has completed initial setup but hasn't submitted docs
        if (verificationStep == 'documents_pending') {
          return 'Pending Verification';
        }
        // If documents are submitted but status isn't set properly
        if (verificationStep == 'documents_submitted') {
          return 'Under Review';
        }
        return 'Pending Verification';
    }
  }

  Color _getStatusColor(Map<String, dynamic>? providerData) {
    if (providerData == null) return Colors.grey;
    
    final status = (providerData['status'] as String?)?.toLowerCase();
    final verificationStep = providerData['verificationStep'] as String?;
    
    switch (status) {
      case 'pending_verification':
      case 'under_review':
        return Colors.orange;
      case 'verified':
      case 'active':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        // If documents are submitted but status isn't set properly
        if (verificationStep == 'documents_submitted') {
          return Colors.orange;
        }
        return Colors.grey;
    }
  }

  Widget _buildStatusCard(Map<String, dynamic>? providerData) {
    final status = (providerData?['status'] as String?)?.toLowerCase();
    final verificationStep = providerData?['verificationStep'] as String?;
    
    final needsVerification = (status == 'pending_verification' || 
                              verificationStep == 'documents_pending') &&
                              status != 'verified' && status != 'active';
    
    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: _getStatusColor(providerData),
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  'Account Status',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: needsVerification ? _navigateToVerification : null,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: _getStatusColor(providerData).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _getStatusColor(providerData).withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _getStatusText(providerData),
                      style: TextStyle(
                        color: _getStatusColor(providerData),
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    if (needsVerification) ...[
                      const SizedBox(width: 8),
                      Icon(
                        Icons.arrow_forward_ios,
                        color: _getStatusColor(providerData),
                        size: 16,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            _buildStatusDescription(providerData),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusDescription(Map<String, dynamic>? providerData) {
    final status = (providerData?['status'] as String?)?.toLowerCase();
    
    switch (status) {
      case 'pending_verification':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Complete your document submission to start taking new task requests.',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            const Text(
              'Required documents:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text(
              '• Government ID\n'
              '• Business License\n'
              '• Insurance Certificate',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tap on the status above to continue with verification.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.orange,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        );
      
      case 'under_review':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your application is currently being reviewed by our team.',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            const Text(
              'What happens next:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text(
              '• Our team is reviewing your submitted documents\n'
              '• You will receive an email notification once approved\n'
              '• Approval typically takes 1-2 business days',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        );
      case 'verified':
      case 'active':
        return const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '🎉 Congratulations! Your account is now verified.',
              style: TextStyle(fontSize: 16, color: Colors.green),
            ),
            SizedBox(height: 8),
            Text(
              'You can now:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 4),
            Text(
              '• Receive service requests from customers\n'
              '• Manage your services and pricing\n'
              '• Build your reputation with reviews',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        );
      
      case 'rejected':
        return const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Unfortunately, we cannot approve your application at this time.',
              style: TextStyle(fontSize: 16, color: Colors.red),
            ),
            SizedBox(height: 8),
            Text(
              'Please contact our support team for more information.',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        );
      default:
        return const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Complete your verification to start receiving service requests.',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              'Tap on the status above to continue with your verification.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        );
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  List<Widget> _getScreens(Map<String, dynamic>? providerData) {
    return [
      _buildDashboard(providerData),
      _buildServices(),
      _buildBookings(),
      _buildProfile(),
    ];
  }

  Widget _buildDashboard(Map<String, dynamic>? providerData) {
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildStatusCard(providerData),
          if (providerData?['status'] == 'verified' || providerData?['status'] == 'active') ...[
            _buildQuickStats(),
            _buildRecentActivity(),
          ],
        ],
      ),
    );
  }

  Widget _buildQuickStats() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Quick Stats',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard('Total Jobs', '12', Colors.blue),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard('This Month', '3', Colors.green),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard('Rating', '4.8', Colors.orange),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard('Earnings', '\$1,250', Colors.purple),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivity() {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Recent Activity',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildActivityItem('Plumbing service completed', '2 hours ago'),
            _buildActivityItem('New booking received', '1 day ago'),
            _buildActivityItem('Customer review received', '2 days ago'),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityItem(String title, String time) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Color(0xFFFBB04C),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                Text(
                  time,
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

  Widget _buildServices() {
    return const Center(
      child: Text(
        'Services',
        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildBookings() {
    return const Center(
      child: Text(
        'Bookings',
        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildProfile() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'Profile',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () async {
              await firebase_auth.FirebaseAuth.instance.signOut();
              if (mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const WelcomeScreen()),
                  (route) => false,
                );
              }
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

  @override
  Widget build(BuildContext context) {
    print('Building HspHomeScreen for user: ${widget.user.uid}');
    print('User email: ${widget.user.email}');
    
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Magic Home Provider'),
        backgroundColor: const Color(0xFFFBB04C),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              print('Manual refresh triggered');
              setState(() {});
            },
          ),
          IconButton(
            icon: const Icon(Icons.bug_report),
            onPressed: () async {
              // Manual debug function
              try {
                final doc = await FirebaseFirestore.instance
                    .collection('providers')
                    .doc(widget.user.uid)
                    .get();
                
                if (doc.exists) {
                  final data = doc.data() as Map<String, dynamic>;
                  print('MANUAL CHECK - Status: ${data['status']}');
                  print('MANUAL CHECK - Full data: $data');
                  
                  // Show dialog with status
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Debug Info'),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('User ID: ${widget.user.uid}'),
                          Text('Email: ${widget.user.email}'),
                          Text('Status: ${data['status']}'),
                          Text('Verification Step: ${data['verificationStep']}'),
                        ],
                      ),
                      actions: [
                        TextButton(
                          onPressed: () async {
                            // Force update status to verified
                            await FirebaseFirestore.instance
                                .collection('providers')
                                .doc(widget.user.uid)
                                .update({'status': 'verified'});
                            Navigator.pop(context);
                          },
                          child: const Text('Set to Verified'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Close'),
                        ),
                      ],
                    ),
                  );
                } else {
                  print('MANUAL CHECK - Document does not exist');
                }
              } catch (e) {
                print('MANUAL CHECK - Error: $e');
              }
            },
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('providers')
            .doc(widget.user.uid)
            .snapshots(),
        builder: (context, snapshot) {
          print('StreamBuilder state: ${snapshot.connectionState}');
          print('Has data: ${snapshot.hasData}');
          if (snapshot.hasData) {
            print('Document exists: ${snapshot.data!.exists}');
            if (snapshot.data!.exists) {
              final data = snapshot.data!.data() as Map<String, dynamic>;
              print('Provider data: $data');
              print('Current status: ${data['status']}');
            }
          }
          if (snapshot.hasError) {
            print('StreamBuilder error: ${snapshot.error}');
          }
          
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Provider data not found',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'User ID: ${widget.user.uid}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      print('Retry button pressed');
                      setState(() {});
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }
          
          final providerData = snapshot.data!.data() as Map<String, dynamic>;
          
          return _getScreens(providerData)[_selectedIndex];
        },
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: const Color(0xFFFBB04C),
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.build),
            label: 'Services',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today),
            label: 'Bookings',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
} 