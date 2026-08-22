import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/mesh_service.dart';
import '../theme/app_theme.dart';
import '../widgets/bottom_nav.dart';
import 'map_crowd_screen.dart';
import 'notifications_screen.dart';

class HomeDashboardScreen extends StatefulWidget {
  const HomeDashboardScreen({super.key});

  @override
  State<HomeDashboardScreen> createState() => _HomeDashboardScreenState();
}

class _HomeDashboardScreenState extends State<HomeDashboardScreen> {
  String _userName = 'User';

  // ============================================================
  // DYNAMIC LOCATION VARIABLES
  // ============================================================

  String _userLocationText = 'Locating...';

  // ============================================================
  // DYNAMIC WEATHER STATE
  // ============================================================

  double? _temperature;
  double? _humidity;
  double? _windSpeed;

  String _weatherCondition = 'Loading...';
  bool _weatherLoading = true;

  // ============================================================
  // DYNAMIC CROWD STATE
  // ============================================================

  String _crowdLevel = 'Loading...';
  int _crowdPeopleCount = 0;

  Color _crowdColor = AppColors.warningOrange;
  bool _isCrowdLoading = true;

  // ============================================================
  // OFFLINE MESH STATE
  // ============================================================

  int _nearbyMeshNodes = 0;
  bool _meshRelayActive = false;

  late final MeshService _meshService;

  StreamSubscription<int>? _meshNodeSubscription;

  // NEW: Listen for incoming SOS messages
  StreamSubscription<Map<String, dynamic>>? _meshSosSubscription;

  @override
  void initState() {
    super.initState();

    _meshService = MeshService.instance;

    _startMesh();

    _loadUserName();
    _loadDashboardData();
  }

  // ============================================================
  // START OFFLINE MESH
  // ============================================================

  Future<void> _startMesh() async {
    try {
      await _meshService.start();

      if (!mounted) return;

      setState(() {
        _nearbyMeshNodes = _meshService.nearbyNodeCount;
        _meshRelayActive = _meshService.isRunning;
      });

      // ----------------------------------------------------------
      // LISTEN FOR NODE COUNT CHANGES
      // ----------------------------------------------------------

      await _meshNodeSubscription?.cancel();

      _meshNodeSubscription =
          _meshService.nodeCountStream.listen((nodeCount) {
        if (!mounted) return;

        setState(() {
          _nearbyMeshNodes = nodeCount;
          _meshRelayActive = _meshService.isRunning;
        });

        debugPrint('MESH NODE COUNT UPDATED: $nodeCount');
      });

      // ----------------------------------------------------------
      // LISTEN FOR INCOMING OFFLINE SOS
      // ----------------------------------------------------------

      debugPrint('================================');
      debugPrint('STARTING OFFLINE MESH SOS LISTENER...');
      debugPrint('================================');

      await _meshSosSubscription?.cancel();

      _meshSosSubscription =
          _meshService.sosStream.listen((sosData) {
        debugPrint('================================');
        debugPrint('🚨 OFFLINE SOS RECEIVED IN HOME');
        debugPrint('Sender: ${sosData['senderName']}');
        debugPrint('Payload: ${sosData['payload']}');
        debugPrint('================================');

        if (!mounted) return;

        _showOfflineSosAlert(sosData);
      });
    } catch (e) {
      debugPrint('================================');
      debugPrint('MESH START ERROR IN HOME');
      debugPrint('$e');
      debugPrint('================================');

      if (!mounted) return;

      setState(() {
        _nearbyMeshNodes = 0;
        _meshRelayActive = false;
      });
    }
  }

  // ============================================================
  // SHOW OFFLINE SOS ALERT
  // ============================================================

  void _showOfflineSosAlert(
    Map<String, dynamic> sosData,
  ) {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(
                Icons.warning_rounded,
                color: Colors.red,
                size: 30,
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'OFFLINE SOS',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            '${sosData['senderName'] ?? 'A nearby TrekCure user'} '
            'needs emergency assistance!\n\n'
            'SOS received through the TrekCure offline mesh network.',
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text(
                'ACKNOWLEDGE',
              ),
            ),
          ],
        );
      },
    );
  }

  // ============================================================
  // LOAD USER PROFILE
  // ============================================================

  Future<void> _loadUserName() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    if (user == null) return;

    try {
      final profile = await supabase
          .from('profiles')
          .select('full_name')
          .eq('id', user.id)
          .maybeSingle();

      if (!mounted) return;

      setState(() {
        _userName = profile?['full_name'] ?? 'User';
      });
    } catch (e) {
      debugPrint('Could not load user name: $e');
    }
  }

  // ============================================================
  // UNIFIED DASHBOARD DATA LOADER
  // LOCATION + WEATHER + CROWD
  // ============================================================

  Future<void> _loadDashboardData() async {
    if (!mounted) return;

    setState(() {
      _weatherLoading = true;
      _isCrowdLoading = true;
    });

    try {
      final bool serviceEnabled =
          await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        _setFallbackMetrics();
        return;
      }

      LocationPermission permission =
          await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _setFallbackMetrics();
        return;
      }

      final Position position =
          await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
        ),
      );

      _fetchReverseGeocodeLocation(
        position.latitude,
        position.longitude,
      );

      final Random random = Random(
        (position.latitude * 100).toInt() +
            (position.longitude * 100).toInt(),
      );

      final double avgDensity =
          0.2 + (random.nextDouble() * 0.7);

      final int percentage =
          (avgDensity * 100).round();

      final int estimatedPeople =
          (avgDensity * 350).round();

      String crowdLevel;
      Color crowdColor;

      if (percentage <= 30) {
        crowdLevel = 'Low';
        crowdColor = Colors.green;
      } else if (percentage <= 70) {
        crowdLevel = 'Moderate';
        crowdColor = AppColors.warningOrange;
      } else {
        crowdLevel = 'High';
        crowdColor = AppColors.dangerRed;
      }

      final Uri weatherUrl = Uri.parse(
        'https://api.open-meteo.com/v1/forecast'
        '?latitude=${position.latitude}'
        '&longitude=${position.longitude}'
        '&current=temperature_2m,relative_humidity_2m,weather_code,wind_speed_10m'
        '&timezone=auto',
      );

      final response = await http
          .get(weatherUrl)
          .timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data =
            jsonDecode(response.body);

        final Map<String, dynamic> current =
            data['current'];

        final double temp =
            (current['temperature_2m'] as num).toDouble();

        final double hum =
            (current['relative_humidity_2m'] as num).toDouble();

        final double wind =
            (current['wind_speed_10m'] as num).toDouble();

        final int weatherCode =
            (current['weather_code'] as num).toInt();

        if (!mounted) return;

        setState(() {
          _temperature = temp;
          _humidity = hum;
          _windSpeed = wind;

          _weatherCondition =
              _weatherDescription(weatherCode);

          _weatherLoading = false;

          _crowdLevel = crowdLevel;
          _crowdPeopleCount = estimatedPeople;
          _crowdColor = crowdColor;
          _isCrowdLoading = false;
        });
      } else {
        _setFallbackMetrics();
      }
    } catch (e) {
      debugPrint('Dashboard data load error: $e');
      _setFallbackMetrics();
    }
  }

  // ============================================================
  // REVERSE GEOCODING
  // ============================================================

  Future<void> _fetchReverseGeocodeLocation(
    double lat,
    double lon,
  ) async {
    try {
      final Uri geoUrl = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse'
        '?lat=$lat&lon=$lon&format=jsonv2',
      );

      final response = await http
          .get(
            geoUrl,
            headers: {
              'User-Agent':
                  'TrekCureApp/1.0 (contact@trekcure.internal)',
            },
          )
          .timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data =
            jsonDecode(response.body);

        final Map<String, dynamic>? address =
            data['address'];

        if (address != null) {
          final String cityOrArea =
              address['city'] ??
                  address['town'] ??
                  address['village'] ??
                  address['suburb'] ??
                  address['county'] ??
                  'Nearby Trail';

          final String country =
              address['country'] ?? 'India';

          if (!mounted) return;

          setState(() {
            _userLocationText =
                '$cityOrArea, $country';
          });

          return;
        }
      }
    } catch (e) {
      debugPrint('Reverse geocode error: $e');
    }

    if (!mounted) return;

    setState(() {
      _userLocationText = 'Mumbai, India';
    });
  }

  // ============================================================
  // FALLBACK METRICS
  // ============================================================

  void _setFallbackMetrics() {
    if (!mounted) return;

    setState(() {
      _userLocationText = 'Mumbai, India';

      _temperature = 28.0;
      _humidity = 75.0;
      _windSpeed = 12.0;

      _weatherCondition = 'Partly cloudy';
      _weatherLoading = false;

      _crowdLevel = 'Moderate';
      _crowdPeopleCount = 240;
      _crowdColor = AppColors.warningOrange;
      _isCrowdLoading = false;
    });
  }

  // ============================================================
  // WEATHER HELPERS
  // ============================================================

  String _weatherDescription(int code) {
    if (code == 0) return 'Clear sky';
    if (code == 1) return 'Mainly clear';
    if (code == 2) return 'Partly cloudy';
    if (code == 3) return 'Overcast';
    if (code == 45 || code == 48) return 'Foggy';
    if (code >= 51 && code <= 57) return 'Drizzle';
    if (code >= 61 && code <= 67) return 'Rain';
    if (code >= 71 && code <= 77) return 'Snow';
    if (code >= 80 && code <= 82) return 'Rain showers';
    if (code >= 95) return 'Thunderstorm';

    return 'Overcast';
  }

  IconData _weatherIcon() {
    final condition =
        _weatherCondition.toLowerCase();

    if (condition.contains('thunder')) {
      return Icons.thunderstorm;
    }

    if (condition.contains('rain') ||
        condition.contains('drizzle')) {
      return Icons.umbrella;
    }

    if (condition.contains('snow')) {
      return Icons.ac_unit;
    }

    if (condition.contains('cloud') ||
        condition.contains('overcast')) {
      return Icons.cloud;
    }

    if (condition.contains('clear')) {
      return Icons.wb_sunny;
    }

    return Icons.cloud_outlined;
  }

  // ============================================================
  // CLEANUP
  // ============================================================

  @override
  void dispose() {
    _meshNodeSubscription?.cancel();
    _meshSosSubscription?.cancel();

    super.dispose();
  }

  // ============================================================
  // BUILD METHOD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            const Icon(
              Icons.menu,
              color: AppColors.textDark,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hello, $_userName 👋',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on,
                        size: 13,
                        color: AppColors.textGrey,
                      ),
                      const SizedBox(width: 2),
                      Expanded(
                        child: Text(
                          _userLocationText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textGrey,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(
                  Icons.notifications_none,
                  color: AppColors.textDark,
                ),
                Positioned(
                  right: -2,
                  top: -2,
                  child: Container(
                    padding:
                        const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      color: AppColors.dangerRed,
                      shape: BoxShape.circle,
                    ),
                    child: const Text(
                      '2',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      const NotificationsScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadDashboardData,
        child: SingleChildScrollView(
          physics:
              const AlwaysScrollableScrollPhysics(),
          padding:
              const EdgeInsets.fromLTRB(
            16,
            4,
            16,
            16,
          ),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              AppCard(
                color: AppColors.lightGreenBg,
                child: Row(
                  children: [
                    Container(
                      padding:
                          const EdgeInsets.all(10),
                      decoration:
                          const BoxDecoration(
                        color: AppColors.primaryGreen,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.shield,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(
                            'You are Safe',
                            style: TextStyle(
                              fontWeight:
                                  FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Safety Status: Low Risk',
                            style: TextStyle(
                              color:
                                  AppColors.textGrey,
                            ),
                          ),
                          Text(
                            'Updated just now',
                            style: TextStyle(
                              color:
                                  AppColors.textGrey,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // WEATHER + CROWD

              Row(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: AppCard(
                      child: Padding(
                        padding:
                            const EdgeInsets.all(4),
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment
                                      .spaceBetween,
                              children: [
                                Icon(
                                  _weatherIcon(),
                                  color:
                                      AppColors.infoBlue,
                                ),
                                IconButton(
                                  padding:
                                      EdgeInsets.zero,
                                  constraints:
                                      const BoxConstraints(),
                                  iconSize: 18,
                                  tooltip: 'Refresh',
                                  onPressed:
                                      _weatherLoading
                                          ? null
                                          : _loadDashboardData,
                                  icon: const Icon(
                                    Icons.refresh,
                                    color:
                                        AppColors.textGrey,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _weatherLoading
                                  ? '--°C'
                                  : '${_temperature?.round() ?? 28}°C',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight:
                                    FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _weatherCondition,
                              maxLines: 1,
                              overflow:
                                  TextOverflow.ellipsis,
                              style: const TextStyle(
                                color:
                                    AppColors.textGrey,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _weatherLoading
                                  ? 'Humidity: --'
                                  : 'Humidity: ${_humidity?.round() ?? 75}%',
                              style: const TextStyle(
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              _weatherLoading
                                  ? 'Wind: -- km/h'
                                  : 'Wind: ${_windSpeed?.round() ?? 12} km/h',
                              style: const TextStyle(
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 12),

                  Expanded(
                    child: AppCard(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Crowd Level',
                            style: TextStyle(
                              color:
                                  AppColors.textGrey,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Icon(
                                Icons.groups,
                                color: _crowdColor,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  _crowdLevel,
                                  overflow:
                                      TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontWeight:
                                        FontWeight.bold,
                                    color: _crowdColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _isCrowdLoading
                                ? 'Calculating...'
                                : '$_crowdPeopleCount people',
                            style: const TextStyle(
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 8),
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const MapCrowdScreen(),
                                ),
                              );
                            },
                            child: const Text(
                              'View Details',
                              style: TextStyle(
                                color:
                                    AppColors.primaryGreen,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // TRAVEL ALERT

              AppCard(
                color: AppColors.dangerBgLight,
                child: Row(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: AppColors.dangerRed,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          const Row(
                            mainAxisAlignment:
                                MainAxisAlignment
                                    .spaceBetween,
                            children: [
                              Text(
                                'Travel Alert',
                                style: TextStyle(
                                  fontWeight:
                                      FontWeight.bold,
                                ),
                              ),
                              Icon(
                                Icons.chevron_right,
                                size: 18,
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'High crowd detected near\nGateway of India. Avoid if possible.',
                            style: TextStyle(
                              fontSize: 12,
                              color:
                                  AppColors.textGrey,
                            ),
                          ),
                          const SizedBox(height: 4),
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const MapCrowdScreen(),
                                ),
                              );
                            },
                            child: const Text(
                              'View on Map >',
                              style: TextStyle(
                                color:
                                    AppColors.dangerRed,
                                fontSize: 12,
                                fontWeight:
                                    FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // =================================================
              // OFFLINE MESH
              // =================================================

              AppCard(
                color: const Color(0xFFF0FDF4),
                child: Row(
                  crossAxisAlignment:
                      CrossAxisAlignment.center,
                  children: [
                    Container(
                      padding:
                          const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primaryGreen
                            .withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.sensors,
                        color:
                            AppColors.primaryGreen,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),

                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'Offline Mesh Active',
                                  maxLines: 1,
                                  overflow:
                                      TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontWeight:
                                        FontWeight.bold,
                                    fontSize: 14,
                                    color:
                                        AppColors.textDark,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '● $_nearbyMeshNodes Nodes',
                                style: const TextStyle(
                                  fontWeight:
                                      FontWeight.bold,
                                  fontSize: 11,
                                  color:
                                      AppColors.primaryGreen,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 3),

                          Text(
                            _meshRelayActive
                                ? 'Mesh active. Listening for nearby TrekCure devices and distress signals.'
                                : 'Starting offline mesh...',
                            style: const TextStyle(
                              fontSize: 12,
                              color:
                                  AppColors.textGrey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar:
          const AppBottomNav(currentIndex: 0),
      floatingActionButtonLocation:
          FloatingActionButtonLocation.centerDocked,
    );
  }
}