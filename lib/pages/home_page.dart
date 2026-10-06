import 'package:SmartFeed/services/ai_recommendation_page.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show
        PostgresChangeEvent,
        PostgresChangeFilter,
        PostgresChangeFilterType,
        RealtimeChannel;

import '../main.dart';
import 'servo_page.dart';
import 'schedule_page.dart';
import 'vet_page.dart';
import 'pet_registration_page.dart';
import 'history_page.dart';
import 'login_page.dart';
import '../widgets/chatbot.dart';
import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';



class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

Future<void> _registerFcmToken() async {
  try {
    final user = supabase.auth.currentUser;

    if (user == null) {
      debugPrint('No logged-in user.');
      return;
    }

    final token = await FirebaseMessaging.instance.getToken();

    if (token == null || token.isEmpty) {
      debugPrint('FCM token is empty.');
      return;
    }

    await supabase.from('fcm_tokens').upsert(
      {
        'user_id': user.id,
        'token': token,
        'updated_at':
            DateTime.now().toUtc().toIso8601String(),
      },
      onConflict: 'user_id,token',
    );

    debugPrint('FCM token registered successfully.');
  } catch (e) {
    debugPrint('FCM registration error: $e');
  }
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;

  // ============================================================
  // FOOD LEVEL
  // ============================================================

  String _foodLevel = 'unknown';
  RealtimeChannel? _foodLevelChannel;

  // Prevents the low-food alert from appearing repeatedly
  // while the food level remains low.
  bool _lowAlertShown = false;

  // ============================================================
  // PAGES
  // ============================================================

  final List<Widget> _pages = const [
    ServoPage(),
    SchedulePage(),
    HistoryPage(),
    VetPage(),
    PetRegistrationPage(),
    AIRecommendationPage(),
  ];

  // ============================================================
  // COLORS
  // ============================================================

  static const Color _coralPink = Color(0xFFFF9E89);
  static const Color _warmSand = Color(0xFFFFD8A0);
  static const Color _inactive = Color(0xFF8A92A3);

  // ============================================================
  // FOOD LEVEL COLORS
  // ============================================================

  static const Map<String, Color> _levelColors = {
    'full': Color(0xFF3FA24A),
    'medium': Color(0xFFC98A1F),
    'small': Color(0xFFD8433C),
    'unknown': Color(0xFF8A92A3),
  };

  static const Map<String, double> _levelFraction = {
    'full': 1.0,
    'medium': 0.5,
    'small': 0.15,
    'unknown': 0.0,
  };

  // Sensor stores "small" when hopper is low.
  static const Map<String, String> _levelLabels = {
    'full': 'Full',
    'medium': 'Medium',
    'small': 'Low',
    'unknown': 'Unknown',
  };

  // ============================================================
  // NAVIGATION ITEMS
  // ============================================================

  final List<Map<String, dynamic>> _navItems = const [
    {
      'icon': Icons.tune_rounded,
      'label': 'Controller',
    },
    {
      'icon': Icons.schedule_rounded,
      'label': 'Schedule',
    },
    {
      'icon': Icons.history_rounded,
      'label': 'History',
    },
    {
      'icon': Icons.health_and_safety_rounded,
      'label': 'Vet',
    },
    {
      'icon': Icons.pets_rounded,
      'label': 'Pets',
    },
    {
      'icon': Icons.auto_awesome_rounded,
      'label': 'AI',
    },
  ];

  // ============================================================
  // FOOD LEVEL GETTERS
  // ============================================================

  Color get _foodLevelColor =>
      _levelColors[_foodLevel] ?? _inactive;

  double get _foodLevelFraction =>
      _levelFraction[_foodLevel] ?? 0.0;

  String get _foodLevelLabel =>
      _levelLabels[_foodLevel] ?? 'Unknown';

  // ============================================================
  // INIT
  // ============================================================

@override
void initState() {
  super.initState();

  _fetchFoodLevel();
  _subscribeToFoodLevel();

  _registerFcmToken();
  saveFcmToken();
}

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    if (_foodLevelChannel != null) {
      supabase.removeChannel(_foodLevelChannel!);
    }

    super.dispose();
  }

  // ============================================================
  // SIGN OUT
  // ============================================================

  Future<void> _signOut() async {
    try {
      // Sign out from Supabase
      await supabase.auth.signOut();

      if (!mounted) return;

      // Remove HomePage and all previous pages,
      // then return to LoginPage.
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => const LoginPage(),
        ),
        (route) => false,
      );
    } catch (e) {
      debugPrint('Sign out error: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Failed to sign out. Please try again.',
          ),
        ),
      );
    }
  }

  // ============================================================
  // FOOD LEVEL REALTIME
  // ============================================================

  void _subscribeToFoodLevel() {
    _foodLevelChannel = supabase
        .channel('sensor-food-level')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'sensor',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: 1,
          ),
          callback: (payload) {
            final row = payload.newRecord;

            if (!mounted || row.isEmpty) return;

            final level =
                (row['level'] as String?)?.toLowerCase();

            final alertSent =
                row['alert_sent'] as bool? ?? false;

            if (level != null && level != _foodLevel) {
              setState(() {
                _foodLevel = level;
              });
            }

            if (alertSent && !_lowAlertShown) {
              _lowAlertShown = true;
              _showLowFoodAlert();
            } else if (!alertSent) {
              _lowAlertShown = false;
            }
          },
        )
        .subscribe();
  }

  // ============================================================
  // FETCH FOOD LEVEL
  // ============================================================

  Future<void> _fetchFoodLevel() async {
    try {
      final data = await supabase
          .from('sensor')
          .select('level, alert_sent')
          .eq('id', 1)
          .single();

      if (!mounted) return;

      final level =
          (data['level'] as String?)?.toLowerCase();

      final alertSent =
          data['alert_sent'] as bool? ?? false;

      if (level != null && level != _foodLevel) {
        setState(() {
          _foodLevel = level;
        });
      }

      if (alertSent && !_lowAlertShown) {
        _lowAlertShown = true;
        _showLowFoodAlert();
      } else if (!alertSent) {
        _lowAlertShown = false;
      }
    } catch (_) {
      // Keep showing the last known food level.
    }
  }

  // ============================================================
  // LOW FOOD ALERT
  // ============================================================

  void _showLowFoodAlert() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFFD8433C),
        content: const Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: Colors.white,
            ),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Food is running low — time to refill the hopper!',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        duration: Duration(seconds: 4),
      ),
    );
  }

  // ============================================================
  // FOOD LEVEL DETAILS
  // ============================================================

  void _showFoodLevelDetails() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) {
        final color = _foodLevelColor;
        final fraction = _foodLevelFraction;

        return Container(
          padding: const EdgeInsets.fromLTRB(
            24,
            20,
            24,
            32,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(28),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E5EA),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),

              const SizedBox(height: 20),

              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.rice_bowl_rounded,
                  color: color,
                  size: 30,
                ),
              ),

              const SizedBox(height: 14),

              Text(
                'Food Level: $_foodLevelLabel',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF172033),
                ),
              ),

              const SizedBox(height: 14),

              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: fraction,
                  minHeight: 10,
                  backgroundColor: const Color(0xFFEFF1F5),
                  valueColor:
                      AlwaysStoppedAnimation<Color>(color),
                ),
              ),

              const SizedBox(height: 16),

              Text(
                _foodLevel == 'small'
                    ? 'The hopper is running low — consider refilling soon.'
                    : 'Your feeder currently has $_foodLevelLabel food levels.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF8A92A3),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ============================================================
  // FOOD LEVEL BUTTON
  // ============================================================

  Widget _buildFoodLevelButton() {
    final color = _foodLevelColor;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: _showFoodLevelDetails,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: color.withOpacity(0.4),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.rice_bowl_rounded,
                size: 16,
                color: color,
              ),

              const SizedBox(width: 6),

              Text(
                _foodLevelLabel.toUpperCase(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: color,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final user = supabase.auth.currentUser;

    final userName =
        user?.userMetadata?['full_name'] ?? 'Pet Parent';

    final userAvatar =
        user?.userMetadata?['avatar_url'];

    return Scaffold(
      extendBody: true,
      backgroundColor: const Color(0xFFFFFDF9),

      // ========================================================
      // APP BAR
      // ========================================================

      appBar: AppBar(
        backgroundColor: _coralPink,
        elevation: 0,
        centerTitle: false,
        titleSpacing: 18,

        title: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFFFF9E89),
                    Color(0xFFFFBFA3),
                  ],
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: _coralPink.withOpacity(0.28),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Icon(
                Icons.pets_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),

            const SizedBox(width: 10),

            RichText(
              text: const TextSpan(
                children: [
                  TextSpan(
                    text: 'Smart',
                    style: TextStyle(
                      color: Color(0xFF172033),
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                  TextSpan(
                    text: 'Feed',
                    style: TextStyle(
                      color: Color(0xFFFF6F61),
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        // ======================================================
        // APP BAR ACTIONS
        // ======================================================

        actions: [
          _buildFoodLevelButton(),

          PopupMenuButton<void>(
            offset: const Offset(0, 48),
            color: Colors.white,
            elevation: 8,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),

            child: Padding(
              padding: const EdgeInsets.only(right: 14),
              child: CircleAvatar(
                radius: 18,
                backgroundColor: _coralPink,

                backgroundImage: userAvatar != null
                    ? NetworkImage(userAvatar)
                    : null,

                child: userAvatar == null
                    ? Text(
                        userName.isNotEmpty
                            ? userName[0].toUpperCase()
                            : 'P',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                        ),
                      )
                    : null,
              ),
            ),

            // ==================================================
            // PROFILE MENU
            // ==================================================

            itemBuilder: (_) => [
              PopupMenuItem<void>(
                enabled: false,
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      userName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF172033),
                      ),
                    ),

                    Text(
                      user?.email ?? '',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF8A92A3),
                      ),
                    ),
                  ],
                ),
              ),

              const PopupMenuDivider(),

              // =================================================
              // FIXED SIGN OUT BUTTON
              // =================================================

              PopupMenuItem<void>(
                onTap: _signOut,
                child: const Row(
                  children: [
                    Icon(
                      Icons.logout_rounded,
                      size: 18,
                      color: Color(0xFFFF6F61),
                    ),

                    SizedBox(width: 8),

                    Text('Sign out'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),

      // ========================================================
      // BODY
      // ========================================================

      body: Stack(
        children: [
          const _PetBackground(),
          _pages[_currentIndex],
        ],
      ),

      // ========================================================
      // BOTTOM NAVIGATION
      // ========================================================

      bottomNavigationBar: SafeArea(
        child: Container(
          margin: const EdgeInsets.fromLTRB(
            16,
            0,
            16,
            12,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: 4,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),

          child: Row(
            children: List.generate(
              _navItems.length,
              (index) {
                final isSelected =
                    _currentIndex == index;

                final item = _navItems[index];

                return Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _currentIndex = index;
                      });
                    },
                    behavior: HitTestBehavior.opaque,

                    child: AnimatedContainer(
                      duration:
                          const Duration(milliseconds: 200),

                      padding:
                          const EdgeInsets.symmetric(
                        horizontal: 2,
                        vertical: 6,
                      ),

                      decoration: BoxDecoration(
                        color: isSelected
                            ? _warmSand.withOpacity(0.55)
                            : Colors.transparent,
                        borderRadius:
                            BorderRadius.circular(20),
                      ),

                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            item['icon'] as IconData,
                            size: 22,
                            color: isSelected
                                ? _coralPink
                                : _inactive,
                          ),

                          const SizedBox(height: 3),

                          Text(
                            item['label'] as String,
                            maxLines: 1,
                            overflow:
                                TextOverflow.ellipsis,
                            textAlign: TextAlign.center,

                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: isSelected
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                              color: isSelected
                                  ? _coralPink
                                  : _inactive,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),

      // ========================================================
      // PETBOT
      // ========================================================

      floatingActionButton: const Padding(
        padding: EdgeInsets.only(bottom: 20),
        child: FloatingChatbot(),
      ),
    );
  }
}

// ================================================================
// PET BACKGROUND
// ================================================================

class _PetBackground extends StatelessWidget {
  const _PetBackground();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -90,
            left: -70,
            child: _Blob(
              size: 210,
              color: const Color(0xFFFF9E89),
              opacity: 0.34,
            ),
          ),

          Positioned(
            bottom: 70,
            right: -85,
            child: _Blob(
              size: 230,
              color: const Color(0xFFFFBFA3),
              opacity: 0.28,
            ),
          ),

          Positioned(
            bottom: -65,
            left: -70,
            child: _Blob(
              size: 210,
              color: const Color(0xFFFFD8A0),
              opacity: 0.34,
            ),
          ),

          Positioned(
            top: 145,
            right: 24,
            child: Icon(
              Icons.pets_rounded,
              size: 34,
              color: const Color(0xFFFF9E89)
                  .withOpacity(0.08),
            ),
          ),

          Positioned(
            top: 250,
            left: 28,
            child: Icon(
              Icons.favorite_rounded,
              size: 24,
              color: const Color(0xFFFFBFA3)
                  .withOpacity(0.1),
            ),
          ),
        ],
      ),
    );
  }
}

// ================================================================
// BLOB
// ================================================================

class _Blob extends StatelessWidget {
  final double size;
  final Color color;
  final double opacity;

  const _Blob({
    required this.size,
    required this.color,
    required this.opacity,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withOpacity(opacity),
        shape: BoxShape.circle,
      ),
    );
  }
}