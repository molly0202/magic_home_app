import 'package:cloud_firestore/cloud_firestore.dart';

class UserRequest {
  final String? requestId;
  final String userId;
  final String serviceCategory;
  final String description;
  final List<String> mediaUrls;
  final Map<String, dynamic> userAvailability;
  final String address;
  final String phoneNumber;
  final Map<String, dynamic>? location; // {lat, lng, formatted_address}
  final Map<String, dynamic>? preferences; // price_range, urgency, etc.
  final DateTime createdAt;
  final String status; // 'pending', 'matched', 'assigned', 'completed'
  final List<String>? tags;
  final int? priority; // 1-5, where 5 is highest priority
  final Map<String, dynamic>? aiPriceEstimation; // AI-generated price estimation
  
  UserRequest({
    this.requestId,
    required this.userId,
    required this.serviceCategory,
    required this.description,
    required this.mediaUrls,
    required this.userAvailability,
    required this.address,
    required this.phoneNumber,
    this.location,
    this.preferences,
    DateTime? createdAt,
    this.status = 'pending',
    this.tags,
    this.priority = 3,
    this.aiPriceEstimation,
  }) : createdAt = createdAt ?? DateTime.now();

  // Create from AI intake service data
  factory UserRequest.fromAIIntake({
    required String userId,
    required String serviceCategory,
    required String description,
    required List<String> mediaUrls,
    required Map<String, dynamic> userAvailability,
    required String address,
    required String phoneNumber,
    Map<String, dynamic>? location,
    Map<String, dynamic>? preferences,
    List<String>? tags,
    int? priority,
    Map<String, dynamic>? aiPriceEstimation,
  }) {
    return UserRequest(
      userId: userId,
      serviceCategory: serviceCategory,
      description: description,
      mediaUrls: mediaUrls,
      userAvailability: userAvailability,
      address: address,
      phoneNumber: phoneNumber,
      location: location,
      preferences: preferences ?? {},
      tags: tags ?? [],
      priority: priority ?? 3,
      aiPriceEstimation: aiPriceEstimation,
    );
  }

  // Create from Firestore document
  factory UserRequest.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserRequest(
      requestId: doc.id,
      userId: data['userId'] ?? '',
      serviceCategory: data['serviceCategory'] ?? '',
      description: data['description'] ?? '',
      mediaUrls: List<String>.from(data['mediaUrls'] ?? []),
      userAvailability: Map<String, dynamic>.from(data['userAvailability'] ?? {}),
      address: data['address'] ?? '',
      phoneNumber: data['phoneNumber'] ?? '',
      location: data['location'] != null ? Map<String, dynamic>.from(data['location']) : null,
      preferences: data['preferences'] != null ? Map<String, dynamic>.from(data['preferences']) : null,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: data['status'] ?? 'pending',
      tags: data['tags'] != null ? List<String>.from(data['tags']) : null,
      priority: data['priority'] ?? 3,
      aiPriceEstimation: data['aiPriceEstimation'] != null 
          ? Map<String, dynamic>.from(data['aiPriceEstimation']) 
          : null,
    );
  }

  // Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'requestId': requestId, // Include requestId in Firestore data
      'userId': userId,
      'serviceCategory': serviceCategory,
      'description': description,
      'mediaUrls': mediaUrls,
      'userAvailability': userAvailability,
      'address': address,
      'phoneNumber': phoneNumber,
      'location': location,
      'preferences': preferences,
      'createdAt': Timestamp.fromDate(createdAt),
      'status': status,
      'tags': tags,
      'priority': priority,
      'aiPriceEstimation': aiPriceEstimation,
    };
  }

  // Create a copy with updated fields
  UserRequest copyWith({
    String? requestId,
    String? userId,
    String? serviceCategory,
    String? description,
    List<String>? mediaUrls,
    Map<String, dynamic>? userAvailability,
    String? address,
    String? phoneNumber,
    Map<String, dynamic>? location,
    Map<String, dynamic>? preferences,
    DateTime? createdAt,
    String? status,
    List<String>? tags,
    int? priority,
    Map<String, dynamic>? aiPriceEstimation,
  }) {
    return UserRequest(
      requestId: requestId ?? this.requestId,
      userId: userId ?? this.userId,
      serviceCategory: serviceCategory ?? this.serviceCategory,
      description: description ?? this.description,
      mediaUrls: mediaUrls ?? this.mediaUrls,
      userAvailability: userAvailability ?? this.userAvailability,
      address: address ?? this.address,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      location: location ?? this.location,
      preferences: preferences ?? this.preferences,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
      tags: tags ?? this.tags,
      priority: priority ?? this.priority,
      aiPriceEstimation: aiPriceEstimation ?? this.aiPriceEstimation,
    );
  }

  @override
  String toString() {
    return 'UserRequest(requestId: $requestId, userId: $userId, serviceCategory: $serviceCategory, status: $status)';
  }
} 