import 'package:cloud_firestore/cloud_firestore.dart';

class ServiceOrder {
  final String orderId;
  final String requestId;
  final String providerId;
  final String userId;
  final double finalPrice;
  final DateTime scheduledTime;
  final String confirmedAddress;
  final String status;
  final String? serviceDescription;
  final String? customerName;
  final String? customerPhotoUrl;

  ServiceOrder({
    required this.orderId,
    required this.requestId,
    required this.providerId,
    required this.userId,
    required this.finalPrice,
    required this.scheduledTime,
    required this.confirmedAddress,
    required this.status,
    this.serviceDescription,
    this.customerName,
    this.customerPhotoUrl,
  });

  factory ServiceOrder.fromMap(String id, Map<String, dynamic> data) {
    return ServiceOrder(
      orderId: id,
      requestId: data['request_id'] ?? '',
      providerId: data['provider_id'] ?? '',
      userId: data['user_id'] ?? '',
      finalPrice: (data['final_price'] ?? 0.0).toDouble(),
      scheduledTime: (data['scheduled_time'] as Timestamp).toDate(),
      confirmedAddress: data['confirmed_address'] ?? '',
      status: data['status'] ?? '',
      serviceDescription: data['service_description'],
      customerName: data['customer_name'],
      customerPhotoUrl: data['customer_photo_url'],
    );
  }
} 