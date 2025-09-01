import 'package:cloud_firestore/cloud_firestore.dart';

class ServiceBid {
  final String bidId;
  final String requestId;
  final String providerId;
  final String userId;
  final double priceQuote;
  final String availability; // e.g., "Available today 2-5 PM"
  final String bidMessage; // Provider's message to user
  final String bidStatus; // pending, accepted, rejected, expired
  final DateTime createdAt;
  final DateTime expiresAt; // 2 hours from creation
  final String priceBenchmark; // low, normal, high (from AI estimation)
  final Map<String, dynamic>? benchmarkMetadata; // AI estimation details

  ServiceBid({
    required this.bidId,
    required this.requestId,
    required this.providerId,
    required this.userId,
    required this.priceQuote,
    required this.availability,
    required this.bidMessage,
    required this.bidStatus,
    required this.createdAt,
    required this.expiresAt,
    required this.priceBenchmark,
    this.benchmarkMetadata,
  });

  // Generate unique bid ID
  factory ServiceBid.create({
    required String requestId,
    required String providerId,
    required String userId,
    required double priceQuote,
    required String availability,
    required String bidMessage,
    required String priceBenchmark,
    Map<String, dynamic>? benchmarkMetadata,
  }) {
    final now = DateTime.now();
    final bidId = 'bid_${now.millisecondsSinceEpoch}_${providerId.substring(0, 8)}';
    
    return ServiceBid(
      bidId: bidId,
      requestId: requestId,
      providerId: providerId,
      userId: userId,
      priceQuote: priceQuote,
      availability: availability,
      bidMessage: bidMessage,
      bidStatus: 'pending',
      createdAt: now,
      expiresAt: now.add(Duration(hours: 2)), // 2-hour window
      priceBenchmark: priceBenchmark,
      benchmarkMetadata: benchmarkMetadata,
    );
  }

  // Create from Firestore document
  factory ServiceBid.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return ServiceBid(
      bidId: doc.id,
      requestId: data['requestId'] ?? '',
      providerId: data['providerId'] ?? '',
      userId: data['userId'] ?? '',
      priceQuote: (data['priceQuote'] ?? 0).toDouble(),
      availability: data['availability'] ?? '',
      bidMessage: data['bidMessage'] ?? '',
      bidStatus: data['bidStatus'] ?? 'pending',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      expiresAt: (data['expiresAt'] as Timestamp).toDate(),
      priceBenchmark: data['priceBenchmark'] ?? 'normal',
      benchmarkMetadata: data['benchmarkMetadata'] != null 
          ? Map<String, dynamic>.from(data['benchmarkMetadata']) 
          : null,
    );
  }

  // Convert to Firestore format
  Map<String, dynamic> toFirestore() {
    return {
      'requestId': requestId,
      'providerId': providerId,
      'userId': userId,
      'priceQuote': priceQuote,
      'availability': availability,
      'bidMessage': bidMessage,
      'bidStatus': bidStatus,
      'createdAt': Timestamp.fromDate(createdAt),
      'expiresAt': Timestamp.fromDate(expiresAt),
      'priceBenchmark': priceBenchmark,
      'benchmarkMetadata': benchmarkMetadata,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    };
  }

  // Check if bid has expired
  bool get isExpired => DateTime.now().isAfter(expiresAt);

  // Get time remaining for bid
  Duration get timeRemaining {
    final now = DateTime.now();
    if (now.isAfter(expiresAt)) {
      return Duration.zero;
    }
    return expiresAt.difference(now);
  }

  // Copy with updated fields
  ServiceBid copyWith({
    String? bidStatus,
    Map<String, dynamic>? benchmarkMetadata,
  }) {
    return ServiceBid(
      bidId: bidId,
      requestId: requestId,
      providerId: providerId,
      userId: userId,
      priceQuote: priceQuote,
      availability: availability,
      bidMessage: bidMessage,
      bidStatus: bidStatus ?? this.bidStatus,
      createdAt: createdAt,
      expiresAt: expiresAt,
      priceBenchmark: priceBenchmark,
      benchmarkMetadata: benchmarkMetadata ?? this.benchmarkMetadata,
    );
  }

  @override
  String toString() {
    return 'ServiceBid(bidId: $bidId, providerId: $providerId, priceQuote: \$$priceQuote, status: $bidStatus)';
  }
}
