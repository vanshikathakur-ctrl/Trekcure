import 'dart:convert';

import 'package:http/http.dart' as http;

class TrekCureApiService {
  // ============================================================
  // BACKEND URLs
  // ============================================================

  // FastAPI Digital ID API
  static const String baseUrl =
      'https://trekcure-digital-id.onrender.com';

  // FastAPI Weather API
  static const String weatherBaseUrl =
      'https://trekcure-weather.onrender.com';

  // ============================================================
  // CREATE DIGITAL ID
  // ============================================================

  static Future<Map<String, dynamic>> createDigitalId({
    required String userId,
    required String name,
    required int age,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/create-digital-id'),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'user_id': userId,
        'name': name,
        'age': age,
      }),
    );

    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(
        jsonDecode(response.body),
      );
    }

    throw Exception(
      'Failed to create Digital ID: ${response.body}',
    );
  }

  // ============================================================
  // VERIFY DIGITAL ID
  // ============================================================

  static Future<Map<String, dynamic>> verifyDigitalId({
    required String userId,
    required Map<String, dynamic> credential,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/verify-digital-id'),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'user_id': userId,
        'credential': credential,
      }),
    );

    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(
        jsonDecode(response.body),
      );
    }

    throw Exception(
      'Failed to verify Digital ID: ${response.body}',
    );
  }

  // ============================================================
  // GET WEATHER
  // ============================================================

  static Future<Map<String, dynamic>> getWeather({
    required double latitude,
    required double longitude,
  }) async {
    final uri = Uri.parse(
      '$weatherBaseUrl/weather'
      '?latitude=$latitude'
      '&longitude=$longitude',
    );

    final response = await http.get(uri);

    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(
        jsonDecode(response.body),
      );
    }

    throw Exception(
      'Failed to load weather: ${response.body}',
    );
  }
}