import 'package:cloud_firestore/cloud_firestore.dart';

class ServiceRequest {
  final String requestId;
  final String userId;
  final String description;
  final List<String> mediaUrls;
  final String preferredTime;
  final String locationMasked;
  final String? finalAddress;
  final String status;
  final DateTime createdAt;
  final String priceRange;
  final String? customerName;
  final String? customerPhotoUrl;

  ServiceRequest({
    required this.requestId,
    required this.userId,
    required this.description,
    required this.mediaUrls,
    required this.preferredTime,
    required this.locationMasked,
    this.finalAddress,
    required this.status,
    required this.createdAt,
    required this.priceRange,
    this.customerName,
    this.customerPhotoUrl,
  });

  factory ServiceRequest.fromMap(String id, Map<String, dynamic> data) {
    return ServiceRequest(
      requestId: id,
      userId: data['user_id'] ?? '',
      description: data['description'] ?? '',
      mediaUrls: List<String>.from(data['media_urls'] ?? []),
      preferredTime: data['preferred_time'] ?? '',
      locationMasked: data['location_masked'] ?? '',
      finalAddress: data['final_address'],
      status: data['status'] ?? '',
      createdAt: (data['created_at'] as Timestamp).toDate(),
      priceRange: data['price_range'] ?? '',
      customerName: data['customer_name'],
      customerPhotoUrl: data['customer_photo_url'],
    );
  }
} 