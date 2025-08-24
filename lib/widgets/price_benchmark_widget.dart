import 'package:flutter/material.dart';
import '../services/price_benchmark_service.dart';

class PriceBenchmarkWidget extends StatefulWidget {
  final String requestId;
  final Function(double, Map<String, dynamic>) onPriceChanged;
  final String? initialPrice;

  const PriceBenchmarkWidget({
    Key? key,
    required this.requestId,
    required this.onPriceChanged,
    this.initialPrice,
  }) : super(key: key);

  @override
  _PriceBenchmarkWidgetState createState() => _PriceBenchmarkWidgetState();
}

class _PriceBenchmarkWidgetState extends State<PriceBenchmarkWidget> {
  final TextEditingController _priceController = TextEditingController();
  Map<String, dynamic>? _currentBenchmark;
  bool _isCalculating = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialPrice != null) {
      _priceController.text = widget.initialPrice!;
      _calculateBenchmark(widget.initialPrice!);
    }
  }

  @override
  void dispose() {
    _priceController.dispose();
    super.dispose();
  }

  void _calculateBenchmark(String value) async {
    if (value.isEmpty) {
      setState(() {
        _currentBenchmark = null;
        _isCalculating = false;
      });
      return;
    }

    final price = double.tryParse(value);
    if (price == null || price <= 0) {
      setState(() {
        _currentBenchmark = null;
        _isCalculating = false;
      });
      return;
    }

    setState(() => _isCalculating = true);

    try {
      final benchmark = await PriceBenchmarkService.calculateBenchmark(
        requestId: widget.requestId,
        proposedPrice: price,
      );
      
      setState(() {
        _currentBenchmark = benchmark;
        _isCalculating = false;
      });
      
      widget.onPriceChanged(price, benchmark);
    } catch (e) {
      setState(() {
        _currentBenchmark = null;
        _isCalculating = false;
      });
      print('Error calculating benchmark: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _priceController,
          keyboardType: TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Your Price Quote (\$)',
            hintText: 'Enter your price',
            prefixIcon: Icon(Icons.attach_money),
            suffixIcon: _isCalculating 
                ? Container(
                    width: 20,
                    height: 20,
                    padding: EdgeInsets.all(12),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : _currentBenchmark != null 
                    ? Icon(
                        _currentBenchmark!['icon'],
                        color: _currentBenchmark!['color'],
                      )
                    : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          onChanged: _calculateBenchmark,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter a price';
            }
            final price = double.tryParse(value);
            if (price == null || price <= 0) {
              return 'Please enter a valid price';
            }
            return null;
          },
        ),
        
        SizedBox(height: 12),
        
        // Benchmark feedback
        AnimatedContainer(
          duration: Duration(milliseconds: 300),
          height: _currentBenchmark != null ? null : 0,
          child: _currentBenchmark != null ? _buildBenchmarkFeedback() : null,
        ),
      ],
    );
  }

  Widget _buildBenchmarkFeedback() {
    if (_currentBenchmark == null) return SizedBox.shrink();

    final benchmark = _currentBenchmark!;
    final displayData = PriceBenchmarkService.getBenchmarkDisplayData(benchmark);

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: benchmark['color'].withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: benchmark['color'].withOpacity(0.3),
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: benchmark['color'].withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  benchmark['icon'],
                  color: benchmark['color'],
                  size: 20,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayData['title'],
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: benchmark['color'],
                      ),
                    ),
                    Text(
                      benchmark['message'],
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                displayData['emoji'],
                style: TextStyle(fontSize: 24),
              ),
            ],
          ),
          
          SizedBox(height: 12),
          
          // Price comparison details
          if (benchmark['isAIGenerated'] == true) ...[
            _buildPriceComparisonRow(
              'AI Suggested Range',
              '\$${benchmark['aiSuggestedMin']?.toInt()} - \$${benchmark['aiSuggestedMax']?.toInt()}',
              Icons.smart_toy,
              Colors.blue,
            ),
            if (benchmark['aiMarketAverage'] != null)
              _buildPriceComparisonRow(
                'Market Average',
                '\$${benchmark['aiMarketAverage']?.toInt()}',
                Icons.trending_flat,
                Colors.green,
              ),
          ] else ...[
            if (benchmark['historicalMin'] != null && benchmark['historicalMax'] != null)
              _buildPriceComparisonRow(
                'Typical Range',
                '\$${benchmark['historicalMin']?.toInt()} - \$${benchmark['historicalMax']?.toInt()}',
                Icons.history,
                Colors.orange,
              ),
            if (benchmark['historicalAverage'] != null)
              _buildPriceComparisonRow(
                'Historical Average',
                '\$${benchmark['historicalAverage']?.toInt()}',
                Icons.bar_chart,
                Colors.purple,
              ),
          ],
          
          // Percentage difference
          if (benchmark['percentageDiff'] != null && benchmark['percentageDiff'] != 0) ...[
            SizedBox(height: 8),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _getPercentageDiffColor(benchmark['percentageDiff']).withOpacity(0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${benchmark['percentageDiff'] > 0 ? '+' : ''}${benchmark['percentageDiff']}% vs market average',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _getPercentageDiffColor(benchmark['percentageDiff']),
                ),
              ),
            ),
          ],
          
          SizedBox(height: 8),
          
          // Confidence level
          Row(
            children: [
              Icon(
                Icons.verified,
                size: 14,
                color: PriceBenchmarkService.getConfidenceColor(benchmark['confidenceLevel']),
              ),
              SizedBox(width: 4),
              Text(
                '${benchmark['confidenceLevel']?.toUpperCase()} confidence • ${displayData['subtitle']}',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPriceComparisonRow(String label, String value, IconData icon, Color color) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Color _getPercentageDiffColor(int percentageDiff) {
    if (percentageDiff > 20) return Colors.red;
    if (percentageDiff > 10) return Colors.orange;
    if (percentageDiff > -10) return Colors.green;
    if (percentageDiff > -20) return Colors.blue;
    return Colors.purple;
  }
}
