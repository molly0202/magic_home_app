import 'dart:convert';
import 'dart:math' as Math;
import 'package:http/http.dart' as http;
import '../config/secrets.dart';

class GoogleMapsService {
  static const String _baseUrl = 'https://maps.googleapis.com/maps/api';
  
  /// Calculate real distance between two addresses using Google Maps Distance Matrix API
  static Future<Map<String, dynamic>> calculateDistance({
    required String originAddress,
    required String destinationAddress,
  }) async {
    try {
      print('🗺️ Calculating distance: $originAddress → $destinationAddress');
      
      final url = Uri.parse(
        '$_baseUrl/distancematrix/json'
        '?origins=${Uri.encodeComponent(originAddress)}'
        '&destinations=${Uri.encodeComponent(destinationAddress)}'
        '&units=metric'
        '&key=${Secrets.googleMapsApiKey}'
      );
      
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['status'] == 'OK' && 
            data['rows'] != null && 
            data['rows'].isNotEmpty &&
            data['rows'][0]['elements'] != null &&
            data['rows'][0]['elements'].isNotEmpty) {
          
          final element = data['rows'][0]['elements'][0];
          
          if (element['status'] == 'OK') {
            final distanceText = element['distance']['text'];
            final distanceValue = element['distance']['value']; // meters
            final durationText = element['duration']['text'];
            final durationValue = element['duration']['value']; // seconds
            
            final distanceKm = distanceValue / 1000.0;
            
            print('✅ Distance calculated: $distanceText ($distanceKm km) - $durationText');
            
            return {
              'success': true,
              'distanceKm': distanceKm,
              'distanceText': distanceText,
              'durationText': durationText,
              'durationMinutes': (durationValue / 60).round(),
            };
          } else {
            print('❌ Distance calculation failed: ${element['status']}');
            return _fallbackDistance();
          }
        } else {
          print('❌ Invalid response from Google Maps: ${data['status']}');
          return _fallbackDistance();
        }
      } else {
        print('❌ HTTP error: ${response.statusCode}');
        return _fallbackDistance();
      }
      
    } catch (e) {
      print('❌ Error calculating distance: $e');
      return _fallbackDistance();
    }
  }
  
  /// Geocode an address to get latitude and longitude
  static Future<Map<String, dynamic>> geocodeAddress(String address) async {
    try {
      print('🌍 Geocoding address: $address');
      
      final url = Uri.parse(
        '$_baseUrl/geocode/json'
        '?address=${Uri.encodeComponent(address)}'
        '&key=${Secrets.googleMapsApiKey}'
      );
      
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['status'] == 'OK' && 
            data['results'] != null && 
            data['results'].isNotEmpty) {
          
          final result = data['results'][0];
          final location = result['geometry']['location'];
          final formattedAddress = result['formatted_address'];
          
          print('✅ Geocoded: $formattedAddress (${location['lat']}, ${location['lng']})');
          
          return {
            'success': true,
            'lat': location['lat'],
            'lng': location['lng'],
            'formatted_address': formattedAddress,
          };
        } else {
          print('❌ Geocoding failed: ${data['status']}');
          return {'success': false};
        }
      } else {
        print('❌ HTTP error: ${response.statusCode}');
        return {'success': false};
      }
      
    } catch (e) {
      print('❌ Error geocoding address: $e');
      return {'success': false};
    }
  }
  
  /// Calculate distance between two coordinates using Haversine formula
  static double calculateDistanceHaversine(
    double lat1, double lon1, 
    double lat2, double lon2
  ) {
    const double earthRadius = 6371; // km
    
    final dLat = _degreesToRadians(lat2 - lat1);
    final dLon = _degreesToRadians(lon2 - lon1);
    
    final a = 
        Math.sin(dLat / 2) * Math.sin(dLat / 2) +
        Math.cos(_degreesToRadians(lat1)) * Math.cos(_degreesToRadians(lat2)) *
        Math.sin(dLon / 2) * Math.sin(dLon / 2);
    
    final c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    
    return earthRadius * c;
  }
  
  static double _degreesToRadians(double degrees) {
    return degrees * (Math.pi / 180);
  }
  
  /// Fallback distance calculation for when API fails
  static Map<String, dynamic> _fallbackDistance() {
    // Return a reasonable default for Seattle area
    return {
      'success': false,
      'distanceKm': 8.5,
      'distanceText': '8.5 km (estimated)',
      'durationText': '15-20 min (estimated)',
      'durationMinutes': 18,
    };
  }
} 