import 'package:flutter/material.dart';

class MarketPriceGuidanceCard extends StatelessWidget {
  final Map<String, dynamic>? aiPriceEstimation;
  final String serviceCategory;

  const MarketPriceGuidanceCard({
    Key? key,
    this.aiPriceEstimation,
    required this.serviceCategory,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (aiPriceEstimation == null || aiPriceEstimation!.isEmpty) {
      return _buildFallbackGuidance();
    }

    final suggestedRange = aiPriceEstimation!['suggestedRange'] as Map<String, dynamic>?;
    final marketAverage = (aiPriceEstimation!['marketAverage'] ?? 0).toDouble();
    final confidenceLevel = aiPriceEstimation!['confidenceLevel'] ?? 'medium';
    final pricingFactors = List<String>.from(aiPriceEstimation!['pricingFactors'] ?? []);

    if (suggestedRange == null) {
      return _buildFallbackGuidance();
    }

    return Card(
      margin: EdgeInsets.symmetric(vertical: 8),
      elevation: 3,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.insights, color: Colors.blue, size: 24),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "AI Market Price Guidance",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                _buildConfidenceBadge(confidenceLevel),
              ],
            ),
            
            SizedBox(height: 12),
            
            // Price range visualization
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue.withOpacity(0.1), Colors.blue.withOpacity(0.05)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildPriceInfo(
                        "Suggested Range",
                        "\$${suggestedRange['min']?.toInt()} - \$${suggestedRange['max']?.toInt()}",
                        Icons.trending_flat,
                        Colors.blue,
                      ),
                      Container(
                        width: 1,
                        height: 40,
                        color: Colors.grey[300],
                      ),
                      _buildPriceInfo(
                        "Market Average",
                        "\$${marketAverage.toInt()}",
                        Icons.bar_chart,
                        Colors.green,
                      ),
                    ],
                  ),
                  
                  SizedBox(height: 12),
                  
                  // Visual price bar
                  _buildPriceRangeBar(
                    context,
                    suggestedRange['min']?.toDouble() ?? 0,
                    suggestedRange['max']?.toDouble() ?? 0,
                    marketAverage,
                  ),
                ],
              ),
            ),
            
            // Pricing factors that influenced AI estimation
            if (pricingFactors.isNotEmpty) ...[
              SizedBox(height: 16),
              Text(
                "Pricing factors considered:",
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
              SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: pricingFactors.map((factor) => Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.orange.withOpacity(0.5)),
                  ),
                  child: Text(
                    _formatPricingFactor(factor),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.orange[800],
                    ),
                  ),
                )).toList(),
              ),
            ],
            
            SizedBox(height: 12),
            
            // Guidance tip
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.lightbulb_outline, color: Colors.green[700], size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Pricing within the suggested range increases your chances of being selected",
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.green[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFallbackGuidance() {
    return Card(
      margin: EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: Colors.orange),
                SizedBox(width: 8),
                Text(
                  "Pricing Guidance",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            Text(
              "AI price estimation is not available for this request. Consider market rates for ${serviceCategory.toLowerCase()} services in your area.",
              style: TextStyle(color: Colors.grey[600]),
            ),
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.tips_and_updates, color: Colors.blue, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Consider your costs, time, and local market rates when pricing",
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue[700],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfidenceBadge(String confidenceLevel) {
    Color badgeColor;
    String label;
    
    switch (confidenceLevel.toLowerCase()) {
      case 'high':
        badgeColor = Colors.green;
        label = "HIGH CONFIDENCE";
        break;
      case 'medium':
        badgeColor = Colors.orange;
        label = "MEDIUM CONFIDENCE";
        break;
      default:
        badgeColor = Colors.grey;
        label = "LOW CONFIDENCE";
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: badgeColor.withOpacity(0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: badgeColor,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildPriceInfo(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildPriceRangeBar(BuildContext context, double minPrice, double maxPrice, double averagePrice) {
    if (minPrice >= maxPrice) return SizedBox.shrink();
    
    final range = maxPrice - minPrice;
    final averagePosition = (averagePrice - minPrice) / range;
    
    return Column(
      children: [
        Container(
          height: 8,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
          ),
          child: Stack(
            children: [
              // Background bar
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              // Price range bar
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.green, Colors.orange, Colors.red],
                    stops: [0.0, 0.5, 1.0],
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              // Average marker
              if (averagePosition >= 0 && averagePosition <= 1)
                Positioned(
                  left: MediaQuery.of(context).size.width * 0.7 * averagePosition - 6,
                  top: -2,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.green, width: 2),
                    ),
                  ),
                ),
            ],
          ),
        ),
        SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Lower",
              style: TextStyle(fontSize: 10, color: Colors.grey[600]),
            ),
            Text(
              "Market Rate",
              style: TextStyle(fontSize: 10, color: Colors.grey[600]),
            ),
            Text(
              "Higher",
              style: TextStyle(fontSize: 10, color: Colors.grey[600]),
            ),
          ],
        ),
      ],
    );
  }

  String _formatPricingFactor(String factor) {
    return factor
        .replaceAll('_', ' ')
        .split(' ')
        .map((word) => word.isEmpty ? '' : word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }
}
