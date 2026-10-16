
// ignore_for_file: unused_element

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:mjpeg_view/mjpeg_view.dart';

import '../main.dart';
import '../server_config.dart';

// ============================================================
// SERVO PAGE
// ============================================================
// SmartFeed main feeder control page.
//
// Features:
// 1. Live camera viewing
// 2. Pet detection
// 3. Feeding portion selection
// 4. Manual feeding
// 5. Feeder Bowl OPEN/CLOSE controls
// 6. Feeding/detection status
//
// NEW:
// FEED NOW is disabled when the Feeder Bowl is closed,
// opening, closing, or its state is unknown.
// ============================================================

class ServoPage extends StatefulWidget {
  const ServoPage({super.key});

  @override
  State<ServoPage> createState() => _ServoPageState();
}

class _ServoPageState extends State<ServoPage>
    with TickerProviderStateMixin {

  // =========================
  // FEEDING
  // =========================

  String _status = 'Select portion & tap Feed Now';

  bool _isFeeding = false;

  String _selectedPortion = 'medium';

  // =========================
  // FEEDER BOWL
  // =========================

  bool _isGateOpening = false;
  bool _isGateClosing = false;

  // true  = Feeder Bowl OPEN
  // false = Feeder Bowl CLOSED
  // null  = State not loaded yet
  bool? _isDoorOpen;

  StreamSubscription<List<Map<String, dynamic>>>? _doorSub;

  // =========================
  // PET DETECTION
  // =========================

  String _petDetection = 'No Pet Detected';

  double _petConfidence = 0.0;

  Timer? _detectionTimer;

  String? _videoUrl;

  int _detectionFailures = 0;

  // =========================
  // ANIMATION
  // =========================

  late AnimationController _pawController;
  late Animation<double> _pawAnimation;

  late AnimationController _pulseController;
  late AnimationController _shimmerController;

  // =========================
  // PALETTE
  // =========================

  static const Color _salmon = Color(0xFFFA7268);
  static const Color _peach = Color(0xFFFF9E89);
  static const Color _blush = Color(0xFFFFD6C4);
  static const Color _cream = Color(0xFFFFEFC4);
  static const Color _brown = Color(0xFF5B3A29);
  static const Color _brownSoft = Color(0xFF7A3E2A);
  static const Color _leafGreen = Color(0xFF6FAE7C);
  static const Color _amber = Color(0xFFE0A438);

  // =========================
  // NEW: FEED BUTTON STATE
  // =========================

  // Feeding is only allowed when:
  // 1. Feeder Bowl is OPEN
  // 2. No feeding is running
  // 3. Bowl is not opening
  // 4. Bowl is not closing

  bool get _canFeed {
    return _isDoorOpen == true &&
        !_isFeeding &&
        !_isGateOpening &&
        !_isGateClosing;
  }

  // =========================
  // INIT
  // =========================

  @override
  void initState() {
    super.initState();

    _pawController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _pawAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(
      CurvedAnimation(
        parent: _pawController,
        curve: Curves.easeOutBack,
      ),
    );

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1400),
      vsync: this,
    )..repeat(reverse: true);

    _shimmerController = AnimationController(
      duration: const Duration(milliseconds: 2400),
      vsync: this,
    )..repeat();

    _initServer();

    _listenDoorState();
  }

  // =========================
  // DOOR STATE LISTENER
  // =========================

  // Listens to Supabase feeder_door table.
  //
  // Whenever the command changes, the UI updates.
  //
  // This also supports changes made by the Python
  // pet detection server.

  void _listenDoorState() {
    _doorSub = supabase
        .from('feeder_door')
        .stream(primaryKey: ['id'])
        .eq('id', 1)
        .listen(
      (rows) {
        if (rows.isEmpty || !mounted) return;

        final cmd = rows.first['command']
            ?.toString()
            .toLowerCase()
            .trim();

        if (cmd == 'open') {
          setState(() {
            _isDoorOpen = true;
          });
        } else if (cmd == 'close') {
          setState(() {
            _isDoorOpen = false;
          });
        }
      },
      onError: (error) {
        debugPrint('Door state error: $error');
      },
    );
  }

  // =========================
  // PET DETECTION SERVER
  // =========================

  Future<void> _initServer() async {
    await ServerConfig.refresh();

    if (!mounted) return;

    setState(() {
      _videoUrl = ServerConfig.isReady
          ? ServerConfig.videoUrl
          : null;
    });

    _startDetectionPolling();
  }

  Future<void> _reloadServer() async {
    await ServerConfig.refresh();

    if (!mounted) return;

    final url = ServerConfig.isReady
        ? ServerConfig.videoUrl
        : null;

    if (url != _videoUrl) {
      setState(() {
        _videoUrl = url;
      });
    }
  }

  // =========================
  // DETECTION POLLING
  // =========================

  void _startDetectionPolling() {
    _detectionTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) async {
        if (!ServerConfig.isReady) {
          await _reloadServer();
          return;
        }

        try {
          final response = await http
              .get(
                Uri.parse(ServerConfig.detectionUrl),
              )
              .timeout(
                const Duration(seconds: 3),
              );

          if (response.statusCode == 200) {
            _detectionFailures = 0;

            final data = jsonDecode(response.body);

            if (!mounted) return;

            setState(() {
              _petDetection =
                  data['pet'] ?? 'No Pet Detected';

              _petConfidence =
                  (data['confidence'] ?? 0.0).toDouble();
            });
          }
        } catch (e) {
          _detectionFailures++;

          if (_detectionFailures >= 3) {
            _detectionFailures = 0;
            await _reloadServer();
          }
        }
      },
    );
  }

  // =========================
  // PORTION INFORMATION
  // =========================

  String _getPortionLabel(String portion) {
    switch (portion) {
      case 'small':
        return 'Small';

      case 'medium':
        return 'Medium';

      case 'full':
        return 'Full';

      default:
        return 'Unknown';
    }
  }

  Duration _getFeedingDuration(String portion) {
    switch (portion) {
      case 'small':
        return const Duration(milliseconds: 500);

      case 'medium':
        return const Duration(seconds: 1);

      case 'full':
        return const Duration(seconds: 2);

      default:
        return const Duration(seconds: 1);
    }
  }

  // =========================
  // FEED NOW
  // =========================

  Future<void> feedNow() async {

    // NEW:
    // Prevent feeding if the Feeder Bowl is CLOSED.
    // Also prevents feeding during other operations.

    if (!_canFeed) {
      return;
    }

    final String portion = _selectedPortion;

    final String portionLabel =
        _getPortionLabel(portion);

    setState(() {
      _isFeeding = true;

      _status =
          '🍖 Dispensing ($portionLabel)...';
    });

    try {

      // Send feeding command to ESP32.

      await supabase.from('servo').update({
        'angle': 45,
        'command': portion,
        'last_confirmed': 0,
      }).eq('id', 27);

      // Save feeding history.

      await supabase.from('feeding_logs').insert({
        'angle': 45,
        'portion_label': portionLabel,
        'trigger_type': 'manual',
        'fed_at':
            DateTime.now().toUtc().toIso8601String(),
      });

      _pawController.forward(from: 0);

      final feedingDuration =
          _getFeedingDuration(portion);

      await Future.delayed(
        feedingDuration +
            const Duration(milliseconds: 800),
      );

      if (!mounted) return;

      setState(() {
        _status =
            '✓ Fed successfully! ($portionLabel Portion)';
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _status = '❌ Error: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isFeeding = false;
        });
      }
    }
  }

  // =========================
  // OPEN FEEDER BOWL
  // =========================

  Future<void> openGate() async {
    if (_isGateOpening ||
        _isGateClosing ||
        _isFeeding) {
      return;
    }

    if (_isDoorOpen == true) return;

    setState(() {
      _isGateOpening = true;
      _status = '🔓 Opening feeder...';
    });

    try {
      await supabase
          .from('feeder_door')
          .update({
            'command': 'open',
          })
          .eq('id', 1);

      if (!mounted) return;

      setState(() {
        _isDoorOpen = true;
        _status = '✓ Feeder opened';
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _status = '❌ Feeder error: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isGateOpening = false;
        });
      }
    }
  }

  // =========================
  // CLOSE FEEDER BOWL
  // =========================

  Future<void> closeGate() async {
    if (_isGateOpening ||
        _isGateClosing ||
        _isFeeding) {
      return;
    }

    if (_isDoorOpen == false) return;

    setState(() {
      _isGateClosing = true;
      _status = '🔒 Closing feeder...';
    });

    try {
      await supabase
          .from('feeder_door')
          .update({
            'command': 'close',
          })
          .eq('id', 1);

      if (!mounted) return;

      setState(() {
        _isDoorOpen = false;
        _status = '✓ Feeder closed';
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _status = '❌ Feeder error: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isGateClosing = false;
        });
      }
    }
  }

  // =========================
  // DISPOSE
  // =========================

  @override
  void dispose() {
    _detectionTimer?.cancel();

    _doorSub?.cancel();

    _pawController.dispose();
    _pulseController.dispose();
    _shimmerController.dispose();

    super.dispose();
  }

  // =========================
  // BUILD
  // =========================

  @override
  Widget build(BuildContext context) {
    final busy =
        _isFeeding ||
        _isGateOpening ||
        _isGateClosing;

    return Scaffold(
      body: Stack(
        children: [

          // =========================
          // BACKGROUND
          // =========================

          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  _peach,
                  Color(0xFFFFBFA3),
                  Color(0xFFFFD8A0),
                  _cream,
                ],
              ),
            ),
          ),

          // =========================
          // SOFT BLOBS
          // =========================

          Positioned(
            top: -60,
            right: -50,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    _salmon.withOpacity(0.3),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          Positioned(
            bottom: -40,
            left: -50,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    _cream.withOpacity(0.7),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // =========================
          // GHOST PAWS
          // =========================

          const Positioned(
            top: 80,
            left: -10,
            child: _GhostPaw(
              size: 46,
              angle: -0.4,
            ),
          ),

          const Positioned(
            top: 150,
            right: 6,
            child: _GhostPaw(
              size: 30,
              angle: 0.5,
            ),
          ),

          const Positioned(
            bottom: 100,
            left: 18,
            child: _GhostPaw(
              size: 34,
              angle: 0.2,
            ),
          ),

          const Positioned(
            bottom: 40,
            right: -6,
            child: _GhostPaw(
              size: 50,
              angle: -0.3,
            ),
          ),

          // =========================
          // PAGE CONTENT
          // =========================

          SafeArea(
            child: SingleChildScrollView(
              physics:
                  const BouncingScrollPhysics(),

              padding: const EdgeInsets.fromLTRB(
                20,
                16,
                20,
                32,
              ),

              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,

                children: [

                  // =========================
                  // LIVE CAMERA
                  // =========================

                  Stack(
                    children: [

                      Container(
                        decoration: BoxDecoration(
                          borderRadius:
                              BorderRadius.circular(30),

                          border: Border.all(
                            color: Colors.white,
                            width: 4,
                          ),

                          boxShadow: [
                            BoxShadow(
                              color:
                                  _brown.withOpacity(0.22),
                              blurRadius: 22,
                              offset:
                                  const Offset(0, 12),
                            ),

                            BoxShadow(
                              color:
                                  _salmon.withOpacity(0.15),
                              blurRadius: 30,
                              offset:
                                  const Offset(0, 6),
                            ),
                          ],
                        ),

                        child: ClipRRect(
                          borderRadius:
                              BorderRadius.circular(26),

                          child: Stack(
                            children: [

                              // MJPEG VIDEO

                              if (_videoUrl == null)
                                Container(
                                  width: double.infinity,
                                  height: 230,
                                  color: Colors.black87,

                                  child: const Center(
                                    child:
                                        CircularProgressIndicator(
                                      color: Colors.white,
                                    ),
                                  ),
                                )
                              else
                                MjpegView(
                                  key: ValueKey(_videoUrl),
                                  uri: _videoUrl!,
                                  width: double.infinity,
                                  height: 230,
                                  fit: BoxFit.cover,
                                ),

                              // VIDEO GRADIENT

                              Positioned(
                                left: 0,
                                right: 0,
                                bottom: 0,

                                child: Container(
                                  height: 70,

                                  decoration: BoxDecoration(
                                    gradient:
                                        LinearGradient(
                                      begin:
                                          Alignment.topCenter,
                                      end:
                                          Alignment.bottomCenter,

                                      colors: [
                                        Colors.transparent,
                                        Colors.black
                                            .withOpacity(0.45),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // =========================
                      // LIVE BADGE
                      // =========================

                      Positioned(
                        top: 14,
                        left: 14,

                        child: Container(
                          padding:
                              const EdgeInsets.symmetric(
                            horizontal: 11,
                            vertical: 6,
                          ),

                          decoration: BoxDecoration(
                            color:
                                Colors.black.withOpacity(0.6),

                            borderRadius:
                                BorderRadius.circular(20),

                            border: Border.all(
                              color: Colors.white
                                  .withOpacity(0.2),
                            ),
                          ),

                          child: Row(
                            mainAxisSize:
                                MainAxisSize.min,

                            children: [

                              AnimatedBuilder(
                                animation:
                                    _pulseController,

                                builder: (context, _) {
                                  final t =
                                      _pulseController.value;

                                  return Container(
                                    width: 8,
                                    height: 8,

                                    decoration: BoxDecoration(
                                      shape:
                                          BoxShape.circle,

                                      color: Color.lerp(
                                        const Color(
                                            0xFFFF5C5C),
                                        const Color(
                                            0xFFFFB4B4),
                                        t,
                                      ),

                                      boxShadow: [
                                        BoxShadow(
                                          color:
                                              const Color(
                                            0xFFFF5C5C,
                                          ).withOpacity(0.6),

                                          blurRadius: 8,
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),

                              const SizedBox(width: 6),

                              Text(
                                'LIVE',

                                style: GoogleFonts.dmSans(
                                  color: Colors.white,
                                  fontSize: 11.5,
                                  fontWeight:
                                      FontWeight.w800,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // =========================
                      // DETECTION PILL
                      // =========================

                      Positioned(
                        bottom: 14,
                        left: 14,
                        child: _buildDetectionPill(),
                      ),

                      // =========================
                      // PAW STICKER
                      // =========================

                      Positioned(
                        bottom: 14,
                        right: 14,

                        child: Container(
                          padding:
                              const EdgeInsets.all(8),

                          decoration: BoxDecoration(
                            color: Colors.white
                                .withOpacity(0.9),

                            shape: BoxShape.circle,

                            boxShadow: [
                              BoxShadow(
                                color: _salmon
                                    .withOpacity(0.3),
                                blurRadius: 10,
                                offset:
                                    const Offset(0, 3),
                              ),
                            ],
                          ),

                          child: const Icon(
                            Icons.pets,
                            size: 16,
                            color: _salmon,
                          ),
                        ),
                      ),
                    ],
                  ),

                  // =========================
                  // CONFIDENCE BAR
                  // =========================

                  if (_petDetection !=
                      'No Pet Detected') ...[
                    const SizedBox(height: 12),
                    _buildConfidenceBar(),
                  ],

                  const SizedBox(height: 22),

                  // =========================
                  // PORTION TITLE
                  // =========================

                  Row(
                    children: [
                      Container(
                        padding:
                            const EdgeInsets.all(6),

                        decoration: BoxDecoration(
                          color:
                              _salmon.withOpacity(0.15),

                          borderRadius:
                              BorderRadius.circular(10),
                        ),

                        child: const Icon(
                          Icons.restaurant_menu_rounded,
                          size: 14,
                          color: _salmon,
                        ),
                      ),

                      const SizedBox(width: 8),

                      Text(
                        'Choose a portion 🥣',

                        style: GoogleFonts.fraunces(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: _brownSoft,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // =========================
                  // PORTION BUTTONS
                  // =========================

                  Row(
                    children: [

                      _buildPresetChip(
                        label: 'Small',
                        subtext: 'Portion',
                        portion: 'small',
                        icon: Icons.restaurant,
                      ),

                      const SizedBox(width: 10),

                      _buildPresetChip(
                        label: 'Medium',
                        subtext: 'Portion',
                        portion: 'medium',
                        icon: Icons.set_meal,
                      ),

                      const SizedBox(width: 10),

                      _buildPresetChip(
                        label: 'Full',
                        subtext: 'Portion',
                        portion: 'full',
                        icon: Icons.dinner_dining,
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // =================================================
                  // NEW: FEED NOW BUTTON WITH BOWL STATE VALIDATION
                  // =================================================

                  SizedBox(
                    width: double.infinity,
                    height: 66,

                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius:
                            BorderRadius.circular(26),

                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,

                          // Gray when disabled.
                          // Salmon when enabled.

                          colors: !_canFeed
                              ? [
                                  Colors.grey.shade400,
                                  Colors.grey.shade500,
                                ]
                              : [
                                  _salmon,
                                  _peach,
                                ],
                        ),

                        boxShadow: !_canFeed
                            ? []
                            : [
                                BoxShadow(
                                  color: _salmon
                                      .withOpacity(0.5),
                                  blurRadius: 22,
                                  offset:
                                      const Offset(0, 10),
                                ),
                              ],
                      ),

                      child: ElevatedButton.icon(

                        // NEW:
                        // FEED NOW only works when
                        // Feeder Bowl is OPEN.

                        onPressed:
                            _canFeed ? feedNow : null,

                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              Colors.transparent,

                          disabledBackgroundColor:
                              Colors.transparent,

                          shadowColor:
                              Colors.transparent,

                          foregroundColor:
                              Colors.white,

                          disabledForegroundColor:
                              Colors.white,

                          elevation: 0,

                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(26),
                          ),
                        ),

                        icon: _isFeeding
                            ? const SizedBox(
                                width: 22,
                                height: 22,

                                child:
                                    CircularProgressIndicator(
                                  strokeWidth: 2.6,
                                  color: Colors.white,
                                ),
                              )
                            : !_canFeed
                                ? const Icon(
                                    Icons.lock_rounded,
                                    size: 26,
                                    color: Colors.white,
                                  )
                                : AnimatedBuilder(
                                    animation:
                                        _pawAnimation,

                                    builder:
                                        (context, _) {
                                      return Transform.rotate(
                                        angle:
                                            _pawAnimation.value *
                                                0.35,

                                        child: const Icon(
                                          Icons.pets,
                                          size: 28,
                                          color:
                                              Colors.white,
                                        ),
                                      );
                                    },
                                  ),

                        label: Text(

                          // NEW:
                          // Button label changes based
                          // on feeder bowl state.

                          _isFeeding
                              ? 'FEEDING...'
                              : _isDoorOpen != true
                                  ? 'BOWL CLOSED'
                                  : busy
                                      ? 'PLEASE WAIT...'
                                      : 'FEED NOW',

                          style: GoogleFonts.dmSans(
                            fontSize: 19,
                            fontWeight:
                                FontWeight.w800,
                            letterSpacing: 1.2,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // =========================
                  // NEW: FEED BUTTON MESSAGE
                  // =========================

                  if (_isDoorOpen != true) ...[
                    const SizedBox(height: 10),

                    Center(
                      child: Row(
                        mainAxisAlignment:
                            MainAxisAlignment.center,

                        children: [
                          const Icon(
                            Icons.lock_outline_rounded,
                            size: 16,
                            color: _brownSoft,
                          ),

                          const SizedBox(width: 6),

                          Flexible(
                            child: Text(
                              _isDoorOpen == null
                                  ? 'Checking feeder bowl status...'
                                  : 'Open the Feeder Bowl to enable feeding',

                              textAlign:
                                  TextAlign.center,

                              style:
                                  GoogleFonts.dmSans(
                                fontSize: 12,
                                fontWeight:
                                    FontWeight.w600,
                                color: _brownSoft,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),

                  // =========================
                  // FEEDER BOWL TITLE
                  // =========================

                  Row(
                    children: [
                      Container(
                        padding:
                            const EdgeInsets.all(6),

                        decoration: BoxDecoration(
                          color: _leafGreen
                              .withOpacity(0.18),

                          borderRadius:
                              BorderRadius.circular(10),
                        ),

                        child: const Icon(
                          Icons.door_sliding_rounded,
                          size: 14,
                          color: _leafGreen,
                        ),
                      ),

                      const SizedBox(width: 8),

                      Text(
                        'Feeder Bowl',

                        style: GoogleFonts.fraunces(
                          fontSize: 16,
                          fontWeight:
                              FontWeight.w800,
                          color: _brownSoft,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // =========================
                  // OPEN / CLOSE BUTTONS
                  // =========================

                  Row(
                    children: [

                      // OPEN BUTTON

                      Expanded(
                        child: _DoorButton(
                          isBusy: busy,
                          isDisabled:
                              _isDoorOpen == true,

                          isWorking:
                              _isGateOpening,

                          label: 'OPEN',
                          workingLabel:
                              'OPENING...',

                          icon:
                              Icons.lock_open_rounded,

                          color: _leafGreen,

                          onPressed: openGate,
                        ),
                      ),

                      const SizedBox(width: 12),

                      // CLOSE BUTTON

                      Expanded(
                        child: _DoorButton(
                          isBusy: busy,

                          isDisabled:
                              _isDoorOpen == false,

                          isWorking:
                              _isGateClosing,

                          label: 'CLOSE',
                          workingLabel:
                              'CLOSING...',

                          icon:
                              Icons.lock_rounded,

                          color:
                              const Color(0xFFC23B3B),

                          onPressed: closeGate,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // =========================
                  // STATUS CARD
                  // =========================

                  AnimatedContainer(
                    duration:
                        const Duration(milliseconds: 300),

                    curve: Curves.easeOutCubic,

                    width: double.infinity,

                    padding:
                        const EdgeInsets.symmetric(
                      vertical: 16,
                      horizontal: 18,
                    ),

                    decoration: BoxDecoration(
                      color: Colors.white
                          .withOpacity(0.75),

                      borderRadius:
                          BorderRadius.circular(20),

                      border: Border.all(
                        color: Colors.white
                            .withOpacity(0.9),
                        width: 1.2,
                      ),

                      boxShadow: [
                        BoxShadow(
                          color: _brownSoft
                              .withOpacity(0.08),

                          blurRadius: 16,

                          offset:
                              const Offset(0, 6),
                        ),
                      ],
                    ),

                    child: Row(
                      children: [

                        Container(
                          padding:
                              const EdgeInsets.all(8),

                          decoration: BoxDecoration(
                            gradient:
                                LinearGradient(
                              colors: [
                                _salmon
                                    .withOpacity(0.2),
                                _peach
                                    .withOpacity(0.15),
                              ],
                            ),

                            shape: BoxShape.circle,
                          ),

                          child: const Icon(
                            Icons.info_outline_rounded,
                            size: 16,
                            color: _salmon,
                          ),
                        ),

                        const SizedBox(width: 12),

                        Expanded(
                          child: Text(
                            _status,

                            style:
                                GoogleFonts.dmSans(
                              fontSize: 14,
                              color: _brownSoft,
                              fontWeight:
                                  FontWeight.w700,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =========================
  // DETECTION PILL
  // =========================

  Widget _buildDetectionPill() {
    late final Color pillColor;
    late final Color dotColor;
    late final String label;
    late final IconData icon;

    if (_petDetection == 'Yuri') {
      pillColor =
          _leafGreen.withOpacity(0.2);
      dotColor = _leafGreen;
      label = 'Yuri Detected';
      icon = Icons.pets;

    } else if (_petDetection == 'Unknown Pet') {
      pillColor =
          _amber.withOpacity(0.22);
      dotColor = _amber;
      label = 'Unknown Pet';
      icon = Icons.help_outline_rounded;

    } else {
      pillColor =
          Colors.black.withOpacity(0.5);
      dotColor = Colors.white70;
      label = 'No Pet Detected';
      icon = Icons.visibility_off_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: 8,
        horizontal: 12,
      ),

      decoration: BoxDecoration(
        color: _petDetection ==
                'No Pet Detected'
            ? pillColor
            : Colors.white.withOpacity(0.95),

        borderRadius:
            BorderRadius.circular(30),

        boxShadow: _petDetection ==
                'No Pet Detected'
            ? null
            : [
                BoxShadow(
                  color:
                      dotColor.withOpacity(0.35),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
      ),

      child: Row(
        mainAxisSize: MainAxisSize.min,

        children: [

          Container(
            width: 18,
            height: 18,

            decoration: BoxDecoration(
              color:
                  dotColor.withOpacity(0.2),
              shape: BoxShape.circle,
            ),

            child: Icon(
              icon,
              size: 11,
              color: dotColor,
            ),
          ),

          const SizedBox(width: 7),

          Text(
            label,

            style: GoogleFonts.dmSans(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,

              color: _petDetection ==
                      'No Pet Detected'
                  ? Colors.white
                  : _brownSoft,
            ),
          ),
        ],
      ),
    );
  }

  // =========================
  // CONFIDENCE BAR
  // =========================

  Widget _buildConfidenceBar() {
    final pct =
        _petConfidence.clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 12,
      ),

      decoration: BoxDecoration(
        color:
            Colors.white.withOpacity(0.75),

        borderRadius:
            BorderRadius.circular(16),

        border: Border.all(
          color:
              Colors.white.withOpacity(0.9),
          width: 1.2,
        ),
      ),

      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,

        children: [

          Row(
            children: [

              Icon(
                Icons.analytics_outlined,
                size: 14,
                color:
                    _brownSoft.withOpacity(0.7),
              ),

              const SizedBox(width: 6),

              Text(
                'Detection confidence',

                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  fontWeight:
                      FontWeight.w800,
                  color:
                      _brownSoft.withOpacity(0.8),
                ),
              ),

              const Spacer(),

              Text(
                '${(_petConfidence * 100).toStringAsFixed(1)}%',

                style:
                    GoogleFonts.fraunces(
                  fontSize: 14,
                  fontWeight:
                      FontWeight.w800,
                  color: _salmon,
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          ClipRRect(
            borderRadius:
                BorderRadius.circular(20),

            child:
                TweenAnimationBuilder<double>(
              tween: Tween(
                begin: 0,
                end: pct,
              ),

              duration:
                  const Duration(milliseconds: 500),

              curve: Curves.easeOutCubic,

              builder: (context, value, _) {
                return LinearProgressIndicator(
                  value: value,
                  minHeight: 9,

                  backgroundColor:
                      _blush.withOpacity(0.5),

                  valueColor:
                      const AlwaysStoppedAnimation<Color>(
                    _salmon,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // =========================
  // PORTION SELECTORS
  // =========================

  Widget _buildPresetChip({
    required String label,
    required String subtext,
    required String portion,
    required IconData icon,
  }) {
    final isSelected =
        _selectedPortion == portion;

    return Expanded(
      child: GestureDetector(

        onTap: _isFeeding
            ? null
            : () {
                setState(() {
                  _selectedPortion = portion;
                });
              },

        child: AnimatedScale(
          scale:
              isSelected ? 1.05 : 1.0,

          duration:
              const Duration(milliseconds: 220),

          curve: Curves.easeOutBack,

          child: AnimatedContainer(
            duration:
                const Duration(milliseconds: 220),

            padding:
                const EdgeInsets.symmetric(
              vertical: 16,
              horizontal: 10,
            ),

            decoration: BoxDecoration(
              gradient: isSelected
                  ? const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        _salmon,
                        _peach,
                      ],
                    )
                  : null,

              color: isSelected
                  ? null
                  : Colors.white.withOpacity(0.92),

              borderRadius:
                  BorderRadius.circular(26),

              border: Border.all(
                color: isSelected
                    ? Colors.transparent
                    : _blush.withOpacity(0.9),
                width: 2,
              ),

              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color:
                            _salmon.withOpacity(0.4),
                        blurRadius: 16,
                        offset:
                            const Offset(0, 8),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color:
                            _brownSoft.withOpacity(0.06),
                        blurRadius: 8,
                        offset:
                            const Offset(0, 3),
                      ),
                    ],
            ),

            child: Column(
              children: [

                Container(
                  padding:
                      const EdgeInsets.all(7),

                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.white
                            .withOpacity(0.25)
                        : _salmon
                            .withOpacity(0.12),

                    shape: BoxShape.circle,
                  ),

                  child: Icon(
                    icon,
                    color: isSelected
                        ? Colors.white
                        : _salmon,
                    size: 22,
                  ),
                ),

                const SizedBox(height: 8),

                Text(
                  label,

                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    fontWeight:
                        FontWeight.w800,

                    color: isSelected
                        ? Colors.white
                        : _brownSoft,
                  ),
                ),

                const SizedBox(height: 1),

                Text(
                  subtext,

                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    fontWeight:
                        FontWeight.w600,

                    color: isSelected
                        ? Colors.white70
                        : _brownSoft
                            .withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// DOOR BUTTON
// ============================================================

class _DoorButton extends StatelessWidget {
  final bool isBusy;
  final bool isDisabled;
  final bool isWorking;

  final String label;
  final String workingLabel;

  final IconData icon;
  final Color color;

  final VoidCallback onPressed;

  const _DoorButton({
    required this.isBusy,
    required this.isDisabled,
    required this.isWorking,
    required this.label,
    required this.workingLabel,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final disabled =
        isBusy || isDisabled;

    return SizedBox(
      height: 56,

      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius:
              BorderRadius.circular(20),

          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,

            colors: disabled
                ? [
                    const Color(0xFFFFD6C4),
                    const Color(0xFFFFD6C4),
                  ]
                : [
                    color,
                    color.withOpacity(0.75),
                  ],
          ),

          boxShadow: disabled
              ? []
              : [
                  BoxShadow(
                    color:
                        color.withOpacity(0.4),
                    blurRadius: 14,
                    offset:
                        const Offset(0, 6),
                  ),
                ],
        ),

        child: ElevatedButton.icon(
          onPressed:
              disabled ? null : onPressed,

          style: ElevatedButton.styleFrom(
            backgroundColor:
                Colors.transparent,

            disabledBackgroundColor:
                Colors.transparent,

            shadowColor:
                Colors.transparent,

            foregroundColor:
                Colors.white,

            disabledForegroundColor:
                Colors.white,

            elevation: 0,

            shape: RoundedRectangleBorder(
              borderRadius:
                  BorderRadius.circular(20),
            ),
          ),

          icon: isWorking
              ? const SizedBox(
                  width: 18,
                  height: 18,

                  child:
                      CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: Colors.white,
                  ),
                )
              : Icon(
                  icon,
                  size: 22,
                  color: Colors.white,
                ),

          label: Text(
            isWorking
                ? workingLabel
                : label,

            style: GoogleFonts.dmSans(
              fontSize: 15,
              fontWeight:
                  FontWeight.w800,
              letterSpacing: 0.8,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// DECORATIVE WIDGETS
// ============================================================

class _PawBadge extends StatelessWidget {
  const _PawBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,

      decoration: const BoxDecoration(
        shape: BoxShape.circle,

        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,

          colors: [
            _ServoPageState._salmon,
            _ServoPageState._peach,
          ],
        ),
      ),

      child: const Icon(
        Icons.pets,
        size: 20,
        color: Colors.white,
      ),
    );
  }
}

class _GhostPaw extends StatelessWidget {
  final double size;
  final double angle;

  const _GhostPaw({
    required this.size,
    required this.angle,
  });

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: angle,

      child: Icon(
        Icons.pets,
        size: size,

        color:
            Colors.white.withOpacity(0.18),
      ),
    );
  }
}
