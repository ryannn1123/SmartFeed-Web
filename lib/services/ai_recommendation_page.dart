import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/ai_recommendation_service.dart';
import '../services/recommendation_data_service.dart';

class _Palette {
  static const Color salmon = Color(0xFFFA7268);
  static const Color peach = Color(0xFFFF9E89);
  static const Color blush = Color(0xFFFFD6C4);
  static const Color cream = Color(0xFFFFEFC4);
  static const Color brown = Color(0xFF5B3A29);
  static const Color brownSoft = Color(0xFF7A3E2A);
  static const Color muted = Color(0xFFAD8A79);
  static const Color amber = Color(0xFFE0A438);
}

class AIRecommendationPage extends StatefulWidget {
  const AIRecommendationPage({super.key});

  @override
  State<AIRecommendationPage> createState() =>
      _AIRecommendationPageState();
}

class _AIRecommendationPageState
    extends State<AIRecommendationPage> {
  AIRecommendation? recommendation;

  bool loading = true;
  bool generating = false;

  String? errorMessage;

  @override
  void initState() {
    super.initState();

    // IMPORTANT:
    // Do NOT generate AI here.
    // We only load the previously saved recommendation.
    loadSavedRecommendation();
  }

  // ============================================================
  // LOAD SAVED RECOMMENDATION
  // ============================================================

  Future<void> loadSavedRecommendation() async {
    if (!mounted) return;

    setState(() {
      loading = true;
      errorMessage = null;
    });

    try {
      final saved =
          await AIRecommendationService
              .getSavedRecommendation();

      if (!mounted) return;

      setState(() {
        recommendation = saved;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        errorMessage = e.toString();
        loading = false;
      });
    }
  }

  // ============================================================
  // GENERATE NEW RECOMMENDATION
  // ============================================================

  Future<void> generateRecommendation() async {
    if (generating) return;

    setState(() {
      generating = true;
      errorMessage = null;
    });

    try {
      final logs =
          await RecommendationDataService
              .getFeedingLogs();

      final schedules =
          await RecommendationDataService
              .getSchedules();

      if (logs.isEmpty) {
        throw Exception(
          'There is not enough feeding history yet. '
          'Feed your pet several times before generating '
          'an AI recommendation.',
        );
      }

      final result =
          await AIRecommendationService
              .generateRecommendation(
        feedingLogs: logs,
        schedules: schedules,
      );

      // Save it to Supabase.
      //
      // Because user_id is UNIQUE, this replaces the
      // previous recommendation instead of creating another.
      await AIRecommendationService
          .saveRecommendation(result);

      if (!mounted) return;

      setState(() {
        recommendation = result;
        generating = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'New AI recommendation generated!',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        errorMessage = e.toString();
        generating = false;
      });
    }
  }

  // ============================================================
  // APPLY RECOMMENDATION
  // ============================================================

  Future<void> _applyRecommendation() async {
    final r = recommendation;

    if (r == null) {
      throw Exception(
        'No recommendation available.',
      );
    }

    final supabase =
        Supabase.instance.client;

    final user =
        supabase.auth.currentUser;

    if (user == null) {
      throw Exception(
        'User is not logged in.',
      );
    }

    int portionToAngle(String portion) {
      switch (portion.toLowerCase()) {
        case 'small':
          return 45;

        case 'medium':
          return 90;

        case 'full':
          return 180;

        default:
          throw Exception(
            'Invalid AI portion: $portion',
          );
      }
    }

    String normalizeTime(String time) {
      final parts = time.split(':');

      if (parts.length < 2) {
        throw Exception(
          'Invalid AI feeding time: $time',
        );
      }

      final hour =
          int.tryParse(parts[0]);

      final minute =
          int.tryParse(parts[1]);

      if (hour == null ||
          minute == null ||
          hour < 0 ||
          hour > 23 ||
          minute < 0 ||
          minute > 59) {
        throw Exception(
          'Invalid AI feeding time: $time',
        );
      }

      return '${hour.toString().padLeft(2, '0')}:'
          '${minute.toString().padLeft(2, '0')}:00';
    }

    final morningTime =
        normalizeTime(r.morningTime);

    final eveningTime =
        normalizeTime(r.eveningTime);

    final morningAngle =
        portionToAngle(r.morningPortion);

    final eveningAngle =
        portionToAngle(r.eveningPortion);

    // ----------------------------------------------------------
    // GET USER'S EXISTING SCHEDULES
    // ----------------------------------------------------------

    final existingResponse =
        await supabase
            .from('schedule')
            .select(
              '''
              id,
              feed_time,
              angle,
              enabled,
              user_id,
              feed_date
              ''',
            )
            .eq('user_id', user.id)
            .order(
              'feed_time',
              ascending: true,
            );

    final schedules =
        List<Map<String, dynamic>>.from(
      existingResponse,
    );

    Map<String, dynamic>? morningSchedule;

    Map<String, dynamic>? eveningSchedule;

    // ----------------------------------------------------------
    // FIND EXISTING MORNING SCHEDULE
    // ----------------------------------------------------------

    for (final schedule in schedules) {
      final feedTime =
          schedule['feed_time']?.toString() ?? '';

      final hour =
          int.tryParse(
                feedTime.split(':').first,
              ) ??
              0;

      if (hour < 12) {
        morningSchedule = schedule;
        break;
      }
    }

    // ----------------------------------------------------------
    // FIND EXISTING EVENING SCHEDULE
    // ----------------------------------------------------------

    for (final schedule in schedules) {
      final feedTime =
          schedule['feed_time']?.toString() ?? '';

      final hour =
          int.tryParse(
                feedTime.split(':').first,
              ) ??
              0;

      if (hour >= 12) {
        eveningSchedule = schedule;
        break;
      }
    }

    // ----------------------------------------------------------
    // MORNING
    // ----------------------------------------------------------

    if (morningSchedule != null) {
      await supabase
          .from('schedule')
          .update({
        'feed_time': morningTime,
        'angle': morningAngle,
        'enabled': true,
      })
          .eq(
            'id',
            morningSchedule['id'],
          )
          .eq(
            'user_id',
            user.id,
          );
    } else {
      await supabase
          .from('schedule')
          .insert({
        'feed_time': morningTime,
        'angle': morningAngle,
        'enabled': true,
        'user_id': user.id,
      });
    }

    // ----------------------------------------------------------
    // EVENING
    // ----------------------------------------------------------

    if (eveningSchedule != null) {
      await supabase
          .from('schedule')
          .update({
        'feed_time': eveningTime,
        'angle': eveningAngle,
        'enabled': true,
      })
          .eq(
            'id',
            eveningSchedule['id'],
          )
          .eq(
            'user_id',
            user.id,
          );
    } else {
      await supabase
          .from('schedule')
          .insert({
        'feed_time': eveningTime,
        'angle': eveningAngle,
        'enabled': true,
        'user_id': user.id,
      });
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              _Palette.peach,
              Color(0xFFFFBFA3),
              Color(0xFFFFD8A0),
              _Palette.cream,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding:
                    const EdgeInsets.fromLTRB(
                  8,
                  10,
                  20,
                  4,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration:
                          const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient:
                            LinearGradient(
                          begin:
                              Alignment.topLeft,
                          end:
                              Alignment.bottomRight,
                          colors: [
                            _Palette.salmon,
                            _Palette.peach,
                          ],
                        ),
                      ),
                      child: const Icon(
                        Icons.auto_awesome,
                        color: Colors.white,
                        size: 17,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'AI Recommendation',
                      style:
                          GoogleFonts.fraunces(
                        color:
                            _Palette.brownSoft,
                        fontSize: 20,
                        fontWeight:
                            FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: RefreshIndicator(
                  color: _Palette.salmon,
                  onRefresh:
                      loadSavedRecommendation,
                  child: ListView(
                    physics:
                        const AlwaysScrollableScrollPhysics(),
                    padding:
                        const EdgeInsets.fromLTRB(
                      20,
                      12,
                      20,
                      40,
                    ),
                    children: [
                      _buildHeader(),

                      const SizedBox(
                        height: 20,
                      ),

                      if (loading)
                        const Center(
                          child: Padding(
                            padding:
                                EdgeInsets.all(40),
                            child:
                                CircularProgressIndicator(
                              color:
                                  _Palette.salmon,
                            ),
                          ),
                        ),

                      if (!loading &&
                          errorMessage != null)
                        _buildError(),

                      if (!loading &&
                          errorMessage == null &&
                          recommendation == null)
                        _buildNoRecommendation(),

                      if (recommendation != null &&
                          !loading)
                        _buildRecommendation(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // HEADER
  // ============================================================

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius:
            BorderRadius.circular(26),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _Palette.salmon,
            _Palette.peach,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: _Palette.salmon
                .withOpacity(0.35),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.all(10),
                  decoration:
                      BoxDecoration(
                    color: Colors.white
                        .withOpacity(0.25),
                    borderRadius:
                        BorderRadius.circular(
                      14,
                    ),
                  ),
                  child: const Icon(
                    Icons.auto_awesome,
                    color: Colors.white,
                    size: 26,
                  ),
                ),

                const SizedBox(
                  height: 14,
                ),

                Text(
                  'SmartFeed AI',
                  style:
                      GoogleFonts.fraunces(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight:
                        FontWeight.w700,
                  ),
                ),

                const SizedBox(
                  height: 6,
                ),

                Text(
                  "Your pet's feeding recommendation.",
                  style:
                      GoogleFonts.dmSans(
                    color: Colors.white
                        .withOpacity(0.92),
                    fontSize: 14,
                    fontWeight:
                        FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          Icon(
            Icons.pets,
            size: 64,
            color: Colors.white
                .withOpacity(0.22),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // NO RECOMMENDATION YET
  // ============================================================

  Widget _buildNoRecommendation() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white
            .withOpacity(0.75),
        borderRadius:
            BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.auto_awesome,
            size: 50,
            color: _Palette.salmon,
          ),

          const SizedBox(
            height: 16,
          ),

          Text(
            'No AI Recommendation Yet',
            textAlign: TextAlign.center,
            style:
                GoogleFonts.fraunces(
              color: _Palette.brown,
              fontSize: 21,
              fontWeight:
                  FontWeight.w700,
            ),
          ),

          const SizedBox(
            height: 8,
          ),

          Text(
            'Generate a recommendation using your '
            'pet’s feeding history and current schedule.',
            textAlign: TextAlign.center,
            style:
                GoogleFonts.dmSans(
              color: _Palette.muted,
              fontSize: 14,
              height: 1.4,
            ),
          ),

          const SizedBox(
            height: 20,
          ),

          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed:
                  generating
                      ? null
                      : generateRecommendation,
              style:
                  ElevatedButton.styleFrom(
                backgroundColor:
                    _Palette.salmon,
                foregroundColor:
                    Colors.white,
                elevation: 0,
                shape:
                    RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(
                    18,
                  ),
                ),
              ),
              icon: generating
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child:
                          CircularProgressIndicator(
                        strokeWidth: 2,
                        color:
                            Colors.white,
                      ),
                    )
                  : const Icon(
                      Icons.auto_awesome,
                    ),
              label: Text(
                generating
                    ? 'Generating...'
                    : 'Generate Recommendation',
                style:
                    GoogleFonts.dmSans(
                  fontWeight:
                      FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // RECOMMENDATION
  // ============================================================

  Widget _buildRecommendation() {
    final r = recommendation!;

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        _recommendationCard(
          icon: Icons.wb_sunny,
          title: 'Morning Feeding',
          value:
              '${_formatTime(r.morningTime)} • '
              '${_capitalize(r.morningPortion)}',
          color: _Palette.amber,
        ),

        const SizedBox(
          height: 12,
        ),

        _recommendationCard(
          icon: Icons.nightlight_round,
          title: 'Evening Feeding',
          value:
              '${_formatTime(r.eveningTime)} • '
              '${_capitalize(r.eveningPortion)}',
          color: _Palette.salmon,
        ),

        const SizedBox(
          height: 20,
        ),

        _textCard(
          'Why this recommendation?',
          r.reason,
          Icons.psychology,
        ),

        const SizedBox(
          height: 12,
        ),

        _textCard(
          'Food Efficiency',
          r.foodEfficiency,
          Icons.restaurant,
        ),

        const SizedBox(
          height: 12,
        ),

        _textCard(
          'Behavior Adjustment',
          r.behaviorAdjustment,
          Icons.pets,
        ),

        const SizedBox(
          height: 24,
        ),

        // ------------------------------------------------------
        // APPLY
        // ------------------------------------------------------

        SizedBox(
          width: double.infinity,
          height: 56,
          child: DecoratedBox(
            decoration:
                BoxDecoration(
              borderRadius:
                  BorderRadius.circular(20),
              gradient:
                  const LinearGradient(
                begin:
                    Alignment.topLeft,
                end:
                    Alignment.bottomRight,
                colors: [
                  _Palette.salmon,
                  _Palette.peach,
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: _Palette.salmon
                      .withOpacity(0.35),
                  blurRadius: 14,
                  offset:
                      const Offset(0, 6),
                ),
              ],
            ),
            child:
                ElevatedButton.icon(
              onPressed:
                  generating
                      ? null
                      : _showApplyDialog,
              style:
                  ElevatedButton.styleFrom(
                backgroundColor:
                    Colors.transparent,
                shadowColor:
                    Colors.transparent,
                foregroundColor:
                    Colors.white,
                elevation: 0,
                shape:
                    RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(
                    20,
                  ),
                ),
              ),
              icon: const Icon(
                Icons.check,
              ),
              label: Text(
                'Apply Recommendation',
                style:
                    GoogleFonts.dmSans(
                  fontSize: 16,
                  fontWeight:
                      FontWeight.w800,
                ),
              ),
            ),
          ),
        ),

        const SizedBox(
          height: 12,
        ),

        // ------------------------------------------------------
        // GENERATE AGAIN
        // ------------------------------------------------------

        SizedBox(
          width: double.infinity,
          height: 52,
          child:
              OutlinedButton.icon(
            onPressed:
                generating
                    ? null
                    : generateRecommendation,
            style:
                OutlinedButton.styleFrom(
              foregroundColor:
                  _Palette.salmon,
              backgroundColor:
                  Colors.white
                      .withOpacity(0.6),
              side: BorderSide(
                color: _Palette.salmon
                    .withOpacity(0.5),
              ),
              shape:
                  RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(
                  20,
                ),
              ),
            ),
            icon: generating
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child:
                        CircularProgressIndicator(
                      strokeWidth: 2,
                      color:
                          _Palette.salmon,
                    ),
                  )
                : const Icon(
                    Icons.refresh,
                  ),
            label: Text(
              generating
                  ? 'Generating...'
                  : 'Generate Again',
              style:
                  GoogleFonts.dmSans(
                fontWeight:
                    FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // RECOMMENDATION CARD
  // ============================================================

  Widget _recommendationCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      padding:
          const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white
            .withOpacity(0.82),
        borderRadius:
            BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black
                .withOpacity(0.05),
            blurRadius: 10,
            offset:
                const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration:
                BoxDecoration(
              color:
                  color.withOpacity(0.15),
              borderRadius:
                  BorderRadius.circular(
                14,
              ),
            ),
            child: Icon(
              icon,
              color: color,
              size: 25,
            ),
          ),

          const SizedBox(
            width: 14,
          ),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style:
                      GoogleFonts.dmSans(
                    color:
                        _Palette.muted,
                    fontSize: 13,
                    fontWeight:
                        FontWeight.w600,
                  ),
                ),

                const SizedBox(
                  height: 4,
                ),

                Text(
                  value,
                  style:
                      GoogleFonts.fraunces(
                    color:
                        _Palette.brown,
                    fontSize: 20,
                    fontWeight:
                        FontWeight.w700,
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
  // TEXT CARD
  // ============================================================

  Widget _textCard(
    String title,
    String text,
    IconData icon,
  ) {
    return Container(
      padding:
          const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white
            .withOpacity(0.72),
        borderRadius:
            BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration:
                BoxDecoration(
              color: _Palette.blush,
              borderRadius:
                  BorderRadius.circular(
                13,
              ),
            ),
            child: Icon(
              icon,
              color:
                  _Palette.brownSoft,
              size: 21,
            ),
          ),

          const SizedBox(
            width: 14,
          ),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style:
                      GoogleFonts.dmSans(
                    color:
                        _Palette.brown,
                    fontSize: 15,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),

                const SizedBox(
                  height: 6,
                ),

                Text(
                  text,
                  style:
                      GoogleFonts.dmSans(
                    color:
                        _Palette.brownSoft,
                    fontSize: 14,
                    height: 1.45,
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
  // ERROR
  // ============================================================

  Widget _buildError() {
    return Container(
      padding:
          const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white
            .withOpacity(0.8),
        borderRadius:
            BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.error_outline,
            color: _Palette.salmon,
            size: 42,
          ),

          const SizedBox(
            height: 12,
          ),

          Text(
            'Something went wrong',
            style:
                GoogleFonts.dmSans(
              color:
                  _Palette.brown,
              fontSize: 17,
              fontWeight:
                  FontWeight.w800,
            ),
          ),

          const SizedBox(
            height: 8,
          ),

          Text(
            errorMessage ?? 'Unknown error',
            textAlign:
                TextAlign.center,
            style:
                GoogleFonts.dmSans(
              color:
                  _Palette.muted,
              fontSize: 13,
              height: 1.4,
            ),
          ),

          const SizedBox(
            height: 16,
          ),

          ElevatedButton(
            onPressed:
                loadSavedRecommendation,
            style:
                ElevatedButton.styleFrom(
              backgroundColor:
                  _Palette.salmon,
              foregroundColor:
                  Colors.white,
            ),
            child:
                const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // APPLY DIALOG
  // ============================================================

  void _showApplyDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor:
              _Palette.cream,
          shape:
              RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(
              24,
            ),
          ),
          title: Text(
            'Apply Recommendation?',
            style:
                GoogleFonts.fraunces(
              color:
                  _Palette.brown,
              fontSize: 21,
              fontWeight:
                  FontWeight.w700,
            ),
          ),
          content: Text(
            'This will update your feeding schedule '
            'using the recommended feeding times and portions.',
            style:
                GoogleFonts.dmSans(
              color:
                  _Palette.brownSoft,
              fontSize: 14,
              height: 1.4,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                );
              },
              child: Text(
                'Cancel',
                style:
                    GoogleFonts.dmSans(
                  color:
                      _Palette.muted,
                  fontWeight:
                      FontWeight.w700,
                ),
              ),
            ),

            FilledButton(
              style:
                  FilledButton.styleFrom(
                backgroundColor:
                    _Palette.salmon,
                foregroundColor:
                    Colors.white,
              ),
              onPressed: () async {
                Navigator.pop(
                  dialogContext,
                );

                setState(() {
                  generating = true;
                });

                try {
                  await _applyRecommendation();

                  if (!mounted) return;

                  setState(() {
                    generating = false;
                  });

                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'AI recommendation applied successfully!',
                      ),
                      behavior:
                          SnackBarBehavior
                              .floating,
                    ),
                  );
                } catch (e) {
                  if (!mounted) return;

                  setState(() {
                    generating = false;
                  });

                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Failed to apply recommendation: $e',
                      ),
                      behavior:
                          SnackBarBehavior
                              .floating,
                    ),
                  );
                }
              },
              child: Text(
                'Apply',
                style:
                    GoogleFonts.dmSans(
                  fontWeight:
                      FontWeight.w800,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // ============================================================
  // HELPERS
  // ============================================================

  String _capitalize(String text) {
    if (text.isEmpty) {
      return text;
    }

    return text[0].toUpperCase() +
        text.substring(1).toLowerCase();
  }

  String _formatTime(String time) {
    try {
      final parts = time.split(':');

      if (parts.length < 2) {
        return time;
      }

      final hour =
          int.parse(parts[0]);

      final minute =
          int.parse(parts[1]);

      final period =
          hour >= 12 ? 'PM' : 'AM';

      final displayHour =
          hour % 12 == 0
              ? 12
              : hour % 12;

      return '$displayHour:'
          '${minute.toString().padLeft(2, '0')} '
          '$period';
    } catch (_) {
      return time;
    }
  }
}