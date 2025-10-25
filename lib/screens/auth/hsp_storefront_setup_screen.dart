import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../home/hsp_home_screen.dart';
import '../../services/admin_notification_service.dart';

class HspStorefrontSetupScreen extends StatefulWidget {
  final firebase_auth.User user;
  final String? email;
  final String? phoneNumber;

  const HspStorefrontSetupScreen({
    super.key,
    required this.user,
    this.email,
    this.phoneNumber,
  });

  @override
  State<HspStorefrontSetupScreen> createState() => _HspStorefrontSetupScreenState();
}

class _HspStorefrontSetupScreenState extends State<HspStorefrontSetupScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _isLoading = false;
  String? _errorMessage;

  // Work showcase photos
  List<File> _workShowcasePhotos = [];
  
  // Employee profiles
  List<EmployeeProfile> _employeeProfiles = [];
  
  // Services and intake questions
  List<ServiceCategory> _selectedServices = [];
  
  final ImagePicker _picker = ImagePicker();

  // Predefined service categories
  final List<ServiceCategory> _availableServices = [
    ServiceCategory(
      id: 'plumbing',
      name: 'Plumbing',
      icon: Icons.plumbing,
      defaultQuestions: [
        'What type of plumbing issue are you experiencing?',
        'Is this an emergency repair?',
        'When did you first notice the problem?',
        'Have you attempted any repairs yourself?',
      ],
    ),
    ServiceCategory(
      id: 'electrical',
      name: 'Electrical',
      icon: Icons.electrical_services,
      defaultQuestions: [
        'What electrical work do you need?',
        'Is this for new installation or repair?',
        'Do you have permits if required?',
        'When would you like the work completed?',
      ],
    ),
    ServiceCategory(
      id: 'hvac',
      name: 'HVAC',
      icon: Icons.air,
      defaultQuestions: [
        'What HVAC service do you need?',
        'What is the age of your current system?',
        'Are you experiencing any specific issues?',
        'What is the square footage of the area?',
      ],
    ),
    ServiceCategory(
      id: 'cleaning',
      name: 'Cleaning',
      icon: Icons.cleaning_services,
      defaultQuestions: [
        'What type of cleaning service do you need?',
        'How large is the space to be cleaned?',
        'How often would you like cleaning service?',
        'Are there any special requirements or preferences?',
      ],
    ),
    ServiceCategory(
      id: 'landscaping',
      name: 'Landscaping',
      icon: Icons.grass,
      defaultQuestions: [
        'What landscaping services do you need?',
        'What is the size of your yard/property?',
        'Do you have a preferred timeline?',
        'Are there any specific plants or features you want?',
      ],
    ),
    ServiceCategory(
      id: 'handyman',
      name: 'Handyman',
      icon: Icons.handyman,
      defaultQuestions: [
        'What repairs or tasks do you need completed?',
        'How urgent is this work?',
        'Do you have materials or should we provide them?',
        'Are there any access restrictions we should know about?',
      ],
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _pickWorkShowcasePhoto() async {
    if (_workShowcasePhotos.length >= 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximum 10 showcase photos allowed')),
      );
      return;
    }

    final ImageSource? source = await _showImageSourceDialog();
    if (source == null) return;

    final XFile? pickedFile = await _picker.pickImage(
      source: source,
      imageQuality: 80,
      maxWidth: 1920,
      maxHeight: 1920,
    );

    if (pickedFile != null) {
      setState(() {
        _workShowcasePhotos.add(File(pickedFile.path));
      });
    }
  }

  Future<void> _addEmployeeProfile() async {
    final result = await showDialog<EmployeeProfile>(
      context: context,
      builder: (context) => const AddEmployeeDialog(),
    );

    if (result != null) {
      setState(() {
        _employeeProfiles.add(result);
      });
    }
  }

  Future<ImageSource?> _showImageSourceDialog() async {
    return showDialog<ImageSource>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select Image Source'),
          content: const Text('Choose how you want to add your photo:'),
          actions: [
            TextButton.icon(
              onPressed: () => Navigator.pop(context, ImageSource.camera),
              icon: const Icon(Icons.camera_alt),
              label: const Text('Take Photo'),
            ),
            TextButton.icon(
              onPressed: () => Navigator.pop(context, ImageSource.gallery),
              icon: const Icon(Icons.photo_library),
              label: const Text('Choose from Gallery'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  Future<List<String>> _uploadPhotos(List<File> photos, String folder) async {
    List<String> urls = [];
    
    for (int i = 0; i < photos.length; i++) {
      try {
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('providers')
            .child(widget.user.uid)
            .child(folder)
            .child('${DateTime.now().millisecondsSinceEpoch}_$i.jpg');
        
        final uploadTask = storageRef.putFile(photos[i]);
        final snapshot = await uploadTask;
        final downloadUrl = await snapshot.ref.getDownloadURL();
        urls.add(downloadUrl);
      } catch (e) {
        print('Error uploading photo $i: $e');
      }
    }
    
    return urls;
  }

  Future<void> _saveStorefront() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Upload work showcase photos
      List<String> showcaseUrls = [];
      if (_workShowcasePhotos.isNotEmpty) {
        showcaseUrls = await _uploadPhotos(_workShowcasePhotos, 'showcase');
      }

      // Upload employee photos and prepare employee data
      List<Map<String, dynamic>> employeesData = [];
      for (var employee in _employeeProfiles) {
        String? photoUrl;
        if (employee.photo != null) {
          final urls = await _uploadPhotos([employee.photo!], 'employees');
          if (urls.isNotEmpty) photoUrl = urls.first;
        }
        
        employeesData.add({
          'name': employee.name,
          'role': employee.role,
          'bio': employee.bio,
          'photoUrl': photoUrl,
        });
      }

      // Prepare services data
      List<Map<String, dynamic>> servicesData = _selectedServices.map((service) => {
        'id': service.id,
        'name': service.name,
        'intakeQuestions': service.intakeQuestions,
        'isActive': true,
      }).toList();

      // Update provider document in Firestore
      await FirebaseFirestore.instance
          .collection('providers')
          .doc(widget.user.uid)
          .update({
        'storefrontCompleted': true,
        'workShowcasePhotos': showcaseUrls,
        'employees': employeesData,
        'services': servicesData,
        'storefrontSetupTimestamp': FieldValue.serverTimestamp(),
      });

      // Notify admins about completed storefront
      await AdminNotificationService.notifyProviderStorefrontCompleted(
        providerId: widget.user.uid,
        providerName: employeesData.isNotEmpty ? employeesData.first['name'] : 'Provider',
        phoneNumber: widget.phoneNumber,
        showcasePhotosCount: showcaseUrls.length,
        employeesCount: employeesData.length,
        services: _selectedServices.map((s) => s.name).toList(),
      );

      if (!mounted) return;

      // Navigate to HSP home screen
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => HspHomeScreen(user: widget.user)),
        (route) => false,
      );

    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to save storefront: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _nextPage() {
    if (_currentPage < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Build Your Storefront'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          // Progress indicator
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                for (int i = 0; i < 3; i++)
                  Expanded(
                    child: Container(
                      height: 4,
                      margin: EdgeInsets.only(right: i < 2 ? 8 : 0),
                      decoration: BoxDecoration(
                        color: i <= _currentPage ? const Color(0xFFFBB04C) : Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          
          // Page content
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: (page) {
                setState(() {
                  _currentPage = page;
                });
              },
              children: [
                _buildWorkShowcasePage(),
                _buildEmployeeProfilesPage(),
                _buildServicesPage(),
              ],
            ),
          ),
          
          // Navigation buttons
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                if (_currentPage > 0)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _previousPage,
                      child: const Text('Back'),
                    ),
                  ),
                if (_currentPage > 0) const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : (_currentPage < 2 ? _nextPage : _saveStorefront),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFBB04C),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            _currentPage < 2 ? 'Next' : 'Complete Setup',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
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
    );
  }

  Widget _buildWorkShowcasePage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Showcase Your Work',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Add photos of your previous work to build trust with potential customers.',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 24),
          
          // Add photo button
          GestureDetector(
            onTap: _pickWorkShowcasePhoto,
            child: Container(
              height: 120,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_photo_alternate, size: 48, color: Colors.grey),
                  SizedBox(height: 8),
                  Text('Add Work Photos', style: TextStyle(color: Colors.grey)),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Photo grid
          if (_workShowcasePhotos.isNotEmpty)
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: _workShowcasePhotos.length,
              itemBuilder: (context, index) {
                return Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        image: DecorationImage(
                          image: FileImage(_workShowcasePhotos[index]),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _workShowcasePhotos.removeAt(index);
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          
          const SizedBox(height: 16),
          Text(
            '${_workShowcasePhotos.length}/10 photos added',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmployeeProfilesPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Team Members',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Introduce your team members to build trust and show your expertise.',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 24),
          
          // Add employee button
          OutlinedButton.icon(
            onPressed: _addEmployeeProfile,
            icon: const Icon(Icons.person_add),
            label: const Text('Add Team Member'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Employee list
          if (_employeeProfiles.isNotEmpty)
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _employeeProfiles.length,
              itemBuilder: (context, index) {
                final employee = _employeeProfiles[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundImage: employee.photo != null
                          ? FileImage(employee.photo!)
                          : null,
                      child: employee.photo == null
                          ? const Icon(Icons.person)
                          : null,
                    ),
                    title: Text(employee.name),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(employee.role),
                        if (employee.bio.isNotEmpty)
                          Text(
                            employee.bio,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                      ],
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () {
                        setState(() {
                          _employeeProfiles.removeAt(index);
                        });
                      },
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildServicesPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Your Services',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Select the services you provide and customize the questions you need to ask customers.',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 24),
          
          if (_errorMessage != null)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red),
              ),
              child: Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.red),
              ),
            ),
          
          // Service categories
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _availableServices.length,
            itemBuilder: (context, index) {
              final service = _availableServices[index];
              final isSelected = _selectedServices.any((s) => s.id == service.id);
              
              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                child: Column(
                  children: [
                    // Service header with checkbox
                    ListTile(
                      leading: Icon(service.icon, color: const Color(0xFFFBB04C)),
                      title: Text(
                        service.name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      trailing: Checkbox(
                        value: isSelected,
                        onChanged: (value) {
                          setState(() {
                            if (value == true) {
                              _selectedServices.add(ServiceCategory(
                                id: service.id,
                                name: service.name,
                                icon: service.icon,
                                intakeQuestions: List.from(service.defaultQuestions),
                              ));
                            } else {
                              _selectedServices.removeWhere((s) => s.id == service.id);
                            }
                          });
                        },
                      ),
                    ),
                    
                    // Questions section - always visible when selected
                    if (isSelected)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          border: Border(
                            top: BorderSide(color: Colors.grey[300]!),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.quiz, color: Colors.grey[600], size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  'Questions You\'ll Ask Customers:',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey[700],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            ...(_selectedServices
                                .firstWhere((s) => s.id == service.id)
                                .intakeQuestions
                                .asMap()
                                .entries
                                .map((entry) {
                              final questionIndex = entry.key;
                              final question = entry.value;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        initialValue: question,
                                        decoration: InputDecoration(
                                          labelText: 'Question ${questionIndex + 1}',
                                          border: const OutlineInputBorder(),
                                        ),
                                        onChanged: (value) {
                                          final serviceIndex = _selectedServices
                                              .indexWhere((s) => s.id == service.id);
                                          if (serviceIndex != -1) {
                                            _selectedServices[serviceIndex]
                                                .intakeQuestions[questionIndex] = value;
                                          }
                                        },
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete, color: Colors.red),
                                      onPressed: () {
                                        setState(() {
                                          final serviceIndex = _selectedServices
                                              .indexWhere((s) => s.id == service.id);
                                          if (serviceIndex != -1) {
                                            _selectedServices[serviceIndex]
                                                .intakeQuestions
                                                .removeAt(questionIndex);
                                          }
                                        });
                                      },
                                    ),
                                  ],
                                ),
                              );
                            })),
                            const SizedBox(height: 8),
                            OutlinedButton.icon(
                              onPressed: () {
                                setState(() {
                                  final serviceIndex = _selectedServices
                                      .indexWhere((s) => s.id == service.id);
                                  if (serviceIndex != -1) {
                                    _selectedServices[serviceIndex]
                                        .intakeQuestions
                                        .add('What specific details do you need for this service?');
                                  }
                                });
                              },
                              icon: const Icon(Icons.add),
                              label: const Text('Add Custom Question'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFFFBB04C),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
          
          const SizedBox(height: 16),
          if (_selectedServices.isEmpty)
            const Text(
              'Please select at least one service to continue.',
              style: TextStyle(color: Colors.red),
            ),
        ],
      ),
    );
  }
}

class ServiceCategory {
  final String id;
  final String name;
  final IconData icon;
  List<String> intakeQuestions;
  List<String> defaultQuestions;

  ServiceCategory({
    required this.id,
    required this.name,
    required this.icon,
    List<String>? intakeQuestions,
    List<String>? defaultQuestions,
  }) : intakeQuestions = intakeQuestions ?? [],
       defaultQuestions = defaultQuestions ?? [];
}

class EmployeeProfile {
  final String name;
  final String role;
  final String bio;
  final File? photo;

  EmployeeProfile({
    required this.name,
    required this.role,
    required this.bio,
    this.photo,
  });
}

class AddEmployeeDialog extends StatefulWidget {
  const AddEmployeeDialog({super.key});

  @override
  State<AddEmployeeDialog> createState() => _AddEmployeeDialogState();
}

class _AddEmployeeDialogState extends State<AddEmployeeDialog> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _roleController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  File? _photo;
  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    _nameController.dispose();
    _roleController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final ImageSource? source = await showDialog<ImageSource>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select Photo Source'),
          actions: [
            TextButton.icon(
              onPressed: () => Navigator.pop(context, ImageSource.camera),
              icon: const Icon(Icons.camera_alt),
              label: const Text('Camera'),
            ),
            TextButton.icon(
              onPressed: () => Navigator.pop(context, ImageSource.gallery),
              icon: const Icon(Icons.photo_library),
              label: const Text('Gallery'),
            ),
          ],
        );
      },
    );

    if (source != null) {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 800,
        maxHeight: 800,
      );

      if (pickedFile != null) {
        setState(() {
          _photo = File(pickedFile.path);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Team Member'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Photo picker
            GestureDetector(
              onTap: _pickPhoto,
              child: CircleAvatar(
                radius: 40,
                backgroundImage: _photo != null ? FileImage(_photo!) : null,
                child: _photo == null
                    ? const Icon(Icons.add_a_photo, size: 30)
                    : null,
              ),
            ),
            const SizedBox(height: 16),
            
            // Name field
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Name *',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            
            // Role field
            TextField(
              controller: _roleController,
              decoration: const InputDecoration(
                labelText: 'Role/Title *',
                border: OutlineInputBorder(),
                hintText: 'e.g., Senior Plumber, Lead Technician',
              ),
            ),
            const SizedBox(height: 16),
            
            // Bio field
            TextField(
              controller: _bioController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Bio (Optional)',
                border: OutlineInputBorder(),
                hintText: 'Brief description of experience and expertise',
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
          onPressed: () {
            if (_nameController.text.trim().isEmpty ||
                _roleController.text.trim().isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Name and role are required')),
              );
              return;
            }

            Navigator.pop(
              context,
              EmployeeProfile(
                name: _nameController.text.trim(),
                role: _roleController.text.trim(),
                bio: _bioController.text.trim(),
                photo: _photo,
              ),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFBB04C),
          ),
          child: const Text('Add', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}
