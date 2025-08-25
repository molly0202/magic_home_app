import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../auth/welcome_screen.dart';
import '../auth/hsp_verification_screen.dart';
import '../../services/notification_service.dart';
import '../../services/hsp_home_service.dart';
import '../../models/provider_stats.dart';
import '../../models/service_order.dart';


import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../debug/function_test_screen.dart';
import '../debug/token_debug_screen.dart';
import '../bidding/provider_bid_screen.dart';
import '../bidding/service_request_detail_screen.dart';
import '../../services/bidding_service.dart';
import '../../services/user_task_service.dart';
import '../../models/user_request.dart';
import '../tasks/assigned_task_detail_screen.dart';
import '../../services/reviews_service.dart';

class HspHomeScreen extends StatefulWidget {
  final firebase_auth.User user;

  const HspHomeScreen({super.key, required this.user});

  @override
  State<HspHomeScreen> createState() => _HspHomeScreenState();
}

class _HspHomeScreenState extends State<HspHomeScreen> {
  int _selectedIndex = 0;
  ProviderStats? _providerStats;
  bool _statusPanelMinimized = false;
  bool _isAcceptingNewTasks = false;
  String _currentAddress = 'Lynnwood, WA 98036';
  String? _dismissedStatusPanelForStatus;

  @override
  void initState() {
    super.initState();
    // Start listening for status changes for in-app notifications
    NotificationService.listenForStatusChanges(widget.user.uid, context);
    // Initialize push notifications and save FCM token
    NotificationService.initializePushNotifications(widget.user.uid);
    // Load provider stats
    _loadProviderStats();
    // Load provider settings
    _loadProviderSettings();
    // Load status panel dismissal state
    _loadStatusPanelDismissalState();
  }

  Future<void> _loadProviderStats() async {
    final stats = await HspHomeService.getProviderStats(widget.user.uid);
    setState(() {
      _providerStats = stats;
    });
  }

  Future<void> _loadProviderSettings() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('providers')
          .doc(widget.user.uid)
          .get();
      
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        setState(() {
          _isAcceptingNewTasks = data['acceptingNewTasks'] ?? false;
          _currentAddress = data['address'] ?? 'Lynnwood, WA 98036';
        });
      }
    } catch (e) {
      print('Error loading provider settings: $e');
    }
  }

  Future<void> _loadStatusPanelDismissalState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'dismissed_status_panel_${widget.user.uid}';
      final dismissedStatus = prefs.getString(key);
      setState(() {
        _dismissedStatusPanelForStatus = dismissedStatus;
      });
    } catch (e) {
      print('Error loading status panel dismissal state: $e');
    }
  }

  Future<void> _saveStatusPanelDismissalState(String status) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'dismissed_status_panel_${widget.user.uid}';
      await prefs.setString(key, status);
      setState(() {
        _dismissedStatusPanelForStatus = status;
      });
    } catch (e) {
      print('Error saving status panel dismissal state: $e');
    }
  }

  Future<void> _toggleNewTasksStatus() async {
    try {
      final newStatus = !_isAcceptingNewTasks;
      
      await FirebaseFirestore.instance
          .collection('providers')
          .doc(widget.user.uid)
          .update({
        'acceptingNewTasks': newStatus,
        'lastStatusUpdate': FieldValue.serverTimestamp(),
      });
      
      setState(() {
        _isAcceptingNewTasks = newStatus;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newStatus 
                ? 'You are now accepting new tasks' 
                : 'You are no longer accepting new tasks'
            ),
            backgroundColor: const Color(0xFFFBB04C),
          ),
        );
      }
    } catch (e) {
      print('Error updating task status: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update status. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _updateProviderAddress() async {
    final addressController = TextEditingController(text: _currentAddress);
    
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update Your Address'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
        children: [
            const Text(
              'Enter your service area address:',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: addressController,
              decoration: const InputDecoration(
                labelText: 'Address',
                border: OutlineInputBorder(),
                helperText: 'This will be shown to customers',
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: () async {
                // Here you could add location services to get current location
                // For now, we'll use a default location
                addressController.text = 'Lynnwood, WA 98036';
              },
              icon: const Icon(Icons.my_location),
              label: const Text('Use Current Location'),
            ),
        ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final newAddress = addressController.text.trim();
              if (newAddress.isNotEmpty) {
                Navigator.pop(context, newAddress);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFBB04C),
              foregroundColor: Colors.white,
            ),
            child: const Text('Update'),
          ),
        ],
      ),
    );
    
    if (result != null && result != _currentAddress) {
      try {
        await FirebaseFirestore.instance
            .collection('providers')
            .doc(widget.user.uid)
            .update({
          'address': result,
          'lastAddressUpdate': FieldValue.serverTimestamp(),
        });
        
        setState(() {
          _currentAddress = result;
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Address updated successfully'),
              backgroundColor: Color(0xFFFBB04C),
            ),
          );
        }
      } catch (e) {
        print('Error updating address: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to update address. Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
    
    addressController.dispose();
  }

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

    // Completely hide panel if user has dismissed it for this status
    if ((status == 'verified' || status == 'active') && 
        _dismissedStatusPanelForStatus == status) {
      return const SizedBox.shrink(); // Completely hidden
    }

    // Legacy minimized state (for backwards compatibility during this session)
    if ((status == 'verified' || status == 'active') && _statusPanelMinimized) {
      return GestureDetector(
        onTap: () {
          setState(() {
            _statusPanelMinimized = false;
          });
        },
        child: Card(
          margin: const EdgeInsets.all(16),
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              children: [
                Icon(Icons.verified, color: Colors.green[700]),
                const SizedBox(width: 10),
                const Text('Account Verified', style: TextStyle(fontWeight: FontWeight.bold)),
                const Spacer(),
                Icon(Icons.expand_more, color: Colors.grey[600]),
              ],
            ),
          ),
        ),
      );
    }

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
                const Spacer(),
                if (status == 'verified' || status == 'active')
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      _saveStatusPanelDismissalState(status!);
                    },
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
      _buildDiscover(),
      _buildMyTasks(),
      _buildProfile(),
    ];
  }

  Widget _buildDashboard(Map<String, dynamic>? providerData) {
    final isVerified = providerData?['status'] == 'verified' || providerData?['status'] == 'active';
    
    return SafeArea(
      child: Column(
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: const BoxDecoration(
              color: Color(0xFFFBB04C),
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: _updateProviderAddress,
                  child: Row(
                    children: [
                      const Icon(Icons.location_on, color: Colors.white),
                      const SizedBox(width: 8),
                      Text(
                        _currentAddress,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.edit, color: Colors.white70, size: 16),
                    ],
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: _toggleNewTasksStatus,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _isAcceptingNewTasks 
                          ? Colors.green.withOpacity(0.2)
                          : Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                        color: _isAcceptingNewTasks 
                            ? Colors.green.withOpacity(0.5)
                            : Colors.white.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'New Tasks',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 40,
                          height: 20,
                          decoration: BoxDecoration(
                            color: _isAcceptingNewTasks ? Colors.green : Colors.grey,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: AnimatedAlign(
                            duration: const Duration(milliseconds: 200),
                            alignment: _isAcceptingNewTasks 
                                ? Alignment.centerRight 
                                : Alignment.centerLeft,
                            child: Container(
                              width: 16,
                              height: 16,
                              margin: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  _buildStatusCard(providerData),
                  if (isVerified) ...[
                    _buildStatsDashboard(),
                    _buildBiddingOpportunities(),
                    // Removed _buildPendingRequests from Home tab - it was redundant with bidding opportunities
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsDashboard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
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
                      '${_providerStats?.tasksThisMonth ?? 3}',
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFFBB04C),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'This Month',
                      style: TextStyle(
                        fontSize: 14,
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
                    Text(
                      '${_providerStats?.totalTasks ?? 12}',
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFFBB04C),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Total Tasks',
                      style: TextStyle(
                        fontSize: 14,
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
                    Text(
                      '\$${(_providerStats?.totalEarned ?? 3402.0).toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFFBB04C),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Earned',
                      style: TextStyle(
                        fontSize: 14,
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
    );
  }

  Widget _buildStatCard(String title, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
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
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildUpcomingTasks() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
            const Text(
              'Upcoming Task',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFFFBB04C),
              ),
            ),
            const SizedBox(height: 16),
            StreamBuilder<List<ServiceOrder>>(
              stream: HspHomeService.getUpcomingTasks(widget.user.uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                if (snapshot.hasError) {
                  debugPrint('Firestore error: \\${snapshot.error}');
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, color: Colors.red, size: 40),
                        const SizedBox(height: 8),
                        Text('Something went wrong. Please try again later.',
                            style: TextStyle(color: Colors.red, fontSize: 16)),
                      ],
                    ),
                  );
                }
                
                final tasks = snapshot.data ?? [];
                
                if (tasks.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Icon(
                          Icons.schedule_outlined,
                          size: 48,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'No upcoming tasks',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'You\'ll see your scheduled tasks here',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  );
                }
                
                return Column(
                  children: tasks.take(3).map((task) => _buildTaskItem(task)).toList(),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildTaskItem(ServiceOrder task) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  task.serviceDescription ?? 'Service Task',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getTaskStatusColor(task.status).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _getTaskStatusText(task.status),
                  style: TextStyle(
                    color: _getTaskStatusColor(task.status),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
            const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
              const SizedBox(width: 4),
              Text(
                _formatDateTime(task.scheduledTime),
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
              const Spacer(),
              Text(
                '\$${task.finalPrice.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.green,
                ),
              ),
            ],
          ),
            const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  task.confirmedAddress,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          ..._buildTaskStatusWidgets(task),
        ],
      ),
    );
  }

  List<Widget> _buildTaskStatusWidgets(ServiceOrder task) {
    if (task.status == 'confirmed') {
      return [
        const SizedBox(height: 12),
        Row(
        children: [
            Expanded(
              child: ElevatedButton(
                onPressed: () => _updateTaskStatus(task.orderId, 'in_progress'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
                child: const Text('Start Task'),
              ),
            ),
        ],
        ),
      ];
    } else if (task.status == 'in_progress') {
      return [
        const SizedBox(height: 12),
        Row(
        children: [
            Expanded(
              child: ElevatedButton(
                onPressed: () => _updateTaskStatus(task.orderId, 'completed'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
                child: const Text('Mark Complete'),
              ),
            ),
        ],
        ),
      ];
    }
    return [];
  }

  Future<void> _updateTaskStatus(String orderId, String newStatus) async {
    try {
      await HspHomeService.updateOrderStatus(orderId, newStatus);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Task status updated to ${_getTaskStatusText(newStatus)}')),
      );
      // Refresh stats
      _loadProviderStats();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating task status: $e')),
      );
    }
  }

  Widget _buildCompletedTasks() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Completed Tasks',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF4CAF50),
            ),
          ),
            const SizedBox(height: 16),
          StreamBuilder<List<ServiceOrder>>(
            stream: HspHomeService.getCompletedTasks(widget.user.uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                if (snapshot.hasError) {
                  debugPrint('Firestore error: ${snapshot.error}');
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, color: Colors.red, size: 40),
                        const SizedBox(height: 8),
                        Text('Something went wrong. Please try again later.',
                            style: TextStyle(color: Colors.red, fontSize: 16)),
                      ],
                    ),
                  );
                }
                
              final tasks = snapshot.data ?? [];
                
              if (tasks.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Icon(
                        Icons.check_circle_outline,
                          size: 48,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 8),
                        Text(
                        'No completed tasks',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                        'Your completed tasks will appear here',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  );
                }
                
                return Column(
                children: tasks.take(5).map((task) => _buildTaskItem(task)).toList(),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildRequestItem(UserRequest request) {
    final isBiddingRequest = request.status == 'bidding';
    
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ServiceRequestDetailScreen(userRequest: request),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isBiddingRequest ? Colors.blue[50] : Colors.orange[50],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isBiddingRequest ? Colors.blue[200]! : Colors.orange[200]!,
            width: isBiddingRequest ? 2 : 1,
          ),
        ),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
            Row(
              children: [
                if (isBiddingRequest) ...[
                  Icon(Icons.gavel, color: Colors.blue[700], size: 18),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    request.description,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isBiddingRequest 
                        ? Colors.blue.withOpacity(0.1)
                        : Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isBiddingRequest ? 'Bidding' : 'Pending',
                    style: TextStyle(
                      color: isBiddingRequest ? Colors.blue : Colors.orange,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            if (isBiddingRequest && request.preferences != null && 
                request.preferences!['price_range'] != null &&
                request.preferences!['price_range'].toString().isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                  Icon(Icons.attach_money, size: 16, color: Colors.green[600]),
                  const SizedBox(width: 4),
                  Text(
                    'Budget: ${request.preferences!['price_range']}',
                    style: TextStyle(
                      color: Colors.green[700],
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.category, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Category: ${request.serviceCategory}',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  request.preferences?['price_range'] ?? 'No budget set',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    request.address,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.schedule, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  _formatDateTime(request.createdAt),
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
                const Spacer(),
                ElevatedButton(
                  onPressed: () => _navigateToAcceptRequest(request),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  child: const Text('Accept'),
                ),
              ],
            ),
        ],
        ),
      ),
    );
  }



  void _navigateToAcceptRequest(UserRequest request) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ServiceRequestDetailScreen(userRequest: request),
      ),
    );
  }

  Color _getTaskStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed':
        return Colors.blue;
      case 'in_progress':
        return Colors.orange;
      case 'completed':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _getTaskStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed':
        return 'Confirmed';
      case 'in_progress':
        return 'In Progress';
      case 'completed':
        return 'Completed';
      default:
        return status;
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final taskDate = DateTime(dateTime.year, dateTime.month, dateTime.day);
    
    String dateText;
    if (taskDate == today) {
      dateText = 'Today';
    } else if (taskDate == tomorrow) {
      dateText = 'Tomorrow';
    } else {
      dateText = '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
    
    final timeText = '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    
    return '$dateText at $timeText';
  }

  Widget _buildDiscover() {
    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
        children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: const BoxDecoration(
                color: Color(0xFFFBB04C),
              ),
              child: GestureDetector(
                onTap: _updateProviderAddress,
                child: Row(
                  children: [
                    const Icon(Icons.location_on, color: Colors.white),
                    const SizedBox(width: 8),
                    Text(
                      _currentAddress,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.edit, color: Colors.white70, size: 16),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Promotional Banner
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              height: 200,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                image: const DecorationImage(
                  image: NetworkImage('https://images.unsplash.com/photo-1558618666-fcd25c85cd64?w=400'),
                  fit: BoxFit.cover,
                ),
              ),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Colors.black.withOpacity(0.7),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: const Padding(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'sendhelper',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                      Text(
                        'DEEP CLEANING SERVICE',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 10),
                      Text(
                        '10% OFF',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'ENTER PROMO CODE',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        'DCFS',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Service Provider Feed
            _buildServiceProviderFeed(),
        ],
        ),
      ),
    );
  }

  Widget _buildBiddingOpportunities() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: BiddingService.getProviderBiddingOpportunities(widget.user.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '🔥 Bidding Opportunities',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFFFBB04C),
                  ),
                ),
              ],
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '🔥 Bidding Opportunities',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.work_outline,
                        size: 48,
                        color: Colors.grey[500],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No Active Bidding Opportunities',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[700],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'We\'ll notify you when customers post requests matching your skills',
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
            ),
          );
        }

        final opportunities = snapshot.data!;
        
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                                  Text(
                  '🔥 Bidding Opportunities',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.refresh, color: Colors.grey[600]),
                  onPressed: () {
                    setState(() {}); // Force rebuild to refresh stream
                  },
                ),
                const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Color(0xFFFBB04C),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${opportunities.length} available',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
              // Bidding opportunities list
              Container(
                height: 230, // Further increased height to prevent bottom overflow
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: opportunities.length,
                  itemBuilder: (context, index) {
                    final opportunity = opportunities[index];
                    final request = opportunity['request'] as UserRequest;
                    final deadline = opportunity['deadline'] as DateTime?;
                    final timeRemaining = opportunity['timeRemaining'] as Duration?;
                    
                    return Container(
                      width: 300, // Further increased width to prevent right overflow
                      margin: EdgeInsets.only(right: 12),
                      child: _buildOpportunityCard(request, deadline, timeRemaining),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOpportunityCard(UserRequest request, DateTime? deadline, Duration? timeRemaining) {
    final isUrgent = timeRemaining != null && timeRemaining.inHours < 1;
    
    return GestureDetector(
      onTap: () => _navigateToBidding(request, deadline),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isUrgent ? Colors.red : Color(0xFFFBB04C),
            width: isUrgent ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Card(
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12), // Reduced padding to prevent overflow
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with urgency indicator
                Row(
                  children: [
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isUrgent ? Colors.red : Color(0xFFFBB04C),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          request.serviceCategory.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (isUrgent)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'URGENT',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                
                const SizedBox(height: 8), // Reduced spacing
                
                // Description
                Text(
                  request.description,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[800],
                    height: 1.3,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                
                const SizedBox(height: 6), // Reduced spacing
                
                // Location
                Row(
                  children: [
                    Icon(Icons.location_on, size: 14, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        request.address.split(',').first, // Show just city
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                
                const Spacer(),
                
                // Price estimation from AI
                if (request.aiPriceEstimation != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.insights, size: 12, color: Colors.blue),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            'AI Price: \$${request.aiPriceEstimation!['suggestedRange']?['min']?.toInt() ?? ''}-\$${request.aiPriceEstimation!['suggestedRange']?['max']?.toInt() ?? ''}',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.blue,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6), // Reduced spacing
                ],
                
                // Time remaining and action button
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Time Remaining',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey[600],
                            ),
                          ),
                          Text(
                            timeRemaining != null 
                                ? BiddingService.formatTimeRemaining(timeRemaining)
                                : 'Unknown',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isUrgent ? Colors.red : Color(0xFFFBB04C),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 70, // Fixed width to prevent overflow
                      child: ElevatedButton(
                        onPressed: () => _navigateToBidding(request, deadline),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isUrgent ? Colors.red : Color(0xFFFBB04C),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          minimumSize: Size(0, 0),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'BID',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _navigateToBidding(UserRequest request, DateTime? deadline) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProviderBidScreen(
          requestId: request.requestId!,
          userRequest: request,
          deadline: deadline,
        ),
      ),
    );
  }



  Widget _buildAssignedTaskCard(UserRequest task) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: UserTaskService.getUserDetails(task.userId),
      builder: (context, userSnapshot) {
        final userData = userSnapshot.data;
        
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.green, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.green.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              // Header with user contact info
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.05),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.check_circle,
                          color: Colors.green,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'QUOTE ACCEPTED',
                          style: TextStyle(
                            color: Colors.green[700],
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          _formatDateTime(task.createdAt),
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    
                    // User contact information
                    if (userData != null) ...[
                      Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.green,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Center(
                              child: Text(
                                (userData['displayName'] ?? userData['email'] ?? 'U')
                                    .substring(0, 1)
                                    .toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  userData['displayName'] ?? 'User',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (task.phoneNumber.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  GestureDetector(
                                    onTap: () => _makePhoneCall(task.phoneNumber),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.phone,
                                          size: 14,
                                          color: Colors.green[700],
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          task.phoneNumber,
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.green[700],
                                            decoration: TextDecoration.underline,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => _makePhoneCall(task.phoneNumber),
                            icon: Icon(
                              Icons.phone,
                              color: Colors.green[700],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              
              // Task details
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.description,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    
                    // Address
                    Row(
                      children: [
                        Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            task.address,
                            style: TextStyle(
                              color: Colors.grey[700],
                              fontSize: 14,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          onPressed: () => _openMaps(task.address),
                          icon: Icon(
                            Icons.directions,
                            color: Colors.blue[700],
                          ),
                        ),
                      ],
                    ),
                    
                    // Availability
                    if (task.userAvailability.isNotEmpty && 
                        task.userAvailability['preferredTime'] != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.schedule, size: 16, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(
                            'Available: ${task.userAvailability['preferredTime']}',
                            style: TextStyle(
                              color: Colors.grey[700],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ],
                    
                    const SizedBox(height: 12),
                    
                    // Action buttons
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _viewTaskDetails(task),
                            icon: const Icon(Icons.visibility, size: 16),
                            label: const Text('View Details'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _markTaskCompleted(task),
                            icon: const Icon(Icons.done, size: 16),
                            label: const Text('Mark Complete'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
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
      },
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

  void _viewTaskDetails(UserRequest task) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AssignedTaskDetailScreen(task: task),
      ),
    );
  }

  void _markTaskCompleted(UserRequest task) {
    // TODO: Implement task completion logic
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mark Task Complete'),
        content: const Text('Are you sure you want to mark this task as completed?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              // TODO: Update task status to completed
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Task marked as completed!'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text('Complete'),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceProviderFeed() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Customer Reviews',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              Row(
                children: [
                  Icon(
                    Icons.location_on,
                    size: 16,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Nearby',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
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
                        'Customer reviews will appear here to help you understand market trends',
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
      // Get current provider's location for distance calculation
      String? providerLocation = _currentAddress;

      // Fetch recent reviews with distance sorting
      return await ReviewsService.getRecentReviewsWithDistance(
        currentUserLocation: providerLocation,
        limit: 15,
      );
    } catch (e) {
      print('Error loading provider reviews: $e');
      return [];
    }
  }

  Widget _buildReviewCard(Map<String, dynamic> review) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with customer info and rating
            Row(
              children: [
                // Customer avatar
                CircleAvatar(
                  radius: 20,
                  backgroundImage: review['customerAvatar'] != null
                      ? NetworkImage(review['customerAvatar'])
                      : null,
                  backgroundColor: Colors.grey[300],
                  child: review['customerAvatar'] == null
                      ? Icon(Icons.person, color: Colors.grey[600])
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              review['customerName'] ?? 'Anonymous',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          Text(
                            review['ratingStars'] ?? '⭐⭐⭐⭐⭐',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(
                            Icons.business,
                            size: 12,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              review['providerName'] ?? 'Provider',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          if (review['distanceText'] != null) ...[
                            Icon(
                              Icons.location_on,
                              size: 12,
                              color: Colors.grey[500],
                            ),
                            const SizedBox(width: 2),
                            Text(
                              review['distanceText'],
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Service category
            if (review['serviceCategory'] != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFBB04C).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  review['serviceCategory'],
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFFFBB04C),
                  ),
                ),
              ),
            
            const SizedBox(height: 8),
            
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
            
            // Photos section (Instagram style)
            if (review['photoUrls'] != null && (review['photoUrls'] as List).isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildPhotoGrid(review['photoUrls'] as List<dynamic>),
            ],
            
            const SizedBox(height: 12),
            
            // Footer with time and photo indicator
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  review['timeAgo'] ?? 'Recently',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                ),
                if (review['hasPhotos'] == true)
                  Row(
                    children: [
                      Icon(
                        Icons.photo_camera,
                        size: 12,
                        color: Colors.grey[500],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${review['photoCount']} photo${review['photoCount'] == 1 ? '' : 's'}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoGrid(List<dynamic> photoUrls) {
    final urls = photoUrls.cast<String>();
    
    if (urls.isEmpty) return const SizedBox.shrink();
    
    // Instagram-style photo layout
    if (urls.length == 1) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Image.network(
            urls[0],
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Container(
              color: Colors.grey[300],
              child: const Icon(Icons.image_not_supported),
            ),
          ),
        ),
      );
    } else if (urls.length == 2) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          height: 200,
          child: Row(
            children: [
              Expanded(
                child: Image.network(
                  urls[0],
                  fit: BoxFit.cover,
                  height: 200,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: Colors.grey[300],
                    child: const Icon(Icons.image_not_supported),
                  ),
                ),
              ),
              const SizedBox(width: 2),
              Expanded(
                child: Image.network(
                  urls[1],
                  fit: BoxFit.cover,
                  height: 200,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: Colors.grey[300],
                    child: const Icon(Icons.image_not_supported),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    } else if (urls.length == 3) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          height: 200,
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: Image.network(
                  urls[0],
                  fit: BoxFit.cover,
                  height: 200,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: Colors.grey[300],
                    child: const Icon(Icons.image_not_supported),
                  ),
                ),
              ),
              const SizedBox(width: 2),
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
                    const SizedBox(height: 2),
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
        ),
      );
    } else {
      // 4+ photos: show first 3 and "+X more" overlay
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          height: 200,
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: Image.network(
                  urls[0],
                  fit: BoxFit.cover,
                  height: 200,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: Colors.grey[300],
                    child: const Icon(Icons.image_not_supported),
                  ),
                ),
              ),
              const SizedBox(width: 2),
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
                    const SizedBox(height: 2),
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
        ),
      );
    }
  }

  Widget _buildProviderPost(Map<String, dynamic> post) {
    final isProvider = post['type'] == 'provider';
    final images = post['images'] as List<String>;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFFBB04C).withOpacity(0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // User/Provider header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundImage: NetworkImage(post['avatar']!),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            post['name']!,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          if (isProvider) ...[
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.verified,
                              color: Color(0xFFFBB04C),
                              size: 16,
                            ),
                          ],
                        ],
                      ),
                      if (post['service']!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          post['service']!,
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Image
          if (images.isNotEmpty)
            Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: NetworkImage(images.first),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          
          // Review and Service info
          if (post['review']!.isNotEmpty || post['service']!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (post['review']!.isNotEmpty)
                    Text(
                      post['review']!,
                      style: const TextStyle(fontSize: 14),
                    ),
                  if (post['service']!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Text(
                          'Service by',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
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
                                Icons.eco,
                                size: 12,
                                color: Colors.green[700],
                              ),
                              const SizedBox(width: 4),
                              Text(
                                post['service']!,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.green[700],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMyTasks() {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          title: const Text(
            'My Tasks',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          backgroundColor: Colors.white,
          elevation: 0,
          automaticallyImplyLeading: false,
          bottom: const TabBar(
            labelColor: Color(0xFFFBB04C),
            unselectedLabelColor: Colors.grey,
            indicatorColor: Color(0xFFFBB04C),
            indicatorWeight: 3,
            labelStyle: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
            unselectedLabelStyle: TextStyle(
              fontWeight: FontWeight.normal,
              fontSize: 16,
            ),
            tabs: [
              Tab(text: 'Assigned'),
              Tab(text: 'Upcoming'),
              Tab(text: 'Completed'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildAssignedTasksTab(),
            _buildUpcomingTasksTab(),
            _buildCompletedTasksTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildAssignedTasksTab() {
    return StreamBuilder<List<UserRequest>>(
      stream: HspHomeService.getAssignedTasks(widget.user.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              color: Color(0xFFFBB04C),
            ),
          );
        }

        if (snapshot.hasError) {
          print('❌ Error loading assigned tasks: ${snapshot.error}');
          return Center(
        child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
                     children: [
                Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  'Error loading assigned tasks',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          );
        }

        final assignedTasks = snapshot.data ?? [];

        if (assignedTasks.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.assignment_turned_in_outlined,
                  size: 64,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  'No Assigned Tasks',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tasks will appear here when customers accept your quotes',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            // Trigger rebuild
            setState(() {});
            await Future.delayed(const Duration(milliseconds: 500));
          },
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: assignedTasks.length,
            itemBuilder: (context, index) {
              return _buildAssignedTaskCard(assignedTasks[index]);
            },
          ),
        );
      },
    );
  }

  Widget _buildUpcomingTasksTab() {
    return StreamBuilder<List<ServiceOrder>>(
      stream: HspHomeService.getUpcomingTasks(widget.user.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
                 color: Color(0xFFFBB04C),
               ),
          );
        }

        final upcomingTasks = snapshot.data ?? [];

        if (upcomingTasks.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
                   children: [
                Icon(
                  Icons.schedule_outlined,
                  size: 64,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  'No Upcoming Tasks',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Scheduled tasks will appear here',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            setState(() {});
            await Future.delayed(const Duration(milliseconds: 500));
          },
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: upcomingTasks.length,
            itemBuilder: (context, index) {
              return _buildUpcomingTaskCard(upcomingTasks[index]);
            },
          ),
        );
      },
    );
  }

  Widget _buildCompletedTasksTab() {
    return StreamBuilder<List<ServiceOrder>>(
      stream: HspHomeService.getCompletedTasks(widget.user.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              color: Color(0xFFFBB04C),
            ),
          );
        }

        final completedTasks = snapshot.data ?? [];

        if (completedTasks.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.check_circle_outline,
                  size: 64,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  'No Completed Tasks',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Completed tasks will appear here',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            setState(() {});
            await Future.delayed(const Duration(milliseconds: 500));
          },
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: completedTasks.length,
            itemBuilder: (context, index) {
              return _buildCompletedTaskCard(completedTasks[index]);
            },
          ),
        );
      },
    );
  }

  Widget _buildUpcomingTaskCard(ServiceOrder task) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.schedule,
                  color: Colors.blue[700],
                  size: 20,
                ),
                     const SizedBox(width: 8),
                     Text(
                  'UPCOMING',
                  style: TextStyle(
                    color: Colors.blue[700],
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  '\$${task.finalPrice.toStringAsFixed(0)}',
                       style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              task.serviceDescription ?? 'Service Task',
              style: const TextStyle(
                         fontSize: 16,
                fontWeight: FontWeight.w600,
                       ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
                     ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                     const SizedBox(width: 4),
                Text(
                  _formatDateTime(task.scheduledTime),
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    task.confirmedAddress,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompletedTaskCard(ServiceOrder task) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.check_circle,
                  color: Colors.green[700],
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'COMPLETED',
                  style: TextStyle(
                    color: Colors.green[700],
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  '\$${task.finalPrice.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              task.serviceDescription ?? 'Service Task',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  _formatDateTime(task.scheduledTime),
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    task.confirmedAddress,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
        ],
        ),
      ),
    );
  }

  Widget _buildProfile() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('providers').doc(widget.user.uid).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Center(child: Text('Profile data not found'));
        }
        final data = snapshot.data!.data() as Map<String, dynamic>;
        
        return SafeArea(
          child: SingleChildScrollView(
            child: Column(
              children: [
                // Storefront Header
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
                      // Profile Photo
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
                      // Rating and Stats
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildStatItem('${_providerStats?.averageRating.toStringAsFixed(1) ?? '4.8'}', 'Rating', Icons.star, Colors.orange),
                          _buildStatItem('${_providerStats?.totalTasks ?? 45}', 'Jobs Done', Icons.work, Colors.blue),
                          _buildStatItem('${_providerStats?.tasksThisMonth ?? 8}', 'This Month', Icons.trending_up, Colors.green),
                        ],
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // Recommended Users Section
                _buildRecommendedUsers(),
                
                const SizedBox(height: 20),
                
                // Company Description Section
                _buildCompanyDescription(data),
                
                const SizedBox(height: 20),
                
                // Past Projects Section
                _buildPastProjects(),
                
                const SizedBox(height: 20),
                
                // Reviews Section
                _buildReviews(),
                
                const SizedBox(height: 20),
                
                // Sign Out Button
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  child: ElevatedButton(
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
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      minimumSize: const Size(double.infinity, 50),
                    ),
                    child: const Text(
                      'Sign Out',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                
                const SizedBox(height: 40),
              ],
            ),
          ),
        );
      },
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
        Text(
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

  Widget _buildRecommendedUsers() {
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
          const Text(
            'Recommended by',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('providers').doc(widget.user.uid).snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              
              final data = snapshot.data!.data() as Map<String, dynamic>?;
              final referredByUserIds = List<String>.from(data?['referred_by_user_ids'] ?? []);
              
              if (referredByUserIds.isEmpty) {
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
                  itemCount: referredByUserIds.length,
                  itemBuilder: (context, index) {
                    final userId = referredByUserIds[index];
                    return FutureBuilder<DocumentSnapshot>(
                      future: FirebaseFirestore.instance.collection('users').doc(userId).get(),
                      builder: (context, userSnapshot) {
                        if (!userSnapshot.hasData) {
                          return Container(
                            width: 60,
                            margin: const EdgeInsets.only(right: 12),
                            child: const CircularProgressIndicator(),
                          );
                        }
                        
                        final userData = userSnapshot.data!.data() as Map<String, dynamic>?;
                        return Container(
                          width: 60,
                          margin: const EdgeInsets.only(right: 12),
                          child: Column(
                            children: [
                              CircleAvatar(
                                radius: 24,
                                backgroundImage: userData?['profileImageUrl'] != null
                                    ? NetworkImage(userData!['profileImageUrl'])
                                    : null,
                                backgroundColor: Colors.grey[300],
                                child: userData?['profileImageUrl'] == null
                                    ? const Icon(Icons.person, color: Colors.grey)
                                    : null,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                userData?['name'] ?? 'User',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        );
                      },
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

  Widget _buildCompanyDescription(Map<String, dynamic> data) {
    final TextEditingController descriptionController = TextEditingController();
    descriptionController.text = data['companyDescription'] ?? '';
    bool isEditing = false;
    
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
      child: StatefulBuilder(
        builder: (context, setState) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    'About Our Service',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(
                      isEditing ? Icons.save : Icons.edit,
                      color: const Color(0xFFFBB04C),
                    ),
                    onPressed: () async {
                      if (isEditing) {
                        // Save the description
                        try {
                          await FirebaseFirestore.instance
                              .collection('providers')
                              .doc(widget.user.uid)
                              .update({
                            'companyDescription': descriptionController.text,
                          });
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Description updated successfully'),
                                backgroundColor: Color(0xFFFBB04C),
                              ),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Error updating description'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                        setState(() {
                          isEditing = false;
                        });
                      } else {
                        setState(() {
                          isEditing = true;
                        });
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (isEditing)
                TextField(
                  controller: descriptionController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    hintText: 'Describe your services, specialties, and what makes your business unique...',
                    border: OutlineInputBorder(),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFFFBB04C), width: 2),
                    ),
                  ),
                )
              else
                Text(
                  data['companyDescription'] ?? 'No description available. Tap the edit button to add information about your services.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                    height: 1.5,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPastProjects() {
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
          const Text(
            'Past Projects',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('service_orders')
                .where('provider_id', isEqualTo: widget.user.uid)
                .where('status', isEqualTo: 'completed')
                .orderBy('created_at', descending: true)
                .limit(6)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.work_outline,
                        size: 48,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'No completed projects yet',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                );
              }
              
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.2,
                ),
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  final doc = snapshot.data!.docs[index];
                  final order = doc.data() as Map<String, dynamic>;
                  
                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                              color: Colors.grey[200],
                            ),
                            child: Center(
                              child: Icon(
                                Icons.photo_library,
                                size: 40,
                                color: Colors.grey[400],
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                order['service_description'] ?? 'Service',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '\$${order['final_price']?.toStringAsFixed(0) ?? '0'}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
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
          const Text(
            'Customer Reviews',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('service_orders')
                .where('provider_id', isEqualTo: widget.user.uid)
                .where('status', isEqualTo: 'completed')
                .orderBy('created_at', descending: true)
                .limit(3)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.rate_review_outlined,
                        size: 48,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'No reviews yet',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                );
              }
              
              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  final doc = snapshot.data!.docs[index];
                  final order = doc.data() as Map<String, dynamic>;
                  
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: Colors.grey[300],
                              child: const Icon(Icons.person, size: 20, color: Colors.grey),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    order['customer_name'] ?? 'Customer',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Row(
                                    children: List.generate(5, (i) => Icon(
                                      Icons.star,
                                      size: 14,
                                      color: i < (order['rating'] ?? 5) ? Colors.orange : Colors.grey[300],
                                    )),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          order['review'] ?? 'Great service! Professional and efficient work. Highly recommend!',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[700],
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  void _showNotificationHistory(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
        children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.notifications, color: Color(0xFFFBB04C)),
                  const SizedBox(width: 8),
                  const Text(
                    'Notifications',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  
                  // Function Test Button
                              IconButton(
              icon: const Icon(Icons.code, color: Colors.purple),
              tooltip: 'Test Functions',
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const FunctionTestScreen(),
                  ),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.bug_report, color: Colors.red),
              tooltip: 'Debug FCM Tokens',
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const TokenDebugScreen(),
                  ),
                );
              },
            ),

                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(),
            // Notification list
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: NotificationService.getNotificationHistory(widget.user.uid),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  
                  if (snapshot.hasError) {
                    return Center(
                      child: Text('Error: ${snapshot.error}'),
                    );
                  }
                  
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.notifications_none,
                            size: 64,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'No notifications yet',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'You\'ll see status updates here',
                            style: TextStyle(
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  
                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: snapshot.data!.docs.length,
                    itemBuilder: (context, index) {
                      final notification = snapshot.data!.docs[index].data() as Map<String, dynamic>;
                      final timestamp = notification['timestamp'] as Timestamp?;
                      final type = notification['type'] as String?;
                      final status = notification['status'] as String?;
                      
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: _getNotificationColor(status),
                            child: Icon(
                              _getNotificationIcon(type),
                              color: Colors.white,
                            ),
                          ),
                          title: Text(
                            _getNotificationTitle(type, status),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _getNotificationMessage(type, status),
                                style: const TextStyle(fontSize: 14),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                timestamp != null 
                                    ? _formatTimestamp(timestamp)
                                    : 'Just now',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                          isThreeLine: true,
                        ),
                      );
                    },
                  );
                },
              ),
            ),
        ],
        ),
      ),
    );
  }

  Color _getNotificationColor(String? status) {
    switch (status) {
      case 'verified':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.blue;
    }
  }

  IconData _getNotificationIcon(String? type) {
    switch (type) {
      case 'verification_success':
        return Icons.check_circle;
      case 'application_rejection':
        return Icons.error;
      default:
        return Icons.notifications;
    }
  }

  String _getNotificationTitle(String? type, String? status) {
    switch (type) {
      case 'verification_success':
        return 'Account Verified! 🎉';
      case 'application_rejection':
        return 'Application Update';
      default:
        return 'Status Update';
    }
  }

  String _getNotificationMessage(String? type, String? status) {
    switch (type) {
      case 'verification_success':
        return 'Your Magic Home provider account has been successfully verified. You can now start accepting service requests.';
      case 'application_rejection':
        return 'Please check your email for details about your application status.';
      default:
        return 'Your application status has been updated.';
    }
  }

  String _formatTimestamp(Timestamp timestamp) {
    final now = DateTime.now();
    final notificationTime = timestamp.toDate();
    final difference = now.difference(notificationTime);
    
    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
    } else {
      return 'Just now';
    }
  }

  Widget _sectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Row(
        children: [
          Icon(icon, color: Colors.black87, size: 22),
            const SizedBox(width: 8),
          Flexible(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
                letterSpacing: 0.2,
                overflow: TextOverflow.ellipsis,
              ),
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Magic Home Provider'),
        backgroundColor: const Color(0xFFFBB04C),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          // Notification icon
            StreamBuilder<QuerySnapshot>(
            stream: NotificationService.getNotificationHistory(widget.user.uid),
            builder: (context, snapshot) {
              int unreadCount = 0;
              if (snapshot.hasData) {
                unreadCount = snapshot.data!.docs.length;
              }
              
              return Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications),
                    onPressed: () {
                      _showNotificationHistory(context);
                    },
                  ),
                  if (unreadCount > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          '$unreadCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _loadProviderStats();
              setState(() {});
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
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.explore),
            label: 'Discover',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.assignment),
            label: 'My Tasks',
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
