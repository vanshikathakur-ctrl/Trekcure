import 'dart:convert';

import 'package:http/http.dart' as http;

class TrekCureApiService {
  // ============================================================
  // BACKEND URL
  // ============================================================

  // FastAPI Digital ID API
  static const String baseUrl = 'https://trekcure-digital-id.onrender.com';

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
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'user_id': userId, 'name': name, 'age': age}),
    );

    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(jsonDecode(response.body));
    }

    throw Exception('Failed to create Digital ID: ${response.body}');
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
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'user_id': userId, 'credential': credential}),
    );

    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(jsonDecode(response.body));
    }

    throw Exception('Failed to verify Digital ID: ${response.body}');
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
      '&forecast_days=2'
      '&timezone=auto',
    );

    try {
      final response = await http.get(uri);

      if (response.statusCode != 200) {
        throw Exception('Failed to load weather: ${response.body}');
      }

      final Map<String, dynamic> data = Map<String, dynamic>.from(
        jsonDecode(response.body),
      );

      // ==========================================================
      // CURRENT WEATHER
      // ==========================================================

      final Map<String, dynamic> current = Map<String, dynamic>.from(
        data['current'] ?? {},
      );

      final double temperature =
          (current['temperature_2m'] as num?)?.toDouble() ?? 0.0;

      final double humidity =
          (current['relative_humidity_2m'] as num?)?.toDouble() ?? 0.0;

      final double feelsLike =
          (current['apparent_temperature'] as num?)?.toDouble() ?? 0.0;

      final double windSpeed =
          (current['wind_speed_10m'] as num?)?.toDouble() ?? 0.0;

      final int weatherCode = (current['weather_code'] as num?)?.toInt() ?? 0;

      final double rain = (current['rain'] as num?)?.toDouble() ?? 0.0;

      final double precipitation =
          (current['precipitation'] as num?)?.toDouble() ?? 0.0;

      // ==========================================================
      // WEATHER CONDITION
      // ==========================================================

      final String condition = _weatherDescription(weatherCode);

      // ==========================================================
      // RISK CALCULATION
      // ==========================================================

      String riskLevel = 'LOW';
      bool hazard = false;

      String message = 'Weather conditions are suitable for travel.';

      // ----------------------------------------------------------
      // THUNDERSTORM
      // ----------------------------------------------------------

      if (weatherCode >= 95) {
        riskLevel = 'HIGH';
        hazard = true;
        message = 'Thunderstorm detected. Avoid outdoor travel if possible.';
      }
      // ----------------------------------------------------------
      // HEAVY RAIN
      // ----------------------------------------------------------
      else if (weatherCode == 65 ||
          weatherCode == 67 ||
          weatherCode == 82 ||
          rain >= 5) {
        riskLevel = 'HIGH';
        hazard = true;
        message = 'Heavy rain conditions detected. Travel with caution.';
      }
      // ----------------------------------------------------------
      // MODERATE RAIN / DRIZZLE
      // ----------------------------------------------------------
      else if ((weatherCode >= 51 && weatherCode <= 67) ||
          (weatherCode >= 80 && weatherCode <= 82)) {
        riskLevel = 'MODERATE';
        hazard = false;
        message =
            'Rainy conditions. Carry rain protection and travel carefully.';
      }
      // ----------------------------------------------------------
      // STRONG WIND
      // ----------------------------------------------------------
      else if (windSpeed >= 40) {
        riskLevel = 'HIGH';
        hazard = true;
        message = 'Strong winds detected. Avoid exposed areas.';
      }
      // ----------------------------------------------------------
      // MODERATE WIND
      // ----------------------------------------------------------
      else if (windSpeed >= 25) {
        riskLevel = 'MODERATE';
        hazard = false;
        message = 'Moderate winds detected. Travel with caution.';
      }
      // ----------------------------------------------------------
      // EXTREME TEMPERATURE
      // ----------------------------------------------------------
      else if (temperature >= 40 || temperature <= 5) {
        riskLevel = 'HIGH';
        hazard = true;
        message = 'Extreme temperature conditions detected. Take precautions.';
      }

      // ==========================================================
      // HOURLY FORECAST
      // ==========================================================

      final Map<String, dynamic> hourly = Map<String, dynamic>.from(
        data['hourly'] ?? {},
      );

      final List<dynamic> times = hourly['time'] ?? [];

      final List<dynamic> temperatures = hourly['temperature_2m'] ?? [];

      final List<dynamic> weatherCodes = hourly['weather_code'] ?? [];

      final List<Map<String, dynamic>> forecast = [];

      // ==========================================================
      // TIMEZONE-SAFE FORECAST
      // ==========================================================
      //
      // Open-Meteo uses timezone=auto, meaning the returned
      // forecast times are in the selected location's timezone.
      //
      // We therefore use Open-Meteo's own current time instead
      // of DateTime.now() from the Android emulator.
      // ==========================================================

      final String currentApiTime = current['time']?.toString() ?? '';

      int currentIndex = 0;

      // ==========================================================
      // FIND CURRENT HOUR
      // ==========================================================

      for (int i = 0; i < times.length; i++) {
        final String forecastTime = times[i].toString();

        // compareTo() is used because both values are Strings.
        if (forecastTime.compareTo(currentApiTime) >= 0) {
          currentIndex = i;
          break;
        }
      }

      // ==========================================================
      // 6-HOUR FORECAST
      // ==========================================================
      //
      // Current hour + next 5 hours.
      //
      // forecast_days=2 above ensures that if it is late at night,
      // tomorrow's hours are also available.
      // ==========================================================

      for (int i = currentIndex; i < times.length && forecast.length < 6; i++) {
        if (i >= temperatures.length || i >= weatherCodes.length) {
          break;
        }

        forecast.add({
          'time': times[i].toString(),
          'temperature': (temperatures[i] as num).toDouble(),
          'weather_code': (weatherCodes[i] as num).toInt(),
        });
      }

      // ==========================================================
      // RETURN DATA
      // ==========================================================

      return {
        'temperature': temperature,
        'humidity': humidity,
        'feels_like': feelsLike,
        'precipitation': precipitation,
        'rain': rain,
        'weather_code': weatherCode,
        'condition': condition,
        'wind_speed': windSpeed,

        // Risk information
        'risk_level': riskLevel,
        'hazard': hazard,
        'message': message,

        // 6-hour forecast
        'forecast': forecast,
      };
    } catch (e) {
      throw Exception('Weather service error: $e');
    }
  }

  // ============================================================
  // WEATHER DESCRIPTION
  // ============================================================

  static String _weatherDescription(int code) {
    if (code == 0) {
      return 'Clear';
    }

    if (code == 1) {
      return 'Mainly clear';
    }

    if (code == 2) {
      return 'Partly cloudy';
    }

    if (code == 3) {
      return 'Cloudy';
    }

    if (code == 45 || code == 48) {
      return 'Foggy';
    }

    if (code >= 51 && code <= 57) {
      return 'Drizzle';
    }

    if (code >= 61 && code <= 67) {
      return 'Rainy';
    }

    if (code >= 71 && code <= 77) {
      return 'Snowy';
    }

    if (code >= 80 && code <= 82) {
      return 'Rain showers';
    }

    if (code == 85 || code == 86) {
      return 'Snow showers';
    }

    if (code >= 95) {
      return 'Thunderstorm';
    }

    return 'Cloudy';
  }
}
