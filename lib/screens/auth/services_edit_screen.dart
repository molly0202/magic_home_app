import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ServicesEditScreen extends StatefulWidget {
  final String providerId;
  final List<dynamic> currentServices;

  const ServicesEditScreen({
    super.key,
    required this.providerId,
    required this.currentServices,
  });

  @override
  State<ServicesEditScreen> createState() => _ServicesEditScreenState();
}

class _ServicesEditScreenState extends State<ServicesEditScreen> {
  List<ServiceCategory> _selectedServices = [];
  bool _isLoading = false;
  String? _errorMessage;
  Set<String> _expandedServices = {}; // Track which services have expanded questions

  // Available service categories
  final List<ServiceCategory> _availableServices = [
    ServiceCategory(
      id: 'plumbing',
      name: 'Plumbing',
      icon: Icons.plumbing,
    ),
    ServiceCategory(
      id: 'electrical',
      name: 'Electrical',
      icon: Icons.electrical_services,
    ),
    ServiceCategory(
      id: 'hvac',
      name: 'HVAC',
      icon: Icons.air,
    ),
    ServiceCategory(
      id: 'cleaning',
      name: 'Cleaning',
      icon: Icons.cleaning_services,
    ),
    ServiceCategory(
      id: 'landscaping',
      name: 'Landscaping',
      icon: Icons.grass,
    ),
    ServiceCategory(
      id: 'handyman',
      name: 'Handyman',
      icon: Icons.handyman,
    ),
    ServiceCategory(
      id: 'moving',
      name: '搬家 (Moving)',
      icon: Icons.local_shipping,
    ),
    ServiceCategory(
      id: 'confinement_nanny',
      name: '月嫂 (Confinement Nanny)',
      icon: Icons.baby_changing_station,
    ),
    ServiceCategory(
      id: 'cooking',
      name: '做饭 (Cooking)',
      icon: Icons.restaurant,
    ),
    ServiceCategory(
      id: 'hourly_worker',
      name: '钟点工 (Hourly Worker)',
      icon: Icons.schedule,
    ),
    ServiceCategory(
      id: 'elderly_care',
      name: '老年陪护 (Elderly Care)',
      icon: Icons.elderly,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadCurrentServices();
  }

  void _loadCurrentServices() {
    setState(() {
      _selectedServices = widget.currentServices.map((service) {
        final availableService = _availableServices.firstWhere(
          (s) => s.id == service['id'],
          orElse: () => ServiceCategory(
            id: service['id'] ?? '',
            name: service['name'] ?? '',
            icon: Icons.build,
          ),
        );
        
        // Auto-expand services that have questions
        final questions = List<String>.from(service['intakeQuestions'] ?? []);
        if (questions.isNotEmpty) {
          _expandedServices.add(availableService.id);
        }
        
        return ServiceCategory(
          id: availableService.id,
          name: availableService.name,
          icon: availableService.icon,
          intakeQuestions: questions,
          hourlyRate: (service['hourlyRate'] as num?)?.toDouble(),
        );
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Edit Services'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveChanges,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text(
                    'Save',
                    style: TextStyle(
                      color: Color(0xFFFBB04C),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Your Services',
              style: TextStyle(
                fontSize: 28,
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
            const SizedBox(height: 32),
            
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
                
                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? const Color(0xFFFBB04C) : Colors.grey[300]!,
                      width: isSelected ? 2 : 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Service header with checkbox
                      ListTile(
                        leading: Icon(
                          service.icon, 
                          color: isSelected ? const Color(0xFFFBB04C) : Colors.grey[600],
                          size: 28,
                        ),
                        title: Text(
                          service.name,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isSelected ? const Color(0xFFFBB04C) : Colors.black87,
                          ),
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
                                intakeQuestions: [],
                              ));
                              // Auto-expand questions for newly selected services
                              _expandedServices.add(service.id);
                            } else {
                              _selectedServices.removeWhere((s) => s.id == service.id);
                              _expandedServices.remove(service.id);
                            }
                          });
                        },
                          activeColor: const Color(0xFFFBB04C),
                        ),
                      ),
                      
                      // Questions section - collapsible when selected
                      if (isSelected)
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFBB04C).withOpacity(0.05),
                            border: Border(
                              top: BorderSide(color: Colors.grey[200]!),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Collapsible header
                              InkWell(
                                onTap: () {
                                  setState(() {
                                    if (_expandedServices.contains(service.id)) {
                                      _expandedServices.remove(service.id);
                                    } else {
                                      _expandedServices.add(service.id);
                                    }
                                  });
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: Row(
                                    children: [
                                      Icon(Icons.quiz, color: Colors.grey[700], size: 20),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Questions You\'ll Ask Customers',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.grey[700],
                                          ),
                                        ),
                                      ),
                                      Icon(
                                        _expandedServices.contains(service.id)
                                            ? Icons.expand_less
                                            : Icons.expand_more,
                                        color: Colors.grey[700],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              
                              // Questions content - only show when expanded
                              if (_expandedServices.contains(service.id))
                                Padding(
                                  padding: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                              // Hourly rate input
                              Row(
                                children: [
                                  Icon(Icons.attach_money, color: Colors.grey[700], size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: TextFormField(
                                      initialValue: _selectedServices
                                          .firstWhere((s) => s.id == service.id)
                                          .hourlyRate?.toString() ?? '',
                                      decoration: const InputDecoration(
                                        labelText: 'Hourly Rate (\$)',
                                        border: OutlineInputBorder(),
                                        filled: true,
                                        fillColor: Colors.white,
                                        prefixText: '\$ ',
                                      ),
                                      keyboardType: TextInputType.number,
                                      onChanged: (value) {
                                        final serviceIndex = _selectedServices
                                            .indexWhere((s) => s.id == service.id);
                                        if (serviceIndex != -1) {
                                          _selectedServices[serviceIndex].hourlyRate = 
                                              double.tryParse(value);
                                        }
                                      },
                                      onFieldSubmitted: (value) {
                                        _autoSaveQuestions();
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              
                              // Questions header
                              Row(
                                children: [
                                  Icon(Icons.quiz, color: Colors.grey[700], size: 20),
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
                              const SizedBox(height: 16),
                              
                              // Show questions if any exist
                              if (_selectedServices
                                  .firstWhere((s) => s.id == service.id)
                                  .intakeQuestions.isNotEmpty)
                                ...(_selectedServices
                                    .firstWhere((s) => s.id == service.id)
                                    .intakeQuestions
                                    .asMap()
                                    .entries
                                    .map((entry) {
                                  final questionIndex = entry.key;
                                  final question = entry.value;
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: TextFormField(
                                            initialValue: question,
                                            decoration: InputDecoration(
                                              labelText: 'Question ${questionIndex + 1}',
                                              border: const OutlineInputBorder(),
                                              filled: true,
                                              fillColor: Colors.white,
                                            ),
                                            onChanged: (value) {
                                              final serviceIndex = _selectedServices
                                                  .indexWhere((s) => s.id == service.id);
                                              if (serviceIndex != -1) {
                                                _selectedServices[serviceIndex]
                                                    .intakeQuestions[questionIndex] = value;
                                              }
                                            },
                                            onFieldSubmitted: (value) {
                                              // Auto-save when user finishes editing a question
                                              _autoSaveQuestions();
                                            },
                                          ),
                                        ),
                                        const SizedBox(width: 8),
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
                                }))
                              else
                                // Show message when no questions added yet
                                Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: Colors.blue[50],
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.blue[200]!),
                                  ),
                                  child: Column(
                                    children: [
                                      Icon(
                                        Icons.quiz_outlined,
                                        color: Colors.blue[600],
                                        size: 32,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'No questions added yet',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.blue[700],
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Add questions you need to ask customers',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: Colors.blue[600],
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              
                              const SizedBox(height: 16),
                              
                              // Add question button
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    setState(() {
                                      final serviceIndex = _selectedServices
                                          .indexWhere((s) => s.id == service.id);
                                      if (serviceIndex != -1) {
                                        _selectedServices[serviceIndex]
                                            .intakeQuestions
                                            .add('');
                                      }
                                    });
                                  },
                                  icon: const Icon(Icons.add),
                                  label: const Text('Add Question'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFFBB04C),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
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
              },
            ),
            
            const SizedBox(height: 32),
            if (_selectedServices.isEmpty)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange[200]!),
                ),
                child: const Text(
                  'Please select at least one service to continue.',
                  style: TextStyle(color: Colors.orange),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _autoSaveQuestions() async {
    // Auto-save questions as user types (debounced)
    try {
      final servicesData = _selectedServices.map((service) => {
        'id': service.id,
        'name': service.name,
        'intakeQuestions': service.intakeQuestions.where((q) => q.trim().isNotEmpty).toList(),
        'hourlyRate': service.hourlyRate,
        'isActive': true,
      }).toList();

      await FirebaseFirestore.instance
          .collection('providers')
          .doc(widget.providerId)
          .update({
        'services': servicesData,
        'servicesUpdatedAt': FieldValue.serverTimestamp(),
      });

      print('✅ Auto-saved questions');
    } catch (e) {
      print('❌ Auto-save failed: $e');
    }
  }

  Future<void> _saveChanges() async {
    if (_selectedServices.isEmpty) {
      setState(() {
        _errorMessage = 'Please select at least one service.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Prepare services data
      final servicesData = _selectedServices.map((service) => {
        'id': service.id,
        'name': service.name,
        'intakeQuestions': service.intakeQuestions.where((q) => q.trim().isNotEmpty).toList(),
        'hourlyRate': service.hourlyRate,
        'isActive': true,
      }).toList();

      // Update database
      await FirebaseFirestore.instance
          .collection('providers')
          .doc(widget.providerId)
          .update({
        'services': servicesData,
        'servicesUpdatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Services updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }

    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to save services: $e';
        _isLoading = false;
      });
    }
  }
}

class ServiceCategory {
  final String id;
  final String name;
  final IconData icon;
  List<String> intakeQuestions;
  double? hourlyRate;

  ServiceCategory({
    required this.id,
    required this.name,
    required this.icon,
    List<String>? intakeQuestions,
    this.hourlyRate,
  }) : intakeQuestions = intakeQuestions ?? [];
}
