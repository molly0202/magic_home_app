import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../auth/welcome_screen.dart';
import '../auth/hsp_verification_screen.dart';
import '../../services/notification_service.dart';
import '../../services/hsp_home_service.dart';
import '../../models/provider_stats.dart';
import '../../models/service_order.dart';
import '../../models/service_request.dart';
import 'package:video_player/video_player.dart';
import 'package:url_launcher/url_launcher.dart';

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

  @override
  void initState() {
    super.initState();
    // Start listening for status changes for in-app notifications
    NotificationService.listenForStatusChanges(widget.user.uid, context);
    // Initialize push notifications and save FCM token
    NotificationService.initializePushNotifications(widget.user.uid);
    // Load provider stats
    _loadProviderStats();
  }

  Future<void> _loadProviderStats() async {
    final stats = await HspHomeService.getProviderStats(widget.user.uid);
    setState(() {
      _providerStats = stats;
    });
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

    // Minimize panel if status is verified and user has seen it
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
                      setState(() {
                        _statusPanelMinimized = true;
                      });
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
      _buildServices(),
      _buildBookings(),
      _buildProfile(),
    ];
  }

  Widget _buildDashboard(Map<String, dynamic>? providerData) {
    final isVerified = providerData?['status'] == 'verified' || providerData?['status'] == 'active';
    
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildStatusCard(providerData),
          if (isVerified) ...[
            _buildStatsDashboard(),
            _buildUpcomingTasks(),
            _buildPendingRequests(),
          ],
        ],
      ),
    );
  }

  Widget _buildStatsDashboard() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeader('My Stats', Icons.analytics),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Total Tasks',
                    '${_providerStats?.totalTasks ?? 0}',
                    Colors.blue,
                    Icons.work,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    'This Month',
                    '${_providerStats?.tasksThisMonth ?? 0}',
                    Colors.green,
                    Icons.calendar_today,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Total Earnings',
                    '\$${(_providerStats?.totalEarned ?? 0.0).toStringAsFixed(0)}',
                    Colors.orange,
                    Icons.attach_money,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    'Collected',
                    '0',
                    Colors.purple,
                    Icons.bookmark,
                  ),
                ),
              ],
            ),
          ],
        ),
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
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeader('Upcoming Tasks', Icons.schedule),
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
          if (task.status == 'confirmed') ...[
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
          ] else if (task.status == 'in_progress') ...[
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
          ],
        ],
      ),
    );
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

  Widget _buildPendingRequests() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeader('Pending Requests', Icons.pending_actions),
            const SizedBox(height: 16),
            StreamBuilder<List<ServiceRequest>>(
              stream: HspHomeService.getPendingRequests(widget.user.uid),
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
                
                final requests = snapshot.data ?? [];
                
                if (requests.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Icon(
                          Icons.pending_outlined,
                          size: 48,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'No pending requests',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'New service requests will appear here',
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
                  children: requests.take(3).map((request) => _buildRequestItem(request)).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestItem(ServiceRequest request) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PendingRequestDetailScreen(request: request),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.orange[50],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.orange[200]!),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
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
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Pending',
                    style: TextStyle(
                      color: Colors.orange,
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
                Expanded(
                  child: Text(
                    'Preferred: ${request.preferredTime}',
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
                  request.priceRange,
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
                    request.locationMasked,
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
                  onPressed: () => _showAcceptRequestDialog(request),
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

  void _showAcceptRequestDialog(ServiceRequest request) {
    final priceController = TextEditingController();
    final dateController = TextEditingController();
    final addressController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          bool isLoadingAddress = true;
          String? customerAddress;
          
          // Fetch customer's address from their user profile
          void fetchCustomerAddress() async {
            try {
              final userDoc = await FirebaseFirestore.instance
                  .collection('users')
                  .doc(request.userId)
                  .get();
              
              if (userDoc.exists) {
                final userData = userDoc.data()!;
                customerAddress = userData['address'] as String?;
                if (customerAddress != null && customerAddress!.isNotEmpty) {
                  addressController.text = customerAddress!;
                } else {
                  customerAddress = 'No address provided by customer';
                  addressController.text = customerAddress!;
                }
              } else {
                customerAddress = 'Customer profile not found';
                addressController.text = customerAddress!;
              }
            } catch (e) {
              customerAddress = 'Error loading customer address';
              addressController.text = customerAddress!;
              print('Error fetching customer address: $e');
            } finally {
              setState(() {
                isLoadingAddress = false;
              });
            }
          }
          
          // Start fetching address if not already done
          if (isLoadingAddress && addressController.text.isEmpty) {
            fetchCustomerAddress();
          }
          
          return AlertDialog(
            title: const Text('Accept Service Request'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Service: ${request.description}'),
                  const SizedBox(height: 16),
                  TextField(
                    controller: priceController,
                    decoration: const InputDecoration(
                      labelText: 'Final Price (\$)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: dateController,
                    decoration: const InputDecoration(
                      labelText: 'Scheduled Date & Time',
                      border: OutlineInputBorder(),
                    ),
                    readOnly: true,
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now().add(const Duration(days: 1)),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (date != null) {
                        final time = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.now(),
                        );
                        if (time != null) {
                          final scheduledDateTime = DateTime(
                            date.year,
                            date.month,
                            date.day,
                            time.hour,
                            time.minute,
                          );
                          dateController.text = scheduledDateTime.toIso8601String();
                        }
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: addressController,
                    decoration: InputDecoration(
                      labelText: 'Customer\'s Home Address',
                      border: const OutlineInputBorder(),
                      helperText: 'This address is from the customer\'s profile',
                      suffixIcon: isLoadingAddress 
                          ? const SizedBox(
                              width: 20, 
                              height: 20, 
                              child: CircularProgressIndicator(strokeWidth: 2)
                            )
                          : const Icon(Icons.location_on),
                    ),
                    maxLines: 2,
                    readOnly: true, // Make it read-only since it comes from customer profile
                  ),
                  if (isLoadingAddress)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text(
                        'Loading customer address...',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
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
                onPressed: () async {
                  if (priceController.text.isEmpty ||
                      dateController.text.isEmpty ||
                      addressController.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please fill in all fields')),
                    );
                    return;
                  }
                  
                  if (isLoadingAddress) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please wait for address to load')),
                    );
                    return;
                  }
                  
                  try {
                    final price = double.parse(priceController.text);
                    final scheduledDateTime = DateTime.parse(dateController.text);
                    
                    await HspHomeService.acceptServiceRequest(
                      request.requestId,
                      widget.user.uid,
                      price,
                      scheduledDateTime,
                      addressController.text,
                    );
                    
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Request accepted successfully!')),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e')),
                    );
                  }
                },
                child: const Text('Accept'),
              ),
            ],
          );
        },
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

class PendingRequestDetailScreen extends StatefulWidget {
  final ServiceRequest request;
  const PendingRequestDetailScreen({super.key, required this.request});

  @override
  State<PendingRequestDetailScreen> createState() => _PendingRequestDetailScreenState();
}

class _PendingRequestDetailScreenState extends State<PendingRequestDetailScreen> {
  final List<VideoPlayerController?> _videoControllers = [];

  @override
  void initState() {
    super.initState();
    for (final url in widget.request.mediaUrls) {
      print('Media URL: $url'); // Debug print
      if (_isVideo(url)) {
        print('Initializing video controller for: $url');
        final controller = VideoPlayerController.networkUrl(Uri.parse(url));
        controller.initialize().then((_) {
          print('Video initialized successfully: $url');
          print('Video duration: ${controller.value.duration}');
          print('Video size: ${controller.value.size}');
          // Seek to first frame to ensure thumbnail is visible
          controller.seekTo(Duration.zero);
          setState(() {});
        }).catchError((e) {
          print('Video failed to initialize: $e');
          print('Video URL: $url');
          print('Error type: ${e.runtimeType}');
          setState(() {});
        });
        _videoControllers.add(controller);
      } else {
        _videoControllers.add(null);
      }
    }
  }

  @override
  void dispose() {
    for (final controller in _videoControllers) {
      controller?.dispose();
    }
    super.dispose();
  }

  bool _isVideo(String url) {
    final lower = url.toLowerCase();
    print('Checking if video: $url');
    
    // Remove query parameters to check the actual file extension
    final urlWithoutQuery = lower.split('?')[0];
    print('URL without query: $urlWithoutQuery');
    
    final isMovFile = urlWithoutQuery.endsWith('.mov');
    final isMp4File = urlWithoutQuery.endsWith('.mp4');
    final isM4vFile = urlWithoutQuery.endsWith('.m4v');
    
    print('Is MOV: $isMovFile');
    print('Is MP4: $isMp4File');
    print('Is M4V: $isM4vFile');
    
    return isMovFile || isMp4File || isM4vFile;
  }

  void _openImageFullScreen(BuildContext context, String imageUrl) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          body: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Center(
              child: InteractiveViewer(
                child: Image.network(imageUrl),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _openVideoFullScreen(BuildContext context, VideoPlayerController controller) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          body: SafeArea(
            child: Center(
              child: AspectRatio(
                aspectRatio: controller.value.aspectRatio,
                child: VideoPlayer(controller),
              ),
            ),
          ),
          floatingActionButton: FloatingActionButton(
            backgroundColor: Colors.white,
            onPressed: () {
              controller.value.isPlaying ? controller.pause() : controller.play();
            },
            child: Icon(
              controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
              color: Colors.black,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final request = widget.request;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Request Details'),
        backgroundColor: const Color(0xFFFBB04C),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              request.description,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.location_on, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    request.locationMasked,
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Preferred: ${request.preferredTime}',
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
                  request.priceRange,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (request.mediaUrls.isNotEmpty) ...[
              const Text('Media Documents:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 8),
              SizedBox(
                height: 140,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: request.mediaUrls.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final url = request.mediaUrls[index];
                    final videoController = _videoControllers[index];
                    if (_isVideo(url)) {
                      return GestureDetector(
                        onTap: () {
                          final controller = _videoControllers[index];
                          if (controller != null && controller.value.isInitialized) {
                            _openVideoFullScreen(context, controller);
                          }
                        },
                        child: Stack(
                          children: [
                            Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                color: Colors.black,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: videoController != null && videoController.value.isInitialized
                                    ? FittedBox(
                                        fit: BoxFit.cover,
                                        child: SizedBox(
                                          width: videoController.value.size.width,
                                          height: videoController.value.size.height,
                                          child: VideoPlayer(videoController),
                                        ),
                                      )
                                    : Container(
                                        color: Colors.grey[900],
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.videocam, color: Colors.white, size: 24),
                                            const SizedBox(height: 4),
                                            Text(
                                              'VIDEO',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            Text(
                                              _getFileExtension(url),
                                              style: TextStyle(
                                                color: _getFileExtension(url) == '.mov' ? Colors.yellow : Colors.white70,
                                                fontSize: 8,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                              ),
                            ),
                            // Number badge
                            Positioned(
                              top: 8,
                              left: 8,
                              child: Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: Colors.orange,
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    '${index + 1}',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            // Play button overlay
                            if (videoController != null && videoController.value.isInitialized)
                              Positioned(
                                bottom: 8,
                                right: 8,
                                child: Container(
                                  padding: EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.black54,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    Icons.play_arrow,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    } else {
                      return GestureDetector(
                        onTap: () => _openImageFullScreen(context, url),
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                url,
                                width: 120,
                                height: 120,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => Container(
                                  width: 120,
                                  height: 120,
                                  decoration: BoxDecoration(
                                    color: Colors.red[50],
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.red[300]!),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.error_outline, color: Colors.red, size: 32),
                                      const SizedBox(height: 4),
                                      Text(
                                        'IMAGE\nFAILED',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: Colors.red,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        '404',
                                        style: TextStyle(
                                          color: Colors.red[700],
                                          fontSize: 8,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                loadingBuilder: (context, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return Container(
                                    width: 120,
                                    height: 120,
                                    decoration: BoxDecoration(
                                      color: Colors.grey[200],
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Center(
                                      child: CircularProgressIndicator(
                                        value: loadingProgress.expectedTotalBytes != null
                                            ? loadingProgress.cumulativeBytesLoaded /
                                                loadingProgress.expectedTotalBytes!
                                            : null,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            // Thumbnail number
                            Positioned(
                              top: 4,
                              left: 4,
                              child: Container(
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: Colors.orange,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Center(
                                  child: Text(
                                    '${index + 1}',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                  },
                ),
              ),
              const SizedBox(height: 16),
              
              // Media URLs List
              const Text('Media URLs:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: request.mediaUrls.asMap().entries.map((entry) {
                    final index = entry.key;
                    final url = entry.value;
                    final isVideo = _isVideo(url);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: Colors.orange,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Center(
                                  child: Text(
                                    '${index + 1}',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                isVideo ? Icons.videocam : Icons.image,
                                size: 16,
                                color: isVideo ? Colors.red : Colors.blue,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${isVideo ? 'Video' : 'Image'}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          GestureDetector(
                            onTap: () async {
                              final uri = Uri.parse(url);
                              if (await canLaunchUrl(uri)) {
                                await launchUrl(uri, mode: LaunchMode.externalApplication);
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Could not open URL')),
                                );
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.blue[50],
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.blue[200]!),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.link, size: 16, color: Colors.blue),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      url,
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: Colors.blue,
                                        fontFamily: 'monospace',
                                        decoration: TextDecoration.underline,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 2,
                                    ),
                                  ),
                                  Icon(Icons.open_in_new, size: 16, color: Colors.blue),
                                ],
                              ),
                            ),
                          ),
                          if (index < request.mediaUrls.length - 1) 
                            const Divider(height: 16),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 16),
            ],
            Text('Request ID: ${request.requestId}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                // TODO: Implement quote/accept logic
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Quote/Accept feature coming soon!')),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
              child: const Text('Provide Quote / Accept'),
            ),
          ],
        ),
      ),
    );
  }

  String _getFileExtension(String url) {
    final parts = url.split('.');
    if (parts.isNotEmpty) {
      return '.' + parts.last;
    }
    return '';
  }
} 