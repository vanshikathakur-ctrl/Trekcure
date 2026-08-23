import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/gemini_config.dart';

class GeminiService {
  GeminiService._();

  static final GeminiService instance =
      GeminiService._();

  static const String _model = 'gemini-3.6-flash';

  static const String _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models';

  Future<Map<String, dynamic>> generateResponse({
    required String userQuestion,
    required String location,
    required double temperature,
    required int humidity,
    required double windSpeed,
    required String weather,
    required String weatherRisk,
    required String crowdLevel,
    required int crowdDensity,
  }) async {
    final apiKey = GeminiConfig.apiKey;

    if (apiKey.isEmpty) {
      throw Exception(
        'Gemini API key is missing.\n\n'
        'Run:\n'
        'flutter run --dart-define="GEMINI_API_KEY=YOUR_API_KEY"',
      );
    }

    final url = Uri.parse(
      '$_baseUrl/$_model:generateContent?key=$apiKey',
    );

    final prompt = '''
You are TrekCure AI, a smart tourist safety assistant.

Answer the user's question using the current TrekCure data.

USER QUESTION:
$userQuestion

CURRENT DATA:

Location: $location
Temperature: $temperature°C
Humidity: $humidity%
Wind Speed: $windSpeed km/h
Weather: $weather
Weather Risk: $weatherRisk
Crowd Level: $crowdLevel
Crowd Density: $crowdDensity%

RULES:

1. Return ONLY valid JSON.
2. Do not return Markdown.
3. Do not use ###.
4. Do not use **.
5. Do not use code blocks.
6. Do not add text outside the JSON.
7. Do not invent information.
8. Keep the response concise.
9. Make the response suitable for a mobile tourist safety app.

The status must be exactly:
SAFE
MODERATE RISK
HIGH RISK

Return this structure:

{
  "status": "SAFE",
  "summary": "Short safety assessment.",
  "conditions": {
    "location": "Location",
    "temperature": "Temperature",
    "humidity": "Humidity",
    "wind": "Wind",
    "weather": "Weather",
    "weatherRisk": "Weather risk",
    "crowd": "Crowd level"
  },
  "risks": [
    "Risk"
  ],
  "recommendations": [
    "Recommendation 1",
    "Recommendation 2",
    "Recommendation 3"
  ],
  "finalAdvice": "Short final advice."
}
''';

    final responseSchema = {
      'type': 'OBJECT',
      'properties': {
        'status': {
          'type': 'STRING',
          'enum': [
            'SAFE',
            'MODERATE RISK',
            'HIGH RISK',
          ],
        },
        'summary': {
          'type': 'STRING',
        },
        'conditions': {
          'type': 'OBJECT',
          'properties': {
            'location': {
              'type': 'STRING',
            },
            'temperature': {
              'type': 'STRING',
            },
            'humidity': {
              'type': 'STRING',
            },
            'wind': {
              'type': 'STRING',
            },
            'weather': {
              'type': 'STRING',
            },
            'weatherRisk': {
              'type': 'STRING',
            },
            'crowd': {
              'type': 'STRING',
            },
          },
          'required': [
            'location',
            'temperature',
            'humidity',
            'wind',
            'weather',
            'weatherRisk',
            'crowd',
          ],
        },
        'risks': {
          'type': 'ARRAY',
          'items': {
            'type': 'STRING',
          },
        },
        'recommendations': {
          'type': 'ARRAY',
          'items': {
            'type': 'STRING',
          },
        },
        'finalAdvice': {
          'type': 'STRING',
        },
      },
      'required': [
        'status',
        'summary',
        'conditions',
        'risks',
        'recommendations',
        'finalAdvice',
      ],
    };

    final requestBody = {
      'contents': [
        {
          'parts': [
            {
              'text': prompt,
            },
          ],
        },
      ],
      'generationConfig': {
        'responseMimeType': 'application/json',
        'responseSchema': responseSchema,
        'maxOutputTokens': 1200,
      },
    };

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestBody),
      );

      if (response.statusCode != 200) {
        String errorMessage =
            'Gemini API request failed.';

        try {
          final errorData =
              jsonDecode(response.body);

          errorMessage =
              errorData['error']?['message'] ??
                  errorMessage;
        } catch (_) {}

        throw Exception(
          '$errorMessage\n'
          'Status code: ${response.statusCode}',
        );
      }

      final Map<String, dynamic> data =
          jsonDecode(response.body);

      final candidates = data['candidates'];

      if (candidates is! List ||
          candidates.isEmpty) {
        throw Exception(
          'Gemini returned no response.',
        );
      }

      final content =
          candidates.first['content'];

      if (content == null) {
        throw Exception(
          'Gemini response did not contain content.',
        );
      }

      final parts = content['parts'];

      if (parts is! List ||
          parts.isEmpty) {
        throw Exception(
          'Gemini response did not contain text.',
        );
      }

      final text =
          parts.first['text']?.toString();

      if (text == null || text.isEmpty) {
        throw Exception(
          'Gemini returned an empty response.',
        );
      }

      final decoded = jsonDecode(text);

      if (decoded is! Map) {
        throw Exception(
          'Gemini returned invalid JSON.',
        );
      }

      return Map<String, dynamic>.from(decoded);
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }

      throw Exception(
        'Unable to connect to Gemini: $e',
      );
    }
  }
}