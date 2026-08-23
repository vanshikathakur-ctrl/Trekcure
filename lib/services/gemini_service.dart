import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/gemini_config.dart';

class GeminiService {
  GeminiService._();

  static final GeminiService instance = GeminiService._();

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
        'Run the application using:\n'
        'flutter run --dart-define="GEMINI_API_KEY=YOUR_API_KEY"',
      );
    }

    final url = Uri.parse('$_baseUrl/$_model:generateContent?key=$apiKey');

    // ============================================================
    // GENERAL PURPOSE AI PROMPT
    // ============================================================

    final prompt =
        '''
You are TrekCure AI, an intelligent and helpful general-purpose AI
assistant inside the TrekCure mobile application.

You can answer BOTH TrekCure-related questions AND general questions.

The user may ask about:

- TrekCure app features
- How TrekCure works
- Offline SOS
- Emergency SOS
- Tourist safety
- Geofencing
- Risk zones
- Crowd monitoring
- Weather
- Travel
- Trekking
- General knowledge
- Science
- Technology
- Programming
- Education
- Daily life
- Recommendations
- Greetings
- Casual conversation
- Any other normal question

IMPORTANT:

Do NOT assume every question is about tourist safety.

First understand what the user is actually asking.

If the question is about TrekCure:
Answer using the available TrekCure information.

If the question is about weather, location, crowd or safety:
Use the current TrekCure context when it is relevant.

If the question is a general question:
Answer it normally using your general knowledge.

If the user says hello, hi, thanks, etc.:
Respond naturally and conversationally.

If the question is unrelated to TrekCure:
DO NOT force the answer to be about TrekCure.

If you do not know something:
Clearly say that you do not know rather than inventing information.

Keep answers clear and useful for a mobile application.

CURRENT TREKCURE CONTEXT:

Location:
$location

Temperature:
$temperature°C

Humidity:
$humidity%

Wind Speed:
$windSpeed km/h

Weather:
$weather

Weather Risk:
$weatherRisk

Crowd Level:
$crowdLevel

Crowd Density:
$crowdDensity%

USER QUESTION:

$userQuestion

RESPONSE RULES:

Return ONLY valid JSON.

Do NOT return Markdown.

Do NOT use code fences.

Do NOT add any text before or after the JSON.

Use exactly this structure:

{
  "type": "general",
  "title": "Short title",
  "answer": "Clear answer to the user's question.",
  "status": "",
  "conditions": {},
  "risks": [],
  "recommendations": [],
  "finalAdvice": ""
}

The "type" must be one of:

"general"
"trekcure"
"safety"
"weather"
"travel"
"emergency"

Use "general" for normal questions.

Use "trekcure" for questions about the TrekCure application.

Use "safety" for safety-related questions.

Use "weather" for weather-related questions.

Use "travel" for travel or trekking questions.

Use "emergency" only when the user is asking about an emergency or SOS situation.

For normal/general questions:

- Put the complete answer in "answer".
- Keep "status" empty.
- Keep "conditions" empty.
- Keep "risks" empty.
- Keep "recommendations" empty.
- Keep "finalAdvice" empty.

For TrekCure/safety/weather/travel questions:

- Put the main explanation in "answer".
- Use "conditions" when useful.
- Use "risks" when useful.
- Use "recommendations" when useful.
- Use "finalAdvice" when useful.

For emergency questions:

- Clearly explain the safest immediate action.
- Do not pretend to contact emergency services.
- Do not claim that an SOS was actually sent unless the application itself confirms it.

For "status":

Use:
"SAFE"
"MODERATE RISK"
"HIGH RISK"

Only use these when a safety assessment is actually relevant.

Otherwise use an empty string.

Example for a general question:

{
  "type": "general",
  "title": "What is Python?",
  "answer": "Python is a high-level programming language...",
  "status": "",
  "conditions": {},
  "risks": [],
  "recommendations": [],
  "finalAdvice": ""
}

Example for a TrekCure question:

{
  "type": "trekcure",
  "title": "Offline SOS",
  "answer": "TrekCure's Offline SOS is designed to...",
  "status": "",
  "conditions": {},
  "risks": [],
  "recommendations": [
    "Keep Bluetooth enabled.",
    "Keep the application running."
  ],
  "finalAdvice": "Use the SOS feature when you need emergency assistance."
}

Example for a safety question:

{
  "type": "safety",
  "title": "Current Safety Assessment",
  "answer": "The current conditions appear moderately safe, but...",
  "status": "MODERATE RISK",
  "conditions": {
    "location": "$location",
    "temperature": "$temperature°C",
    "humidity": "$humidity%",
    "wind": "$windSpeed km/h",
    "weather": "$weather",
    "weatherRisk": "$weatherRisk",
    "crowd": "$crowdLevel"
  },
  "risks": [
    "Example risk"
  ],
  "recommendations": [
    "Example recommendation"
  ],
  "finalAdvice": "Follow local safety guidance."
}
''';

    // ============================================================
    // RESPONSE SCHEMA
    // ============================================================

    final responseSchema = {
      'type': 'OBJECT',
      'properties': {
        'type': {
          'type': 'STRING',
          'enum': [
            'general',
            'trekcure',
            'safety',
            'weather',
            'travel',
            'emergency',
          ],
        },

        'title': {'type': 'STRING'},

        'answer': {'type': 'STRING'},

        'status': {'type': 'STRING'},

        'conditions': {
          'type': 'OBJECT',
          'properties': {
            'location': {'type': 'STRING'},
            'temperature': {'type': 'STRING'},
            'humidity': {'type': 'STRING'},
            'wind': {'type': 'STRING'},
            'weather': {'type': 'STRING'},
            'weatherRisk': {'type': 'STRING'},
            'crowd': {'type': 'STRING'},
          },
        },

        'risks': {
          'type': 'ARRAY',
          'items': {'type': 'STRING'},
        },

        'recommendations': {
          'type': 'ARRAY',
          'items': {'type': 'STRING'},
        },

        'finalAdvice': {'type': 'STRING'},
      },

      'required': [
        'type',
        'title',
        'answer',
        'status',
        'conditions',
        'risks',
        'recommendations',
        'finalAdvice',
      ],
    };

    // ============================================================
    // REQUEST
    // ============================================================

    final requestBody = {
      'contents': [
        {
          'parts': [
            {'text': prompt},
          ],
        },
      ],

      'generationConfig': {
        'responseMimeType': 'application/json',
        'responseSchema': responseSchema,
        'maxOutputTokens': 1500,
      },
    };

    // ============================================================
    // API REQUEST
    // ============================================================

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode != 200) {
        String errorMessage = 'Gemini API request failed.';

        try {
          final errorData = jsonDecode(response.body);

          errorMessage = errorData['error']?['message'] ?? errorMessage;
        } catch (_) {}

        throw Exception(
          '$errorMessage\n'
          'Status code: ${response.statusCode}',
        );
      }

      final Map<String, dynamic> data = jsonDecode(response.body);

      final candidates = data['candidates'];

      if (candidates is! List || candidates.isEmpty) {
        throw Exception('Gemini returned no response.');
      }

      final content = candidates.first['content'];

      if (content == null) {
        throw Exception('Gemini response did not contain content.');
      }

      final parts = content['parts'];

      if (parts is! List || parts.isEmpty) {
        throw Exception('Gemini response did not contain text.');
      }

      final text = parts.first['text']?.toString();

      if (text == null || text.trim().isEmpty) {
        throw Exception('Gemini returned an empty response.');
      }

      final decoded = jsonDecode(text);

      if (decoded is! Map) {
        throw Exception('Gemini returned invalid JSON.');
      }

      return Map<String, dynamic>.from(decoded);
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }

      throw Exception('Unable to connect to Gemini: $e');
    }
  }
}
