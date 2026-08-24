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

  final StreamController<Map<String, dynamic>> _sosController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<int> get nodeCountStream => _nodeCountController.stream;

  Stream<Map<String, dynamic>> get sosStream => _sosController.stream;

  final Map<String, String> _discoveredEndpoints = {};

  final Set<String> _connectedEndpoints = {};

  final Set<String> _connectingEndpoints = {};

  int _nearbyNodeCount = 0;

  bool _isRunning = false;

  bool _isStarting = false;

  String? _userId;

  String? _userName;

  int get nearbyNodeCount => _nearbyNodeCount;

  bool get isRunning => _isRunning;

  // ============================================================
  // CREATE LOCAL DEVICE ID
  // ============================================================

  String _createDeviceId() {
    final random = Random();

    return 'tc_${100000 + random.nextInt(900000)}';
  }

  // ============================================================
  // CREATE UNIQUE OFFLINE SOS ID
  // ============================================================

  String _createSosId() {
    final random = Random();

    return 'offline_'
        '${DateTime.now().millisecondsSinceEpoch}_'
        '${1000 + random.nextInt(9000)}';
  }

  // ============================================================
  // REQUEST REQUIRED PERMISSIONS
  // ============================================================

  Future<bool> _requestMeshPermissions() async {
    final permissions = <Permission>[
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

    final nearbyWifiGranted =
        statuses[Permission.nearbyWifiDevices]?.isGranted ?? true;

    debugPrint('');
    debugPrint('==============================');
    debugPrint('TREKCURE MESH PERMISSIONS');
    debugPrint('Bluetooth Scan: $bluetoothScan');
    debugPrint('Bluetooth Advertise: $bluetoothAdvertise');
    debugPrint('Bluetooth Connect: $bluetoothConnect');
    debugPrint('Location: $location');
    debugPrint('Nearby WiFi: $nearbyWifiGranted');
    debugPrint('==============================');
    debugPrint('');

    return bluetoothScan &&
        bluetoothAdvertise &&
        bluetoothConnect &&
        location;
  }

  // ============================================================
  // LOAD USER INFORMATION
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
        final metadataName =
            user.userMetadata?['full_name']
                ?.toString()
                .trim();

        if (metadataName != null &&
            metadataName.isNotEmpty) {
          _userName = metadataName;
        } else {
          _userName = 'TrekCure User';
        }
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
          permission ==
              LocationPermission.deniedForever) {
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
  // REVERSE GEOCODE LOCATION
  // ============================================================

  Future<String> _getReadableLocation(
    double latitude,
    double longitude,
  ) async {
    try {
      if (latitude == 0.0 &&
          longitude == 0.0) {
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
          data['address']
              as Map<String, dynamic>?;

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

      final state =
          address['state'];

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
          city.toString() !=
              locality?.toString()) {
        locationParts.add(
          city.toString(),
        );
      }

      if (state != null &&
          state.toString().trim().isNotEmpty &&
          state.toString() !=
              city?.toString()) {
        locationParts.add(
          state.toString(),
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
        'READABLE SOS LOCATION: '
        '$readableLocation',
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
      'Discovered devices: '
      '${_discoveredEndpoints.length}',
    );
    debugPrint(
      'Connected devices: '
      '$_nearbyNodeCount',
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
    if (_isRunning) {
      debugPrint(
        'TREKCURE OFFLINE NETWORK ALREADY RUNNING',
      );

      return;
    }

    if (_isStarting) {
      debugPrint(
        'TREKCURE OFFLINE NETWORK ALREADY STARTING',
      );

      return;
    }

    _isStarting = true;

    try {
      final permissionsGranted =
          await _requestMeshPermissions();

      if (!permissionsGranted) {
        throw Exception(
          'Bluetooth and location permissions '
          'are required for Offline SOS.',
        );
      }

      await _loadUserName();

      _userId ??= _createDeviceId();

      if (_userName == null ||
          _userName!.trim().isEmpty) {
        final suffix =
            _userId!.substring(
          _userId!.length - 4,
        );

        _userName = 'T$suffix';
      }

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

      await Nearby().startDiscovery(
        _userName!,
        _strategy,
        onEndpointFound:
            _onEndpointFound,
        onEndpointLost:
            _onEndpointLost,
        serviceId:
            'com.trekcure.offline_sos',
      );

      _isRunning = true;

      _updateNodeCount();

      debugPrint(
        'TREKCURE OFFLINE NETWORK STARTED',
      );
    } catch (e) {
      _isRunning = false;

      try {
        await Nearby().stopAdvertising();
      } catch (_) {}

      try {
        await Nearby().stopDiscovery();
      } catch (_) {}

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
    if (endpointId.isEmpty) {
      return;
    }

    _discoveredEndpoints[endpointId] =
        endpointName;

    if (_connectedEndpoints.contains(endpointId) ||
        _connectingEndpoints.contains(endpointId)) {
      return;
    }

    _connectingEndpoints.add(endpointId);

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

  // ============================================================
  // ENDPOINT LOST
  // ============================================================

  void _onEndpointLost(
    String? endpointId,
  ) {
    if (endpointId == null ||
        endpointId.isEmpty) {
      return;
    }

    _discoveredEndpoints.remove(endpointId);
    _connectedEndpoints.remove(endpointId);
    _connectingEndpoints.remove(endpointId);

    _updateNodeCount();
  }

  // ============================================================
  // CONNECTION INITIATED
  // ============================================================

  void _onConnectionInitiated(
    String endpointId,
    ConnectionInfo connectionInfo,
  ) {
    _discoveredEndpoints[endpointId] =
        connectionInfo.endpointName;

    _connectingEndpoints.add(endpointId);

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
    _connectingEndpoints.remove(endpointId);

    if (status == Status.CONNECTED) {
      _connectedEndpoints.add(endpointId);

      debugPrint(
        'DEVICE CONNECTED: $endpointId',
      );
    } else {
      _connectedEndpoints.remove(endpointId);

      debugPrint(
        'CONNECTION FAILED: $endpointId',
      );
    }

    _updateNodeCount();
  }

  // ============================================================
  // DEVICE DISCONNECTED
  // ============================================================

  void _onDisconnected(
    String endpointId,
  ) {
    _connectedEndpoints.remove(endpointId);

    _connectingEndpoints.remove(endpointId);

    _discoveredEndpoints.remove(endpointId);

    debugPrint(
      'DEVICE DISCONNECTED: $endpointId',
    );

    _updateNodeCount();
  }

  // ============================================================
  // RECEIVE PAYLOAD
  //
  // SOS FORMAT:
  //
  // SOS|sosId|message|latitude|longitude|senderName|location
  //
  // CANCELLATION FORMAT:
  //
  // SOS_CANCELLED|sosId|senderName
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

    String message;

    try {
      message = utf8.decode(bytes);
    } catch (e) {
      debugPrint(
        'FAILED TO DECODE OFFLINE PAYLOAD: $e',
      );

      return;
    }

    final parts =
        message.split('|');

    if (parts.isEmpty) {
      return;
    }

    final messageType =
        parts.first.toUpperCase();

    // ============================================================
    // SOS CANCELLATION RECEIVED
    // ============================================================

    if (messageType == 'SOS_CANCELLED') {
      final sosId =
          parts.length > 1
              ? parts[1].trim()
              : '';

      final senderName =
          parts.length > 2 &&
                  parts[2].trim().isNotEmpty
              ? parts[2].trim()
              : 'Unknown TrekCure User';

      if (sosId.isEmpty) {
        debugPrint(
          'INVALID SOS CANCELLATION RECEIVED',
        );

        return;
      }

      debugPrint('');
      debugPrint('==============================');
      debugPrint('REMOTE SOS CANCELLED');
      debugPrint('SOS ID: $sosId');
      debugPrint('From: $senderName');
      debugPrint('==============================');
      debugPrint('');

      if (!_sosController.isClosed) {
        _sosController.add({
          'type': 'SOS_CANCELLED',
          'sosId': sosId,
          'senderName': senderName,
          'payload': message,
          'endpointId': endpointId,
          'receivedAt':
              DateTime.now()
                  .toIso8601String(),
        });
      }

      return;
    }

    // ============================================================
    // NORMAL SOS RECEIVED
    // ============================================================

    if (messageType != 'SOS') {
      debugPrint(
        'NON-SOS MESSAGE IGNORED',
      );

      return;
    }

    if (parts.length < 2 ||
        parts[1].trim().isEmpty) {
      debugPrint(
        'INVALID SOS RECEIVED: MISSING SOS ID',
      );

      return;
    }

    final sosId =
        parts[1].trim();

    final sosMessage =
        parts.length > 2 &&
                parts[2].trim().isNotEmpty
            ? parts[2]
            : 'Emergency SOS';

    final latitude =
        parts.length > 3
            ? parts[3]
            : 'Unavailable';

    final longitude =
        parts.length > 4
            ? parts[4]
            : 'Unavailable';

    final senderName =
        parts.length > 5 &&
                parts[5].trim().isNotEmpty
            ? parts[5].trim()
            : 'Unknown TrekCure User';

    final readableLocation =
        parts.length > 6 &&
                parts[6].trim().isNotEmpty
            ? parts[6].trim()
            : 'Location unavailable';

    debugPrint('');
    debugPrint('==============================');
    debugPrint('REMOTE SOS RECEIVED');
    debugPrint('SOS ID: $sosId');
    debugPrint('From: $senderName');
    debugPrint('Message: $sosMessage');
    debugPrint('Location: $readableLocation');
    debugPrint('==============================');
    debugPrint('');

    if (!_sosController.isClosed) {
      _sosController.add({
        'type': 'SOS',
        'sosId': sosId,
        'senderName': senderName,
        'payload': message,
        'message': sosMessage,
        'latitude': latitude,
        'longitude': longitude,
        'location': readableLocation,
        'endpointId': endpointId,
        'receivedAt':
            DateTime.now()
                .toIso8601String(),
      });
    }
  }

  // ============================================================
  // PAYLOAD TRANSFER STATUS
  // ============================================================

  void _onPayloadTransferUpdate(
    String endpointId,
    PayloadTransferUpdate update,
  ) {
    debugPrint(
      'PAYLOAD UPDATE '
      '[$endpointId]: '
      '${update.status}',
    );
  }

  // ============================================================
  // BROADCAST OFFLINE SOS
  //
  // RETURNS THE UNIQUE SOS ID
  // ============================================================

  Future<String> broadcastSos({
    required String message,
    double? latitude,
    double? longitude,
  }) async {
    if (!_isRunning) {
      throw Exception(
        'Offline network is not running.',
      );
    }

    if (_connectedEndpoints.isEmpty) {
      throw Exception(
        'No nearby TrekCure devices are connected yet.',
      );
    }

    await _loadUserName();

    final sosId = _createSosId();

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
                _userName!.trim().isEmpty)
            ? 'TrekCure User'
            : _userName!.trim();

    final readableLocation =
        await _getReadableLocation(
      sosLatitude,
      sosLongitude,
    );

    final payload =
        'SOS|'
        '$sosId|'
        '$message|'
        '$sosLatitude|'
        '$sosLongitude|'
        '$senderName|'
        '$readableLocation';

    final payloadBytes =
        utf8.encode(payload);

    final endpoints =
        _connectedEndpoints.toList();

    int successfulSends = 0;

    for (final endpointId in endpoints) {
      try {
        await Nearby().sendBytesPayload(
          endpointId,
          payloadBytes,
        );

        successfulSends++;

        debugPrint(
          'SOS SENT TO: $endpointId',
        );
      } catch (e) {
        debugPrint(
          'FAILED TO SEND SOS TO '
          '$endpointId: $e',
        );

        _connectedEndpoints.remove(
          endpointId,
        );
      }
    }

    _updateNodeCount();

    if (successfulSends == 0) {
      throw Exception(
        'Unable to deliver SOS to any nearby device.',
      );
    }

    debugPrint('');
    debugPrint('==============================');
    debugPrint('SOS BROADCAST COMPLETE');
    debugPrint('SOS ID: $sosId');
    debugPrint(
      'Delivered to: '
      '$successfulSends device(s)',
    );
    debugPrint('==============================');
    debugPrint('');

    return sosId;
  }

  // ============================================================
  // BROADCAST SOS CANCELLATION
  // ============================================================

  Future<void> broadcastSosCancellation({
    required String sosId,
  }) async {
    if (!_isRunning) {
      throw Exception(
        'Offline network is not running.',
      );
    }

    if (sosId.trim().isEmpty) {
      throw Exception(
        'Invalid SOS ID.',
      );
    }

    if (_connectedEndpoints.isEmpty) {
      throw Exception(
        'No nearby TrekCure devices are connected.',
      );
    }

    await _loadUserName();

    final senderName =
        (_userName == null ||
                _userName!.trim().isEmpty)
            ? 'TrekCure User'
            : _userName!.trim();

    final payload =
        'SOS_CANCELLED|'
        '${sosId.trim()}|'
        '$senderName';

    final payloadBytes =
        utf8.encode(payload);

    final endpoints =
        _connectedEndpoints.toList();

    int successfulSends = 0;

    for (final endpointId in endpoints) {
      try {
        await Nearby().sendBytesPayload(
          endpointId,
          payloadBytes,
        );

        successfulSends++;

        debugPrint(
          'SOS CANCELLATION SENT TO: '
          '$endpointId',
        );
      } catch (e) {
        debugPrint(
          'FAILED TO SEND SOS CANCELLATION '
          'TO $endpointId: $e',
        );

        _connectedEndpoints.remove(
          endpointId,
        );
      }
    }

    _updateNodeCount();

    if (successfulSends == 0) {
      throw Exception(
        'Unable to deliver SOS cancellation '
        'to any nearby device.',
      );
    }

    debugPrint('');
    debugPrint('==============================');
    debugPrint(
      'SOS CANCELLATION BROADCAST COMPLETE',
    );
    debugPrint('SOS ID: $sosId');
    debugPrint(
      'Delivered to: '
      '$successfulSends device(s)',
    );
    debugPrint('==============================');
    debugPrint('');
  }

  // ============================================================
  // STOP OFFLINE NETWORK
  // ============================================================

  Future<void> stop() async {
    try {
      await Nearby().stopAdvertising();
    } catch (e) {
      debugPrint(
        'STOP ADVERTISING ERROR: $e',
      );
    }

    try {
      await Nearby().stopDiscovery();
    } catch (e) {
      debugPrint(
        'STOP DISCOVERY ERROR: $e',
      );
    }

    for (final endpointId
        in _connectedEndpoints.toList()) {
      try {
        await Nearby()
            .disconnectFromEndpoint(
          endpointId,
        );
      } catch (e) {
        debugPrint(
          'DISCONNECT ERROR '
          '[$endpointId]: $e',
        );
      }
    }

    _discoveredEndpoints.clear();

    _connectedEndpoints.clear();

    _connectingEndpoints.clear();

    _nearbyNodeCount = 0;

    _isRunning = false;

    _isStarting = false;

    if (!_nodeCountController.isClosed) {
      _nodeCountController.add(0);
    }

    debugPrint(
      'TREKCURE OFFLINE NETWORK STOPPED',
    );
  }

  // ============================================================
  // DISPOSE
  // ============================================================

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