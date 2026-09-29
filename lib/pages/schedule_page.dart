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
}

// =========================
// PORTION MAPPING
// =========================

String _portionLabel(int angle) {
  if (angle == 45) {
    return 'Small';
  } else if (angle == 90) {
    return 'Medium';
  } else if (angle == 180) {
    return 'Full';
  }
  return 'Unknown';
}

IconData _portionIcon(int angle) {
  if (angle == 45) {
    return Icons.restaurant;
  } else if (angle == 90) {
    return Icons.set_meal;
  } else if (angle == 180) {
    return Icons.dinner_dining;
  }
  return Icons.pets;
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
          borderRadius: BorderRadius.circular(24),
        ),
        title: Text(
          'Delete feeding time?',
          style: GoogleFonts.fraunces(
            fontWeight: FontWeight.w800,
            color: _Palette.brownSoft,
          ),
        ),
        content: Text(
          'This feeding schedule will be removed.',
          style: GoogleFonts.dmSans(
            color: _Palette.brownSoft.withOpacity(0.8),
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
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await supabase
          .from('schedule')
          .delete()
          .eq('id', id);

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
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            _Palette.salmon,
                            _Palette.peach,
                          ],
                        ),
                      ),
                      child: const Icon(
                        Icons.schedule_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Feeding Schedule',
                      style: GoogleFonts.fraunces(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: _Palette.brownSoft,
                      ),
                    ),
                  ],
                ),
              ),

              // =========================
              // ADD FEEDING TIME
              // =========================

              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
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
                          blurRadius: 14,
                          offset: const Offset(0, 6),
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
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      icon: const Icon(Icons.pets, size: 20),
                      label: Text(
                        'Add feeding time',
                        style: GoogleFonts.dmSans(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

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
                                12,
                                18,
                                130,
                              ),
                              itemCount: _schedules.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 14),
                              itemBuilder: (context, index) {
                                final s = _schedules[index];

                                final timeStr =
                                    s['feed_time'].toString();

                                final dateStr =
                                    s['feed_date']?.toString();

                                final enabled =
                                    s['enabled'] as bool;

                                final angle =
                                    s['angle'] as int? ?? 90;

                                return _ScheduleCard(
                                  rawTimeString: timeStr,
                                  rawDateString: dateStr,
                                  angle: angle,
                                  enabled: enabled,
                                  onEdit: () =>
                                      _editSchedule(s),
                                  onDelete: () =>
                                      _deleteSchedule(
                                    s['id'] as int,
                                  ),
                                  onToggle: (val) =>
                                      _toggleSchedule(
                                    s['id'] as int,
                                    val,
                                  ),
                                );
                              },
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

    try {
      final parts = rawTimeString.split(':');

      if (parts.length >= 2) {
        final hour = int.parse(parts[0]);
        final minute = int.parse(parts[1]);

        final timeOfDay = TimeOfDay(
          hour: hour,
          minute: minute,
        );

        final now = DateTime.now();

        final dt = DateTime(
          now.year,
          now.month,
          now.day,
          timeOfDay.hour,
          timeOfDay.minute,
        );

        formattedTime = DateFormat.jm().format(dt);
      }
    } catch (_) {
      if (rawTimeString.length >= 5) {
        formattedTime = rawTimeString.substring(0, 5);
      }
    }

    // Format feed_date
    if (rawDateString != null &&
        rawDateString!.isNotEmpty &&
        rawDateString != 'null') {
      try {
        final date = DateTime.parse(rawDateString!);

        formattedDate =
            'Scheduled for ${DateFormat('MMM d, yyyy').format(date)}';
      } catch (_) {
        formattedDate = 'Scheduled for $rawDateString';
      }
    }

    final portionLabel = _portionLabel(angle);
    final portionIcon = _portionIcon(angle);

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 220),
      opacity: enabled ? 1 : 0.5,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: enabled
                ? _Palette.salmon.withOpacity(0.25)
                : Colors.grey.withOpacity(0.18),
          ),
          boxShadow: [
            BoxShadow(
              color: _Palette.brownSoft.withOpacity(0.1),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: enabled
                          ? const [
                              _Palette.salmon,
                              _Palette.peach,
                            ]
                          : [
                              Colors.grey.shade300,
                              Colors.grey.shade200,
                            ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.pets,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        formattedTime,
                        style: GoogleFonts.fraunces(
                          fontSize: 25,
                          fontWeight: FontWeight.w700,
                          color: _Palette.brown,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        formattedDate,
                        style: GoogleFonts.dmSans(
                          color: _Palette.brownSoft
                              .withOpacity(0.7),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: enabled,
                  activeColor: _Palette.salmon,
                  onChanged: onToggle,
                ),
              ],
            ),

            const SizedBox(height: 18),

            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: _Palette.blush.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        portionIcon,
                        size: 16,
                        color: _Palette.salmon,
                      ),
                      const SizedBox(width: 5),
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
                    child: LinearProgressIndicator(
                      value: angle / 180,
                      minHeight: 8,
                      backgroundColor:
                          _Palette.blush.withOpacity(0.5),
                      color: _Palette.salmon,
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
                    icon: const Icon(
                      Icons.edit_rounded,
                      size: 17,
                    ),
                    label: Text(
                      'Edit',
                      style: GoogleFonts.dmSans(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _Palette.salmon,
                      side: BorderSide(
                        color:
                            _Palette.salmon.withOpacity(0.45),
                      ),
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
                      backgroundColor:
                          const Color(0xFFFFEEF0),
                      foregroundColor: Colors.redAccent,
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
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.85),
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: _Palette.brownSoft.withOpacity(0.1),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  color: _Palette.blush.withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.pets,
                  size: 42,
                  color: _Palette.salmon,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'No meals scheduled',
                style: GoogleFonts.fraunces(
                  color: _Palette.brownSoft,
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Tap "Add feeding time" to create your pet\'s next meal.',
                textAlign: TextAlign.center,
                style: GoogleFonts.dmSans(
                  color:
                      _Palette.brownSoft.withOpacity(0.7),
                  fontSize: 13,
                  height: 1.45,
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
  State<_AddScheduleDialog> createState() =>
      _AddScheduleDialogState();
}

class _AddScheduleDialogState
    extends State<_AddScheduleDialog> {
  DateTime _selectedDate = DateTime.now();
  TimeOfDay? _selectedTime;
  int _angle = 90;

  final List<Map<String, dynamic>> _presets = [
    {
      'label': 'Small',
      'angle': 45,
      'icon': Icons.restaurant,
    },
    {
      'label': 'Medium',
      'angle': 90,
      'icon': Icons.set_meal,
    },
    {
      'label': 'Full',
      'angle': 180,
      'icon': Icons.dinner_dining,
    },
  ];

  @override
  void initState() {
    super.initState();

    if (widget.existing != null) {
      // =========================
      // LOAD FEED DATE
      // =========================

      final rawDate =
          widget.existing!['feed_date']?.toString();

      if (rawDate != null &&
          rawDate.isNotEmpty &&
          rawDate != 'null') {
        try {
          _selectedDate = DateTime.parse(rawDate);
        } catch (_) {
          _selectedDate = DateTime.now();
        }
      }

      // =========================
      // LOAD FEED TIME
      // =========================

      final rawTime =
          widget.existing!['feed_time'].toString();

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

      _angle =
          widget.existing!['angle'] as int? ?? 90;
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate:
          DateTime.now().subtract(const Duration(days: 1)),
      lastDate:
          DateTime.now().add(const Duration(days: 365)),
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

    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime:
          _selectedTime ?? TimeOfDay.now(),
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

    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;

    return AlertDialog(
      backgroundColor: const Color(0xFFFFFDF9),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
      ),
      title: Text(
        isEdit
            ? 'Edit feeding time'
            : 'Add feeding time',
        style: GoogleFonts.fraunces(
          color: _Palette.brownSoft,
          fontWeight: FontWeight.w700,
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            // =========================
            // DATE
            // =========================

            Text(
              'Date',
              style: GoogleFonts.dmSans(
                fontWeight: FontWeight.w800,
                color: _Palette.brownSoft,
              ),
            ),

            const SizedBox(height: 8),

            InkWell(
              onTap: _pickDate,
              borderRadius:
                  BorderRadius.circular(18),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color:
                      _Palette.blush.withOpacity(0.45),
                  borderRadius:
                      BorderRadius.circular(18),
                  border: Border.all(
                    color:
                        _Palette.salmon.withOpacity(0.22),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.calendar_today_rounded,
                      color: _Palette.salmon,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      DateFormat(
                        'EEE, MMM d, yyyy',
                      ).format(_selectedDate),
                      style: GoogleFonts.dmSans(
                        fontSize: 16,
                        fontWeight:
                            FontWeight.w700,
                        color: _Palette.brown,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 18),

            // =========================
            // TIME
            // =========================

            Text(
              'Time',
              style: GoogleFonts.dmSans(
                fontWeight: FontWeight.w800,
                color: _Palette.brownSoft,
              ),
            ),

            const SizedBox(height: 8),

            InkWell(
              onTap: _pickTime,
              borderRadius:
                  BorderRadius.circular(18),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color:
                      _Palette.blush.withOpacity(0.45),
                  borderRadius:
                      BorderRadius.circular(18),
                  border: Border.all(
                    color:
                        _Palette.salmon.withOpacity(0.22),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.access_time_rounded,
                      color: _Palette.salmon,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      _selectedTime == null
                          ? 'Tap to pick time'
                          : _selectedTime!.format(
                              context,
                            ),
                      style: GoogleFonts.dmSans(
                        fontSize: 16,
                        fontWeight:
                            FontWeight.w700,
                        color:
                            _selectedTime == null
                                ? _Palette.muted
                                : _Palette.brown,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 22),

            // =========================
            // PORTION
            // =========================

            Text(
              'Portion Size 🥣',
              style: GoogleFonts.dmSans(
                fontWeight: FontWeight.w800,
                color: _Palette.brownSoft,
              ),
            ),

            const SizedBox(height: 10),

            Row(
              children: _presets.map((p) {
                final presetAngle =
                    p['angle'] as int;

                final isSelected =
                    _angle == presetAngle;

                return Expanded(
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(
                      horizontal: 4.0,
                    ),
                    child: InkWell(
                      onTap: () => setState(
                        () => _angle =
                            presetAngle,
                      ),
                      borderRadius:
                          BorderRadius.circular(16),
                      child: AnimatedContainer(
                        duration:
                            const Duration(
                          milliseconds: 180,
                        ),
                        padding:
                            const EdgeInsets.symmetric(
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          gradient: isSelected
                              ? const LinearGradient(
                                  begin:
                                      Alignment.topLeft,
                                  end:
                                      Alignment.bottomRight,
                                  colors: [
                                    _Palette.salmon,
                                    _Palette.peach,
                                  ],
                                )
                              : null,
                          color: isSelected
                              ? null
                              : _Palette.blush
                                  .withOpacity(0.4),
                          borderRadius:
                              BorderRadius.circular(
                            16,
                          ),
                          border: Border.all(
                            color: isSelected
                                ? Colors.transparent
                                : _Palette.salmon
                                    .withOpacity(
                                    0.22,
                                  ),
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              p['icon']
                                  as IconData,
                              size: 20,
                              color: isSelected
                                  ? Colors.white
                                  : _Palette.salmon,
                            ),
                            const SizedBox(
                              height: 6,
                            ),
                            Text(
                              '${p['label']}',
                              style:
                                  GoogleFonts.dmSans(
                                fontSize: 13,
                                color: isSelected
                                    ? Colors.white
                                    : _Palette.brown,
                                fontWeight:
                                    FontWeight.w700,
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

      actionsPadding:
          const EdgeInsets.fromLTRB(
        18,
        0,
        18,
        18,
      ),

      actions: [
        TextButton(
          onPressed: () =>
              Navigator.pop(context),
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
                      DateFormat('yyyy-MM-dd')
                          .format(_selectedDate);

                  Navigator.pop(
                    context,
                    {
                      'feed_date': dateStr,
                      'feed_time': timeStr,
                      'angle': _angle,
                    },
                  );
                },
          style: FilledButton.styleFrom(
            backgroundColor: _Palette.salmon,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius:
                  BorderRadius.circular(14),
            ),
          ),
          child: Text(
            isEdit ? 'Save' : 'Add',
            style: GoogleFonts.dmSans(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}
