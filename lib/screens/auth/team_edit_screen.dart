import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class TeamEditScreen extends StatefulWidget {
  final String providerId;
  final List<dynamic> currentTeam;

  const TeamEditScreen({
    super.key,
    required this.providerId,
    required this.currentTeam,
  });

  @override
  State<TeamEditScreen> createState() => _TeamEditScreenState();
}

class _TeamEditScreenState extends State<TeamEditScreen> {
  List<TeamMember> _teamMembers = [];
  bool _isLoading = false;
  String? _errorMessage;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadTeamMembers();
  }

  void _loadTeamMembers() {
    setState(() {
      _teamMembers = widget.currentTeam.map((member) => TeamMember(
        name: member['name'] ?? '',
        role: member['role'] ?? '',
        bio: member['bio'] ?? '',
        photoUrl: member['photoUrl'],
      )).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Edit Team'),
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
              'Manage Your Team',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Add team members to showcase your professional expertise.',
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
            
            // Add team member button
            OutlinedButton.icon(
              onPressed: _addTeamMember,
              icon: const Icon(Icons.person_add),
              label: const Text('Add Team Member'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: const BorderSide(color: Color(0xFFFBB04C)),
                foregroundColor: const Color(0xFFFBB04C),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Team members list
            if (_teamMembers.isNotEmpty)
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _teamMembers.length,
                itemBuilder: (context, index) {
                  final member = _teamMembers[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[200]!),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        // Profile photo
                        GestureDetector(
                          onTap: () => _editTeamMemberPhoto(index),
                          child: Stack(
                            children: [
                              Container(
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: const Color(0xFFFBB04C), width: 2),
                                ),
                                child: ClipOval(
                                  child: member.photo != null
                                      ? Image.file(member.photo!, fit: BoxFit.cover)
                                      : member.photoUrl != null
                                          ? Image.network(
                                              member.photoUrl!,
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
                                              child: const Icon(Icons.add_a_photo, color: Colors.grey),
                                            ),
                                ),
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  width: 20,
                                  height: 20,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFFBB04C),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.camera_alt,
                                    color: Colors.white,
                                    size: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        
                        // Member info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                member.name.isNotEmpty ? member.name : 'Team Member',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              if (member.role.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  member.role,
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        
                        // Action buttons
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              onPressed: () => _editTeamMember(index),
                              icon: const Icon(Icons.edit, color: Color(0xFFFBB04C)),
                            ),
                            IconButton(
                              onPressed: () => _removeTeamMember(index),
                              icon: const Icon(Icons.delete, color: Colors.red),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  void _addTeamMember() {
    setState(() {
      _teamMembers.add(TeamMember(
        name: '',
        role: '',
        bio: '',
        photoUrl: null,
      ));
    });
    
    // Automatically open edit dialog for new member
    _editTeamMember(_teamMembers.length - 1);
  }

  void _editTeamMember(int index) {
    final member = _teamMembers[index];
    showDialog(
      context: context,
      builder: (context) => TeamMemberEditDialog(
        member: member,
        onSave: (updatedMember) {
          setState(() {
            _teamMembers[index] = updatedMember;
          });
        },
      ),
    );
  }

  Future<void> _editTeamMemberPhoto(int index) async {
    try {
      final ImageSource? source = await showDialog<ImageSource>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Select Photo Source'),
            content: const Text('Choose how to add a photo for this team member:'),
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

      if (source != null) {
        final XFile? pickedFile = await _picker.pickImage(
          source: source,
          imageQuality: 80,
          maxWidth: 800,
          maxHeight: 800,
        );

        if (pickedFile != null) {
          setState(() {
            _teamMembers[index] = _teamMembers[index].copyWith(
              photo: File(pickedFile.path),
            );
          });
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Photo added! Save to upload.'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      print('Photo picker error: $e');
      
      // Show user-friendly error message
      String errorMessage = 'Unable to access photos.';
      if (e.toString().contains('camera_access_denied')) {
        errorMessage = 'Camera access denied. Please enable camera access in Settings → Privacy & Security → Camera → Magic Home App.';
      } else if (e.toString().contains('photo_access_denied')) {
        errorMessage = 'Photo library access denied. Please enable photo access in Settings → Privacy & Security → Photos → Magic Home App.';
      }
      
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Photo Access Issue'),
          content: Text(errorMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  void _removeTeamMember(int index) {
    setState(() {
      _teamMembers.removeAt(index);
    });
  }

  Future<void> _saveChanges() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Upload photos and prepare team data
      List<Map<String, dynamic>> teamData = [];
      
      for (var member in _teamMembers) {
        String? photoUrl = member.photoUrl;
        
        // Upload new photo if selected
        if (member.photo != null) {
          final storageRef = FirebaseStorage.instance
              .ref()
              .child('providers')
              .child(widget.providerId)
              .child('employees')
              .child('${DateTime.now().millisecondsSinceEpoch}_${teamData.length}.jpg');

          final uploadTask = storageRef.putFile(member.photo!);
          final snapshot = await uploadTask;
          photoUrl = await snapshot.ref.getDownloadURL();
        }
        
        teamData.add({
          'name': member.name,
          'role': member.role,
          'bio': member.bio,
          'photoUrl': photoUrl,
        });
      }

      // Update database
      await FirebaseFirestore.instance
          .collection('providers')
          .doc(widget.providerId)
          .update({
        'employees': teamData,
        'teamUpdatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Team updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }

    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to save team: $e';
        _isLoading = false;
      });
    }
  }
}

class TeamMember {
  final String name;
  final String role;
  final String bio;
  final String? photoUrl;
  final File? photo;

  TeamMember({
    required this.name,
    required this.role,
    required this.bio,
    this.photoUrl,
    this.photo,
  });

  TeamMember copyWith({
    String? name,
    String? role,
    String? bio,
    String? photoUrl,
    File? photo,
  }) {
    return TeamMember(
      name: name ?? this.name,
      role: role ?? this.role,
      bio: bio ?? this.bio,
      photoUrl: photoUrl ?? this.photoUrl,
      photo: photo ?? this.photo,
    );
  }
}

class TeamMemberEditDialog extends StatefulWidget {
  final TeamMember member;
  final Function(TeamMember) onSave;

  const TeamMemberEditDialog({
    super.key,
    required this.member,
    required this.onSave,
  });

  @override
  State<TeamMemberEditDialog> createState() => _TeamMemberEditDialogState();
}

class _TeamMemberEditDialogState extends State<TeamMemberEditDialog> {
  late TextEditingController _nameController;
  late TextEditingController _roleController;
  late TextEditingController _bioController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.member.name);
    _roleController = TextEditingController(text: widget.member.role);
    _bioController = TextEditingController(text: widget.member.bio);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _roleController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Team Member'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Name',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _roleController,
            decoration: const InputDecoration(
              labelText: 'Role/Title',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _bioController,
            decoration: const InputDecoration(
              labelText: 'Bio (Optional)',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
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
            final updatedMember = widget.member.copyWith(
              name: _nameController.text.trim(),
              role: _roleController.text.trim(),
              bio: _bioController.text.trim(),
            );
            widget.onSave(updatedMember);
            Navigator.pop(context);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFBB04C),
          ),
          child: const Text('Save', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}
