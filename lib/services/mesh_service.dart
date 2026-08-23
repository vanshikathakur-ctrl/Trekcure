import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:nearby_connections/nearby_connections.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MeshService {
  MeshService._();

  static final MeshService instance = MeshService._();

  final Strategy _strategy = Strategy.P2P_CLUSTER;

  final StreamController<int> _nodeCountController =
      StreamController<int>.broadcast();

  Stream<int> get nodeCountStream => _nodeCountController.stream;

  final StreamController<Map<String, dynamic>> _sosController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get sosStream => _sosController.stream;

  final Map<String, String> _discoveredEndpoints = {};

  final Set<String> _connectedEndpoints = {};

  int _nearbyNodeCount = 0;

  bool _isRunning = false;
  bool _isStarting = false;

  String? _userId;
  String? _userName;

  int get nearbyNodeCount => _nearbyNodeCount;

  bool get isRunning => _isRunning;

  String _createDeviceId() {
    final random = Random();

    return 'tc_${100000 + random.nextInt(900000)}';
  }

  // ============================================================
  // REQUEST MESH PERMISSIONS
  // ============================================================

  Future<bool> _requestMeshPermissions() async {
    final permissions = [
      Permission.bluetoothScan,
      Permission.bluetoothAdvertise,
      Permission.bluetoothConnect,
      Permission.location,
      Permission.nearbyWifiDevices,
    ];

    final statuses = await permissions.request();

    final bluetoothScan =
        statuses[Permission.bluetoothScan]?.isGranted ?? false;

    final bluetoothAdvertise =
        statuses[Permission.bluetoothAdvertise]?.isGranted ?? false;

    final bluetoothConnect =
        statuses[Permission.bluetoothConnect]?.isGranted ?? false;

    final location =
        statuses[Permission.location]?.isGranted ?? false;

    return bluetoothScan &&
        bluetoothAdvertise &&
        bluetoothConnect &&
        location;
  }

  // ============================================================
  // LOAD USER NAME FROM SUPABASE
  // ============================================================

  Future<void> _loadUserName() async {
    try {
      final supabase = Supabase.instance.client;

      final user = supabase.auth.currentUser;

      if (user == null) {
        _userId ??= _createDeviceId();

        final suffix =
            _userId!.substring(_userId!.length - 4);

        _userName ??= 'T$suffix';

        return;
      }

      _userId = user.id;

      final profile = await supabase
          .from('profiles')
          .select('full_name')
          .eq('id', user.id)
          .maybeSingle();

      final fullName =
          profile?['full_name']?.toString().trim();

      if (fullName != null && fullName.isNotEmpty) {
        _userName = fullName;
      } else {
        _userName = 'TrekCure User';
      }

      debugPrint(
        'MESH USER NAME LOADED: $_userName',
      );
    } catch (e) {
      debugPrint(
        'FAILED TO LOAD MESH USER NAME: $e',
      );

      _userId ??= _createDeviceId();

      final suffix =
          _userId!.substring(_userId!.length - 4);

      _userName ??= 'T$suffix';
    }
  }

  // ============================================================
  // GET CURRENT LOCATION
  // ============================================================

  Future<Position?> _getCurrentLocation() async {
    try {
      final serviceEnabled =
          await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        debugPrint('LOCATION SERVICE IS DISABLED');
        return null;
      }

      LocationPermission permission =
          await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission =
            await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        debugPrint(
          'LOCATION PERMISSION NOT GRANTED',
        );

        return null;
      }

      final position =
          await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      debugPrint(
        'CURRENT SOS LOCATION: '
        '${position.latitude}, ${position.longitude}',
      );

      return position;
    } catch (e) {
      debugPrint(
        'FAILED TO GET SOS LOCATION: $e',
      );

      return null;
    }
  }

  // ============================================================
  // CONVERT COORDINATES TO READABLE LOCATION
  // ============================================================

  Future<String> _getReadableLocation(
    double latitude,
    double longitude,
  ) async {
    try {
      if (latitude == 0.0 && longitude == 0.0) {
        return 'Location unavailable';
      }

      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse'
        '?lat=$latitude'
        '&lon=$longitude'
        '&format=jsonv2',
      );

      final response = await http
          .get(
            uri,
            headers: {
              'User-Agent': 'TrekCure/1.0',
            },
          )
          .timeout(
            const Duration(seconds: 5),
          );

      if (response.statusCode != 200) {
        return 'Location unavailable';
      }

      final data =
          jsonDecode(response.body)
              as Map<String, dynamic>;

      final address =
          data['address'] as Map<String, dynamic>?;

      if (address == null) {
        return 'Location unavailable';
      }

      final locality =
          address['suburb'] ??
              address['neighbourhood'] ??
              address['city_district'] ??
              address['town'] ??
              address['village'] ??
              address['city'];

      final city =
          address['city'] ??
              address['town'] ??
              address['county'];

      final country =
          address['country'];

      final locationParts = <String>[];

      if (locality != null &&
          locality.toString().trim().isNotEmpty) {
        locationParts.add(
          locality.toString(),
        );
      }

      if (city != null &&
          city.toString().trim().isNotEmpty &&
          city.toString() != locality?.toString()) {
        locationParts.add(
          city.toString(),
        );
      }

      if (country != null &&
          country.toString().trim().isNotEmpty) {
        locationParts.add(
          country.toString(),
        );
      }

      if (locationParts.isEmpty) {
        return 'Location unavailable';
      }

      final readableLocation =
          locationParts.join(', ');

      debugPrint(
        'READABLE SOS LOCATION: $readableLocation',
      );

      return readableLocation;
    } catch (e) {
      debugPrint(
        'FAILED TO REVERSE GEOCODE SOS LOCATION: $e',
      );

      return 'Location unavailable';
    }
  }

  // ============================================================
  // UPDATE NODE COUNT
  // ============================================================

  void _updateNodeCount() {
    _nearbyNodeCount =
        _connectedEndpoints.length;

    debugPrint('');
    debugPrint('==============================');
    debugPrint('TREKCURE NEARBY STATUS');
    debugPrint('Local device: $_userName');
    debugPrint(
      'Connected nodes: $_nearbyNodeCount',
    );
    debugPrint(
      'Connected IDs: '
      '${_connectedEndpoints.join(", ")}',
    );
    debugPrint('==============================');
    debugPrint('');

    if (!_nodeCountController.isClosed) {
      _nodeCountController.add(
        _nearbyNodeCount,
      );
    }
  }

  // ============================================================
  // START OFFLINE NETWORK
  // ============================================================

  Future<void> start() async {
    if (_isRunning || _isStarting) {
      return;
    }

    _isStarting = true;

    try {
      final permissionsGranted =
          await _requestMeshPermissions();

      if (!permissionsGranted) {
        throw Exception(
          'Required Nearby Connections permissions '
          'were not granted',
        );
      }

      await _loadUserName();

      _userId ??= _createDeviceId();

      if (_userName == null ||
          _userName!.isEmpty) {
        final suffix =
            _userId!.substring(
          _userId!.length - 4,
        );

        _userName = 'T$suffix';
      }

      debugPrint('');
      debugPrint('==============================');
      debugPrint(
        'STARTING TREKCURE OFFLINE NETWORK',
      );
      debugPrint('User: $_userName');
      debugPrint('==============================');

      await Nearby().startAdvertising(
        _userName!,
        _strategy,
        onConnectionInitiated:
            _onConnectionInitiated,
        onConnectionResult:
            _onConnectionResult,
        onDisconnected:
            _onDisconnected,
        serviceId:
            'com.trekcure.offline_sos',
      );

      _isRunning = true;

      await Nearby().startDiscovery(
        _userName!,
        _strategy,
        onEndpointFound:
            _onEndpointFound,
        onEndpointLost: (endpointId) {
          if (endpointId != null) {
            _handleEndpointLost(
              endpointId,
            );
          }
        },
        serviceId:
            'com.trekcure.offline_sos',
      );

      _updateNodeCount();

      debugPrint('');
      debugPrint('==============================');
      debugPrint(
        'TREKCURE OFFLINE NETWORK STARTED',
      );
      debugPrint('User: $_userName');
      debugPrint('==============================');
      debugPrint('');
    } catch (e) {
      _isRunning = false;

      debugPrint(
        'OFFLINE NETWORK START ERROR: $e',
      );

      rethrow;
    } finally {
      _isStarting = false;
    }
  }

  // ============================================================
  // ENDPOINT FOUND
  // ============================================================

  void _onEndpointFound(
    String endpointId,
    String endpointName,
    String serviceId,
  ) {
    debugPrint('');
    debugPrint('==============================');
    debugPrint('ENDPOINT FOUND');
    debugPrint('Endpoint ID: $endpointId');
    debugPrint(
      'Endpoint Name: $endpointName',
    );
    debugPrint('==============================');
    debugPrint('');

    if (_discoveredEndpoints
        .containsKey(endpointId)) {
      return;
    }

    _discoveredEndpoints[endpointId] =
        endpointName;

    Nearby().requestConnection(
      _userName ?? 'TrekCure User',
      endpointId,
      onConnectionInitiated:
          _onConnectionInitiated,
      onConnectionResult:
          _onConnectionResult,
      onDisconnected:
          _onDisconnected,
    );
  }

  void _handleEndpointLost(
    String endpointId,
  ) {
    debugPrint('');
    debugPrint('==============================');
    debugPrint('ENDPOINT LOST');
    debugPrint('Endpoint ID: $endpointId');
    debugPrint('==============================');
    debugPrint('');

    _discoveredEndpoints.remove(
      endpointId,
    );

    _connectedEndpoints.remove(
      endpointId,
    );

    _updateNodeCount();
  }

  // ============================================================
  // CONNECTION INITIATED
  // ============================================================

  void _onConnectionInitiated(
    String endpointId,
    ConnectionInfo connectionInfo,
  ) {
    debugPrint('');
    debugPrint('==============================');
    debugPrint('CONNECTION INITIATED');
    debugPrint('Endpoint ID: $endpointId');
    debugPrint(
      'Device: ${connectionInfo.endpointName}',
    );
    debugPrint('==============================');
    debugPrint('');

    _discoveredEndpoints[endpointId] =
        connectionInfo.endpointName;

    Nearby().acceptConnection(
      endpointId,
      onPayLoadRecieved:
          _onPayloadReceived,
      onPayloadTransferUpdate:
          _onPayloadTransferUpdate,
    );
  }

  // ============================================================
  // CONNECTION RESULT
  // ============================================================

  void _onConnectionResult(
    String endpointId,
    Status status,
  ) {
    debugPrint('');
    debugPrint('==============================');
    debugPrint('CONNECTION RESULT');
    debugPrint('Endpoint ID: $endpointId');
    debugPrint('Status: $status');
    debugPrint('==============================');
    debugPrint('');

    if (status == Status.CONNECTED) {
      _connectedEndpoints.add(
        endpointId,
      );

      debugPrint(
        'DEVICE CONNECTED: $endpointId',
      );
    } else {
      _connectedEndpoints.remove(
        endpointId,
      );

      debugPrint(
        'CONNECTION FAILED: $endpointId',
      );
    }

    _updateNodeCount();
  }

  void _onDisconnected(
    String endpointId,
  ) {
    _connectedEndpoints.remove(
      endpointId,
    );

    _discoveredEndpoints.remove(
      endpointId,
    );

    debugPrint(
      'DEVICE DISCONNECTED: $endpointId',
    );

    _updateNodeCount();
  }

  // ============================================================
  // RECEIVE SOS
  // ============================================================

  void _onPayloadReceived(
    String endpointId,
    Payload payload,
  ) {
    if (payload.type != PayloadType.BYTES) {
      return;
    }

    final bytes = payload.bytes;

    if (bytes == null) {
      return;
    }

    final message =
        utf8.decode(bytes);

    debugPrint('');
    debugPrint('==============================');
    debugPrint('OFFLINE MESSAGE RECEIVED');
    debugPrint('Endpoint ID: $endpointId');
    debugPrint('Payload: $message');
    debugPrint('==============================');
    debugPrint('');

    if (!message
        .toUpperCase()
        .startsWith('SOS|')) {
      debugPrint(
        'Non-SOS message ignored',
      );

      return;
    }

    final parts =
        message.split('|');

    String senderName =
        'Unknown user';

    if (parts.length >= 5 &&
        parts[4].trim().isNotEmpty) {
      senderName = parts[4];
    }

    String readableLocation =
        'Location unavailable';

    if (parts.length >= 6 &&
        parts[5].trim().isNotEmpty) {
      readableLocation =
          parts[5];
    }

    debugPrint('');
    debugPrint('==============================');
    debugPrint('REMOTE SOS RECEIVED');
    debugPrint('From: $senderName');
    debugPrint(
      'Location: $readableLocation',
    );
    debugPrint('On device: $_userName');
    debugPrint('==============================');
    debugPrint('');

    if (!_sosController.isClosed) {
      _sosController.add({
        'senderName': senderName,
        'payload': message,
        'message':
            parts.length > 1
                ? parts[1]
                : '',
        'latitude':
            parts.length > 2
                ? parts[2]
                : 'Unavailable',
        'longitude':
            parts.length > 3
                ? parts[3]
                : 'Unavailable',
        'location':
            readableLocation,
        'receivedAt':
            DateTime.now()
                .toIso8601String(),
      });

      debugPrint(
        'SOS FORWARDED TO DASHBOARD',
      );
    }
  }

  void _onPayloadTransferUpdate(
    String endpointId,
    PayloadTransferUpdate update,
  ) {
    debugPrint(
      'Payload update from $endpointId: '
      '${update.status}',
    );
  }

  // ============================================================
  // BROADCAST SOS
  // ============================================================

  Future<void> broadcastSos({
    required String message,
    double? latitude,
    double? longitude,
  }) async {
    if (!_isRunning) {
      throw Exception(
        'Offline network is not running',
      );
    }

    if (_connectedEndpoints.isEmpty) {
      throw Exception(
        'No nearby devices are connected yet',
      );
    }

    await _loadUserName();

    Position? position;

    if (latitude == null ||
        longitude == null) {
      position =
          await _getCurrentLocation();
    }

    final sosLatitude =
        latitude ??
            position?.latitude ??
            0.0;

    final sosLongitude =
        longitude ??
            position?.longitude ??
            0.0;

    final senderName =
        (_userName == null ||
                _userName!.isEmpty)
            ? 'TrekCure User'
            : _userName!;

    final readableLocation =
        await _getReadableLocation(
      sosLatitude,
      sosLongitude,
    );

    final payload =
        'SOS|$message|'
        '$sosLatitude|'
        '$sosLongitude|'
        '$senderName|'
        '$readableLocation';

    final payloadBytes =
        utf8.encode(payload);

    debugPrint('');
    debugPrint('==============================');
    debugPrint('BROADCASTING OFFLINE SOS');
    debugPrint('From: $senderName');
    debugPrint(
      'Location: $readableLocation',
    );
    debugPrint(
      'Coordinates: '
      '$sosLatitude, $sosLongitude',
    );
    debugPrint(
      'Connected devices: '
      '${_connectedEndpoints.length}',
    );
    debugPrint('Payload: $payload');
    debugPrint('==============================');
    debugPrint('');

    final endpoints =
        _connectedEndpoints.toList();

    for (final endpointId
        in endpoints) {
      try {
        await Nearby().sendBytesPayload(
          endpointId,
          payloadBytes,
        );

        debugPrint(
          'SOS SENT TO ENDPOINT: '
          '$endpointId',
        );
      } catch (e) {
        debugPrint(
          'FAILED TO SEND TO '
          '$endpointId: $e',
        );
      }
    }

    debugPrint('');
    debugPrint('==============================');
    debugPrint('SOS BROADCAST COMPLETE');
    debugPrint('==============================');
    debugPrint('');
  }

  // ============================================================
  // STOP OFFLINE NETWORK
  // ============================================================

  Future<void> stop() async {
    try {
      await Nearby().stopAdvertising();

      await Nearby().stopDiscovery();

      for (final endpointId
          in _connectedEndpoints.toList()) {
        try {
          await Nearby()
              .disconnectFromEndpoint(
            endpointId,
          );
        } catch (_) {}
      }

      _discoveredEndpoints.clear();

      _connectedEndpoints.clear();

      _nearbyNodeCount = 0;

      _isRunning = false;

      _isStarting = false;

      if (!_nodeCountController.isClosed) {
        _nodeCountController.add(0);
      }

      debugPrint(
        'TREKCURE OFFLINE NETWORK STOPPED',
      );
    } catch (e) {
      debugPrint(
        'OFFLINE NETWORK STOP ERROR: $e',
      );
    }
  }

  Future<void> dispose() async {
    await stop();

    if (!_nodeCountController.isClosed) {
      await _nodeCountController.close();
    }

    if (!_sosController.isClosed) {
      await _sosController.close();
    }
  }
}