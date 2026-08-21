import 'dart:convert';

import 'package:http/http.dart' as http;

class ApiService {
  // Android Emulator → Windows computer
  static const String baseUrl = 'http://10.0.2.2:8000';

  static Future<Map<String, dynamic>> createDigitalId({
    required String userId,
    required String name,
    required int age,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/create-digital-id'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'user_id': userId, 'name': name, 'age': age}),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to create Digital ID: ${response.body}');
    }
  }

  static Future<Map<String, dynamic>> verifyDigitalId({
    required String userId,
    required Map<String, dynamic> credential,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/verify-digital-id'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'user_id': userId, 'credential': credential}),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to verify Digital ID: ${response.body}');
    }
  }
}
