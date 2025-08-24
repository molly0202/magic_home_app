import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/user_request.dart';

class PriceBenchmarkService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Calculate price benchmark using AI estimation or fallback to historical data
  static Future<Map<String, dynamic>> calculateBenchmark({
    required String requestId,
    required double proposedPrice,
  }) async {
    try {
      // Get UserRequest to access AI price estimation
      final userRequest = await _getUserRequest(requestId);
      final aiEstimation = userRequest.aiPriceEstimation;
      
      if (aiEstimation != null && aiEstimation.isNotEmpty) {
        // Use AI-generated price range (preferred method)
        return _calculateWithAIEstimation(proposedPrice, aiEstimation);
      } else {
        // Fallback to historical market data
        return await _calculateWithHistoricalData(
          proposedPrice, 
          userRequest.serviceCategory,
        );
      }
    } catch (e) {
      print('Error calculating price benchmark: $e');
      // Return neutral benchmark on error
      return _createNeutralBenchmark(proposedPrice);
    }
  }

  /// Get UserRequest from Firestore
  static Future<UserRequest> _getUserRequest(String requestId) async {
    final doc = await _firestore.collection('user_requests').doc(requestId).get();
    
    if (!doc.exists) {
      throw Exception('UserRequest not found for ID: $requestId');
    }
    
    return UserRequest.fromFirestore(doc);
  }

  /// Calculate benchmark using AI-generated price estimation
  static Map<String, dynamic> _calculateWithAIEstimation(
    double proposedPrice, 
    Map<String, dynamic> aiEstimation,
  ) {
    try {
      final suggestedRange = aiEstimation['suggestedRange'] as Map<String, dynamic>?;
      final marketAverage = (aiEstimation['marketAverage'] ?? 0).toDouble();
      final confidenceLevel = aiEstimation['confidenceLevel'] ?? 'medium';
      final pricingFactors = List<String>.from(aiEstimation['pricingFactors'] ?? []);
      
      if (suggestedRange == null) {
        return _createNeutralBenchmark(proposedPrice);
      }
      
      final minPrice = (suggestedRange['min'] ?? 0).toDouble();
      final maxPrice = (suggestedRange['max'] ?? 0).toDouble();
      
      // Validate AI data
      if (minPrice <= 0 || maxPrice <= 0 || minPrice >= maxPrice) {
        return _createNeutralBenchmark(proposedPrice);
      }
      
      String benchmark;
      String message;
      Color indicatorColor;
      IconData icon;
      
      // Determine benchmark category
      if (proposedPrice < minPrice) {
        final percentBelow = ((minPrice - proposedPrice) / minPrice * 100).round();
        benchmark = "low";
        message = "$percentBelow% below AI suggested range";
        indicatorColor = Colors.green;
        icon = Icons.trending_down;
      } else if (proposedPrice <= maxPrice) {
        benchmark = "normal";
        message = "Within AI suggested range";
        indicatorColor = Colors.orange;
        icon = Icons.check_circle;
      } else {
        final percentAbove = ((proposedPrice - maxPrice) / maxPrice * 100).round();
        benchmark = "high";
        message = "$percentAbove% above AI suggested range";
        indicatorColor = Colors.red;
        icon = Icons.trending_up;
      }
      
      // Calculate percentage difference from market average
      final percentageDiff = marketAverage > 0 
          ? ((proposedPrice - marketAverage) / marketAverage * 100).round()
          : 0;
      
      return {
        'benchmark': benchmark,
        'message': message,
        'color': indicatorColor,
        'icon': icon,
        'aiSuggestedMin': minPrice,
        'aiSuggestedMax': maxPrice,
        'aiMarketAverage': marketAverage,
        'percentageDiff': percentageDiff,
        'confidenceLevel': confidenceLevel,
        'pricingFactors': pricingFactors,
        'isAIGenerated': true,
        'dataSource': 'AI Estimation',
        'generatedAt': aiEstimation['generatedAt'],
        'aiModel': aiEstimation['aiModel'] ?? 'Unknown',
      };
    } catch (e) {
      print('Error processing AI estimation: $e');
      return _createNeutralBenchmark(proposedPrice);
    }
  }

  /// Fallback: Calculate benchmark using historical market data
  static Future<Map<String, dynamic>> _calculateWithHistoricalData(
    double proposedPrice,
    String serviceCategory,
  ) async {
    try {
      // Query historical service requests for this category
      final querySnapshot = await _firestore
          .collection('user_requests')
          .where('serviceCategory', isEqualTo: serviceCategory)
          .where('status', isEqualTo: 'completed')
          .orderBy('createdAt', descending: true)
          .limit(50) // Last 50 completed requests
          .get();
      
      if (querySnapshot.docs.isEmpty) {
        return _createNeutralBenchmark(proposedPrice, 
            dataSource: 'Insufficient historical data');
      }
      
      // Extract completed pricing data (this would need actual pricing data)
      // For now, create sample historical ranges based on category
      final historicalRange = _getHistoricalRange(serviceCategory);
      
      String benchmark;
      String message;
      Color indicatorColor;
      IconData icon;
      
      final minPrice = historicalRange['min'] ?? 80.0;
      final maxPrice = historicalRange['max'] ?? 200.0;
      final marketAverage = historicalRange['average'] ?? 140.0;
      
      if (proposedPrice < minPrice) {
        benchmark = "low";
        message = "Below typical market rate";
        indicatorColor = Colors.green;
        icon = Icons.trending_down;
      } else if (proposedPrice <= maxPrice) {
        benchmark = "normal";
        message = "Within typical market range";
        indicatorColor = Colors.orange;
        icon = Icons.check_circle;
      } else {
        benchmark = "high";
        message = "Above typical market rate";
        indicatorColor = Colors.red;
        icon = Icons.trending_up;
      }
      
      final percentageDiff = ((proposedPrice - marketAverage) / marketAverage * 100).round();
      
      return {
        'benchmark': benchmark,
        'message': message,
        'color': indicatorColor,
        'icon': icon,
        'historicalMin': minPrice,
        'historicalMax': maxPrice,
        'historicalAverage': marketAverage,
        'percentageDiff': percentageDiff,
        'sampleSize': querySnapshot.docs.length,
        'isAIGenerated': false,
        'dataSource': 'Historical Market Data',
        'confidenceLevel': 'medium',
      };
    } catch (e) {
      print('Error calculating historical benchmark: $e');
      return _createNeutralBenchmark(proposedPrice, 
          dataSource: 'Historical data unavailable');
    }
  }

  /// Get historical price range for service category (placeholder implementation)
  static Map<String, double> _getHistoricalRange(String serviceCategory) {
    // TODO: Replace with actual historical pricing analysis
    // This is a placeholder implementation
    final Map<String, Map<String, double>> categoryRanges = {
      'plumbing': {'min': 80.0, 'max': 200.0, 'average': 140.0},
      'electrical': {'min': 100.0, 'max': 250.0, 'average': 175.0},
      'hvac': {'min': 120.0, 'max': 300.0, 'average': 210.0},
      'cleaning': {'min': 50.0, 'max': 150.0, 'average': 100.0},
      'handyman': {'min': 60.0, 'max': 180.0, 'average': 120.0},
      'landscaping': {'min': 70.0, 'max': 220.0, 'average': 145.0},
    };
    
    return categoryRanges[serviceCategory.toLowerCase()] ?? 
           {'min': 80.0, 'max': 200.0, 'average': 140.0};
  }

  /// Create neutral benchmark when no data is available
  static Map<String, dynamic> _createNeutralBenchmark(
    double proposedPrice, {
    String dataSource = 'Insufficient data',
  }) {
    return {
      'benchmark': 'normal',
      'message': 'Price assessment unavailable',
      'color': Colors.grey,
      'icon': Icons.help_outline,
      'proposedPrice': proposedPrice,
      'percentageDiff': 0,
      'isAIGenerated': false,
      'dataSource': dataSource,
      'confidenceLevel': 'low',
    };
  }

  /// Get benchmark display widget data
  static Map<String, dynamic> getBenchmarkDisplayData(
    Map<String, dynamic> benchmark,
  ) {
    final benchmarkType = benchmark['benchmark'] as String;
    final isAIGenerated = benchmark['isAIGenerated'] as bool? ?? false;
    
    String displayTitle;
    String displaySubtitle;
    
    if (isAIGenerated) {
      displayTitle = "AI Price Analysis";
      displaySubtitle = "Based on ${benchmark['aiModel']}";
    } else {
      displayTitle = "Market Analysis";
      displaySubtitle = benchmark['dataSource'] ?? 'Historical data';
    }
    
    // Get benchmark emoji
    String emoji;
    switch (benchmarkType) {
      case 'low':
        emoji = '💰'; // Money bag for good deal
        break;
      case 'high':
        emoji = '💸'; // Flying money for expensive
        break;
      default:
        emoji = '📊'; // Chart for normal/neutral
    }
    
    return {
      'title': displayTitle,
      'subtitle': displaySubtitle,
      'emoji': emoji,
      'color': benchmark['color'],
      'icon': benchmark['icon'],
      'message': benchmark['message'],
      'confidenceLevel': benchmark['confidenceLevel'],
    };
  }

  /// Format price for display
  static String formatPrice(double price) {
    if (price >= 1000) {
      return '\$${(price / 1000).toStringAsFixed(1)}k';
    }
    return '\$${price.toStringAsFixed(0)}';
  }

  /// Get confidence level color
  static Color getConfidenceColor(String confidenceLevel) {
    switch (confidenceLevel.toLowerCase()) {
      case 'high':
        return Colors.green;
      case 'medium':
        return Colors.orange;
      case 'low':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
