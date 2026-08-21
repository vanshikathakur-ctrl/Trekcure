import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_heatmap/flutter_map_heatmap.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../theme/app_theme.dart';
import '../widgets/bottom_nav.dart';

class MapCrowdScreen extends StatefulWidget {
  const MapCrowdScreen({super.key});

  @override
  State<MapCrowdScreen> createState() => _MapCrowdScreenState();
}

class _MapCrowdScreenState extends State<MapCrowdScreen> {
  final MapController _mapController = MapController();

  LatLng? _userLocation;

  List<WeightedLatLng> _crowdPoints = [];

  StreamSubscription<Position>? _locationSubscription;

  bool _isLoading = true;
  bool _locationError = false;

  String _crowdLevel = 'Loading...';
  int _density = 0;

  @override
  void initState() {
    super.initState();
    _getLocation();
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    super.dispose();
  }

  // ============================================================
  // LOCATION
  // ============================================================

  Future<void> _getLocation() async {
    try {
      // Check whether GPS is enabled.
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        _showLocationError(
          'Location services are disabled. Please turn on GPS.',
        );
        return;
      }

      // Check permission.
      LocationPermission permission = await Geolocator.checkPermission();

      // Ask for permission if necessary.
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        _showLocationError('Location permission was denied.');
        return;
      }

      if (permission == LocationPermission.deniedForever) {
        _showLocationError(
          'Location permission is permanently denied. '
          'Please enable it from Settings.',
        );
        return;
      }

      // Get current location.
      final Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      _updateLocation(position);

      // Continue tracking location.
      _locationSubscription =
          Geolocator.getPositionStream(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              distanceFilter: 50,
            ),
          ).listen((Position position) {
            _updateLocation(position);
          });
    } catch (e) {
      _showLocationError('Unable to get your current location.');
    }
  }

  // ============================================================
  // UPDATE USER LOCATION
  // ============================================================

  void _updateLocation(Position position) {
    if (!mounted) return;

    final LatLng location = LatLng(position.latitude, position.longitude);

    setState(() {
      _userLocation = location;
      _isLoading = false;
      _locationError = false;
    });

    // Generate crowd data around current location.
    _generateCrowdData(location);

    // Move map to current location.
    _mapController.move(location, 14.0);
  }

  // ============================================================
  // CROWD DATA
  //
  // IMPORTANT:
  // These values are currently DEMO DATA.
  //
  // Later this function can be replaced with:
  //
  // API / Supabase crowd data
  //             ↓
  //       _crowdPoints
  //             ↓
  //          Heatmap
  // ============================================================

  void _generateCrowdData(LatLng center) {
    final Random random = Random();

    final List<WeightedLatLng> points = [];

    // Keep track of density separately because
    // WeightedLatLng in flutter_map_heatmap 0.0.8
    // does not expose a "weight" getter.
    double totalDensity = 0;

    // Create 100 density points around the user.
    for (int i = 0; i < 100; i++) {
      final double latitudeOffset = (random.nextDouble() - 0.5) * 0.05;

      final double longitudeOffset = (random.nextDouble() - 0.5) * 0.05;

      // Density between 0.1 and 1.0.
      final double density = 0.1 + random.nextDouble() * 0.9;

      totalDensity += density;

      points.add(
        WeightedLatLng(
          LatLng(
            center.latitude + latitudeOffset,
            center.longitude + longitudeOffset,
          ),
          density,
        ),
      );
    }

    // Calculate average density.
    final double averageDensity = totalDensity / points.length;

    final int percentage = (averageDensity * 100).round();

    String level;

    if (percentage <= 30) {
      level = 'Low';
    } else if (percentage <= 70) {
      level = 'Moderate';
    } else {
      level = 'High';
    }

    if (!mounted) return;

    setState(() {
      _crowdPoints = points;
      _density = percentage;
      _crowdLevel = level;
    });
  }

  // ============================================================
  // REFRESH HEATMAP
  // ============================================================

  void _refreshHeatmap() {
    if (_userLocation == null) {
      _getLocation();
      return;
    }

    _generateCrowdData(_userLocation!);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Crowd heatmap updated'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  // ============================================================
  // MOVE TO USER LOCATION
  // ============================================================

  void _goToCurrentLocation() {
    if (_userLocation == null) {
      _getLocation();
      return;
    }

    _mapController.move(_userLocation!, 15.0);
  }

  // ============================================================
  // LOCATION ERROR
  // ============================================================

  void _showLocationError(String message) {
    if (!mounted) return;

    setState(() {
      _isLoading = false;
      _locationError = true;
    });

    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Crowd Map',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            onPressed: _refreshHeatmap,
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),

      body: Column(
        children: [
          // ======================================================
          // MAP
          // ======================================================

          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: _buildMap(),
              ),
            ),
          ),

          // ======================================================
          // LEGEND
          // ======================================================
          _buildLegend(),

          // ======================================================
          // CROWD INFORMATION
          // ======================================================
          _buildCrowdCard(),
        ],
      ),

      // ========================================================
      // CURRENT LOCATION BUTTON
      // ========================================================
      floatingActionButton: FloatingActionButton(
        onPressed: _goToCurrentLocation,
        tooltip: 'My Location',
        child: const Icon(Icons.my_location),
      ),

      // ========================================================
      // BOTTOM NAVIGATION
      // ========================================================
      bottomNavigationBar: const AppBottomNav(currentIndex: 1),
    );
  }

  // ============================================================
  // MAP
  // ============================================================

  Widget _buildMap() {
    // Mumbai is only used as a temporary default
    // before GPS location is obtained.
    const LatLng defaultLocation = LatLng(19.0760, 72.8777);

    return FlutterMap(
      mapController: _mapController,

      options: MapOptions(
        initialCenter: _userLocation ?? defaultLocation,
        initialZoom: 14.0,
        minZoom: 5.0,
        maxZoom: 19.0,
      ),

      children: [
        // ======================================================
        // OPEN STREET MAP
        // ======================================================

        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.trekcure.app',
        ),

        // ======================================================
        // HEATMAP
        // ======================================================
        if (_crowdPoints.isNotEmpty)
          HeatMapLayer(
            heatMapDataSource: InMemoryHeatMapDataSource(data: _crowdPoints),

            heatMapOptions: HeatMapOptions(
              radius: 35,
              blurFactor: 0.8,
              minOpacity: 0.25,

              // Removed "const" because it caused
              // the constant evaluation error.
              gradient: {
                0.0: Colors.green,
                0.35: Colors.yellow,
                0.60: Colors.orange,
                1.0: Colors.red,
              },
            ),
          ),

        // ======================================================
        // USER LOCATION MARKER
        // ======================================================
        if (_userLocation != null)
          MarkerLayer(
            markers: [
              Marker(
                point: _userLocation!,
                width: 50,
                height: 50,

                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.blue.withOpacity(0.20),
                  ),

                  child: const Icon(
                    Icons.location_on,
                    color: Colors.blue,
                    size: 36,
                  ),
                ),
              ),
            ],
          ),

        // ======================================================
        // LOADING
        // ======================================================
        if (_isLoading) const Center(child: CircularProgressIndicator()),

        // ======================================================
        // LOCATION ERROR
        // ======================================================
        if (_locationError)
          Center(
            child: Container(
              margin: const EdgeInsets.all(30),
              padding: const EdgeInsets.all(20),

              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(blurRadius: 10, color: Colors.black26),
                ],
              ),

              child: Column(
                mainAxisSize: MainAxisSize.min,

                children: [
                  const Icon(Icons.location_off, size: 40, color: Colors.red),

                  const SizedBox(height: 10),

                  const Text(
                    'Location unavailable',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),

                  const SizedBox(height: 10),

                  ElevatedButton(
                    onPressed: _getLocation,
                    child: const Text('Try Again'),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  // ============================================================
  // LEGEND
  // ============================================================

  Widget _buildLegend() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),

      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,

        children: [
          _buildLegendItem(Colors.green, 'Low'),

          const SizedBox(width: 22),

          _buildLegendItem(Colors.orange, 'Moderate'),

          const SizedBox(width: 22),

          _buildLegendItem(Colors.red, 'High'),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,

      children: [
        Container(
          width: 12,
          height: 12,

          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),

        const SizedBox(width: 6),

        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppColors.textGrey),
        ),
      ],
    );
  }

  // ============================================================
  // CROWD CARD
  // ============================================================

  Widget _buildCrowdCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),

      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            const Text(
              'Crowd Overview',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 8),

            Text(
              _userLocation == null
                  ? 'Getting your current location...'
                  : 'Crowd density around your current location.',
              style: const TextStyle(color: AppColors.textGrey, fontSize: 13),
            ),

            const SizedBox(height: 14),

            Row(
              children: [
                // CURRENT CROWD

                Expanded(
                  child: _buildCrowdInfo(
                    Icons.groups,
                    _crowdLevel,
                    'Current Crowd',
                    _getCrowdColor(),
                  ),
                ),

                Container(width: 1, height: 45, color: Colors.grey),

                // DENSITY
                Expanded(
                  child: _buildCrowdInfo(
                    Icons.percent,
                    '$_density%',
                    'Density',
                    _getCrowdColor(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // CROWD INFO
  // ============================================================

  Widget _buildCrowdInfo(
    IconData icon,
    String value,
    String label,
    Color color,
  ) {
    return Column(
      children: [
        Icon(icon, color: color, size: 23),

        const SizedBox(height: 5),

        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: color,
            fontSize: 14,
          ),
        ),

        const SizedBox(height: 2),

        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 10, color: AppColors.textGrey),
        ),
      ],
    );
  }

  // ============================================================
  // CROWD COLOR
  // ============================================================

  Color _getCrowdColor() {
    if (_density <= 30) {
      return Colors.green;
    }

    if (_density <= 70) {
      return Colors.orange;
    }

    return Colors.red;
  }
}
