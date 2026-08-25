import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

import '../theme/app_theme.dart';
import '../widgets/bottom_nav.dart';
import '../services/trekcure_api_service.dart';

class WeatherScreen extends StatefulWidget {
  const WeatherScreen({super.key});

  @override
  State<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen> {
  // ============================================================
  // GEOCODING
  // ============================================================

  final Geocoding _geocoding = Geocoding();

  // ============================================================
  // STATE
  // ============================================================

  bool _loading = true;
  String? _error;

  // ============================================================
  // CURRENT LOCATION
  // ============================================================

  String _currentLocation = 'Current Location';

  // ============================================================
  // WEATHER DATA
  // ============================================================

  double _temperature = 0;
  double _humidity = 0;
  double _windSpeed = 0;
  double _feelsLike = 0;

  int _weatherCode = 0;

  String _riskLevel = '';
  bool _hazard = false;
  String _message = '';

  List<Map<String, dynamic>> _forecast = [];

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();
    _loadWeather();
  }

  // ============================================================
  // GET LOCATION AND WEATHER
  // ============================================================

  Future<void> _loadWeather() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // ==========================================================
      // 1. CHECK LOCATION SERVICES
      // ==========================================================

      final serviceEnabled = await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        throw Exception('Location services are disabled.');
      }

      // ==========================================================
      // 2. CHECK LOCATION PERMISSION
      // ==========================================================

      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        throw Exception('Location permission was denied.');
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permission is permanently denied.');
      }

      // ==========================================================
      // 3. GET CURRENT GPS LOCATION
      // ==========================================================

      final Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      // ==========================================================
      // 4. CONVERT GPS COORDINATES TO LOCATION NAME
      // ==========================================================

      String locationName = 'Current Location';

      try {
        final List<Placemark> placemarks = await _geocoding
            .placemarkFromCoordinates(position.latitude, position.longitude);

        if (placemarks.isNotEmpty) {
          final Placemark place = placemarks.first;

          final String? city = place.locality;

          final String? state = place.administrativeArea;

          final String? country = place.country;

          final List<String> parts = [
            if (city != null && city.isNotEmpty) city,
            if (state != null && state.isNotEmpty) state,
            if (country != null && country.isNotEmpty) country,
          ];

          if (parts.isNotEmpty) {
            locationName = parts.join(', ');
          }
        }
      } catch (_) {
        locationName = 'Current Location';
      }

      // ==========================================================
      // 5. GET WEATHER
      // ==========================================================

      final weather = await TrekCureApiService.getWeather(
        latitude: position.latitude,
        longitude: position.longitude,
      );

      if (!mounted) return;

      // ==========================================================
      // 6. UPDATE SCREEN
      // ==========================================================

      setState(() {
        _currentLocation = locationName;

        _temperature = (weather['temperature'] ?? 0).toDouble();

        _humidity = (weather['humidity'] ?? 0).toDouble();

        _feelsLike = (weather['feels_like'] ?? 0).toDouble();

        _windSpeed = (weather['wind_speed'] ?? 0).toDouble();

        _weatherCode = (weather['weather_code'] ?? 0) as int;

        _riskLevel = weather['risk_level'] ?? '';

        _hazard = weather['hazard'] ?? false;

        _message = weather['message'] ?? '';

        _forecast = List<Map<String, dynamic>>.from(weather['forecast'] ?? []);

        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  // ============================================================
  // WEATHER DESCRIPTION
  // ============================================================

  String _weatherDescription(int code) {
    if (code == 0) {
      return 'Clear';
    }

    if (code == 1 || code == 2 || code == 3) {
      return 'Cloudy';
    }

    if (code == 45 || code == 48) {
      return 'Foggy';
    }

    if (code >= 51 && code <= 67) {
      return 'Rainy';
    }

    if (code >= 71 && code <= 77) {
      return 'Snowy';
    }

    if (code >= 80 && code <= 82) {
      return 'Rain showers';
    }

    if (code >= 95) {
      return 'Thunderstorm';
    }

    return 'Cloudy';
  }

  // ============================================================
  // WEATHER ICON
  // ============================================================

  IconData _weatherIcon(int code) {
    if (code == 0) {
      return Icons.wb_sunny_outlined;
    }

    if (code == 1 || code == 2 || code == 3) {
      return Icons.wb_cloudy_outlined;
    }

    if (code == 45 || code == 48) {
      return Icons.foggy;
    }

    if (code >= 51 && code <= 82) {
      return Icons.grain;
    }

    if (code >= 95) {
      return Icons.thunderstorm_outlined;
    }

    return Icons.wb_cloudy_outlined;
  }

  // ============================================================
  // FORMAT FORECAST TIME
  // ============================================================

  String _formatTime(String time) {
    try {
      final DateTime dateTime = DateTime.parse(time);

      int hour = dateTime.hour;

      final String period = hour >= 12 ? 'PM' : 'AM';

      if (hour == 0) {
        hour = 12;
      } else if (hour > 12) {
        hour -= 12;
      }

      return '$hour:00 $period';
    } catch (_) {
      return time;
    }
  }

  // ============================================================
  // RISK COLOR
  // ============================================================

  Color _riskColor() {
    if (_riskLevel == 'HIGH') {
      return AppColors.dangerRed;
    }

    if (_riskLevel == 'MODERATE') {
      return AppColors.warningOrange;
    }

    return AppColors.primaryGreen;
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,

        title: Row(
          children: [
            const Icon(Icons.wb_cloudy_outlined),

            const SizedBox(width: 8),

            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Weather',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),

                Row(
                  children: [
                    const Icon(
                      Icons.location_on,
                      size: 12,
                      color: AppColors.textGrey,
                    ),

                    const SizedBox(width: 2),

                    Text(
                      _currentLocation,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textGrey,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),

        actions: [
          IconButton(
            onPressed: _loading ? null : _loadWeather,
            icon: const Icon(Icons.refresh),
          ),

          const SizedBox(width: 8),
        ],
      ),

      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _buildError()
          : _buildWeatherContent(),

      bottomNavigationBar: const AppBottomNav(currentIndex: 3),
    );
  }

  // ============================================================
  // ERROR
  // ============================================================

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),

        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,

          children: [
            const Icon(Icons.cloud_off, size: 60, color: AppColors.textGrey),

            const SizedBox(height: 16),

            const Text(
              'Unable to load weather',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 8),

            Text(
              _error ?? 'Unknown error',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textGrey),
            ),

            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: _loadWeather,
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // WEATHER CONTENT
  // ============================================================

  Widget _buildWeatherContent() {
    return ListView(
      padding: const EdgeInsets.all(16),

      children: [
        // ========================================================
        // CURRENT WEATHER CARD
        // ========================================================

        AppCard(
          color: const Color(0xFFDCEAF7),

          child: Column(
            children: [
              Icon(
                _weatherIcon(_weatherCode),
                size: 40,
                color: AppColors.infoBlue,
              ),

              const SizedBox(height: 8),

              Text(
                '${_temperature.round()}°C',
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),

              Text(
                _weatherDescription(_weatherCode),
                style: const TextStyle(color: AppColors.textGrey),
              ),

              const SizedBox(height: 14),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,

                children: [
                  _StatColumn(
                    label: 'Humidity',
                    value: '${_humidity.round()}%',
                  ),

                  _StatColumn(
                    label: 'Wind',
                    value: '${_windSpeed.round()} km/h',
                  ),

                  _StatColumn(
                    label: 'Feels Like',
                    value: '${_feelsLike.round()}°C',
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // ========================================================
        // HOURLY FORECAST TITLE
        // ========================================================
        const Text(
          "Today's Forecast",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),

        const SizedBox(height: 10),

        // ========================================================
        // 6-HOUR FORECAST
        // ========================================================
        AppCard(
          padding: EdgeInsets.zero,

          child: _forecast.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(20),

                  child: Text(
                    'Forecast unavailable',
                    style: TextStyle(color: AppColors.textGrey),
                  ),
                )
              : SizedBox(
                  // Allows several forecast rows to be
                  // visible while keeping the card compact.
                  height: 220,

                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 4),

                    itemCount: _forecast.length,

                    separatorBuilder: (context, index) {
                      return const Divider(
                        height: 1,
                        indent: 48,
                        endIndent: 16,
                      );
                    },

                    itemBuilder: (context, index) {
                      final Map<String, dynamic> forecast = _forecast[index];

                      final int code = (forecast['weather_code'] ?? 0) as int;

                      final double temperature = (forecast['temperature'] ?? 0)
                          .toDouble();

                      final String time = _formatTime(forecast['time'] ?? '');

                      return ListTile(
                        dense: true,

                        leading: Icon(
                          _weatherIcon(code),
                          color: AppColors.infoBlue,
                        ),

                        title: Text(time, style: const TextStyle(fontSize: 14)),

                        trailing: Text(
                          '${temperature.round()}°C',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      );
                    },
                  ),
                ),
        ),

        const SizedBox(height: 16),

        // ========================================================
        // WEATHER STATUS
        // ========================================================
        AppCard(
          color: _hazard ? AppColors.dangerBgLight : AppColors.infoBgLight,

          child: Row(
            children: [
              Icon(
                _hazard ? Icons.warning_amber : Icons.info_outline,

                color: _hazard ? AppColors.dangerRed : AppColors.infoBlue,
              ),

              const SizedBox(width: 10),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [
                    Text(
                      _hazard ? 'Weather Alert' : 'Weather Status',

                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),

                    const SizedBox(height: 2),

                    Text(
                      _message,

                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textGrey,
                      ),
                    ),

                    const SizedBox(height: 4),

                    Text(
                      'Risk: $_riskLevel',

                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: _riskColor(),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ================================================================
// STAT COLUMN
// ================================================================

class _StatColumn extends StatelessWidget {
  final String label;
  final String value;

  const _StatColumn({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),

        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.textGrey),
        ),
      ],
    );
  }
}
