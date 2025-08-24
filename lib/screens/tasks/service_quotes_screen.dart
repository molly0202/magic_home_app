import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/user_request.dart';
import '../../models/service_bid.dart';
import '../../services/user_task_service.dart';

class ServiceQuotesScreen extends StatefulWidget {
  final UserRequest task;
  final User user;

  const ServiceQuotesScreen({
    Key? key,
    required this.task,
    required this.user,
  }) : super(key: key);

  @override
  State<ServiceQuotesScreen> createState() => _ServiceQuotesScreenState();
}

class _ServiceQuotesScreenState extends State<ServiceQuotesScreen> {
  bool _isAcceptingBid = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Service Quotes',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Price Range Estimation
            _buildPriceRangeCard(),

            // Quotes List
            _buildQuotesSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceRangeCard() {
    if (widget.task.aiPriceEstimation == null) {
      return const SizedBox.shrink();
    }

    final estimation = widget.task.aiPriceEstimation!;
    final suggestedRange = estimation['suggestedRange'];
    
    if (suggestedRange == null) {
      return const SizedBox.shrink();
    }

    final minPrice = (suggestedRange['min'] ?? 0).toDouble();
    final maxPrice = (suggestedRange['max'] ?? 0).toDouble();
    final marketAverage = (estimation['marketAverage'] ?? ((minPrice + maxPrice) / 2)).toDouble();

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Estimated Price Range',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFFFBB04C),
            ),
          ),
          const SizedBox(height: 20),
          
          // Price range visualization
          Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    // Price range bar
                    Container(
                      height: 8,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        gradient: const LinearGradient(
                          colors: [
                            Colors.green,
                            Color(0xFFFBB04C),
                            Colors.red,
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    // Price labels
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '\$${minPrice.toInt()}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                        Column(
                          children: [
                            const Icon(
                              Icons.keyboard_arrow_up,
                              color: Color(0xFFFBB04C),
                              size: 20,
                            ),
                            Text(
                              '\$${marketAverage.toInt()}',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFFBB04C),
                              ),
                            ),
                            const Text(
                              'Market Average',
                              style: TextStyle(
                                fontSize: 10,
                                color: Color(0xFFFBB04C),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '\$${maxPrice.toInt()}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuotesSection() {
    print('🔍 SERVICE_QUOTES: Loading bids for requestId: ${widget.task.requestId}');
    return StreamBuilder<List<ServiceBid>>(
      stream: UserTaskService.getBidsForRequest(widget.task.requestId ?? ''),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            margin: const EdgeInsets.all(16),
            child: const Center(
              child: CircularProgressIndicator(
                color: Color(0xFFFBB04C),
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          print('❌ SERVICE_QUOTES: Error loading bids: ${snapshot.error}');
          return Container(
            margin: const EdgeInsets.all(16),
            child: Center(
              child: Column(
                children: [
                  Text(
                    'Error loading quotes',
                    style: TextStyle(
                      color: Colors.red[600],
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'RequestID: ${widget.task.requestId}',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    'Error: ${snapshot.error}',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final bids = snapshot.data ?? [];

        if (bids.isEmpty) {
          return Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.hourglass_empty,
                    size: 48,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Waiting for Quotes',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Providers are reviewing your request and will submit quotes soon.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return Column(
          children: bids.map((bid) => _buildQuoteCard(bid)).toList(),
        );
      },
    );
  }

  Widget _buildQuoteCard(ServiceBid bid) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: UserTaskService.getProviderDetails(bid.providerId),
      builder: (context, providerSnapshot) {
        final provider = providerSnapshot.data;
        final companyName = provider?['company'] ?? provider?['companyName'] ?? 'Provider';
        final reviewCount = provider?['thumbs_up_count'] ?? 12;
        final distance = '5 miles away'; // This would come from location calculation

        // Calculate match percentage (this would be more sophisticated in real app)
        final matchPercentage = _calculateMatchPercentage(bid, provider);
        
        // Determine price benchmark
        final priceBenchmark = _getPriceBenchmark(bid.priceQuote);

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: bid.bidStatus == 'accepted' 
                ? Border.all(color: Colors.green, width: 2)
                : null,
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              // Provider header with match percentage
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: bid.bidStatus == 'accepted' 
                      ? Colors.green.withOpacity(0.1)
                      : Colors.grey[50],
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                ),
                child: Row(
                  children: [
                    // Provider avatar
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFBB04C),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Center(
                        child: Text(
                          companyName.substring(0, 1).toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    
                    // Provider info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            companyName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '$distance • $reviewCount reviews',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Match percentage
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$matchPercentage%',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Text(
                            'Excellent Match',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              // Quote details
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Price and benchmark
                    Row(
                      children: [
                        Text(
                          'Quote',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '\$${bid.priceQuote.toInt()}',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: priceBenchmark['color'].withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            priceBenchmark['label'],
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: priceBenchmark['color'],
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 12),
                    
                    // Recommended by network
                    if (provider != null) ...[
                      Row(
                        children: [
                          Text(
                            'Recommended by 4 people in your network',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Avatar stack
                          SizedBox(
                            width: 80,
                            height: 20,
                            child: Stack(
                              children: List.generate(4, (index) {
                                return Positioned(
                                  left: index * 15.0,
                                  child: Container(
                                    width: 20,
                                    height: 20,
                                    decoration: BoxDecoration(
                                      color: Colors.grey[300],
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 1,
                                      ),
                                    ),
                                    child: Center(
                                      child: Text(
                                        String.fromCharCode(65 + index),
                                        style: const TextStyle(
                                          fontSize: 8,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],
                    
                    // Tags
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        _buildTag('Friend Referral', Colors.blue),
                        _buildTag('Perfect Match', Colors.green),
                        _buildTag('Top Rated', const Color(0xFFFBB04C)),
                      ],
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Availability and message
                    if (bid.availability.isNotEmpty) ...[
                      Text(
                        'Availability: ${bid.availability}',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    
                    if (bid.bidMessage.isNotEmpty) ...[
                      Text(
                        bid.bidMessage,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[700],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    
                    // Action button
                    if (bid.bidStatus == 'pending' && widget.task.status != 'assigned') ...[
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isAcceptingBid ? null : () => _acceptBid(bid),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: _isAcceptingBid
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text(
                                  'Accept Quote',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                    ] else if (bid.bidStatus == 'accepted') ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.check_circle,
                              color: Colors.green,
                              size: 20,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Quote Accepted',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  int _calculateMatchPercentage(ServiceBid bid, Map<String, dynamic>? provider) {
    // This would be a more sophisticated calculation in a real app
    // For now, return a mock percentage based on various factors
    return 98;
  }

  Map<String, dynamic> _getPriceBenchmark(double price) {
    if (widget.task.aiPriceEstimation == null) {
      return {
        'label': 'Normal',
        'color': const Color(0xFFFBB04C),
      };
    }

    final estimation = widget.task.aiPriceEstimation!;
    final suggestedRange = estimation['suggestedRange'];
    
    if (suggestedRange == null) {
      return {
        'label': 'Normal',
        'color': const Color(0xFFFBB04C),
      };
    }

    final minPrice = (suggestedRange['min'] ?? 0).toDouble();
    final maxPrice = (suggestedRange['max'] ?? 0).toDouble();

    if (price < minPrice) {
      return {
        'label': 'Lower',
        'color': Colors.green,
      };
    } else if (price > maxPrice) {
      return {
        'label': 'Higher',
        'color': Colors.red,
      };
    } else {
      return {
        'label': 'Normal',
        'color': const Color(0xFFFBB04C),
      };
    }
  }

  Future<void> _acceptBid(ServiceBid bid) async {
    setState(() {
      _isAcceptingBid = true;
    });

    try {
      final success = await UserTaskService.acceptBid(bid.bidId!, widget.user.uid);
      
      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Quote accepted successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          
          // Navigate back to task detail
          Navigator.pop(context);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to accept quote. Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isAcceptingBid = false;
        });
      }
    }
  }
}
