import 'dart:convert';

import 'package:http/http.dart' as http;

class TrekCureApiService {
  // ============================================================
  // BACKEND URLs
  // ============================================================

  // FastAPI Digital ID API
  static const String baseUrl =
      'https://trekcure-digital-id.onrender.com';

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
      'https://api.open-meteo.com/v1/forecast'
      '?latitude=$latitude'
      '&longitude=$longitude'
      '&current='
      'temperature_2m,'
      'relative_humidity_2m,'
      'apparent_temperature,'
      'precipitation,'
      'rain,'
      'weather_code,'
      'wind_speed_10m'
      '&hourly='
      'temperature_2m,'
      'weather_code'
      '&forecast_days=1'
      '&timezone=auto',
    );

    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to load weather: ${response.body}',
      );
    }

    final Map<String, dynamic> data =
        Map<String, dynamic>.from(
      jsonDecode(response.body),
    );

    final Map<String, dynamic> current =
        Map<String, dynamic>.from(
      data['current'],
    );

    // ============================================================
    // CURRENT WEATHER
    // ============================================================

    final double temperature =
        (current['temperature_2m'] as num?)?.toDouble() ?? 0.0;

    final double humidity =
        (current['relative_humidity_2m'] as num?)?.toDouble() ?? 0.0;

    final double feelsLike =
        (current['apparent_temperature'] as num?)?.toDouble() ?? 0.0;

    final double windSpeed =
        (current['wind_speed_10m'] as num?)?.toDouble() ?? 0.0;

    final int weatherCode =
        (current['weather_code'] as num?)?.toInt() ?? 0;

    final double rain =
        (current['rain'] as num?)?.toDouble() ?? 0.0;

    // ============================================================
    // RISK CALCULATION
    // ============================================================

    String riskLevel = 'LOW';
    bool hazard = false;
    String message = 'Weather conditions are suitable for travel.';

    // Thunderstorm
    if (weatherCode >= 95) {
      riskLevel = 'HIGH';
      hazard = true;
      message =
          'Thunderstorm detected. Avoid outdoor travel if possible.';
    }

    // Heavy rain / rain showers
    else if (weatherCode == 65 ||
        weatherCode == 67 ||
        weatherCode == 82 ||
        rain >= 5) {
      riskLevel = 'HIGH';
      hazard = true;
      message =
          'Heavy rain conditions detected. Travel with caution.';
    }

    // Moderate rain / drizzle
    else if ((weatherCode >= 51 && weatherCode <= 67) ||
        (weatherCode >= 80 && weatherCode <= 82)) {
      riskLevel = 'MODERATE';
      hazard = false;
      message =
          'Rainy conditions. Carry rain protection and travel carefully.';
    }

    // Strong wind
    else if (windSpeed >= 40) {
      riskLevel = 'HIGH';
      hazard = true;
      message =
          'Strong winds detected. Avoid exposed areas.';
    }

    else if (windSpeed >= 25) {
      riskLevel = 'MODERATE';
      hazard = false;
      message =
          'Moderate winds detected. Travel with caution.';
    }

    // Extreme temperature
    else if (temperature >= 40 || temperature <= 5) {
      riskLevel = 'HIGH';
      hazard = true;
      message =
          'Extreme temperature conditions detected. Take precautions.';
    }

    // ============================================================
    // HOURLY FORECAST
    // ============================================================

    final Map<String, dynamic> hourly =
        Map<String, dynamic>.from(
      data['hourly'] ?? {},
    );

    final List<dynamic> times =
        hourly['time'] ?? [];

    final List<dynamic> temperatures =
        hourly['temperature_2m'] ?? [];

    final List<dynamic> weatherCodes =
        hourly['weather_code'] ?? [];

    final List<Map<String, dynamic>> forecast = [];

    final DateTime now = DateTime.now();

    for (int i = 0; i < times.length; i++) {
      try {
        final DateTime forecastTime =
            DateTime.parse(times[i].toString());

        // Only show upcoming hours
        if (forecastTime.isBefore(now)) {
          continue;
        }

        forecast.add({
          'time': times[i],
          'temperature':
              temperatures[i],
          'weather_code':
              weatherCodes[i],
        });

        // Show next 8 hours
        if (forecast.length >= 8) {
          break;
        }
      } catch (_) {
        continue;
      }
    }

    // ============================================================
    // RETURN DATA IN THE FORMAT YOUR WEATHER SCREEN EXPECTS
    // ============================================================

    return {
      'temperature': temperature,
      'humidity': humidity,
      'feels_like': feelsLike,
      'precipitation':
          current['precipitation'] ?? 0,
      'rain': rain,
      'weather_code': weatherCode,
      'condition': 'Weather',
      'wind_speed': windSpeed,

      // These were missing before
      'risk_level': riskLevel,
      'hazard': hazard,
      'message': message,
      'forecast': forecast,
    };
  }
}