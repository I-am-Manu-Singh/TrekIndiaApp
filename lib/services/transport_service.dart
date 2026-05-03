import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class TransportService {
  // SIMULATED PUBLIC API ENDPOINT (Open Transit Mock)
  static const String _publicApiUrl = 'https://my-json-server.typicode.com/I-am-Manu-Singh/TrekIndiaApp/transport';

  static Future<List<Map<String, dynamic>>> fetchTransportData({
    required String type, // 'bus' or 'train'
    required String from,
    required String to,
    required DateTime date,
  }) async {
    try {
      // 1. ATTEMPT PUBLIC API FETCH
      try {
        final response = await http.get(Uri.parse('$_publicApiUrl?type=$type&origin=$from&destination=$to'))
            .timeout(const Duration(seconds: 3));
        
        if (response.statusCode == 200) {
          final List dynamicData = jsonDecode(response.body);
          if (dynamicData.isNotEmpty) {
            return dynamicData.map((item) => _processItem(item, date)).toList();
          }
        }
      } catch (e) {
        debugPrint('PUBLIC API UNREACHABLE: $e. Falling back to Supabase/Mock...');
      }

      // 2. FALLBACK TO SUPABASE DB
      final client = Supabase.instance.client;
      final dbResponse = await client
          .from('transports')
          .select()
          .eq('type', type)
          .ilike('origin', '%$from%')
          .ilike('destination', '%$to%');
      
      final List data = dbResponse as List;
      
      if (data.isNotEmpty) {
        return data.map((item) => _processItem(item, date)).toList();
      }

      // 3. FINAL FALLBACK TO DYNAMIC MOCK (Realistic)
      return _generateMockData(type, from, to, date);
    } catch (e) {
      debugPrint('TRANSPORT SERVICE TOTAL FAILURE: $e');
      return _generateMockData(type, from, to, date);
    }
  }

  static Map<String, dynamic> _processItem(dynamic item, DateTime date) {
    return {
      'id': item['id']?.toString() ?? 'ID-${item['name']}',
      'name': item['name'],
      'time': '${item['departure_time']} - ${item['arrival_time']}',
      'price': double.tryParse(item['price'].toString()) ?? 0.0,
      'type': (item['type'] ?? 'Standard').toString().toUpperCase(),
      'seats': item['seats_available'] ?? 20,
      'rating': (item['rating'] ?? 4.5).toString(),
      'amenities': item['amenities'] is List ? List<String>.from(item['amenities']) : ['AC', 'WiFi'],
      'from': item['origin'] ?? 'N/A',
      'to': item['destination'] ?? 'N/A',
      'date': date.toIso8601String(),
    };
  }

  static List<Map<String, dynamic>> _generateMockData(String type, String from, String to, DateTime date) {
    final bool isBus = type == 'bus';
    final List<String> operators = isBus 
      ? ['Zingbus', 'IntrCity', 'Laxmi', 'HRTC', 'Vistara']
      : ['Shatabdi', 'Rajdhani', 'Duronto', 'Himalayan Queen', 'Garib Rath'];

    final List<String> suffixes = isBus 
      ? ['Premium', 'Grand', 'Sleeper', 'Express', 'Superfast']
      : ['Express', 'Superfast', 'Special', 'Links', 'Connect'];

    return List.generate(6, (i) {
      final basePrice = isBus ? 650 : 950;
      final op = operators[i % operators.length];
      final suffix = suffixes[(i + from.length) % suffixes.length];
      
      return {
        'id': 'API-MOCK-${type[0].toUpperCase()}-$i',
        'name': '$op $suffix ($from-$to)',
        'time': '${05 + i}:00 AM - ${17 + i}:00 PM',
        'price': (basePrice + (i * 125) + (from.length * 2)).toDouble(),
        'type': isBus ? 'Luxury Multi-Axle' : 'AC Chair/Sleeper',
        'seats': 5 + (i * 3),
        'rating': (4.0 + (i % 10) / 10).toStringAsFixed(1),
        'amenities': isBus ? ['WiFi', 'AC', 'Water'] : ['Food', 'AC', 'Charging'],
        'from': from,
        'to': to,
        'date': date.toIso8601String(),
      };
    });
  }
}
