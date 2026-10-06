import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../main.dart';

// =========================
// SHARED PALETTE
// =========================

class _Palette {
  static const Color salmon = Color(0xFFFA7268);
  static const Color peach = Color(0xFFFF9E89);
  static const Color blush = Color(0xFFFFD6C4);
  static const Color cream = Color(0xFFFFEFC4);
  static const Color brown = Color(0xFF5B3A29);
  static const Color brownSoft = Color(0xFF7A3E2A);
  static const Color muted = Color(0xFFAD8A79);
  static const Color mint = Color(0xFFB8E0D2);
  static const Color sky = Color(0xFFBFD7EA);
}

// =========================
// PORTION MAPPING
// =========================

String _portionLabel(int angle) {
  if (angle == 45) return 'Small';
  if (angle == 90) return 'Medium';
  if (angle == 180) return 'Full';
  return 'Unknown';
}

IconData _portionIcon(int angle) {
  if (angle == 45) return Icons.restaurant;
  if (angle == 90) return Icons.set_meal;
  if (angle == 180) return Icons.dinner_dining;
  return Icons.pets;
}

// =========================
// PAW PRINT BACKGROUND PAINTER
// =========================

class _PawPrintPainter extends CustomPainter {
  final Color color;
  _PawPrintPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    // Scatter a few subtle paw prints
    _drawPaw(canvas, paint, Offset(size.width * 0.15, size.height * 0.12), 14, -0.3);
    _drawPaw(canvas, paint, Offset(size.width * 0.82, size.height * 0.28), 11, 0.4);
    _drawPaw(canvas, paint, Offset(size.width * 0.08, size.height * 0.62), 12, 0.2);
    _drawPaw(canvas, paint, Offset(size.width * 0.88, size.height * 0.78), 15, -0.5);
  }

  void _drawPaw(Canvas canvas, Paint paint, Offset c, double r, double rot) {
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(rot);
    // main pad
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: r * 1.6, height: r * 1.3),
      paint,
    );
    // toes
    final toes = [
      Offset(-r * 0.75, -r * 1.0),
      Offset(-r * 0.25, -r * 1.3),
      Offset(r * 0.25, -r * 1.3),
      Offset(r * 0.75, -r * 1.0),
    ];
    for (final t in toes) {
      canvas.drawCircle(t, r * 0.35, paint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class SchedulePage extends StatefulWidget {
  const SchedulePage({super.key});

  @override
  State<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends State<SchedulePage> {
  List<Map<String, dynamic>> _schedules = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchSchedules();
  }

  Future<void> _fetchSchedules() async {
    setState(() => _loading = true);
    try {
      final res = await supabase
          .from('schedule')
          .select()
          .order('feed_date', ascending: true)
          .order('feed_time', ascending: true);
      setState(() {
        _schedules = List<Map<String, dynamic>>.from(res);
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<void> _addSchedule() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => const _AddScheduleDialog(),
    );
    if (result == null) return;
    try {
      await supabase.from('schedule').insert({
        'feed_date': result['feed_date'],
        'feed_time': result['feed_time'],
        'angle': result['angle'],
        'enabled': true,
      });
      _fetchSchedules();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _editSchedule(Map<String, dynamic> schedule) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => _AddScheduleDialog(existing: schedule),
    );
    if (result == null) return;
    try {
      await supabase
          .from('schedule')
          .update({
            'feed_date': result['feed_date'],
            'feed_time': result['feed_time'],
            'angle': result['angle'],
          })
          .eq('id', schedule['id'] as int);
      _fetchSchedules();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _toggleSchedule(int id, bool enabled) async {
    await supabase
        .from('schedule')
        .update({'enabled': enabled})
        .eq('id', id);
    _fetchSchedules();
  }

  Future<void> _deleteSchedule(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFFFFFDF9),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.redAccent.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.delete_outline_rounded,
                color: Colors.redAccent,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Delete feeding time?',
                style: GoogleFonts.fraunces(
                  fontWeight: FontWeight.w800,
                  color: _Palette.brownSoft,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'This feeding schedule will be removed from your pet\'s routine. 🐾',
          style: GoogleFonts.dmSans(
            color: _Palette.brownSoft.withOpacity(0.8),
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.dmSans(color: _Palette.muted),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Delete',
              style: GoogleFonts.dmSans(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await supabase.from('schedule').delete().eq('id', id);
      _fetchSchedules();
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
        child: Stack(
          children: [
            // Subtle paw prints background
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _PawPrintPainter(
                    color: Colors.white.withOpacity(0.18),
                  ),
                ),
              ),
            ),
            // Soft blurred blobs for depth
            Positioned(
              top: -40,
              right: -30,
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      _Palette.salmon.withOpacity(0.35),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 40,
              left: -50,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      _Palette.cream.withOpacity(0.6),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  // =========================
                  // HEADER
                  // =========================
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [_Palette.salmon, _Palette.peach],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: _Palette.salmon.withOpacity(0.4),
                                blurRadius: 14,
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
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Feeding Schedule',
                                style: GoogleFonts.fraunces(
                                  fontSize: 23,
                                  fontWeight: FontWeight.w800,
                                  color: _Palette.brownSoft,
                                  letterSpacing: -0.4,
                                ),
                              ),
                              Text(
                                'Keep your furry friend happy 🐶',
                                style: GoogleFonts.dmSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: _Palette.brownSoft.withOpacity(0.65),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // =========================
                  // STATS STRIP
                  // =========================
                  if (!_loading && _schedules.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                      child: Row(
                        children: [
                          _StatChip(
                            icon: Icons.event_available_rounded,
                            label: '${_schedules.where((s) => s['enabled'] == true).length} active',
                            color: _Palette.mint,
                          ),
                          const SizedBox(width: 8),
                          _StatChip(
                            icon: Icons.calendar_month_rounded,
                            label: '${_schedules.length} total',
                            color: _Palette.sky,
                          ),
                          const SizedBox(width: 8),
                          _StatChip(
                            icon: Icons.local_fire_department_rounded,
                            label: 'Daily',
                            color: _Palette.blush,
                          ),
                        ],
                      ),
                    ),

                  // =========================
                  // ADD BUTTON
                  // =========================
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
                    child: SizedBox(
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
                              color: _Palette.salmon.withOpacity(0.4),
                              blurRadius: 16,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: ElevatedButton.icon(
                          onPressed: _addSchedule,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          icon: const Icon(Icons.add_circle_outline_rounded, size: 22),
                          label: Text(
                            'Add feeding time',
                            style: GoogleFonts.dmSans(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // =========================
                  // LIST
                  // =========================
                  Expanded(
                    child: _loading
                        ? const Center(
                            child: CircularProgressIndicator(
                              color: _Palette.salmon,
                            ),
                          )
                        : _schedules.isEmpty
                            ? const _EmptyScheduleState()
                            : RefreshIndicator(
                                color: _Palette.salmon,
                                onRefresh: _fetchSchedules,
                                child: ListView.separated(
                                  padding: const EdgeInsets.fromLTRB(
                                    18,
                                    14,
                                    18,
                                    130,
                                  ),
                                  itemCount: _schedules.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(height: 14),
                                  itemBuilder: (context, index) {
                                    final s = _schedules[index];
                                    final timeStr = s['feed_time'].toString();
                                    final dateStr = s['feed_date']?.toString();
                                    final enabled = s['enabled'] as bool;
                                    final angle = s['angle'] as int? ?? 90;

                                    return _ScheduleCard(
                                      rawTimeString: timeStr,
                                      rawDateString: dateStr,
                                      angle: angle,
                                      enabled: enabled,
                                      onEdit: () => _editSchedule(s),
                                      onDelete: () =>
                                          _deleteSchedule(s['id'] as int),
                                      onToggle: (val) =>
                                          _toggleSchedule(s['id'] as int, val),
                                    );
                                  },
                                ),
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

// =========================
// STAT CHIP
// =========================

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _StatChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Flexible(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.75),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withOpacity(0.6), width: 1.2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: _Palette.brownSoft),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.dmSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: _Palette.brownSoft,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ======================================================
// SCHEDULE CARD
// ======================================================

class _ScheduleCard extends StatelessWidget {
  final String rawTimeString;
  final String? rawDateString;
  final int angle;
  final bool enabled;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<bool> onToggle;

  const _ScheduleCard({
    required this.rawTimeString,
    required this.rawDateString,
    required this.angle,
    required this.enabled,
    required this.onEdit,
    required this.onDelete,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    String formattedTime = rawTimeString;
    String formattedDate = 'Scheduled feeding';
    String dayLabel = '';

    try {
      final parts = rawTimeString.split(':');
      if (parts.length >= 2) {
        final hour = int.parse(parts[0]);
        final minute = int.parse(parts[1]);
        final dt = DateTime(2000, 1, 1, hour, minute);
        formattedTime = DateFormat.jm().format(dt);
        // Compute greeting label
        if (hour < 12) {
          dayLabel = 'Morning';
        } else if (hour < 17) {
          dayLabel = 'Afternoon';
        } else {
          dayLabel = 'Evening';
        }
      }
    } catch (_) {
      if (rawTimeString.length >= 5) {
        formattedTime = rawTimeString.substring(0, 5);
      }
    }

    if (rawDateString != null &&
        rawDateString!.isNotEmpty &&
        rawDateString != 'null') {
      try {
        final date = DateTime.parse(rawDateString!);
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final target = DateTime(date.year, date.month, date.day);
        final diff = target.difference(today).inDays;

        if (diff == 0) {
          formattedDate = 'Today';
        } else if (diff == 1) {
          formattedDate = 'Tomorrow';
        } else {
          formattedDate =
              'Scheduled for ${DateFormat('MMM d, yyyy').format(date)}';
        }
      } catch (_) {
        formattedDate = 'Scheduled for $rawDateString';
      }
    }

    final portionLabel = _portionLabel(angle);
    final portionIcon = _portionIcon(angle);

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 220),
      opacity: enabled ? 1 : 0.55,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.92),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: enabled
                ? _Palette.salmon.withOpacity(0.28)
                : Colors.grey.withOpacity(0.18),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: _Palette.brownSoft.withOpacity(0.12),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Stack(
            children: [
              // Left accent bar
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: Container(
                  width: 5,
                  decoration: BoxDecoration(
                    gradient: enabled
                        ? const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [_Palette.salmon, _Palette.peach],
                          )
                        : LinearGradient(
                            colors: [Colors.grey.shade300, Colors.grey.shade200],
                          ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 18, 18),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 62,
                          height: 62,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: enabled
                                  ? const [_Palette.salmon, _Palette.peach]
                                  : [Colors.grey.shade300, Colors.grey.shade200],
                            ),
                            borderRadius: BorderRadius.circular(22),
                            boxShadow: enabled
                                ? [
                                    BoxShadow(
                                      color: _Palette.salmon.withOpacity(0.3),
                                      blurRadius: 12,
                                      offset: const Offset(0, 6),
                                    ),
                                  ]
                                : null,
                          ),
                          child: const Icon(
                            Icons.pets,
                            color: Colors.white,
                            size: 30,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              FittedBox(
  fit: BoxFit.scaleDown,
  alignment: Alignment.centerLeft,
  child: Row(
    children: [
      Text(
        formattedTime,
        style: GoogleFonts.fraunces(
          fontSize: 26,
          fontWeight: FontWeight.w800,
          color: _Palette.brown,
          letterSpacing: -0.5,
        ),
      ),
      if (dayLabel.isNotEmpty && enabled) ...[
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: _Palette.cream.withOpacity(0.9),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            dayLabel,
            style: GoogleFonts.dmSans(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: _Palette.brownSoft,
            ),
          ),
        ),
      ],
    ],
  ),
),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    Icons.event_rounded,
                                    size: 13,
                                    color: _Palette.brownSoft.withOpacity(0.6),
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      formattedDate,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.dmSans(
                                        color:
                                            _Palette.brownSoft.withOpacity(0.7),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Transform.scale(
                          scale: 0.9,
                          child: Switch(
                            value: enabled,
                            activeColor: _Palette.salmon,
                            onChanged: onToggle,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // Portion chip + progress
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                _Palette.blush.withOpacity(0.6),
                                _Palette.cream.withOpacity(0.6),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: _Palette.salmon.withOpacity(0.2),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                portionIcon,
                                size: 16,
                                color: _Palette.salmon,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '$portionLabel Portion',
                                style: GoogleFonts.dmSans(
                                  color: _Palette.brownSoft,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(99),
                            child: TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0, end: angle / 180),
                              duration: const Duration(milliseconds: 600),
                              curve: Curves.easeOutCubic,
                              builder: (context, value, _) {
                                return LinearProgressIndicator(
                                  value: value,
                                  minHeight: 9,
                                  backgroundColor:
                                      _Palette.blush.withOpacity(0.5),
                                  color: _Palette.salmon,
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: onEdit,
                            icon: const Icon(Icons.edit_rounded, size: 17),
                            label: Text(
                              'Edit',
                              style: GoogleFonts.dmSans(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _Palette.salmon,
                              side: BorderSide(
                                color: _Palette.salmon.withOpacity(0.45),
                                width: 1.4,
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: onDelete,
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                              size: 17,
                            ),
                            label: Text(
                              'Delete',
                              style: GoogleFonts.dmSans(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFFFFEEF0),
                              foregroundColor: Colors.redAccent,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ======================================================
// EMPTY STATE
// ======================================================

class _EmptyScheduleState extends StatelessWidget {
  const _EmptyScheduleState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.88),
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: _Palette.brownSoft.withOpacity(0.12),
                blurRadius: 26,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [_Palette.blush, _Palette.cream],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _Palette.salmon.withOpacity(0.25),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.pets,
                  size: 46,
                  color: _Palette.salmon,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'No meals scheduled',
                style: GoogleFonts.fraunces(
                  color: _Palette.brownSoft,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Tap "Add feeding time" to create your pet\'s next meal 🐾',
                textAlign: TextAlign.center,
                style: GoogleFonts.dmSans(
                  color: _Palette.brownSoft.withOpacity(0.7),
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ======================================================
// ADD / EDIT SCHEDULE DIALOG
// ======================================================

class _AddScheduleDialog extends StatefulWidget {
  final Map<String, dynamic>? existing;

  const _AddScheduleDialog({this.existing});

  @override
  State<_AddScheduleDialog> createState() => _AddScheduleDialogState();
}

class _AddScheduleDialogState extends State<_AddScheduleDialog> {
  DateTime _selectedDate = DateTime.now();
  TimeOfDay? _selectedTime;
  int _angle = 90;

  final List<Map<String, dynamic>> _presets = [
    {'label': 'Small', 'angle': 45, 'icon': Icons.restaurant},
    {'label': 'Medium', 'angle': 90, 'icon': Icons.set_meal},
    {'label': 'Full', 'angle': 180, 'icon': Icons.dinner_dining},
  ];

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      final rawDate = widget.existing!['feed_date']?.toString();
      if (rawDate != null && rawDate.isNotEmpty && rawDate != 'null') {
        try {
          _selectedDate = DateTime.parse(rawDate);
        } catch (_) {
          _selectedDate = DateTime.now();
        }
      }

      final rawTime = widget.existing!['feed_time'].toString();
      try {
        final timeStr = rawTime.substring(0, 5);
        final parts = timeStr.split(':');
        _selectedTime = TimeOfDay(
          hour: int.parse(parts[0]),
          minute: int.parse(parts[1]),
        );
      } catch (_) {
        _selectedTime = null;
      }

      _angle = widget.existing!['angle'] as int? ?? 90;
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: ThemeData(
            colorScheme: const ColorScheme.light(
              primary: _Palette.salmon,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: _Palette.brown,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData(
            colorScheme: const ColorScheme.light(
              primary: _Palette.salmon,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: _Palette.brown,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) setState(() => _selectedTime = picked);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;

    return AlertDialog(
      backgroundColor: const Color(0xFFFFFDF9),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      titlePadding: const EdgeInsets.fromLTRB(24, 22, 24, 6),
      title: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [_Palette.salmon, _Palette.peach],
              ),
            ),
            child: const Icon(Icons.pets, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isEdit ? 'Edit feeding time' : 'Add feeding time',
              style: GoogleFonts.fraunces(
                color: _Palette.brownSoft,
                fontWeight: FontWeight.w800,
                fontSize: 20,
              ),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionLabel('Date'),
            const SizedBox(height: 8),
            _pickerTile(
              icon: Icons.calendar_today_rounded,
              text: DateFormat('EEE, MMM d, yyyy').format(_selectedDate),
              onTap: _pickDate,
            ),
            const SizedBox(height: 18),
            _sectionLabel('Time'),
            const SizedBox(height: 8),
            _pickerTile(
              icon: Icons.access_time_rounded,
              text: _selectedTime == null
                  ? 'Tap to pick time'
                  : _selectedTime!.format(context),
              onTap: _pickTime,
              muted: _selectedTime == null,
            ),
            const SizedBox(height: 22),
            _sectionLabel('Portion Size 🥣'),
            const SizedBox(height: 10),
            Row(
              children: _presets.map((p) {
                final presetAngle = p['angle'] as int;
                final isSelected = _angle == presetAngle;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: InkWell(
                      onTap: () => setState(() => _angle = presetAngle),
                      borderRadius: BorderRadius.circular(16),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          gradient: isSelected
                              ? const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [_Palette.salmon, _Palette.peach],
                                )
                              : null,
                          color: isSelected
                              ? null
                              : _Palette.blush.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected
                                ? Colors.transparent
                                : _Palette.salmon.withOpacity(0.22),
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: _Palette.salmon.withOpacity(0.35),
                                    blurRadius: 10,
                                    offset: const Offset(0, 5),
                                  ),
                                ]
                              : null,
                        ),
                        child: Column(
                          children: [
                            Icon(
                              p['icon'] as IconData,
                              size: 20,
                              color: isSelected ? Colors.white : _Palette.salmon,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${p['label']}',
                              style: GoogleFonts.dmSans(
                                fontSize: 13,
                                color:
                                    isSelected ? Colors.white : _Palette.brown,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Cancel',
            style: GoogleFonts.dmSans(
              color: _Palette.muted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        FilledButton(
          onPressed: _selectedTime == null
              ? null
              : () {
                  final timeStr =
                      '${_selectedTime!.hour.toString().padLeft(2, '0')}:'
                      '${_selectedTime!.minute.toString().padLeft(2, '0')}:00';
                  final dateStr =
                      DateFormat('yyyy-MM-dd').format(_selectedDate);
                  Navigator.pop(context, {
                    'feed_date': dateStr,
                    'feed_time': timeStr,
                    'angle': _angle,
                  });
                },
          style: FilledButton.styleFrom(
            backgroundColor: _Palette.salmon,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: Text(
            isEdit ? 'Save' : 'Add',
            style: GoogleFonts.dmSans(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.dmSans(
        fontWeight: FontWeight.w800,
        color: _Palette.brownSoft,
        fontSize: 13,
      ),
    );
  }

  Widget _pickerTile({
    required IconData icon,
    required String text,
    required VoidCallback onTap,
    bool muted = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: _Palette.blush.withOpacity(0.45),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _Palette.salmon.withOpacity(0.22)),
        ),
        child: Row(
          children: [
            Icon(icon, color: _Palette.salmon),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: GoogleFonts.dmSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: muted ? _Palette.muted : _Palette.brown,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}