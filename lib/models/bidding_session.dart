import 'package:cloud_firestore/cloud_firestore.dart';

class BiddingSession {
  final String sessionId;
  final String requestId;
  final String userId;
  final List<String> notifiedProviders; // Providers who were notified
  final List<String> receivedBids; // Bid IDs that have been submitted
  final String sessionStatus; // active, completed, expired
  final String? selectedBidId; // Winner bid ID
  final String? winningProviderId; // Winner provider ID
  final DateTime createdAt;
  final DateTime deadline; // When bidding window closes
  final Map<String, dynamic>? sessionMetadata; // Additional session info

  BiddingSession({
    required this.sessionId,
    required this.requestId,
    required this.userId,
    required this.notifiedProviders,
    required this.receivedBids,
    required this.sessionStatus,
    this.selectedBidId,
    this.winningProviderId,
    required this.createdAt,
    required this.deadline,
    this.sessionMetadata,
  });

  // Create new bidding session
  factory BiddingSession.create({
    required String requestId,
    required String userId,
    required List<String> notifiedProviders,
    int deadlineHours = 2,
  }) {
    final now = DateTime.now();
    final sessionId = 'session_${now.millisecondsSinceEpoch}_${requestId.substring(0, 8)}';
    
    return BiddingSession(
      sessionId: sessionId,
      requestId: requestId,
      userId: userId,
      notifiedProviders: notifiedProviders,
      receivedBids: [],
      sessionStatus: 'active',
      createdAt: now,
      deadline: now.add(Duration(hours: deadlineHours)),
      sessionMetadata: {
        'notificationsSent': notifiedProviders.length,
        'expectedResponses': notifiedProviders.length,
      },
    );
  }

  // Create from Firestore document
  factory BiddingSession.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return BiddingSession(
      sessionId: doc.id,
      requestId: data['requestId'] ?? '',
      userId: data['userId'] ?? '',
      notifiedProviders: List<String>.from(data['notifiedProviders'] ?? []),
      receivedBids: List<String>.from(data['receivedBids'] ?? []),
      sessionStatus: data['sessionStatus'] ?? 'active',
      selectedBidId: data['selectedBidId'],
      winningProviderId: data['winningProviderId'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      deadline: (data['deadline'] as Timestamp).toDate(),
      sessionMetadata: data['sessionMetadata'] != null 
          ? Map<String, dynamic>.from(data['sessionMetadata']) 
          : null,
    );
  }

  // Convert to Firestore format
  Map<String, dynamic> toFirestore() {
    return {
      'requestId': requestId,
      'userId': userId,
      'notifiedProviders': notifiedProviders,
      'receivedBids': receivedBids,
      'sessionStatus': sessionStatus,
      'selectedBidId': selectedBidId,
      'winningProviderId': winningProviderId,
      'createdAt': Timestamp.fromDate(createdAt),
      'deadline': Timestamp.fromDate(deadline),
      'sessionMetadata': sessionMetadata,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    };
  }

  // Check if session has expired
  bool get isExpired => DateTime.now().isAfter(deadline);

  // Get time remaining for session
  Duration get timeRemaining {
    final now = DateTime.now();
    if (now.isAfter(deadline)) {
      return Duration.zero;
    }
    return deadline.difference(now);
  }

  // Get response rate
  double get responseRate {
    if (notifiedProviders.isEmpty) return 0.0;
    return receivedBids.length / notifiedProviders.length;
  }

  // Add a new bid to the session
  BiddingSession addBid(String bidId) {
    final updatedBids = List<String>.from(receivedBids);
    if (!updatedBids.contains(bidId)) {
      updatedBids.add(bidId);
    }
    
    return copyWith(receivedBids: updatedBids);
  }

  // Select winning bid and close session
  BiddingSession selectWinner(String bidId, String providerId) {
    return copyWith(
      sessionStatus: 'completed',
      selectedBidId: bidId,
      winningProviderId: providerId,
    );
  }

  // Copy with updated fields
  BiddingSession copyWith({
    List<String>? notifiedProviders,
    List<String>? receivedBids,
    String? sessionStatus,
    String? selectedBidId,
    String? winningProviderId,
    Map<String, dynamic>? sessionMetadata,
  }) {
    return BiddingSession(
      sessionId: sessionId,
      requestId: requestId,
      userId: userId,
      notifiedProviders: notifiedProviders ?? this.notifiedProviders,
      receivedBids: receivedBids ?? this.receivedBids,
      sessionStatus: sessionStatus ?? this.sessionStatus,
      selectedBidId: selectedBidId ?? this.selectedBidId,
      winningProviderId: winningProviderId ?? this.winningProviderId,
      createdAt: createdAt,
      deadline: deadline,
      sessionMetadata: sessionMetadata ?? this.sessionMetadata,
    );
  }

  @override
  String toString() {
    return 'BiddingSession(sessionId: $sessionId, requestId: $requestId, status: $sessionStatus, bids: ${receivedBids.length}/${notifiedProviders.length})';
  }
}
