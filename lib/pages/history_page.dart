import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../main.dart';

// =========================
// SHARED PALETTE
// (matches servo_page.dart / schedule_page.dart)
// =========================

class _Palette {
  static const Color salmon = Color(0xFFFA7268);
  static const Color peach = Color(0xFFFF9E89);
  static const Color blush = Color(0xFFFFD6C4);
  static const Color cream = Color(0xFFFFEFC4);
  static const Color brown = Color(0xFF5B3A29);
  static const Color brownSoft = Color(0xFF7A3E2A);
  static const Color muted = Color(0xFFAD8A79);
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

//
  String _portionLabel(int? angle) {
    if (angle == null) return 'Unknown';

    if (angle <= 45) return 'Small';
    if (angle <= 90) return 'Medium';
    return 'Full';
  }

  // Progress-bar fraction driven by the normalized Small/Medium/Full
  // label (not the raw stored angle) — older rows can have an angle
  // value that no longer matches the 45/90/180 presets, which would
  // otherwise make the bar disagree with the text next to it.
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
    final months = ['Jan','Feb','Mar','Apr','May','Jun',
                    'Jul','Aug','Sep','Oct','Nov','Dec'];
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

  // Group logs by date
  Map<String, List<Map<String, dynamic>>> get _groupedLogs {
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final log in _filteredLogs) {
      final date = _formatDate(log['fed_at'] as String?);
      grouped.putIfAbsent(date, () => []).add(log);
    }
    return grouped;
  }

  // Stats
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
          const SnackBar(
            content: Text('Log deleted'),
            backgroundColor: _Palette.peach,
            duration: Duration(seconds: 2),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.delete_sweep, color: _Palette.salmon),
            const SizedBox(width: 8),
            Text(
              'Delete All Logs?',
              style: GoogleFonts.fraunces(
                fontWeight: FontWeight.w700,
                color: _Palette.brownSoft,
              ),
            ),
          ],
        ),
        content: Text(
          'This will permanently delete all feeding history. This cannot be undone.',
          style: GoogleFonts.dmSans(color: _Palette.brownSoft.withOpacity(0.8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: GoogleFonts.dmSans(color: _Palette.muted)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: _Palette.salmon,
            ),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await supabase
          .from('feeding_logs')
          .delete()
          .neq('id', 0); // delete all rows
      setState(() => _logs = []);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All logs deleted'),
            backgroundColor: _Palette.peach,
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
        child: SafeArea(
          child: Column(
            children: [
              // =========================
              // HEADER (built inline — no separate
              // Material AppBar, so no stray surface/tint box)
              // =========================
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 12, 6),
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
                        Icons.pets,
                        color: Colors.white,
                        size: 17,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Feeding History',
                        style: GoogleFonts.fraunces(
                          color: _Palette.brownSoft,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh, color: _Palette.brownSoft),
                      onPressed: _fetchLogs,
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_sweep, color: _Palette.brownSoft),
                      tooltip: 'Delete all logs',
                      onPressed: _deleteAllLogs,
                    ),
                  ],
                ),
              ),

              Expanded(
                child: _loading
                    ? const Center(
                        child: CircularProgressIndicator(color: _Palette.salmon),
                      )
                    : RefreshIndicator(
                        color: _Palette.salmon,
                        onRefresh: _fetchLogs,
                        child: CustomScrollView(
                          slivers: [
                            // Stats Cards
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  children: [
                                    IntrinsicHeight(
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.stretch,
                                        children: [
                                          Expanded(
                                            child: _StatCard(
                                              label: 'Total Feedings',
                                              value: '$_totalFeedings',
                                              icon: Icons.history,
                                              color: _Palette.salmon,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: _StatCard(
                                              label: 'Today',
                                              value: '$_todayFeedings',
                                              icon: Icons.today,
                                              color: _Palette.peach,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: _StatCard(
                                              label: 'Common Portion',
                                              value: _mostCommonPortion,
                                              icon: Icons.pie_chart,
                                              color: const Color(0xFFE0A438),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 16),

                                    // Filter chips
                                    Row(
                                      children: _filters.map((f) {
                                        final selected = _filter == f;
                                        return Padding(
                                          padding: const EdgeInsets.only(right: 8),
                                          child: GestureDetector(
                                            onTap: () =>
                                                setState(() => _filter = f),
                                            child: AnimatedContainer(
                                              duration:
                                                  const Duration(milliseconds: 180),
                                              padding: const EdgeInsets.symmetric(
                                                  horizontal: 16, vertical: 8),
                                              decoration: BoxDecoration(
                                                gradient: selected
                                                    ? const LinearGradient(
                                                        begin: Alignment.topLeft,
                                                        end: Alignment.bottomRight,
                                                        colors: [
                                                          _Palette.salmon,
                                                          _Palette.peach,
                                                        ],
                                                      )
                                                    : null,
                                                color:
                                                    selected ? null : Colors.white,
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                                border: Border.all(
                                                  color: selected
                                                      ? Colors.transparent
                                                      : _Palette.salmon
                                                          .withOpacity(0.4),
                                                ),
                                              ),
                                              child: Text(
                                                f,
                                                style: GoogleFonts.dmSans(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w600,
                                                  color: selected
                                                      ? Colors.white
                                                      : _Palette.salmon,
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
                            ),

                            // Empty state
                            if (_filteredLogs.isEmpty)
                              SliverFillRemaining(
                                child: Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        width: 84,
                                        height: 84,
                                        decoration: BoxDecoration(
                                          color: _Palette.blush.withOpacity(0.5),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.no_meals,
                                          size: 40,
                                          color: _Palette.salmon,
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        'No feeding logs yet',
                                        style: GoogleFonts.fraunces(
                                          fontSize: 17,
                                          fontWeight: FontWeight.w700,
                                          color: _Palette.brownSoft,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Logs appear after the feeder feeds your pet',
                                        style: GoogleFonts.dmSans(
                                          fontSize: 13,
                                          color: _Palette.brownSoft.withOpacity(0.6),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                            // Grouped logs
                            for (final entry in grouped.entries) ...[
                              // Date header
                              SliverToBoxAdapter(
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.7),
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          entry.key,
                                          style: GoogleFonts.dmSans(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: _Palette.brownSoft,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Divider(
                                          color: _Palette.brown.withOpacity(0.2),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              // Log items
                              SliverList(
                                delegate: SliverChildBuilderDelegate(
                                  (context, index) {
                                    final log = entry.value[index];
                                    final angle = log['angle'] as int?;

                                    String portion = log['portion_label'] as String? ??
                                        _portionLabel(angle);

                                    // Normalize old database values to the new names
                                    if (portion.toLowerCase().contains('small')) {
                                      portion = 'Small';
                                    } else if (portion.toLowerCase().contains('medium')) {
                                      portion = 'Medium';
                                    } else if (portion.toLowerCase().contains('full') ||
                                        portion.toLowerCase().contains('large')) {
                                      portion = 'Full';
                                    } else {
                                      portion = _portionLabel(angle);
                                    }

                                    final triggerType =
                                        log['trigger_type'] as String? ?? 'manual';
                                    final isScheduled =
                                        triggerType.toLowerCase() == 'scheduled';

                                    return Dismissible(
                                      key: Key('log_${log['id']}'),
                                      direction: DismissDirection.endToStart,
                                      background: Container(
                                        margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                                        decoration: BoxDecoration(
                                          color: Colors.red.withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        alignment: Alignment.centerRight,
                                        padding: const EdgeInsets.only(right: 20),
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            const Icon(Icons.delete_outline,
                                                color: Colors.red, size: 26),
                                            const SizedBox(height: 4),
                                            Text(
                                              'Delete',
                                              style: GoogleFonts.dmSans(
                                                color: Colors.red,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      confirmDismiss: (_) async {
                                        return await showDialog<bool>(
                                          context: context,
                                          builder: (ctx) => AlertDialog(
                                            backgroundColor: const Color(0xFFFFFDF9),
                                            shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(20)),
                                            title: Text(
                                              'Delete this log?',
                                              style: GoogleFonts.fraunces(
                                                fontWeight: FontWeight.w700,
                                                color: _Palette.brownSoft,
                                              ),
                                            ),
                                            content: Text(
                                              'This feeding record will be removed.',
                                              style: GoogleFonts.dmSans(
                                                color: _Palette.brownSoft.withOpacity(0.8),
                                              ),
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () =>
                                                    Navigator.pop(ctx, false),
                                                child: Text('Cancel',
                                                    style: GoogleFonts.dmSans(
                                                        color: _Palette.muted)),
                                              ),
                                              FilledButton(
                                                onPressed: () =>
                                                    Navigator.pop(ctx, true),
                                                style: FilledButton.styleFrom(
                                                  backgroundColor: _Palette.salmon,
                                                ),
                                                child: const Text('Delete'),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                      onDismissed: (_) =>
                                          _deleteLog(log['id'] as int),
                                      child: Container(
                                        margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.92),
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(
                                            color: isScheduled
                                                ? _Palette.peach.withOpacity(0.5)
                                                : _Palette.salmon.withOpacity(0.25),
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: _Palette.brownSoft.withOpacity(0.08),
                                              blurRadius: 12,
                                              offset: const Offset(0, 5),
                                            ),
                                          ],
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.all(14),
                                          child: Row(
                                            children: [
                                              // Icon
                                              Container(
                                                width: 44,
                                                height: 44,
                                                decoration: BoxDecoration(
                                                  gradient: isScheduled
                                                      ? LinearGradient(
                                                          colors: [
                                                            _Palette.peach.withOpacity(0.7),
                                                            _Palette.blush,
                                                          ],
                                                        )
                                                      : LinearGradient(
                                                          colors: [
                                                            _Palette.salmon,
                                                            _Palette.peach,
                                                          ],
                                                        ),
                                                  borderRadius: BorderRadius.circular(14),
                                                ),
                                                child: Icon(
                                                  isScheduled
                                                      ? Icons.schedule
                                                      : Icons.touch_app,
                                                  color: Colors.white,
                                                  size: 22,
                                                ),
                                              ),
                                              const SizedBox(width: 12),

                                              // Details
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Row(
                                                      children: [
                                                        Text(
                                                          _formatTime(
                                                              log['fed_at'] as String?),
                                                          style: GoogleFonts.fraunces(
                                                            fontSize: 16,
                                                            fontWeight: FontWeight.w700,
                                                            color: _Palette.brown,
                                                          ),
                                                        ),
                                                        const SizedBox(width: 8),
                                                        Container(
                                                          padding: const EdgeInsets.symmetric(
                                                              horizontal: 8, vertical: 2),
                                                          decoration: BoxDecoration(
                                                            color: isScheduled
                                                                ? _Palette.peach.withOpacity(0.3)
                                                                : _Palette.salmon.withOpacity(0.15),
                                                            borderRadius:
                                                                BorderRadius.circular(8),
                                                          ),
                                                          child: Text(
                                                            isScheduled
                                                                ? 'Scheduled'
                                                                : 'Manual',
                                                            style: GoogleFonts.dmSans(
                                                              fontSize: 11,
                                                              fontWeight: FontWeight.w600,
                                                              color: _Palette.brownSoft,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Row(
                                                      children: [
                                                        Icon(
                                                          Icons.pets,
                                                          size: 13,
                                                          color: _Palette.brownSoft
                                                              .withOpacity(0.5),
                                                        ),
                                                        const SizedBox(width: 4),
                                                        Text(
                                                          '$portion portion',
                                                          style: GoogleFonts.dmSans(
                                                            fontSize: 13,
                                                            color: _Palette.brownSoft
                                                                .withOpacity(0.65),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    if (log['notes'] != null &&
                                                        (log['notes'] as String)
                                                            .isNotEmpty) ...[
                                                      const SizedBox(height: 4),
                                                      Text(
                                                        log['notes'] as String,
                                                        style: GoogleFonts.dmSans(
                                                          fontSize: 12,
                                                          color: _Palette.brownSoft
                                                              .withOpacity(0.45),
                                                          fontStyle: FontStyle.italic,
                                                        ),
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                              ),

                                              // Portion progress
                                              Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.end,
                                                children: [
                                                  Text(
                                                    portion,
                                                    style: GoogleFonts.dmSans(
                                                      fontSize: 15,
                                                      fontWeight: FontWeight.w800,
                                                      color: _Palette.salmon,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  SizedBox(
                                                    width: 48,
                                                    child: ClipRRect(
                                                      borderRadius:
                                                          BorderRadius.circular(4),
                                                      child: LinearProgressIndicator(
                                                        // Driven by the normalized
                                                        // label, not the raw angle —
                                                        // see _portionProgress above.
                                                        value: _portionProgress(portion),
                                                        backgroundColor: _Palette.blush
                                                            .withOpacity(0.5),
                                                        color: _Palette.salmon,
                                                        minHeight: 6,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ), // close Container (Dismissible child)
                                    ); // close Dismissible
                                  },
                                  childCount: entry.value.length,
                                ),
                              ),
                            ],

                            // Bottom padding
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
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
//TOTAL FEEDINGS
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 252, 250, 251).withOpacity(0.92),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: _Palette.brownSoft.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withOpacity(0.16),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.fraunces(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: _Palette.brown,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.dmSans(
              fontSize: 11,
              color: _Palette.brownSoft.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }
}