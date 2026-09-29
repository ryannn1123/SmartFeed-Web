import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/ai_recommendation_service.dart';
import '../services/recommendation_data_service.dart';

// =========================
// SHARED PALETTE
// (matches servo_page / schedule_page / history_page / vet_page)
// =========================

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
  const AIRecommendationPage({
    super.key,
  });

  @override
  State<AIRecommendationPage> createState() =>
      _AIRecommendationPageState();
}

class _AIRecommendationPageState
    extends State<AIRecommendationPage> {

  AIRecommendation? recommendation;

  bool loading = false;

  String? errorMessage;

  @override
  void initState() {
    super.initState();
    generateRecommendation();
  }

  Future<void> generateRecommendation() async {
    setState(() {
      loading = true;
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
          'Feed your pet several times before generating an AI recommendation.',
        );
      }

      final result =
          await AIRecommendationService
              .generateRecommendation(
        feedingLogs: logs,
        schedules: schedules,
      );

      if (!mounted) return;

      setState(() {
        recommendation = result;
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
              // =========================
              // HEADER (inline, with back button since this
              // page is pushed as its own route)
              // =========================
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 10, 20, 4),
                child: Row(
                  children: [
                    
                    Container(
                      width: 34,
                      height: 34,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [_Palette.salmon, _Palette.peach],
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
                      style: GoogleFonts.fraunces(
                        color: _Palette.brownSoft,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: RefreshIndicator(
                  color: _Palette.salmon,
                  onRefresh: generateRecommendation,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
                    children: [
                      _buildHeader(),

                      const SizedBox(height: 20),

                      if (loading)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(40),
                            child: CircularProgressIndicator(
                              color: _Palette.salmon,
                            ),
                          ),
                        ),

                      if (errorMessage != null)
                        _buildError(),

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

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
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
            color: _Palette.salmon.withOpacity(0.35),
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
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.auto_awesome,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'SmartFeed AI',
                  style: GoogleFonts.fraunces(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  "Your pet's recent feeding history.",
                  style: GoogleFonts.dmSans(
                    color: Colors.white.withOpacity(0.92),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.pets,
            size: 64,
            color: Colors.white.withOpacity(0.22),
          ),
        ],
      ),
    );
  }

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
              '${_formatTime(r.morningTime)} • ${_capitalize(r.morningPortion)}',
          color: _Palette.amber,
        ),

        const SizedBox(height: 12),

        _recommendationCard(
          icon: Icons.nightlight_round,
          title: 'Evening Feeding',
          value:
              '${_formatTime(r.eveningTime)} • ${_capitalize(r.eveningPortion)}',
          color: _Palette.salmon,
        ),

        const SizedBox(height: 20),

        _textCard(
          'Why this recommendation?',
          r.reason,
          Icons.psychology,
        ),

        const SizedBox(height: 12),

        _textCard(
          'Food Efficiency',
          r.foodEfficiency,
          Icons.restaurant,
        ),

        const SizedBox(height: 12),

        _textCard(
          'Behavior Adjustment',
          r.behaviorAdjustment,
          Icons.pets,
        ),

        const SizedBox(height: 24),

        SizedBox(
          width: double.infinity,
          height: 56,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_Palette.salmon, _Palette.peach],
              ),
              boxShadow: [
                BoxShadow(
                  color: _Palette.salmon.withOpacity(0.35),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ElevatedButton.icon(
              onPressed: () {
                _showApplyDialog();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              icon: const Icon(Icons.check),
              label: Text(
                'Apply Recommendation',
                style: GoogleFonts.dmSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ),

        const SizedBox(height: 12),

        SizedBox(
          width: double.infinity,
          height: 52,
          child: OutlinedButton.icon(
            onPressed: loading
                ? null
                : generateRecommendation,
            style: OutlinedButton.styleFrom(
              foregroundColor: _Palette.salmon,
              backgroundColor: Colors.white.withOpacity(0.6),
              side: BorderSide(
                color: _Palette.salmon.withOpacity(0.5),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            icon: const Icon(Icons.refresh),
            label: Text(
              'Generate Again',
              style: GoogleFonts.dmSans(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _recommendationCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: color.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            blurRadius: 14,
            offset: const Offset(0, 6),
            color: _Palette.brownSoft.withOpacity(0.1),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [color, color.withOpacity(0.7)],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: Colors.white),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.dmSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: _Palette.brownSoft.withOpacity(0.7),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: GoogleFonts.fraunces(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: _Palette.brown,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _textCard(
    String title,
    String text,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.85),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            blurRadius: 12,
            offset: const Offset(0, 5),
            color: _Palette.brownSoft.withOpacity(0.08),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _Palette.blush.withOpacity(0.6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 19, color: _Palette.salmon),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.fraunces(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: _Palette.brown,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  text,
                  style: GoogleFonts.dmSans(
                    height: 1.45,
                    fontSize: 13.5,
                    color: _Palette.brownSoft.withOpacity(0.85),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.red.withOpacity(0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.error_outline,
            color: Colors.red.shade400,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              errorMessage!,
              style: GoogleFonts.dmSans(
                color: Colors.red.shade800,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _capitalize(String text) {
    if (text.isEmpty) return text;

    return text[0].toUpperCase() +
        text.substring(1).toLowerCase();
  }

  String _formatTime(String time) {
    final parts = time.split(':');

    if (parts.length < 2) {
      return time;
    }

    int hour = int.tryParse(parts[0]) ?? 0;
    final minute = parts[1];

    final period =
        hour >= 12 ? 'PM' : 'AM';

    hour = hour % 12;

    if (hour == 0) {
      hour = 12;
    }

    return '$hour:$minute $period';
  }

  void _showApplyDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFFFFFDF9),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Text(
            'Apply AI Recommendation?',
            style: GoogleFonts.fraunces(
              fontWeight: FontWeight.w700,
              color: _Palette.brownSoft,
            ),
          ),
          content: Text(
            'This will update your feeding schedule '
            'using the recommended feeding times and portions.',
            style: GoogleFonts.dmSans(
              color: _Palette.brownSoft.withOpacity(0.8),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text(
                'Cancel',
                style: GoogleFonts.dmSans(color: _Palette.muted),
              ),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: _Palette.salmon,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: () {
                Navigator.pop(context);

                ScaffoldMessenger.of(context)
                    .showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Recommendation ready to apply.',
                    ),
                  ),
                );
              },
              child: Text(
                'Apply',
                style: GoogleFonts.dmSans(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        );
      },
    );
  }
}