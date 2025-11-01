import 'package:cloud_firestore/cloud_firestore.dart';

class ProviderPost {
  final String? postId;
  final String providerId;
  final String providerName;
  final String? providerAvatar; // Changed from providerPhotoUrl to match existing code
  final String? companyName; // Added for compatibility
  final String city;
  final String? state;
  final String serviceCategory;
  final String description;
  final List<String> imageUrls;
  final DateTime createdAt;
  final int likesCount;
  final int sharesCount;
  final dynamic location; // Changed to dynamic for flexibility

  ProviderPost({
    this.postId,
    required this.providerId,
    required this.providerName,
    this.providerAvatar,
    this.companyName,
    required this.city,
    this.state,
    required this.serviceCategory,
    required this.description,
    required this.imageUrls,
    DateTime? createdAt,
    this.likesCount = 0,
    this.sharesCount = 0,
    this.location,
  }) : createdAt = createdAt ?? DateTime.now();

  factory ProviderPost.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ProviderPost(
      postId: doc.id,
      providerId: data['providerId'] ?? '',
      providerName: data['providerName'] ?? '',
      providerAvatar: data['providerAvatar'],
      companyName: data['companyName'],
      city: data['city'] ?? '',
      state: data['state'],
      serviceCategory: data['serviceCategory'] ?? '',
      description: data['description'] ?? '',
      imageUrls: List<String>.from(data['imageUrls'] ?? []),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      likesCount: data['likesCount'] ?? 0,
      sharesCount: data['sharesCount'] ?? 0,
      location: data['location'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'providerId': providerId,
      'providerName': providerName,
      'providerAvatar': providerAvatar,
      'companyName': companyName,
      'city': city,
      'state': state,
      'serviceCategory': serviceCategory,
      'description': description,
      'imageUrls': imageUrls,
      'createdAt': Timestamp.fromDate(createdAt),
      'likesCount': likesCount,
      'sharesCount': sharesCount,
      'location': location,
    };
  }
}
