import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:mjpeg_view/mjpeg_view.dart';

import '../main.dart';

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

  // Selected servo angle
// Selected feeding portion
String _selectedPortion = 'medium';

/////////////////
//String _foodLvel = 'unknown';
  // =========================
  // PET DETECTION
  // =========================

  String _petDetection = 'No Pet Detected';
  double _petConfidence = 0.0;


  Timer? _detectionTimer;

  // =========================
  // ANIMATION
  // =========================

  late AnimationController _pawController;
  late Animation<double> _pawAnimation;

  // Purely decorative pulse for the "live" indicators — UI only.
  late AnimationController _pulseController;

  // =========================
  // PALETTE (matches SmartFeed's established pet-warm theme)
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

    // Start checking YOLO detection
    _startDetectionPolling();
  }

  //
 
  // =========================
  // PET DETECTION POLLING
  // =========================

  void _startDetectionPolling() {
    _detectionTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) async {
        try {
          final response = await http.get(
            Uri.parse(
              '192.168.137.173',
            ),
          ).timeout(
            const Duration(seconds: 3),
          );

          if (response.statusCode == 200) {
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
  if (_isFeeding) return;

  final String portion = _selectedPortion;
  final String portionLabel = _getPortionLabel(portion);

  setState(() {
    _isFeeding = true;
    _status = "🍖 Dispensing ($portionLabel)...";
  });

  try {
    // =================================================
    // 1. SEND PORTION COMMAND TO ESP32 THROUGH SUPABASE
    // =================================================
    //
    // IMPORTANT:
    // The physical servo ALWAYS opens to 45°.
    // The command tells the ESP32 how long to keep it open.
    //

    await supabase
        .from('servo')
        .update({
      'angle': 45,
      'command': portion,
      'last_confirmed': 0,
    })
        .eq('id', 27);

    // =================================================
    // 2. SAVE FEEDING HISTORY
    // =================================================

    await supabase.from('feeding_logs').insert({
      'angle': 45,
      'portion_label': portionLabel,
      'trigger_type': 'manual',
      'fed_at': DateTime.now().toUtc().toIso8601String(),
    });

    // =================================================
    // 3. PAW ANIMATION
    // =================================================

    _pawController.forward(from: 0);

    // =================================================
    // 4. WAIT FOR ESP32 TO FINISH FEEDING
    // =================================================
    //
    // ESP32 is responsible for:
    // Small  = 0.5 sec
    // Medium = 1 sec
    // Full   = 2 sec
    // then automatically closing the feeder.
    //

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
    if (!mounted) return;

    setState(() {
      _isFeeding = false;
    });
  }
}

  // =========================
  // DISPOSE
  // =========================

  @override
  void dispose() {
    _detectionTimer?.cancel();
    _pawController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  // =========================
  // BUILD
  // =========================

  @override
  Widget build(BuildContext context) {
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

          // ---- DECORATIVE PAW PRINTS ----
          const Positioned(
            top: 70,
            left: -10,
            child: _GhostPaw(size: 46, angle: -0.4),
          ),
          const Positioned(
            top: 140,
            right: 6,
            child: _GhostPaw(size: 30, angle: 0.5),
          ),
          const Positioned(
            bottom: 90,
            left: 18,
            child: _GhostPaw(size: 34, angle: 0.2),
          ),
          const Positioned(
            bottom: 30,
            right: -6,
            child: _GhostPaw(size: 50, angle: -0.3),
          ),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                20, 12, 20, 28,
              ),
              child: Column(
                children: [

                  // =========================
                  // HEADER
                  // =========================

                 

                  const SizedBox(height: 10),

                  Text(
                    'Realtime pet food controller 🐶',
                    style: GoogleFonts.dmSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: _brownSoft.withOpacity(0.85),
                    ),
                  ),

                  const SizedBox(height: 22),

                  // =========================
                  // CAMERA
                  // =========================

                  Stack(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          borderRadius:
                              BorderRadius.circular(28),
                          border: Border.all(
                            color: Colors.white,
                            width: 4,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: _brown.withOpacity(0.18),
                              blurRadius: 16,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius:
                              BorderRadius.circular(24),
                          child: MjpegView( 
                            uri:
                               'http://smartfeedcam.local:81/stream',
                            width: double.infinity,
                            height: 220,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),

                      // "LIVE" badge
                      Positioned(
                        top: 14,
                        left: 14,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.55),
                            borderRadius:
                                BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
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
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'LIVE',
                                style: GoogleFonts.dmSans(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.6,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // paw corner sticker
                      Positioned(
                        bottom: 12,
                        right: 12,
                        child: Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.85),
                            shape: BoxShape.circle,
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

                  const SizedBox(height: 18),

                  // =========================
                  // PET DETECTION CARD
                  // =========================

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.88),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: _brownSoft.withOpacity(0.12),
                          blurRadius: 12,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment:
                              MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(
                                color: _blush,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.pets,
                                color: _salmon,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Pet Detection',
                              style: GoogleFonts.fraunces(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: _brownSoft,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 14),

                        _buildDetectionPill(),

                        if (_petConfidence > 0) ...[
                          const SizedBox(height: 14),
                          _buildConfidenceBar(),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 26),

                  // =========================
                  // PORTION SELECTORS
                  // =========================

                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Choose a Portion to Feed🥣',
                      style: GoogleFonts.fraunces(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: _brownSoft,
                      ),
                    ),
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

    const SizedBox(width: 12),

    _buildPresetChip(
      label: 'Medium',
      subtext: 'Portion',
      portion: 'medium',
      icon: Icons.set_meal,
    ),

    const SizedBox(width: 12),

    _buildPresetChip(
      label: 'Full',
      subtext: 'Portion',
      portion: 'full',
      icon: Icons.dinner_dining,
    ),
  ],
),

                  const SizedBox(height: 28),

                  // =========================
                  // FEED NOW BUTTON
                  // =========================

                  SizedBox(
                    width: double.infinity,
                    height: 64,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: _isFeeding
                              ? [_blush, _blush]
                              : [_salmon, _peach],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: _salmon.withOpacity(0.4),
                            blurRadius: 18,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: ElevatedButton.icon(
                        onPressed: _isFeeding ? null : feedNow,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(24),
                          ),
                        ),
                        icon: _isFeeding
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.4,
                                  color: _salmon,
                                ),
                              )
                            : AnimatedBuilder(
                                animation: _pawAnimation,
                                builder: (context, _) {
                                  return Transform.rotate(
                                    angle:
                                        _pawAnimation.value * 0.35,
                                    child: const Icon(
                                      Icons.pets,
                                      size: 26,
                                    ),
                                  );
                                },
                              ),
                        label: Text(
                          _isFeeding ? 'FEEDING...' : 'FEED NOW',
                          style: GoogleFonts.dmSans(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.1,
                            color: _isFeeding ? _salmon : Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // =========================
                  // STATUS
                  // =========================

                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 16,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Text(
                      _status,
                      style: GoogleFonts.dmSans(
                        fontSize: 15,
                        color: _brownSoft,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
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
  // DETECTION PILL (UI helper — reads existing state only)
  // =========================

  Widget _buildDetectionPill() {
    late final Color pillColor;
    late final Color dotColor;
    late final String label;

    if (_petDetection == 'Yuri') {
      pillColor = _leafGreen.withOpacity(0.15);
      dotColor = _leafGreen;
      label = 'Yuri Detected';
    } else if (_petDetection == 'Unknown Pet') {
      pillColor = _amber.withOpacity(0.18);
      dotColor = _amber;
      label = 'Unknown Pet';
    } else {
      pillColor = Colors.grey.withOpacity(0.15);
      dotColor = Colors.grey;
      label = 'No Pet Detected';
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: 10,
        horizontal: 16,
      ),
      decoration: BoxDecoration(
        color: pillColor,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: dotColor,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: GoogleFonts.dmSans(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: _brownSoft,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfidenceBar() {
    final pct = _petConfidence.clamp(0.0, 1.0);

    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: LinearProgressIndicator(
            value: pct,
            minHeight: 8,
            backgroundColor: _blush.withOpacity(0.5),
            valueColor:
                const AlwaysStoppedAnimation<Color>(_salmon),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '${(_petConfidence * 100).toStringAsFixed(1)}% confidence',
          style: GoogleFonts.dmSans(
            fontSize: 12.5,
            color: _brownSoft.withOpacity(0.75),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // =========================
  // PRESET CHIP
  // =========================

  Widget _buildPresetChip({
  required String label,
  required String subtext,
  required String portion,
  required IconData icon,
}) {
  final isSelected = _selectedPortion == portion;

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
        scale: isSelected ? 1.04 : 1.0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutBack,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(
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
                : Colors.white.withOpacity(0.85),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: isSelected
                  ? Colors.transparent
                  : _blush,
              width: 2,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: _salmon.withOpacity(0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 5),
                    ),
                  ]
                : [],
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: isSelected
                    ? Colors.white
                    : _salmon,
                size: 26,
              ),

              const SizedBox(height: 8),

              Text(
                label,
                style: GoogleFonts.dmSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isSelected
                      ? Colors.white
                      : _brownSoft,
                ),
              ),

              const SizedBox(height: 2),

              Text(
                subtext,
                style: GoogleFonts.dmSans(
                  fontSize: 11.5,
                  color: isSelected
                      ? Colors.white70
                      : _brownSoft.withOpacity(0.7),
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

// =========================
// SMALL DECORATIVE WIDGETS (UI only — no state/logic)
// =========================

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

  const _GhostPaw({required this.size, required this.angle});

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