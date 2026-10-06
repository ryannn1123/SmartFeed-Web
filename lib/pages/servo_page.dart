// This file-level directive tells Dart to ignore warnings about unused
// private elements/functions in this file.
// ignore_for_file: unused_element

// Provides asynchronous programming features such as Future, Timer, etc.
import 'dart:async';

// Provides JSON encoding and decoding functionality.
import 'dart:convert';

// Provides Flutter's Material Design widgets and UI framework.
import 'package:flutter/material.dart';

// Provides custom fonts used throughout the page.
import 'package:google_fonts/google_fonts.dart';

// Provides HTTP networking functionality for communicating with
// the Python/Flask pet detection server.
import 'package:http/http.dart' as http;

// Provides the MJPEG video widget used to display the live camera stream.
import 'package:mjpeg_view/mjpeg_view.dart';

// Imports the main.dart file so this page can access the global
// Supabase client named "supabase".
import '../main.dart';


// ============================================================
// SERVO PAGE
// ============================================================
// This is the main page for controlling the SmartFeed feeder.
//
// It provides:
// 1. Live camera viewing
// 2. Pet detection information
// 3. Feeding portion selection
// 4. Manual feeding
// 5. Feeder door OPEN/CLOSE controls
// 6. Feeding/detection status
// ============================================================

class ServoPage extends StatefulWidget {
  const ServoPage({super.key});

  @override
  State<ServoPage> createState() => _ServoPageState();
}


// ============================================================
// SERVO PAGE STATE
// ============================================================

class _ServoPageState extends State<ServoPage>
    with TickerProviderStateMixin {

  // =========================
  // FEEDING
  // =========================

  // Message displayed in the status card.
  String _status = 'Select portion & tap Feed Now';

  // True while the feeder is dispensing food.
  bool _isFeeding = false;

  // Currently selected portion: "small", "medium" or "full".
  String _selectedPortion = 'medium';


  // =========================
  // FEEDER DOOR (SERVO 2)
  // =========================

  // True while the feeder door is being opened.
  bool _isGateOpening = false;

  // True while the feeder door is being closed.
  bool _isGateClosing = false;

  // NEW: Current door state read from Supabase (feeder_door.command).
  //
  //   true  -> door is OPEN   (OPEN button disabled)
  //   false -> door is CLOSED (CLOSE button disabled)
  //   null  -> state not loaded yet (both buttons stay enabled)
  //
  // Because this comes from the database, it also updates when the
  // Python pet-detection script opens the door automatically.
  bool? _isDoorOpen;

  // NEW: Realtime subscription that listens for door changes.
  StreamSubscription<List<Map<String, dynamic>>>? _doorSub;


  // =========================
  // PET DETECTION
  // =========================

  // Name/status returned by the pet detection server.
  String _petDetection = 'No Pet Detected';

  // Confidence score from the pet detection server (0.0 - 1.0).
  double _petConfidence = 0.0;

  // Timer used to repeatedly request pet detection results.
  Timer? _detectionTimer;


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
  static const Color _mint = Color(0xFFB8E0D2);


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

    _pawAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _pawController, curve: Curves.easeOutBack),
    );

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1400),
      vsync: this,
    )..repeat(reverse: true);

    _shimmerController = AnimationController(
      duration: const Duration(milliseconds: 2400),
      vsync: this,
    )..repeat();

    // Starts repeatedly checking the pet detection server.
    _startDetectionPolling();

    // NEW: Starts listening to the feeder door state in Supabase.
    _listenDoorState();
  }


  // =========================
  // NEW: DOOR STATE LISTENER
  // =========================
  // Subscribes to the feeder_door row (id = 1) using Supabase Realtime.
  //
  // Whenever the "command" column changes (from this app, from the
  // Python script, or from anywhere else), the UI updates and the
  // correct button is enabled/disabled.
  //
  // NOTE: Realtime must be enabled for the "feeder_door" table in the
  // Supabase dashboard, otherwise only the initial value is received.
  void _listenDoorState() {
    _doorSub = supabase
        .from('feeder_door')
        .stream(primaryKey: ['id'])
        .eq('id', 1)
        .listen(
      (rows) {
        if (rows.isEmpty || !mounted) return;

        // Reads the command and normalizes it so "OPEN", "Open"
        // and "open" are all treated the same.
        final cmd = rows.first['command']?.toString().toLowerCase().trim();

        // Only "open" and "close" change the door state.
        // Any other value (e.g. "idle") keeps the last known state.
        if (cmd == 'open') {
          setState(() => _isDoorOpen = true);
        } else if (cmd == 'close') {
          setState(() => _isDoorOpen = false);
        }
      },
      onError: (_) {
        // Ignore stream errors so the page does not crash if the
        // connection drops. The stream reconnects automatically.
      },
    );
  }


  // =========================
  // PET DETECTION POLLING
  // =========================
  // Asks the Python/Flask server for the latest detection result
  // once every second.
  void _startDetectionPolling() {
    _detectionTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) async {
        try {
          final response = await http
              .get(Uri.parse('http://192.168.1.13:5000/detection'))
              .timeout(const Duration(seconds: 3));

          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);

            if (!mounted) return;

            setState(() {
              _petDetection = data['pet'] ?? 'No Pet Detected';
              _petConfidence = (data['confidence'] ?? 0.0).toDouble();
            });
          }
        } catch (e) {
          // Detection server may be offline - ignore on purpose so the
          // page does not crash.
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
    // Prevents another feeding while one is already running.
    if (_isFeeding) return;

    final String portion = _selectedPortion;
    final String portionLabel = _getPortionLabel(portion);

    setState(() {
      _isFeeding = true;
      _status = "🍖 Dispensing ($portionLabel)...";
    });

    try {
      // Updates the "servo" row so the ESP32 starts dispensing.
      await supabase.from('servo').update({
        'angle': 45,
        'command': portion,
        'last_confirmed': 0,
      }).eq('id', 27);

      // Saves the feeding in the history table.
      await supabase.from('feeding_logs').insert({
        'angle': 45,
        'portion_label': portionLabel,
        'trigger_type': 'manual',
        'fed_at': DateTime.now().toUtc().toIso8601String(),
      });

      _pawController.forward(from: 0);

      final feedingDuration = _getFeedingDuration(portion);

      await Future.delayed(
        feedingDuration + const Duration(milliseconds: 800),
      );

      if (!mounted) return;

      setState(() {
        _status = '✓ Fed successfully! ($portionLabel Portion)';
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _status = "❌ Error: $e";
      });
    } finally {
      if (mounted) {
        setState(() => _isFeeding = false);
      }
    }
  }


  // =========================
  // FEEDER DOOR - OPEN
  // =========================
  // The app does not move the servo directly. It updates the
  // "command" in Supabase and the ESP32 moves the servo.
  Future<void> openGate() async {
    // Prevents conflicting door operations.
    if (_isGateOpening || _isGateClosing) return;

    // NEW: Extra safety - do nothing if the door is already open.
    if (_isDoorOpen == true) return;

    setState(() {
      _isGateOpening = true;
      _status = '🔓 Opening feeder...';
    });

    try {
      await supabase
          .from('feeder_door')
          .update({'command': 'open'})
          .eq('id', 1);

      if (!mounted) return;

      setState(() {
        // NEW: Update immediately so the OPEN button disables right
        // away, without waiting for the realtime event.
        _isDoorOpen = true;
        _status = '✓ Feeder opened';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _status = '❌ Feeder error: $e');
    } finally {
      if (mounted) setState(() => _isGateOpening = false);
    }
  }


  // =========================
  // FEEDER DOOR - CLOSE
  // =========================
  Future<void> closeGate() async {
    // Prevents conflicting door operations.
    if (_isGateOpening || _isGateClosing) return;

    // NEW: Extra safety - do nothing if the door is already closed.
    if (_isDoorOpen == false) return;

    setState(() {
      _isGateClosing = true;
      _status = '🔒 Closing feeder...';
    });

    try {
      await supabase
          .from('feeder_door')
          .update({'command': 'close'})
          .eq('id', 1);

      if (!mounted) return;

      setState(() {
        // NEW: Update immediately so the CLOSE button disables right
        // away, without waiting for the realtime event.
        _isDoorOpen = false;
        _status = '✓ Feeder closed';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _status = '❌ Feeder error: $e');
    } finally {
      if (mounted) setState(() => _isGateClosing = false);
    }
  }


  // =========================
  // DISPOSE
  // =========================
  @override
  void dispose() {
    // Stops the pet detection timer.
    _detectionTimer?.cancel();

    // NEW: Stops listening to the door state.
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
    // True while any major operation is running.
    final busy = _isFeeding || _isGateOpening || _isGateClosing;

    return Scaffold(
      body: Stack(
        children: [

          // ---- BACKGROUND ----
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


          // ---- SOFT BLOBS ----
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


          // ---- GHOST PAWS ----
          const Positioned(
            top: 80,
            left: -10,
            child: _GhostPaw(size: 46, angle: -0.4),
          ),

          const Positioned(
            top: 150,
            right: 6,
            child: _GhostPaw(size: 30, angle: 0.5),
          ),

          const Positioned(
            bottom: 100,
            left: 18,
            child: _GhostPaw(size: 34, angle: 0.2),
          ),

          const Positioned(
            bottom: 40,
            right: -6,
            child: _GhostPaw(size: 50, angle: -0.3),
          ),


          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),

              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // =========================
                  // LIVE CAMERA
                  // =========================
                  Stack(
                    children: [

                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                            color: Colors.white,
                            width: 4,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: _brown.withOpacity(0.22),
                              blurRadius: 22,
                              offset: const Offset(0, 12),
                            ),
                            BoxShadow(
                              color: _salmon.withOpacity(0.15),
                              blurRadius: 30,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),

                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(26),

                          child: Stack(
                            children: [

                              // MJPEG live stream from the Flask server.
                              MjpegView(
                                uri: 'http://192.168.1.13:5000/video',
                                width: double.infinity,
                                height: 230,
                                fit: BoxFit.cover,
                              ),

                              // Dark gradient at the bottom so overlay
                              // information is easier to see.
                              Positioned(
                                left: 0,
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  height: 70,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.transparent,
                                        Colors.black.withOpacity(0.45),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),


                      // "LIVE" badge
                      Positioned(
                        top: 14,
                        left: 14,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 11,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.2),
                            ),
                          ),

                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [

                              // Pulsing red dot.
                              AnimatedBuilder(
                                animation: _pulseController,
                                builder: (context, _) {
                                  final t = _pulseController.value;

                                  return Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Color.lerp(
                                        const Color(0xFFFF5C5C),
                                        const Color(0xFFFFB4B4),
                                        t,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFFFF5C5C)
                                              .withOpacity(0.6),
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
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),


                      // Detection pill overlay (bottom-left)
                      Positioned(
                        bottom: 14,
                        left: 14,
                        child: _buildDetectionPill(),
                      ),


                      // Paw corner sticker
                      Positioned(
                        bottom: 14,
                        right: 14,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.9),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: _salmon.withOpacity(0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
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


                  // Confidence bar (only shows if a pet is detected)
                  if (_petDetection != 'No Pet Detected') ...[
                    const SizedBox(height: 12),
                    _buildConfidenceBar(),
                  ],


                  const SizedBox(height: 22),


                  // =========================
                  // PORTION SELECTORS
                  // =========================
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: _salmon.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
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


                  // =========================
                  // FEED NOW BUTTON
                  // =========================
                  SizedBox(
                    width: double.infinity,
                    height: 66,

                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(26),

                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: _isFeeding
                              ? [_blush, _blush]
                              : [_salmon, _peach],
                        ),

                        boxShadow: _isFeeding
                            ? []
                            : [
                                BoxShadow(
                                  color: _salmon.withOpacity(0.5),
                                  blurRadius: 22,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                      ),

                      child: ElevatedButton.icon(
                        onPressed: busy ? null : feedNow,

                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(26),
                          ),
                        ),

                        icon: _isFeeding
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.6,
                                  color: Colors.white,
                                ),
                              )
                            : AnimatedBuilder(
                                animation: _pawAnimation,
                                builder: (context, _) {
                                  return Transform.rotate(
                                    angle: _pawAnimation.value * 0.35,
                                    child: const Icon(
                                      Icons.pets,
                                      size: 28,
                                      color: Colors.white,
                                    ),
                                  );
                                },
                              ),

                        label: Text(
                          _isFeeding ? 'FEEDING...' : 'FEED NOW',
                          style: GoogleFonts.dmSans(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),


                  const SizedBox(height: 20),


                  // =========================
                  // DOOR CONTROLS
                  // =========================
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: _leafGreen.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.door_sliding_rounded,
                          size: 14,
                          color: _leafGreen,
                        ),
                      ),

                      const SizedBox(width: 8),

                      Text(
                        'Feeder Door',
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


                  // OPEN and CLOSE buttons side-by-side.
                  Row(
                    children: [

                      // OPEN button.
                      // NEW: disabled when the door is already OPEN.
                      Expanded(
                        child: _DoorButton(
                          isBusy: busy,
                          isDisabled: _isDoorOpen == true,
                          isWorking: _isGateOpening,
                          label: 'OPEN',
                          workingLabel: 'OPENING...',
                          icon: Icons.lock_open_rounded,
                          color: _leafGreen,
                          onPressed: openGate,
                        ),
                      ),

                      const SizedBox(width: 12),

                      // CLOSE button.
                      // NEW: disabled when the door is already CLOSED.
                      Expanded(
                        child: _DoorButton(
                          isBusy: busy,
                          isDisabled: _isDoorOpen == false,
                          isWorking: _isGateClosing,
                          label: 'CLOSE',
                          workingLabel: 'CLOSING...',
                          icon: Icons.lock_rounded,
                          color: const Color(0xFFC23B3B),
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
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                    width: double.infinity,

                    padding: const EdgeInsets.symmetric(
                      vertical: 16,
                      horizontal: 18,
                    ),

                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.75),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.9),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _brownSoft.withOpacity(0.08),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),

                    child: Row(
                      children: [

                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                _salmon.withOpacity(0.2),
                                _peach.withOpacity(0.15),
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
                            style: GoogleFonts.dmSans(
                              fontSize: 14,
                              color: _brownSoft,
                              fontWeight: FontWeight.w700,
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
  // Small status indicator shown on top of the camera.
  Widget _buildDetectionPill() {
    late final Color pillColor;
    late final Color dotColor;
    late final String label;
    late final IconData icon;

    if (_petDetection == 'Yuri') {
      pillColor = _leafGreen.withOpacity(0.2);
      dotColor = _leafGreen;
      label = 'Yuri Detected';
      icon = Icons.pets;
    } else if (_petDetection == 'Unknown Pet') {
      pillColor = _amber.withOpacity(0.22);
      dotColor = _amber;
      label = 'Unknown Pet';
      icon = Icons.help_outline_rounded;
    } else {
      pillColor = Colors.black.withOpacity(0.5);
      dotColor = Colors.white70;
      label = 'No Pet Detected';
      icon = Icons.visibility_off_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),

      decoration: BoxDecoration(
        color: _petDetection == 'No Pet Detected'
            ? pillColor
            : Colors.white.withOpacity(0.95),

        borderRadius: BorderRadius.circular(30),

        boxShadow: _petDetection == 'No Pet Detected'
            ? null
            : [
                BoxShadow(
                  color: dotColor.withOpacity(0.35),
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
              color: dotColor.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 11, color: dotColor),
          ),

          const SizedBox(width: 7),

          Text(
            label,
            style: GoogleFonts.dmSans(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: _petDetection == 'No Pet Detected'
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
    // Keeps the value between 0.0 and 1.0.
    final pct = _petConfidence.clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),

      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.75),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.9),
          width: 1.2,
        ),
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          Row(
            children: [
              Icon(
                Icons.analytics_outlined,
                size: 14,
                color: _brownSoft.withOpacity(0.7),
              ),

              const SizedBox(width: 6),

              Text(
                'Detection confidence',
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: _brownSoft.withOpacity(0.8),
                ),
              ),

              const Spacer(),

              Text(
                '${(_petConfidence * 100).toStringAsFixed(1)}%',
                style: GoogleFonts.fraunces(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: _salmon,
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          ClipRRect(
            borderRadius: BorderRadius.circular(20),

            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: pct),
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeOutCubic,

              builder: (context, value, _) {
                return LinearProgressIndicator(
                  value: value,
                  minHeight: 9,
                  backgroundColor: _blush.withOpacity(0.5),
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(_salmon),
                );
              },
            ),
          ),
        ],
      ),
    );
  }


  // =========================
  // PRESET PORTIONS
  // =========================
  // Creates one of the Small, Medium, or Full portion buttons.
  Widget _buildPresetChip({
    required String label,
    required String subtext,
    required String portion,
    required IconData icon,
  }) {
    final isSelected = _selectedPortion == portion;

    return Expanded(
      child: GestureDetector(

        // Prevents changing the portion while feeding.
        onTap: _isFeeding
            ? null
            : () {
                setState(() => _selectedPortion = portion);
              },

        child: AnimatedScale(
          scale: isSelected ? 1.05 : 1.0,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutBack,

          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),

            padding: const EdgeInsets.symmetric(
              vertical: 16,
              horizontal: 10,
            ),

            decoration: BoxDecoration(
              gradient: isSelected
                  ? const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [_salmon, _peach],
                    )
                  : null,

              color: isSelected ? null : Colors.white.withOpacity(0.92),

              borderRadius: BorderRadius.circular(26),

              border: Border.all(
                color: isSelected
                    ? Colors.transparent
                    : _blush.withOpacity(0.9),
                width: 2,
              ),

              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: _salmon.withOpacity(0.4),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: _brownSoft.withOpacity(0.06),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
            ),

            child: Column(
              children: [

                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.white.withOpacity(0.25)
                        : _salmon.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    color: isSelected ? Colors.white : _salmon,
                    size: 22,
                  ),
                ),

                const SizedBox(height: 8),

                Text(
                  label,
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: isSelected ? Colors.white : _brownSoft,
                  ),
                ),

                const SizedBox(height: 1),

                Text(
                  subtext,
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isSelected
                        ? Colors.white70
                        : _brownSoft.withOpacity(0.6),
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
// Reusable widget for the feeder door OPEN and CLOSE buttons.
// ============================================================

class _DoorButton extends StatelessWidget {

  // True while ANY operation (feeding / opening / closing) is running.
  final bool isBusy;

  // NEW: True when the door is already in the state this button would
  // set (e.g. OPEN button while the door is already open).
  final bool isDisabled;

  // True while THIS button's own operation is running.
  final bool isWorking;

  // Normal button text.
  final String label;

  // Text displayed while the operation is running.
  final String workingLabel;

  // Icon displayed on the button.
  final IconData icon;

  // Button color.
  final Color color;

  // Function executed when the button is pressed.
  final VoidCallback onPressed;

  const _DoorButton({
    required this.isBusy,
    required this.isDisabled, // NEW
    required this.isWorking,
    required this.label,
    required this.workingLabel,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {

    // NEW: Disabled when busy OR when the door is already in this state.
    final disabled = isBusy || isDisabled;

    return SizedBox(
      height: 56,

      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),

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
                    color: color.withOpacity(0.4),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
        ),

        child: ElevatedButton.icon(

          // null disables the button.
          onPressed: disabled ? null : onPressed,

          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),

          icon: isWorking
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: Colors.white,
                  ),
                )
              : Icon(icon, size: 22, color: Colors.white),

          label: Text(
            isWorking ? workingLabel : label,
            style: GoogleFonts.dmSans(
              fontSize: 15,
              fontWeight: FontWeight.w800,
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

// Circular paw icon with a SmartFeed gradient (decorative only).
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


// Faded decorative paw icon used in the page background.
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
        color: Colors.white.withOpacity(0.18),
      ),
    );
  }
}