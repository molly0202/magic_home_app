import 'package:cloud_firestore/cloud_firestore.dart';

class ProviderPost {
  final String? postId;
  final String providerId;
  final String providerName;
  final String? providerAvatar;
  final String? companyName;
  final String serviceCategory;
  final String description;
  final List<String> imageUrls;
  final String city;
  final String location; // Full address for filtering
  final DateTime createdAt;
  final int likesCount;
  final int viewsCount;
  
  ProviderPost({
    this.postId,
    required this.providerId,
    required this.providerName,
    this.providerAvatar,
    this.companyName,
    required this.serviceCategory,
    required this.description,
    required this.imageUrls,
    required this.city,
    required this.location,
    DateTime? createdAt,
    this.likesCount = 0,
    this.viewsCount = 0,
  }) : createdAt = createdAt ?? DateTime.now();

  // Create from Firestore document
  factory ProviderPost.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ProviderPost(
      postId: doc.id,
      providerId: data['providerId'] ?? '',
      providerName: data['providerName'] ?? '',
      providerAvatar: data['providerAvatar'],
      companyName: data['companyName'],
      serviceCategory: data['serviceCategory'] ?? '',
      description: data['description'] ?? '',
      imageUrls: List<String>.from(data['imageUrls'] ?? []),
      city: data['city'] ?? '',
      location: data['location'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      likesCount: data['likesCount'] ?? 0,
      viewsCount: data['viewsCount'] ?? 0,
    );
  }

  // Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'providerId': providerId,
      'providerName': providerName,
      'providerAvatar': providerAvatar,
      'companyName': companyName,
      'serviceCategory': serviceCategory,
      'description': description,
      'imageUrls': imageUrls,
      'city': city,
      'location': location,
      'createdAt': Timestamp.fromDate(createdAt),
      'likesCount': likesCount,
      'viewsCount': viewsCount,
    };
  }
}

