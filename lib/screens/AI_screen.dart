import 'package:flutter/material.dart';

import '../services/gemini_service.dart';

class AiAgentScreen extends StatefulWidget {
  final String location;
  final double temperature;
  final int humidity;
  final double windSpeed;
  final String weather;
  final String weatherRisk;
  final String crowdLevel;
  final int crowdDensity;

  const AiAgentScreen({
    super.key,
    this.location = 'Mumbai, India',
    this.temperature = 27,
    this.humidity = 81,
    this.windSpeed = 11,
    this.weather = 'Partly Cloudy',
    this.weatherRisk = 'Moderate',
    this.crowdLevel = 'Moderate',
    this.crowdDensity = 52,
  });

  @override
  State<AiAgentScreen> createState() =>
      _AiAgentScreenState();
}

class _AiAgentScreenState
    extends State<AiAgentScreen> {
  final GeminiService _gemini =
      GeminiService.instance;

  final TextEditingController _controller =
      TextEditingController();

  final ScrollController _scrollController =
      ScrollController();

  final List<Map<String, dynamic>> _messages =
      [];

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();

    _messages.add({
      'type': 'welcome',
    });
  }

  // ============================================================
  // SEND MESSAGE
  // ============================================================

  Future<void> _sendMessage() async {
    final question =
        _controller.text.trim();

    if (question.isEmpty || _isLoading) {
      return;
    }

    _controller.clear();

    setState(() {
      _messages.add({
        'type': 'user',
        'text': question,
      });

      _isLoading = true;
    });

    _scrollToBottom();

    try {
      final result =
          await _gemini.generateResponse(
        userQuestion: question,
        location: widget.location,
        temperature: widget.temperature,
        humidity: widget.humidity,
        windSpeed: widget.windSpeed,
        weather: widget.weather,
        weatherRisk: widget.weatherRisk,
        crowdLevel: widget.crowdLevel,
        crowdDensity: widget.crowdDensity,
      );

      if (!mounted) return;

      setState(() {
        _messages.add({
          'type': 'ai',
          'data': result,
        });

        _isLoading = false;
      });

      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _messages.add({
          'type': 'error',
          'text': e.toString(),
        });

        _isLoading = false;
      });

      _scrollToBottom();
    }
  }

  // ============================================================
  // SCROLL
  // ============================================================

  void _scrollToBottom() {
    WidgetsBinding.instance
        .addPostFrameCallback((_) {
      if (!_scrollController.hasClients) {
        return;
      }

      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration:
            const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          const Color(0xffF5F7F8),

      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,

        title: const Text(
          'TrekCure AI',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),

      body: Column(
        children: [
          _buildContextCard(),

          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding:
                  const EdgeInsets.all(12),
              itemCount: _messages.length,
              itemBuilder:
                  (context, index) {
                final message =
                    _messages[index];

                switch (message['type']) {
                  case 'welcome':
                    return _buildWelcome();

                  case 'user':
                    return _buildUserMessage(
                      message['text'],
                    );

                  case 'ai':
                    return _buildAiMessage(
                      message['data'],
                    );

                  case 'error':
                    return _buildError(
                      message['text'],
                    );

                  default:
                    return const SizedBox();
                }
              },
            ),
          ),

          if (_isLoading)
            _buildLoading(),

          _buildInput(),
        ],
      ),
    );
  }

  // ============================================================
  // CONTEXT
  // ============================================================

  Widget _buildContextCard() {
    return Container(
      margin:
          const EdgeInsets.fromLTRB(
        12,
        12,
        12,
        5,
      ),

      padding:
          const EdgeInsets.all(14),

      decoration: BoxDecoration(
        color:
            const Color(0xffEAF7F0),

        borderRadius:
            BorderRadius.circular(14),

        border: Border.all(
          color:
              const Color(0xffD3EBDD),
        ),
      ),

      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.auto_awesome,
                size: 18,
                color:
                    Color(0xff198754),
              ),

              SizedBox(width: 7),

              Expanded(
                child: Text(
                  'Current TrekCure Context',
                  style: TextStyle(
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _chip(
                Icons.location_on,
                widget.location,
              ),
              _chip(
                Icons.thermostat,
                '${widget.temperature}°C',
              ),
              _chip(
                Icons.water_drop,
                '${widget.humidity}%',
              ),
              _chip(
                Icons.air,
                '${widget.windSpeed} km/h',
              ),
              _chip(
                Icons.cloud,
                widget.weather,
              ),
              _chip(
                Icons.people,
                '${widget.crowdLevel} '
                    '(${widget.crowdDensity}%)',
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // CHIP
  // ============================================================

  Widget _chip(
    IconData icon,
    String text,
  ) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 6,
      ),

      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(20),
      ),

      child: Row(
        mainAxisSize:
            MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 13,
            color:
                const Color(0xff198754),
          ),

          const SizedBox(width: 4),

          Text(
            text,
            style: const TextStyle(
              fontSize: 11,
              fontWeight:
                  FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // WELCOME
  // ============================================================

  Widget _buildWelcome() {
    return _aiContainer(
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          _aiHeader(),

          const SizedBox(height: 10),

          const Text(
            'I can analyze your current TrekCure '
            'conditions and provide a safety assessment.',
            style: TextStyle(
              fontSize: 14,
              height: 1.4,
            ),
          ),

          const SizedBox(height: 12),

          const Text(
            'Try asking:',
            style: TextStyle(
              fontWeight:
                  FontWeight.bold,
            ),
          ),

          const SizedBox(height: 5),

          const Text(
            '• Is it safe to trek now?\n'
            '• Analyze my current conditions\n'
            '• What precautions should I take?\n'
            '• What should I carry?',
            style: TextStyle(
              fontSize: 13,
              height: 1.5,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // AI HEADER
  // ============================================================

  Widget _aiHeader() {
    return const Row(
      children: [
        Icon(
          Icons.auto_awesome,
          size: 17,
          color:
              Color(0xff198754),
        ),

        SizedBox(width: 6),

        Text(
          'TrekCure AI',
          style: TextStyle(
            fontWeight:
                FontWeight.bold,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // USER MESSAGE
  // ============================================================

  Widget _buildUserMessage(
    String text,
  ) {
    return Align(
      alignment:
          Alignment.centerRight,

      child: Container(
        constraints:
            const BoxConstraints(
          maxWidth: 280,
        ),

        margin:
            const EdgeInsets.only(
          bottom: 10,
        ),

        padding:
            const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 10,
        ),

        decoration:
            BoxDecoration(
          color:
              const Color(0xff198754),

          borderRadius:
              BorderRadius.circular(15),
        ),

        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // AI MESSAGE
  // ============================================================

  Widget _buildAiMessage(
    dynamic rawData,
  ) {
    final data =
        Map<String, dynamic>.from(
      rawData as Map,
    );

    final status =
        data['status']?.toString() ??
            'MODERATE RISK';

    final summary =
        data['summary']?.toString() ??
            'No summary available.';

    final conditions =
        data['conditions'] is Map
            ? Map<String, dynamic>.from(
                data['conditions'],
              )
            : <String, dynamic>{};

    final risks =
        _stringList(data['risks']);

    final recommendations =
        _stringList(
          data['recommendations'],
        );

    final finalAdvice =
        data['finalAdvice']?.toString() ??
            'Follow local safety guidance.';

    return _aiContainer(
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          _aiHeader(),

          const SizedBox(height: 12),

          _statusCard(status),

          const SizedBox(height: 14),

          _section(
            Icons.assessment,
            'Safety Assessment',
          ),

          const SizedBox(height: 6),

          Text(
            summary,
            style: const TextStyle(
              fontSize: 14,
              height: 1.4,
            ),
          ),

          const SizedBox(height: 15),

          _section(
            Icons.cloud,
            'Current Conditions',
          ),

          const SizedBox(height: 8),

          _conditionsGrid(conditions),

          if (risks.isNotEmpty) ...[
            const SizedBox(height: 15),

            _section(
              Icons.warning_amber_rounded,
              'Risks',
            ),

            const SizedBox(height: 8),

            _bulletList(risks),
          ],

          if (recommendations.isNotEmpty) ...[
            const SizedBox(height: 15),

            _section(
              Icons.tips_and_updates,
              'Recommendations',
            ),

            const SizedBox(height: 8),

            _bulletList(recommendations),
          ],

          const SizedBox(height: 15),

          Container(
            width: double.infinity,

            padding:
                const EdgeInsets.all(12),

            decoration: BoxDecoration(
              color:
                  const Color(0xffF1F8F4),

              borderRadius:
                  BorderRadius.circular(12),
            ),

            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                const Text(
                  'Final Advice',
                  style: TextStyle(
                    fontWeight:
                        FontWeight.bold,
                    color:
                        Color(0xff198754),
                  ),
                ),

                const SizedBox(height: 5),

                Text(
                  finalAdvice,
                  style:
                      const TextStyle(
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // STATUS
  // ============================================================

  Widget _statusCard(
    String status,
  ) {
    late Color background;
    late Color foreground;
    late IconData icon;

    if (status == 'SAFE') {
      background =
          const Color(0xffE8F7EE);
      foreground =
          const Color(0xff198754);
      icon = Icons.check_circle;
    } else if (status == 'HIGH RISK') {
      background =
          const Color(0xffffeeee);
      foreground =
          const Color(0xffdc3545);
      icon = Icons.dangerous;
    } else {
      background =
          const Color(0xfffff5df);
      foreground =
          const Color(0xffd97706);
      icon = Icons.warning_rounded;
    }

    return Container(
      width: double.infinity,

      padding:
          const EdgeInsets.all(14),

      decoration: BoxDecoration(
        color: background,
        borderRadius:
            BorderRadius.circular(13),
      ),

      child: Row(
        children: [
          Icon(
            icon,
            color: foreground,
            size: 28,
          ),

          const SizedBox(width: 10),

          Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              const Text(
                'Safety Status',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey,
                ),
              ),

              const SizedBox(height: 2),

              Text(
                status,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight:
                      FontWeight.bold,
                  color: foreground,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SECTION
  // ============================================================

  Widget _section(
    IconData icon,
    String title,
  ) {
    return Row(
      children: [
        Icon(
          icon,
          size: 17,
          color:
              const Color(0xff198754),
        ),

        const SizedBox(width: 6),

        Text(
          title,
          style: const TextStyle(
            fontWeight:
                FontWeight.bold,
            fontSize: 15,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // CONDITIONS
  // ============================================================

  Widget _conditionsGrid(
    Map<String, dynamic> conditions,
  ) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,

      physics:
          const NeverScrollableScrollPhysics(),

      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      childAspectRatio: 2.5,

      children: [
        _condition(
          'Location',
          conditions['location'],
          Icons.location_on,
        ),

        _condition(
          'Temperature',
          conditions['temperature'],
          Icons.thermostat,
        ),

        _condition(
          'Humidity',
          conditions['humidity'],
          Icons.water_drop,
        ),

        _condition(
          'Wind',
          conditions['wind'],
          Icons.air,
        ),

        _condition(
          'Weather',
          conditions['weather'],
          Icons.cloud,
        ),

        _condition(
          'Crowd',
          conditions['crowd'],
          Icons.people,
        ),
      ],
    );
  }

  // ============================================================
  // CONDITION
  // ============================================================

  Widget _condition(
    String title,
    dynamic value,
    IconData icon,
  ) {
    return Container(
      padding:
          const EdgeInsets.all(9),

      decoration: BoxDecoration(
        color:
            const Color(0xffF7F8F9),

        borderRadius:
            BorderRadius.circular(10),
      ),

      child: Row(
        children: [
          Icon(
            icon,
            size: 17,
            color:
                const Color(0xff198754),
          ),

          const SizedBox(width: 7),

          Expanded(
            child: Column(
              mainAxisAlignment:
                  MainAxisAlignment.center,

              crossAxisAlignment:
                  CrossAxisAlignment.start,

              children: [
                Text(
                  title,
                  style:
                      const TextStyle(
                    fontSize: 9,
                    color: Colors.grey,
                  ),
                ),

                Text(
                  value?.toString() ??
                      'Not available',

                  maxLines: 1,

                  overflow:
                      TextOverflow.ellipsis,

                  style:
                      const TextStyle(
                    fontSize: 11,
                    fontWeight:
                        FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // BULLET LIST
  // ============================================================

  Widget _bulletList(
    List<String> items,
  ) {
    return Column(
      children: items.map(
        (item) {
          return Padding(
            padding:
                const EdgeInsets.only(
              bottom: 7,
            ),

            child: Row(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding:
                      EdgeInsets.only(top: 5),

                  child: Icon(
                    Icons.circle,
                    size: 6,
                    color:
                        Color(0xff198754),
                  ),
                ),

                const SizedBox(width: 8),

                Expanded(
                  child: Text(
                    item,
                    style:
                        const TextStyle(
                      fontSize: 13,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ).toList(),
    );
  }

  // ============================================================
  // STRING LIST
  // ============================================================

  List<String> _stringList(
    dynamic value,
  ) {
    if (value is! List) {
      return [];
    }

    return value
        .map(
          (item) => item.toString(),
        )
        .toList();
  }

  // ============================================================
  // AI CONTAINER
  // ============================================================

  Widget _aiContainer({
    required Widget child,
  }) {
    return Container(
      margin:
          const EdgeInsets.only(
        bottom: 10,
      ),

      padding:
          const EdgeInsets.all(14),

      decoration: BoxDecoration(
        color: Colors.white,

        borderRadius:
            BorderRadius.circular(16),

        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: 0.04,
            ),

            blurRadius: 5,

            offset:
                const Offset(0, 2),
          ),
        ],
      ),

      child: child,
    );
  }

  // ============================================================
  // ERROR
  // ============================================================

  Widget _buildError(
    String error,
  ) {
    return Container(
      margin:
          const EdgeInsets.only(
        bottom: 10,
      ),

      padding:
          const EdgeInsets.all(12),

      decoration: BoxDecoration(
        color:
            const Color(0xffffeeee),

        borderRadius:
            BorderRadius.circular(12),
      ),

      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,

        children: [
          const Icon(
            Icons.error_outline,
            color: Colors.red,
          ),

          const SizedBox(width: 8),

          Expanded(
            child: Text(
              error,
              style:
                  const TextStyle(
                fontSize: 13,
                color: Colors.red,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // LOADING
  // ============================================================

  Widget _buildLoading() {
    return const Padding(
      padding:
          EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 8,
      ),

      child: Row(
        children: [
          SizedBox(
            width: 18,
            height: 18,

            child:
                CircularProgressIndicator(
              strokeWidth: 2,
            ),
          ),

          SizedBox(width: 10),

          Text(
            'TrekCure AI is analyzing...',
            style: TextStyle(
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // INPUT
  // ============================================================

  Widget _buildInput() {
    return SafeArea(
      child: Container(
        padding:
            const EdgeInsets.fromLTRB(
          10,
          7,
          10,
          7,
        ),

        color: Colors.white,

        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller:
                    _controller,

                textInputAction:
                    TextInputAction.send,

                onSubmitted: (_) {
                  _sendMessage();
                },

                decoration:
                    InputDecoration(
                  hintText:
                      'Ask TrekCure AI...',

                  prefixIcon:
                      const Icon(
                    Icons
                        .chat_bubble_outline,
                    size: 20,
                  ),

                  filled: true,

                  fillColor:
                      const Color(
                    0xffF4F5F6,
                  ),

                  border:
                      OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(
                      12,
                    ),

                    borderSide:
                        BorderSide.none,
                  ),
                ),
              ),
            ),

            const SizedBox(width: 8),

            GestureDetector(
              onTap:
                  _sendMessage,

              child: Container(
                width: 43,
                height: 43,

                decoration:
                    BoxDecoration(
                  color:
                      const Color(
                    0xff198754,
                  ),

                  borderRadius:
                      BorderRadius.circular(
                    13,
                  ),
                ),

                child: const Icon(
                  Icons.arrow_forward,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();

    super.dispose();
  }
}