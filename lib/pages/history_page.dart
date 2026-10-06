import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

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
  static const Color honey = Color(0xFFF4B860);
}

// =========================
// PAW PRINT PAINTER
// =========================

class _PawPrintPainter extends CustomPainter {
  final Color color;
  _PawPrintPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    _drawPaw(canvas, paint, Offset(size.width * 0.18, size.height * 0.10), 13, -0.35);
    _drawPaw(canvas, paint, Offset(size.width * 0.86, size.height * 0.22), 10, 0.4);
    _drawPaw(canvas, paint, Offset(size.width * 0.08, size.height * 0.48), 11, 0.15);
    _drawPaw(canvas, paint, Offset(size.width * 0.92, size.height * 0.68), 13, -0.5);
    _drawPaw(canvas, paint, Offset(size.width * 0.22, size.height * 0.86), 12, 0.3);
  }

  void _drawPaw(Canvas canvas, Paint paint, Offset c, double r, double rot) {
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(rot);
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: r * 1.6, height: r * 1.3),
      paint,
    );
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

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  List<Map<String, dynamic>> _logs = [];
  bool _loading = true;
  String _filter = 'All';

  final List<String> _filters = ['All', 'Manual', 'Scheduled'];

  @override
  void initState() {
    super.initState();
    _fetchLogs();
  }

  Future<void> _fetchLogs() async {
    setState(() => _loading = true);
    try {
      var query = supabase
          .from('feeding_logs')
          .select()
          .order('fed_at', ascending: false);

      final res = await query;
      setState(() {
        _logs = List<Map<String, dynamic>>.from(res);
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredLogs {
    if (_filter == 'All') return _logs;
    return _logs.where((log) {
      final type = (log['trigger_type'] as String? ?? 'manual').toLowerCase();
      return type == _filter.toLowerCase();
    }).toList();
  }

  String _portionLabel(int? angle) {
    if (angle == null) return 'Unknown';
    if (angle <= 45) return 'Small';
    if (angle <= 90) return 'Medium';
    return 'Full';
  }

  double _portionProgress(String portion) {
    switch (portion) {
      case 'Small':
        return 0.25;
      case 'Medium':
        return 0.5;
      case 'Full':
        return 1.0;
      default:
        return 0.0;
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '—';
    final dt = DateTime.tryParse(dateStr)?.toLocal();
    if (dt == null) return '—';
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  String _formatTime(String? dateStr) {
    if (dateStr == null) return '—';
    final dt = DateTime.tryParse(dateStr)?.toLocal();
    if (dt == null) return '—';
    final hour = dt.hour > 12 ? dt.hour - 12 : dt.hour == 0 ? 12 : dt.hour;
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    final min = dt.minute.toString().padLeft(2, '0');
    return '$hour:$min $ampm';
  }

  Map<String, List<Map<String, dynamic>>> get _groupedLogs {
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final log in _filteredLogs) {
      final date = _formatDate(log['fed_at'] as String?);
      grouped.putIfAbsent(date, () => []).add(log);
    }
    return grouped;
  }

  int get _totalFeedings => _logs.length;

  int get _todayFeedings {
    final today = DateTime.now();
    return _logs.where((log) {
      final dt = DateTime.tryParse(log['fed_at'] as String? ?? '')?.toLocal();
      if (dt == null) return false;
      return dt.day == today.day &&
          dt.month == today.month &&
          dt.year == today.year;
    }).length;
  }

  String get _mostCommonPortion {
    if (_logs.isEmpty) return '—';
    final counts = <String, int>{};
    for (final log in _logs) {
      final label = log['portion_label'] as String? ??
          _portionLabel(log['angle'] as int?);
      counts[label] = (counts[label] ?? 0) + 1;
    }
    return counts.entries.reduce((a, b) => a.value > b.value ? a : b).key;
  }

  Future<void> _deleteLog(int id) async {
    try {
      await supabase.from('feeding_logs').delete().eq('id', id);
      setState(() {
        _logs.removeWhere((log) => log['id'] == id);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded,
                    color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Text(
                  'Log deleted',
                  style: GoogleFonts.dmSans(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            backgroundColor: _Palette.peach,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _deleteAllLogs() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFFFFFDF9),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: _Palette.salmon.withOpacity(0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.delete_sweep_rounded,
                  color: _Palette.salmon, size: 22),
            ),
            const SizedBox(width: 12),
            Text(
              'Delete All Logs?',
              style: GoogleFonts.fraunces(
                fontWeight: FontWeight.w800,
                color: _Palette.brownSoft,
                fontSize: 19,
              ),
            ),
          ],
        ),
        content: Text(
          'This will permanently delete all feeding history. This cannot be undone. 🐾',
          style: GoogleFonts.dmSans(
            color: _Palette.brownSoft.withOpacity(0.8),
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: GoogleFonts.dmSans(color: _Palette.muted)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: _Palette.salmon,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: Text('Delete All',
                style: GoogleFonts.dmSans(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await supabase.from('feeding_logs').delete().neq('id', 0);
      setState(() => _logs = []);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'All logs deleted',
              style: GoogleFonts.dmSans(fontWeight: FontWeight.w600),
            ),
            backgroundColor: _Palette.peach,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final grouped = _groupedLogs;

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
            // Soft blurred radial blobs
            Positioned(
              top: -60,
              right: -40,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      _Palette.salmon.withOpacity(0.3),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: -50,
              left: -60,
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      _Palette.cream.withOpacity(0.7),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            // Paw print scatter
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _PawPrintPainter(
                    color: Colors.white.withOpacity(0.15),
                  ),
                ),
              ),
            ),
            // Floating big paw
            Positioned(
              top: 130,
              right: -30,
              child: Icon(
                Icons.pets,
                size: 160,
                color: Colors.white.withOpacity(0.06),
              ),
            ),

            SafeArea(
              child: Column(
                children: [
                  // =========================
                  // HEADER
                  // =========================
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.72),
                        borderRadius: BorderRadius.circular(26),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.75),
                          width: 1.4,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: _Palette.brownSoft.withOpacity(0.1),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
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
                              Icons.menu_book_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Feeding History',
                                  style: GoogleFonts.fraunces(
                                    color: _Palette.brownSoft,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    height: 1.1,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                const SizedBox(height: 1),
                                Text(
                                  'Your pet\'s meal timeline 🐾',
                                  style: GoogleFonts.dmSans(
                                    color: _Palette.brownSoft.withOpacity(0.6),
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _HeaderIconButton(
                            icon: Icons.refresh_rounded,
                            onTap: _fetchLogs,
                          ),
                          const SizedBox(width: 8),
                          _HeaderIconButton(
                            icon: Icons.delete_sweep_rounded,
                            onTap: _deleteAllLogs,
                            danger: true,
                          ),
                        ],
                      ),
                    ),
                  ),

                  Expanded(
                    child: _loading
                        ? const Center(
                            child: CircularProgressIndicator(
                                color: _Palette.salmon),
                          )
                        : RefreshIndicator(
                            color: _Palette.salmon,
                            onRefresh: _fetchLogs,
                            child: CustomScrollView(
                              physics: const AlwaysScrollableScrollPhysics(
                                parent: BouncingScrollPhysics(),
                              ),
                              slivers: [
                                // =========================
                                // STATS + FILTERS
                                // =========================
                                SliverToBoxAdapter(
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      children: [
                                        IntrinsicHeight(
                                          child: Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.stretch,
                                            children: [
                                              Expanded(
                                                child: _StatCard(
                                                  label: 'Total Feedings',
                                                  value: '$_totalFeedings',
                                                  icon: Icons.history_rounded,
                                                  color: _Palette.salmon,
                                                  emoji: '🍽️',
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: _StatCard(
                                                  label: 'Today',
                                                  value: '$_todayFeedings',
                                                  icon: Icons.today_rounded,
                                                  color: _Palette.peach,
                                                  emoji: '☀️',
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: _StatCard(
                                                  label: 'Top Portion',
                                                  value: _mostCommonPortion,
                                                  icon: Icons.pie_chart_rounded,
                                                  color: _Palette.honey,
                                                  emoji: '🥣',
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 18),

                                        // Filter chips row
                                        Row(
                                          children: [
                                            for (int i = 0;
                                                i < _filters.length;
                                                i++) ...[
                                              _FilterChip(
                                                label: _filters[i],
                                                selected:
                                                    _filter == _filters[i],
                                                onTap: () => setState(() =>
                                                    _filter = _filters[i]),
                                              ),
                                              if (i != _filters.length - 1)
                                                const SizedBox(width: 8),
                                            ],
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                                // =========================
                                // EMPTY STATE
                                // =========================
                                if (_filteredLogs.isEmpty)
                                  SliverFillRemaining(
                                    hasScrollBody: false,
                                    child: Center(
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 32),
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            _EmptyPawBadge(),
                                            const SizedBox(height: 22),
                                            Text(
                                              'No feeding logs yet',
                                              style: GoogleFonts.fraunces(
                                                fontSize: 20,
                                                fontWeight: FontWeight.w800,
                                                color: _Palette.brownSoft,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              'Logs appear here after your pet\'s feeder dispenses a meal. 🐾',
                                              textAlign: TextAlign.center,
                                              style: GoogleFonts.dmSans(
                                                fontSize: 13,
                                                height: 1.5,
                                                color: _Palette.brownSoft
                                                    .withOpacity(0.65),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),

                                // =========================
                                // GROUPED LOGS
                                // =========================
                                for (final entry in grouped.entries) ...[
                                  SliverToBoxAdapter(
                                    child: Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                          16, 12, 16, 10),
                                      child: Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 12, vertical: 7),
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                colors: [
                                                  Colors.white,
                                                  Colors.white
                                                      .withOpacity(0.7),
                                                ],
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(999),
                                              border: Border.all(
                                                color: _Palette.peach
                                                    .withOpacity(0.5),
                                                width: 1.2,
                                              ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: _Palette.brownSoft
                                                      .withOpacity(0.07),
                                                  blurRadius: 10,
                                                  offset: const Offset(0, 4),
                                                ),
                                              ],
                                            ),
                                            child: Row(
                                              children: [
                                                Container(
                                                  padding:
                                                      const EdgeInsets.all(3),
                                                  decoration: BoxDecoration(
                                                    color: _Palette.salmon
                                                        .withOpacity(0.15),
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: const Icon(
                                                    Icons.pets,
                                                    size: 11,
                                                    color: _Palette.salmon,
                                                  ),
                                                ),
                                                const SizedBox(width: 7),
                                                Text(
                                                  entry.key,
                                                  style: GoogleFonts.dmSans(
                                                    fontSize: 12.5,
                                                    fontWeight: FontWeight.w800,
                                                    color: _Palette.brownSoft,
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 7,
                                                      vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: _Palette.salmon
                                                        .withOpacity(0.12),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            999),
                                                  ),
                                                  child: Text(
                                                    '${entry.value.length}',
                                                    style:
                                                        GoogleFonts.dmSans(
                                                      fontSize: 10,
                                                      fontWeight:
                                                          FontWeight.w800,
                                                      color: _Palette.salmon,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Container(
                                              height: 1.5,
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                  colors: [
                                                    _Palette.peach
                                                        .withOpacity(0.7),
                                                    _Palette.peach
                                                        .withOpacity(0.0),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),

                                  SliverList(
                                    delegate: SliverChildBuilderDelegate(
                                      (context, index) {
                                        final log = entry.value[index];
                                        final angle = log['angle'] as int?;

                                        String portion =
                                            log['portion_label'] as String? ??
                                                _portionLabel(angle);

                                        if (portion
                                            .toLowerCase()
                                            .contains('small')) {
                                          portion = 'Small';
                                        } else if (portion
                                            .toLowerCase()
                                            .contains('medium')) {
                                          portion = 'Medium';
                                        } else if (portion
                                                .toLowerCase()
                                                .contains('full') ||
                                            portion
                                                .toLowerCase()
                                                .contains('large')) {
                                          portion = 'Full';
                                        } else {
                                          portion = _portionLabel(angle);
                                        }

                                        final triggerType =
                                            log['trigger_type'] as String? ??
                                                'manual';
                                        final isScheduled =
                                            triggerType.toLowerCase() ==
                                                'scheduled';

                                        return Dismissible(
                                          key: Key('log_${log['id']}'),
                                          direction:
                                              DismissDirection.endToStart,
                                          background: _SwipeBackground(),
                                          confirmDismiss: (_) async {
                                            return await showDialog<bool>(
                                              context: context,
                                              builder: (ctx) => AlertDialog(
                                                backgroundColor:
                                                    const Color(0xFFFFFDF9),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(28),
                                                ),
                                                title: Text(
                                                  'Delete this log?',
                                                  style:
                                                      GoogleFonts.fraunces(
                                                    fontWeight: FontWeight.w800,
                                                    color: _Palette.brownSoft,
                                                  ),
                                                ),
                                                content: Text(
                                                  'This feeding record will be removed. 🐾',
                                                  style: GoogleFonts.dmSans(
                                                    color: _Palette.brownSoft
                                                        .withOpacity(0.8),
                                                    height: 1.4,
                                                  ),
                                                ),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () =>
                                                        Navigator.pop(
                                                            ctx, false),
                                                    child: Text('Cancel',
                                                        style:
                                                            GoogleFonts.dmSans(
                                                                color: _Palette
                                                                    .muted)),
                                                  ),
                                                  FilledButton(
                                                    onPressed: () =>
                                                        Navigator.pop(
                                                            ctx, true),
                                                    style: FilledButton
                                                        .styleFrom(
                                                      backgroundColor:
                                                          _Palette.salmon,
                                                      shape:
                                                          RoundedRectangleBorder(
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(14),
                                                      ),
                                                    ),
                                                    child: Text('Delete',
                                                        style:
                                                            GoogleFonts.dmSans(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w700)),
                                                  ),
                                                ],
                                              ),
                                            );
                                          },
                                          onDismissed: (_) =>
                                              _deleteLog(log['id'] as int),
                                          child: _LogTile(
                                            time: _formatTime(
                                                log['fed_at'] as String?),
                                            portion: portion,
                                            portionProgress:
                                                _portionProgress(portion),
                                            isScheduled: isScheduled,
                                            notes: log['notes'] as String?,
                                          ),
                                        );
                                      },
                                      childCount: entry.value.length,
                                    ),
                                  ),
                                ],

                                const SliverToBoxAdapter(
                                  child: SizedBox(height: 100),
                                ),
                              ],
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
// HEADER ICON BUTTON
// =========================

class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool danger;

  const _HeaderIconButton({
    required this.icon,
    required this.onTap,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final baseColor = danger ? Colors.redAccent : _Palette.brownSoft;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: danger
                ? Colors.redAccent.withOpacity(0.1)
                : Colors.white.withOpacity(0.85),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: danger
                  ? Colors.redAccent.withOpacity(0.3)
                  : _Palette.peach.withOpacity(0.5),
              width: 1.2,
            ),
          ),
          child: Icon(icon, size: 19, color: baseColor),
        ),
      ),
    );
  }
}

// =========================
// STAT CARD
// =========================

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String emoji;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.emoji,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.98),
            Colors.white.withOpacity(0.82),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: Colors.white.withOpacity(0.8),
          width: 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.14),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: _Palette.brownSoft.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [color, color.withOpacity(0.65)],
                  ),
                  borderRadius: BorderRadius.circular(11),
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Icon(icon, size: 17, color: Colors.white),
              ),
              const Spacer(),
              Text(emoji, style: const TextStyle(fontSize: 14)),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.fraunces(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: _Palette.brown,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.dmSans(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: _Palette.brownSoft.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }
}

// =========================
// FILTER CHIP
// =========================

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  IconData _iconFor(String label) {
    switch (label) {
      case 'Manual':
        return Icons.touch_app_rounded;
      case 'Scheduled':
        return Icons.schedule_rounded;
      default:
        return Icons.auto_awesome_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutBack,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          gradient: selected
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [_Palette.salmon, _Palette.peach],
                )
              : null,
          color: selected ? null : Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? Colors.transparent
                : _Palette.salmon.withOpacity(0.35),
            width: 1.2,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: _Palette.salmon.withOpacity(0.4),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ]
              : [
                  BoxShadow(
                    color: _Palette.brownSoft.withOpacity(0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _iconFor(label),
              size: 14,
              color: selected ? Colors.white : _Palette.salmon,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.dmSans(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: selected ? Colors.white : _Palette.salmon,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =========================
// LOG TILE
// =========================

class _LogTile extends StatelessWidget {
  final String time;
  final String portion;
  final double portionProgress;
  final bool isScheduled;
  final String? notes;

  const _LogTile({
    required this.time,
    required this.portion,
    required this.portionProgress,
    required this.isScheduled,
    this.notes,
  });

  @override
  Widget build(BuildContext context) {
    final accent = isScheduled ? _Palette.peach : _Palette.salmon;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.96),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isScheduled
              ? _Palette.peach.withOpacity(0.45)
              : _Palette.salmon.withOpacity(0.2),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: _Palette.brownSoft.withOpacity(0.1),
            blurRadius: 16,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          children: [
            // Left accent bar
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: Container(
                width: 4,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [accent, accent.withOpacity(0.4)],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
              child: Row(
                children: [
                  // Icon badge
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      gradient: isScheduled
                          ? LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                _Palette.peach.withOpacity(0.9),
                                _Palette.blush,
                              ],
                            )
                          : const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [_Palette.salmon, _Palette.peach],
                            ),
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                          color: accent.withOpacity(0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(
                      isScheduled
                          ? Icons.schedule_rounded
                          : Icons.touch_app_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              time,
                              style: GoogleFonts.fraunces(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: _Palette.brown,
                                letterSpacing: -0.2,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                gradient: isScheduled
                                    ? LinearGradient(
                                        colors: [
                                          _Palette.peach.withOpacity(0.35),
                                          _Palette.blush.withOpacity(0.35),
                                        ],
                                      )
                                    : LinearGradient(
                                        colors: [
                                          _Palette.salmon.withOpacity(0.18),
                                          _Palette.salmon.withOpacity(0.08),
                                        ],
                                      ),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                isScheduled ? 'Scheduled' : 'Manual',
                                style: GoogleFonts.dmSans(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: _Palette.brownSoft,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            Icon(
                              Icons.pets,
                              size: 13,
                              color: _Palette.brownSoft.withOpacity(0.5),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '$portion portion',
                              style: GoogleFonts.dmSans(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: _Palette.brownSoft.withOpacity(0.7),
                              ),
                            ),
                          ],
                        ),
                        if (notes != null && notes!.isNotEmpty) ...[
                          const SizedBox(height: 5),
                          Text(
                            notes!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.dmSans(
                              fontSize: 11.5,
                              color: _Palette.brownSoft.withOpacity(0.5),
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Portion progress
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        portion,
                        style: GoogleFonts.dmSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: _Palette.salmon,
                        ),
                      ),
                      const SizedBox(height: 6),
                      SizedBox(
                        width: 52,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(5),
                              child: TweenAnimationBuilder<double>(
                                tween: Tween(begin: 0, end: portionProgress),
                                duration:
                                    const Duration(milliseconds: 600),
                                curve: Curves.easeOutCubic,
                                builder: (context, value, _) {
                                  return LinearProgressIndicator(
                                    value: value,
                                    backgroundColor:
                                        _Palette.blush.withOpacity(0.55),
                                    color: _Palette.salmon,
                                    minHeight: 7,
                                  );
                                },
                              ),
                            ),
                            if (portionProgress > 0)
                              Positioned(
                                left: (52 * portionProgress) - 8,
                                top: -6,
                                child: Icon(
                                  Icons.pets,
                                  size: 11,
                                  color: _Palette.salmon.withOpacity(0.9),
                                ),
                              ),
                          ],
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
    );
  }
}

// =========================
// SWIPE BACKGROUND
// =========================

class _SwipeBackground extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Colors.red.withOpacity(0.05),
            Colors.red.withOpacity(0.22),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.red.withOpacity(0.25)),
      ),
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 22),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.delete_outline_rounded,
                color: Colors.red, size: 20),
          ),
          const SizedBox(height: 4),
          Text(
            'Delete',
            style: GoogleFonts.dmSans(
              color: Colors.red,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

// =========================
// EMPTY PAW BADGE
// =========================

class _EmptyPawBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 130,
      height: 130,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 130,
            height: 130,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  _Palette.blush.withOpacity(0.7),
                  _Palette.blush.withOpacity(0.0),
                ],
              ),
            ),
          ),
          // little orbiting paw
          Positioned(
            top: 8,
            right: 12,
            child: Icon(
              Icons.pets,
              size: 16,
              color: _Palette.salmon.withOpacity(0.55),
            ),
          ),
          Positioned(
            bottom: 12,
            left: 8,
            child: Icon(
              Icons.pets,
              size: 13,
              color: _Palette.peach.withOpacity(0.7),
            ),
          ),
          Container(
            width: 90,
            height: 90,
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
                  blurRadius: 22,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: const Icon(
              Icons.pets,
              size: 46,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}