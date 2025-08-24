import 'package:flutter/material.dart';
import '../models/service_bid.dart';
import '../models/user_request.dart';

class BidComparisonCard extends StatefulWidget {
  final ServiceBid bid;
  final UserRequest userRequest;
  final bool isHighlighted;
  final VoidCallback onAccept;
  final VoidCallback onViewProfile;
  final bool isExpired;

  const BidComparisonCard({
    Key? key,
    required this.bid,
    required this.userRequest,
    this.isHighlighted = false,
    required this.onAccept,
    required this.onViewProfile,
    this.isExpired = false,
  }) : super(key: key);

  @override
  _BidComparisonCardState createState() => _BidComparisonCardState();
}

class _BidComparisonCardState extends State<BidComparisonCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: Duration(milliseconds: 600),
      vsync: this,
    );

    _slideAnimation = Tween<double>(
      begin: 50.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    ));

    // Start animation when card is created
    Future.delayed(Duration(milliseconds: 100), () {
      if (mounted) _animationController.forward();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _slideAnimation.value),
          child: Opacity(
            opacity: _fadeAnimation.value,
            child: Container(
              margin: EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: widget.isHighlighted
                    ? Border.all(color: Colors.green, width: 2)
                    : Border.all(color: Colors.grey[300]!, width: 1),
                boxShadow: [
                  BoxShadow(
                    color: widget.isHighlighted
                        ? Colors.green.withOpacity(0.3)
                        : Colors.grey.withOpacity(0.2),
                    blurRadius: widget.isHighlighted ? 8 : 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Card(
                elevation: 0,
                margin: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: _buildCardContent(),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCardContent() {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with NEW BID badge and time
              Row(
                children: [
                  if (widget.isHighlighted)
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.fiber_new, size: 14, color: Colors.white),
                          SizedBox(width: 4),
                          Text(
                            "NEW BID",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  Spacer(),
                  Text(
                    "Submitted ${_formatTimeAgo(widget.bid.createdAt)}",
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),

              SizedBox(height: 12),

              // Provider info and price
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Provider avatar and info
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildProviderInfo(),
                        SizedBox(height: 8),
                        _buildPriceBenchmark(),
                      ],
                    ),
                  ),

                  SizedBox(width: 16),

                  // Price and availability
                  Expanded(
                    flex: 1,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _buildPriceSection(),
                        SizedBox(height: 8),
                        _buildAvailabilityChip(),
                      ],
                    ),
                  ),
                ],
              ),

              SizedBox(height: 12),

              // Bid message preview
              _buildBidMessagePreview(),

              SizedBox(height: 16),

              // Action buttons
              _buildActionButtons(),
            ],
          ),
        ),

        // Expandable details section
        if (_isExpanded) _buildExpandedDetails(),
      ],
    );
  }

  Widget _buildProviderInfo() {
    return Row(
      children: [
        // Provider avatar
        CircleAvatar(
          radius: 20,
          backgroundColor: Colors.grey[300],
          child: Icon(Icons.person, color: Colors.grey[600]),
        ),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Provider #${widget.bid.providerId.substring(0, 8)}",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              SizedBox(height: 2),
              Row(
                children: [
                  Icon(Icons.star, size: 14, color: Colors.amber),
                  SizedBox(width: 4),
                  Text(
                    "4.8 • 127 reviews",
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPriceBenchmark() {
    final benchmark = widget.bid.priceBenchmark;
    Color benchmarkColor;
    IconData benchmarkIcon;
    String benchmarkText;

    switch (benchmark.toLowerCase()) {
      case 'low':
        benchmarkColor = Colors.green;
        benchmarkIcon = Icons.trending_down;
        benchmarkText = "Great Deal";
        break;
      case 'high':
        benchmarkColor = Colors.red;
        benchmarkIcon = Icons.trending_up;
        benchmarkText = "Premium Price";
        break;
      default:
        benchmarkColor = Colors.orange;
        benchmarkIcon = Icons.check_circle;
        benchmarkText = "Market Rate";
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: benchmarkColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: benchmarkColor.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(benchmarkIcon, size: 14, color: benchmarkColor),
          SizedBox(width: 4),
          Text(
            benchmarkText,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: benchmarkColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          "\$${widget.bid.priceQuote.toInt()}",
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).primaryColor,
          ),
        ),
        if (widget.bid.benchmarkMetadata != null &&
            widget.bid.benchmarkMetadata!['isAIGenerated'] == true)
          Container(
            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              "AI ANALYZED",
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildAvailabilityChip() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.schedule, size: 12, color: Colors.blue),
          SizedBox(width: 4),
          Flexible(
            child: Text(
              widget.bid.availability,
              style: TextStyle(
                fontSize: 11,
                color: Colors.blue,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBidMessagePreview() {
    final message = widget.bid.bidMessage;
    final isLongMessage = message.length > 100;
    final displayMessage = isLongMessage && !_isExpanded
        ? "${message.substring(0, 100)}..."
        : message;

    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.message, size: 14, color: Colors.grey[600]),
              SizedBox(width: 6),
              Text(
                "Provider's Message",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
            ],
          ),
          SizedBox(height: 6),
          Text(
            displayMessage,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[700],
              height: 1.3,
            ),
          ),
          if (isLongMessage)
            GestureDetector(
              onTap: () => setState(() => _isExpanded = !_isExpanded),
              child: Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(
                  _isExpanded ? "Show less" : "Read more",
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).primaryColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: widget.onViewProfile,
            icon: Icon(Icons.person, size: 16),
            label: Text("View Profile"),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.grey[700],
              side: BorderSide(color: Colors.grey[300]!),
            ),
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: widget.isExpired ? null : widget.onAccept,
            icon: Icon(Icons.check, size: 16),
            label: Text("Accept Bid"),
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.isExpired ? Colors.grey : Colors.green,
              foregroundColor: Colors.white,
              elevation: widget.isExpired ? 0 : 2,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildExpandedDetails() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border(
          top: BorderSide(color: Colors.grey[300]!),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Additional Details",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            SizedBox(height: 12),

            // Time remaining if not expired
            if (!widget.bid.isExpired && !widget.isExpired)
              _buildDetailRow(
                Icons.timer,
                "Bid Expires",
                widget.bid.timeRemaining.inMinutes > 0
                    ? "${widget.bid.timeRemaining.inMinutes} minutes remaining"
                    : "Expired",
                Colors.orange,
              ),

            // AI Analysis details if available
            if (widget.bid.benchmarkMetadata != null &&
                widget.bid.benchmarkMetadata!['isAIGenerated'] == true) ...[
              _buildDetailRow(
                Icons.insights,
                "AI Price Analysis",
                "Confidence: ${widget.bid.benchmarkMetadata!['confidenceLevel']?.toUpperCase()}",
                Colors.blue,
              ),
              if (widget.bid.benchmarkMetadata!['aiSuggestedMin'] != null)
                _buildDetailRow(
                  Icons.trending_flat,
                  "AI Suggested Range",
                  "\$${widget.bid.benchmarkMetadata!['aiSuggestedMin']?.toInt()} - \$${widget.bid.benchmarkMetadata!['aiSuggestedMax']?.toInt()}",
                  Colors.purple,
                ),
            ],

            SizedBox(height: 12),

            // Provider stats (mock data for now)
            Row(
              children: [
                _buildStatChip("98% On-time", Icons.schedule, Colors.green),
                SizedBox(width: 8),
                _buildStatChip("5 years exp", Icons.work, Colors.blue),
                SizedBox(width: 8),
                _buildStatChip("Licensed", Icons.verified, Colors.orange),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value, Color color) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Icon(icon, size: 14, color: color),
          ),
          SizedBox(width: 8),
          Text(
            "$label: ",
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(String text, IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimeAgo(DateTime bidTime) {
    final difference = DateTime.now().difference(bidTime);

    if (difference.inMinutes < 1) {
      return "just now";
    } else if (difference.inMinutes < 60) {
      return "${difference.inMinutes} min ago";
    } else if (difference.inHours < 24) {
      return "${difference.inHours} hr ago";
    } else {
      return "${difference.inDays} days ago";
    }
  }
}
