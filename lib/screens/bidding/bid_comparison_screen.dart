import 'package:flutter/material.dart';
import 'dart:async';
import '../../models/service_bid.dart';
import '../../models/bidding_session.dart';
import '../../models/user_request.dart';
import '../../services/bidding_service.dart';
import '../../widgets/bid_comparison_card.dart';
import '../../widgets/provider_header_widget.dart';

class BidComparisonScreen extends StatefulWidget {
  final String requestId;
  final UserRequest userRequest;

  const BidComparisonScreen({
    Key? key,
    required this.requestId,
    required this.userRequest,
  }) : super(key: key);

  @override
  _BidComparisonScreenState createState() => _BidComparisonScreenState();
}

class _BidComparisonScreenState extends State<BidComparisonScreen>
    with TickerProviderStateMixin {
  Timer? _deadlineTimer;
  String _timeRemaining = "";
  BiddingSession? _currentSession;
  List<ServiceBid> _bids = [];
  bool _isSessionExpired = false;
  late AnimationController _pulseController;
  late AnimationController _newBidController;
  String? _lastBidId;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _startDeadlineTimer();
  }

  @override
  void dispose() {
    _deadlineTimer?.cancel();
    _pulseController.dispose();
    _newBidController.dispose();
    super.dispose();
  }

  void _setupAnimations() {
    _pulseController = AnimationController(
      duration: Duration(seconds: 2),
      vsync: this,
    )..repeat();

    _newBidController = AnimationController(
      duration: Duration(milliseconds: 600),
      vsync: this,
    );
  }

  void _startDeadlineTimer() {
    _deadlineTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (_currentSession != null) {
        final now = DateTime.now();
        final difference = _currentSession!.deadline.difference(now);

        if (difference.isNegative) {
          setState(() {
            _timeRemaining = "EXPIRED";
            _isSessionExpired = true;
          });
          timer.cancel();
          _handleBiddingExpired();
        } else {
          setState(() {
            _timeRemaining = BiddingService.formatTimeRemaining(difference);
          });
        }
      }
    });
  }

  void _handleBiddingExpired() {
    if (_bids.isEmpty) {
      _showNoBidsDialog();
    }
  }

  void _showNoBidsDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.hourglass_empty, color: Colors.orange),
            SizedBox(width: 8),
            Text('Bidding Expired'),
          ],
        ),
        content: Text(
          'The bidding period has ended but no providers submitted bids. Would you like to extend the deadline or modify your request?',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            child: Text('Modify Request'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // TODO: Implement extend deadline functionality
            },
            child: Text('Extend Deadline'),
          ),
        ],
      ),
    );
  }

  void _onBidAccepted(String bidId) async {
    // Show confirmation dialog
    final confirmed = await _showAcceptBidDialog();
    if (!confirmed) return;

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Accepting bid...'),
          ],
        ),
      ),
    );

    try {
      final result = await BiddingService.acceptBid(bidId);
      
      Navigator.of(context).pop(); // Close loading dialog

      if (result['success']) {
        _showSuccessDialog(result['winningProviderId'], result['price']);
      } else {
        _showErrorDialog(result['message']);
      }
    } catch (e) {
      Navigator.of(context).pop(); // Close loading dialog
      _showErrorDialog('Failed to accept bid: $e');
    }
  }

  Future<bool> _showAcceptBidDialog() async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Accept This Bid?'),
        content: Text(
          'Once you accept this bid, all other bids will be automatically rejected and the provider will be notified to start the job.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: Text('Accept Bid'),
          ),
        ],
      ),
    ) ?? false;
  }

  void _showSuccessDialog(String providerId, double price) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 28),
            SizedBox(width: 8),
            Text('Bid Accepted!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('You have successfully accepted the bid for \$${price.toInt()}.'),
            SizedBox(height: 12),
            Text(
              'The provider has been notified and will contact you shortly to schedule the service.',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
              // TODO: Navigate to job tracking screen
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: Text('View Job Details'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.error, color: Colors.red),
            SizedBox(width: 8),
            Text('Error'),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  void _triggerNewBidAnimation() {
    _newBidController.forward().then((_) {
      _newBidController.reset();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Compare Bids'),
            Text(
              _timeRemaining.isNotEmpty ? _timeRemaining : 'Loading...',
              style: TextStyle(
                fontSize: 12,
                color: _timeRemaining.contains("EXPIRED") 
                    ? Colors.red 
                    : Colors.white70,
              ),
            ),
          ],
        ),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Bidding status banner
          _buildBiddingStatusBanner(),
          
          // Real-time bid stream
          Expanded(
            child: StreamBuilder<BiddingSession?>(
              stream: BiddingService.getBiddingSessionStream(widget.requestId),
              builder: (context, sessionSnapshot) {
                if (sessionSnapshot.hasData) {
                  _currentSession = sessionSnapshot.data;
                }

                return StreamBuilder<List<ServiceBid>>(
                  stream: BiddingService.getBidsStream(widget.requestId),
                  builder: (context, bidsSnapshot) {
                    if (bidsSnapshot.connectionState == ConnectionState.waiting && _bids.isEmpty) {
                      return _buildWaitingForBidsScreen();
                    }

                    if (bidsSnapshot.hasData) {
                      final newBids = bidsSnapshot.data!;
                      
                      // Check for new bids to trigger animation
                      if (_bids.isNotEmpty && newBids.length > _bids.length) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          _triggerNewBidAnimation();
                        });
                      }
                      
                      _bids = newBids;
                    }

                    if (_bids.isEmpty) {
                      return _buildNoBidsYetScreen();
                    }

                    // Sort bids by submission time (most recent first)
                    _bids.sort((a, b) => b.createdAt.compareTo(a.createdAt));

                    return _buildBidsList();
                  },
                );
              },
            ),
          ),
          
          // Quick action footer
          if (!_isSessionExpired && _bids.isNotEmpty)
            _buildQuickActionFooter(),
        ],
      ),
    );
  }

  Widget _buildBiddingStatusBanner() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return Container(
          width: double.infinity,
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _isSessionExpired 
                ? Colors.red.withOpacity(0.1)
                : Colors.blue.withOpacity(0.1 + 0.05 * _pulseController.value),
            border: Border(
              bottom: BorderSide(
                color: _isSessionExpired ? Colors.red : Colors.blue,
                width: 2,
              ),
            ),
          ),
          child: Row(
            children: [
              Icon(
                _isSessionExpired ? Icons.timer_off : Icons.schedule,
                color: _isSessionExpired ? Colors.red : Colors.blue,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isSessionExpired ? "Bidding Closed" : "Bidding in Progress",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _isSessionExpired ? Colors.red : Colors.blue,
                      ),
                    ),
                    Text(
                      _isSessionExpired 
                          ? "No more bids can be submitted"
                          : "Providers can submit bids until $_timeRemaining",
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              StreamBuilder<int>(
                stream: BiddingService.getBidCountStream(widget.requestId),
                builder: (context, snapshot) {
                  final bidCount = snapshot.data ?? 0;
                  return Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _isSessionExpired ? Colors.red : Colors.blue,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      "$bidCount bid${bidCount != 1 ? 's' : ''}",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildWaitingForBidsScreen() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                return Transform.scale(
                  scale: 1.0 + 0.1 * _pulseController.value,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Theme.of(context).primaryColor,
                    ),
                  ),
                );
              },
            ),
            SizedBox(height: 16),
            Text(
              "Waiting for provider responses...",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
            SizedBox(height: 8),
            Text(
              "We've notified ${_currentSession?.notifiedProviders.length ?? 0} qualified providers",
              style: TextStyle(color: Colors.grey[600]),
            ),
            SizedBox(height: 24),
            _buildProviderResponseAnimation(),
          ],
        ),
      ),
    );
  }

  Widget _buildNoBidsYetScreen() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _isSessionExpired ? Icons.sentiment_dissatisfied : Icons.hourglass_empty,
              size: 64,
              color: _isSessionExpired ? Colors.red : Colors.grey,
            ),
            SizedBox(height: 16),
            Text(
              _isSessionExpired ? "No bids received" : "No bids received yet",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
            Text(
              _isSessionExpired 
                  ? "The bidding period has ended"
                  : "Providers have $_timeRemaining to respond",
              style: TextStyle(color: Colors.grey[600]),
            ),
            if (_isSessionExpired) ...[
              SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  // TODO: Implement extend deadline or modify request
                },
                icon: Icon(Icons.refresh),
                label: Text('Extend Deadline'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBidsList() {
    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: _bids.length,
      itemBuilder: (context, index) {
        final bid = _bids[index];
        final isNewBid = _isRecentBid(bid.createdAt);
        
        return AnimatedBuilder(
          animation: _newBidController,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(
                isNewBid ? 50 * (1 - _newBidController.value) : 0,
                0,
              ),
              child: Opacity(
                opacity: isNewBid ? _newBidController.value : 1.0,
                child: BidComparisonCard(
                  bid: bid,
                  userRequest: widget.userRequest,
                  isHighlighted: isNewBid,
                  onAccept: () => _onBidAccepted(bid.bidId),
                  onViewProfile: () => _viewProviderProfile(bid.providerId),
                  isExpired: _isSessionExpired,
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildProviderResponseAnimation() {
    return Container(
      height: 60,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(3, (index) {
          return AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              final delay = index * 0.3;
              final animationValue = (_pulseController.value + delay) % 1.0;
              
              return Container(
                margin: EdgeInsets.symmetric(horizontal: 4),
                child: Transform.scale(
                  scale: 0.5 + 0.5 * animationValue,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor.withOpacity(
                        0.3 + 0.7 * animationValue,
                      ),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              );
            },
          );
        }),
      ),
    );
  }

  Widget _buildQuickActionFooter() {
    final bestBid = _bids.isEmpty 
        ? null 
        : _bids.reduce((a, b) => a.priceQuote < b.priceQuote ? a : b);
    
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.3),
            spreadRadius: 1,
            blurRadius: 5,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (bestBid != null) ...[
            Text(
              "Best Price: \$${bestBid.priceQuote.toInt()}",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            SizedBox(height: 8),
          ],
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    // TODO: Implement message all providers
                  },
                  icon: Icon(Icons.message),
                  label: Text('Message All'),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: bestBid != null 
                      ? () => _onBidAccepted(bestBid.bidId)
                      : null,
                  icon: Icon(Icons.check),
                  label: Text('Accept Best'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  bool _isRecentBid(DateTime bidTime) {
    // Highlight bids submitted in the last 2 minutes
    return DateTime.now().difference(bidTime).inMinutes < 2;
  }

  void _viewProviderProfile(String providerId) {
    // TODO: Navigate to provider profile screen
    print('View provider profile: $providerId');
  }
}
