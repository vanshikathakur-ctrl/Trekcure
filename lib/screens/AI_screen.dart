import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

import '../services/gemini_service.dart';
import '../services/trekcure_api_service.dart';
import '../theme/app_theme.dart';

class AiAgentScreen extends StatefulWidget {
  const AiAgentScreen({super.key});

  @override
  State<AiAgentScreen> createState() => _AiAgentScreenState();
}

class _AiAgentScreenState extends State<AiAgentScreen> {
  // ============================================================
  // CONTROLLERS
  // ============================================================

  final TextEditingController _messageController = TextEditingController();

  final ScrollController _scrollController = ScrollController();

  // ============================================================
  // STATE
  // ============================================================

  final List<_ChatMessage> _messages = [];

  bool _loading = false;
  bool _loadingContext = true;

  // ============================================================
  // CURRENT TREKCURE DATA
  // ============================================================

  Position? _position;

  String _location = 'Current location';

  double? _temperature;
  double? _humidity;
  double? _windSpeed;

  String _weather = 'Unavailable';
  String _weatherRisk = 'Unavailable';

  String _crowdLevel = 'Unavailable';
  int _crowdDensity = 0;
  int _estimatedPeople = 0;

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    _messages.add(
      const _ChatMessage(
        text:
            'Hello! I am TrekCure AI 🤖\n\n'
            'I can analyse your current weather, crowd and safety '
            'conditions, and answer your travel and trekking questions.\n\n'
            'Try asking:\n'
            '• Is it safe to trek now?\n'
            '• Analyse my current conditions\n'
            '• What precautions should I take?\n'
            '• What should I carry?',
        isUser: false,
      ),
    );

    _loadCurrentContext();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ============================================================
  // LOAD CURRENT LOCATION + WEATHER
  // ============================================================

  Future<void> _loadCurrentContext() async {
    if (!mounted) return;

    setState(() {
      _loadingContext = true;
    });

    try {
      final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        throw Exception('Location services are disabled.');
      }

      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception('Location permission was not granted.');
      }

      final Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
        ),
      );

      _position = position;

      await _loadLocationName(position.latitude, position.longitude);

      try {
        final Map<String, dynamic> weatherData =
            await TrekCureApiService.getWeather(
              latitude: position.latitude,
              longitude: position.longitude,
            );

        _parseWeather(weatherData);
      } catch (e) {
        debugPrint('AI weather load error: $e');
      }

      _setCrowdData();

      if (!mounted) return;

      setState(() {
        _loadingContext = false;
      });
    } catch (e) {
      debugPrint('AI context error: $e');

      if (!mounted) return;

      setState(() {
        _loadingContext = false;
      });
    }
  }

  // ============================================================
  // LOCATION NAME
  // ============================================================

  Future<void> _loadLocationName(double latitude, double longitude) async {
    try {
      final Geocoding geocoding = Geocoding();

      final List<Placemark> places = await geocoding.placemarkFromCoordinates(
        latitude,
        longitude,
      );

      if (places.isEmpty) return;

      final Placemark place = places.first;

      final String area = place.locality?.trim().isNotEmpty == true
          ? place.locality!
          : place.subAdministrativeArea?.trim().isNotEmpty == true
          ? place.subAdministrativeArea!
          : 'Current location';

      final String country = place.country?.trim().isNotEmpty == true
          ? place.country!
          : '';

      if (!mounted) return;

      setState(() {
        _location = country.isEmpty ? area : '$area, $country';
      });
    } catch (e) {
      debugPrint('AI geocoding error: $e');
    }
  }

  // ============================================================
  // WEATHER PARSER
  // ============================================================

  void _parseWeather(Map<String, dynamic> data) {
    final dynamic current = data['current'];

    if (current is Map) {
      _temperature = _toDouble(current['temperature']);

      _humidity = _toDouble(current['humidity']);

      _windSpeed = _toDouble(current['wind_speed']);

      _weather =
          current['weather']?.toString() ??
          current['condition']?.toString() ??
          'Unavailable';

      _weatherRisk =
          current['risk_level']?.toString() ??
          current['risk']?.toString() ??
          _calculateWeatherRisk(
            temperature: _temperature,
            windSpeed: _windSpeed,
          );

      return;
    }

    // ------------------------------------------------------------
    // Support flat FastAPI response
    // ------------------------------------------------------------

    _temperature = _toDouble(data['temperature']);

    _humidity = _toDouble(data['humidity']);

    _windSpeed = _toDouble(data['wind_speed']);

    _weather =
        data['weather']?.toString() ??
        data['condition']?.toString() ??
        data['weather_condition']?.toString() ??
        'Unavailable';

    _weatherRisk =
        data['risk_level']?.toString() ??
        data['risk']?.toString() ??
        'Unavailable';

    if (_weatherRisk == 'Unavailable') {
      _weatherRisk = _calculateWeatherRisk(
        temperature: _temperature,
        windSpeed: _windSpeed,
      );
    }
  }

  // ============================================================
  // SAFE NUMBER CONVERSION
  // ============================================================

  double? _toDouble(dynamic value) {
    if (value == null) return null;

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value.toString());
  }

  // ============================================================
  // WEATHER RISK FALLBACK
  // ============================================================

  String _calculateWeatherRisk({double? temperature, double? windSpeed}) {
    if (temperature == null && windSpeed == null) {
      return 'Unavailable';
    }

    final double temp = temperature ?? 25;
    final double wind = windSpeed ?? 0;

    if (temp >= 40 || temp <= 0 || wind >= 50) {
      return 'HIGH';
    }

    if (temp >= 35 || temp <= 5 || wind >= 30) {
      return 'MODERATE';
    }

    return 'SAFE';
  }

  // ============================================================
  // CROWD DATA
  // ============================================================

  void _setCrowdData() {
    /*
     * Your current map/dashboard generates an estimated crowd
     * value locally.
     *
     * We reproduce a stable estimate here using the current
     * coordinates so the AI has the same type of crowd context.
     *
     * Replace this method later when you connect real crowd
     * detection data.
     */

    if (_position == null) {
      _crowdDensity = 0;
      _crowdLevel = 'Unavailable';
      _estimatedPeople = 0;
      return;
    }

    final double lat = _position!.latitude.abs();

    final double lon = _position!.longitude.abs();

    final int seed = ((lat * 100).round() + (lon * 100).round()).abs();

    final int density = 20 + (seed % 71);

    _crowdDensity = density;

    _estimatedPeople = (density * 3.5).round();

    if (density <= 30) {
      _crowdLevel = 'Low';
    } else if (density <= 70) {
      _crowdLevel = 'Moderate';
    } else {
      _crowdLevel = 'High';
    }
  }

  // ============================================================
  // BUILD AI CONTEXT
  // ============================================================

  Map<String, dynamic> _buildContext() {
    return {
      'location': _location,
      'latitude': _position?.latitude,
      'longitude': _position?.longitude,
      'temperature': _temperature,
      'humidity': _humidity,
      'windSpeed': _windSpeed,
      'weather': _weather,
      'weatherRisk': _weatherRisk,
      'crowdLevel': _crowdLevel,
      'crowdDensity': _crowdDensity,
      'estimatedPeople': _estimatedPeople,
    };
  }

  // ============================================================
  // SEND MESSAGE
  // ============================================================

  Future<void> _sendMessage([String? presetQuestion]) async {
    final String question = (presetQuestion ?? _messageController.text).trim();

    if (question.isEmpty || _loading) {
      return;
    }

    _messageController.clear();

    setState(() {
      _messages.add(_ChatMessage(text: question, isUser: true));

      _loading = true;
    });

    _scrollToBottom();

    try {
      final List<Map<String, String>> history = _messages
          .take(_messages.length - 1)
          .where((message) => message.text.trim().isNotEmpty)
          .map(
            (message) => {
              'role': message.isUser ? 'user' : 'assistant',
              'text': message.text,
            },
          )
          .toList();

      final String answer = await GeminiService.instance.ask(
        question: question,
        context: _buildContext(),
        conversation: history,
      );

      if (!mounted) return;

      setState(() {
        _messages.add(_ChatMessage(text: answer, isUser: false));

        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _messages.add(
          _ChatMessage(text: _friendlyError(e), isUser: false, isError: true),
        );

        _loading = false;
      });
    }

    _scrollToBottom();
  }

  // ============================================================
  // FRIENDLY ERROR
  // ============================================================

  String _friendlyError(Object error) {
    final String message = error.toString();

    debugPrint('================================');
    debugPrint('TREKCURE AI ERROR');
    debugPrint(message);
    debugPrint('================================');

    if (message.contains('API key is EMPTY')) {
      return '''
Gemini API key is not configured.

Run the app using:

flutter run --dart-define=GEMINI_API_KEY=YOUR_KEY
''';
    }

    if (message.contains('400')) {
      return '''
Gemini rejected the request.

$message
''';
    }

    if (message.contains('401') || message.contains('403')) {
      return '''
Gemini API key or permissions are incorrect.

$message
''';
    }

    if (message.contains('404')) {
      return '''
The Gemini model was not found.

$message
''';
    }

    if (message.contains('429')) {
      return '''
Gemini rate limit reached.

$message
''';
    }

    if (message.contains('SocketException')) {
      return '''
Could not connect to Gemini.

Check your internet connection.

$message
''';
    }

    if (message.contains('TimeoutException')) {
      return '''
Gemini request timed out.

Please try again.

$message
''';
    }

    return '''
TrekCure AI error:

$message
''';
  }

  // ============================================================
  // SCROLL
  // ============================================================

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;

      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  // ============================================================
  // CONTEXT CARD
  // ============================================================

  Widget _buildContextCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.lightGreenBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primaryGreen.withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.auto_awesome,
                color: AppColors.primaryGreen,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Current TrekCure Context',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                onPressed: _loadingContext ? null : _loadCurrentContext,
                icon: const Icon(Icons.refresh, size: 20),
                tooltip: 'Refresh',
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _contextChip(Icons.location_on, _location),
              _contextChip(
                Icons.thermostat,
                _temperature == null ? '--' : '${_temperature!.round()}°C',
              ),
              _contextChip(
                Icons.water_drop,
                _humidity == null ? '--' : '${_humidity!.round()}%',
              ),
              _contextChip(
                Icons.air,
                _windSpeed == null ? '--' : '${_windSpeed!.round()} km/h',
              ),
              _contextChip(Icons.cloud, _weather),
              _contextChip(Icons.groups, '$_crowdLevel ($_crowdDensity%)'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _contextChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: AppColors.primaryGreen),
          const SizedBox(width: 5),
          Text(
            text,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SUGGESTIONS
  // ============================================================

  Widget _buildSuggestions() {
    if (_messages.length > 1) {
      return const SizedBox.shrink();
    }

    final List<String> questions = [
      'Is it safe to trek now?',
      'Analyse my current conditions',
      'What precautions should I take?',
      'What should I carry?',
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: questions.map((question) {
          return ActionChip(
            label: Text(question),
            onPressed: () => _sendMessage(question),
          );
        }).toList(),
      ),
    );
  }

  // ============================================================
  // MESSAGE BUBBLE
  // ============================================================

  Widget _buildMessage(_ChatMessage message) {
    final bool user = message.isUser;

    return Align(
      alignment: user ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.84,
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: message.isError
              ? AppColors.dangerBgLight
              : user
              ? AppColors.primaryGreen
              : AppColors.cardGrey,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(user ? 16 : 4),
            bottomRight: Radius.circular(user ? 4 : 16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!user)
              Row(
                children: [
                  Icon(
                    message.isError ? Icons.error_outline : Icons.auto_awesome,
                    size: 17,
                    color: message.isError
                        ? AppColors.dangerRed
                        : AppColors.primaryGreen,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'TrekCure AI',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: message.isError
                          ? AppColors.dangerRed
                          : AppColors.primaryGreen,
                    ),
                  ),
                  const SizedBox(height: 5),
                ],
              ),
            Text(
              message.text,
              style: TextStyle(
                color: user ? Colors.white : AppColors.textDark,
                height: 1.45,
                fontSize: 14.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // TYPING INDICATOR
  // ============================================================

  Widget _buildTypingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.cardGrey,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primaryGreen,
              ),
            ),
            SizedBox(width: 10),
            Text(
              'TrekCure AI is analysing...',
              style: TextStyle(color: AppColors.textGrey, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.auto_awesome, color: AppColors.primaryGreen),
            SizedBox(width: 8),
            Text('TrekCure AI', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _loadingContext ? null : _loadCurrentContext,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh current data',
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildContextCard(),

            if (_loadingContext)
              const LinearProgressIndicator(
                minHeight: 2,
                color: AppColors.primaryGreen,
              ),

            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.only(top: 8, bottom: 8),
                itemCount: _messages.length + (_loading ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index >= _messages.length) {
                    return _buildTypingIndicator();
                  }

                  return _buildMessage(_messages[index]);
                },
              ),
            ),

            _buildSuggestions(),

            // ----------------------------------------------------
            // INPUT
            // ----------------------------------------------------
            Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      textInputAction: TextInputAction.send,
                      minLines: 1,
                      maxLines: 4,
                      enabled: !_loading,
                      onSubmitted: (_) => _sendMessage(),
                      decoration: InputDecoration(
                        hintText: 'Ask TrekCure AI...',
                        prefixIcon: const Icon(Icons.chat_bubble_outline),
                        suffixIcon: IconButton(
                          onPressed: _loading
                              ? null
                              : () => _messageController.clear(),
                          icon: const Icon(Icons.close, size: 18),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: const BoxDecoration(
                      color: AppColors.primaryGreen,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      onPressed: _loading ? null : _sendMessage,
                      icon: const Icon(Icons.send_rounded, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ================================================================
// CHAT MESSAGE MODEL
// ================================================================

class _ChatMessage {
  final String text;
  final bool isUser;
  final bool isError;

  const _ChatMessage({
    required this.text,
    required this.isUser,
    this.isError = false,
  });
}
