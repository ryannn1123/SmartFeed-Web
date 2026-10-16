import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';

// ============================================================
// OFFLINE SCHEDULING OVER BLUETOOTH
// ============================================================
// Use this page when the feeder has no WiFi/internet:
//
// 1. Tap "Connect" (the phone finds the "SmartFeed" ESP32).
// 2. The app logs in with the PIN and syncs the phone's time
//    to the feeder's clock.
// 3. Add a schedule: it is saved on the ESP32 itself and fires
//    even with no internet. When the feeder is back online it
//    uploads the schedule to Supabase automatically.
//
// Open this page from anywhere with:
//   Navigator.push(context,
//     MaterialPageRoute(builder: (_) => const BleSchedulePage()));
// ============================================================


// =========================
// PALETTE
// =========================
class _Palette {
  static const Color salmon = Color(0xFFFA7268);
  static const Color peach = Color(0xFFFF9E89);
  static const Color blush = Color(0xFFFFD6C4);
  static const Color cream = Color(0xFFFFEFC4);
  static const Color brown = Color(0xFF5B3A29);
  static const Color brownSoft = Color(0xFF7A3E2A);
  static const Color amber = Color(0xFFE0A438);
  static const Color leaf = Color(0xFF6FAE7C);
  static const Color red = Color(0xFFC23B3B);
}

// =========================
// BLUETOOTH CONSTANTS
// =========================
// These MUST match the ESP32 code.
const String _kDeviceName = 'SmartFeed';
const String _kService = '7f1c0001-5b3a-4c1e-9a2d-8e4f1b2c3d4e';
const String _kRx = '7f1c0002-5b3a-4c1e-9a2d-8e4f1b2c3d4e'; // phone -> ESP32
const String _kTx = '7f1c0003-5b3a-4c1e-9a2d-8e4f1b2c3d4e'; // ESP32 -> phone

// Must match BLE_PIN in the ESP32 code.
const String _kPin = '1234';


// One schedule as reported by the feeder.
class _Sched {
  final int id;
  final String date;
  final String time;
  final int angle;
  final bool isLocal; // true = saved on the feeder, not uploaded yet

  const _Sched({
    required this.id,
    required this.date,
    required this.time,
    required this.angle,
    required this.isLocal,
  });

  String get portion {
    if (angle == 45) return 'Small';
    if (angle == 90) return 'Medium';
    return 'Full';
  }
}


class BleSchedulePage extends StatefulWidget {
  const BleSchedulePage({super.key});

  @override
  State<BleSchedulePage> createState() => _BleSchedulePageState();
}


class _BleSchedulePageState extends State<BleSchedulePage> {
  // ---- connection ----
  BluetoothDevice? _device;
  BluetoothCharacteristic? _rx;
  BluetoothCharacteristic? _tx;
  StreamSubscription<BluetoothConnectionState>? _connSub;
  StreamSubscription<List<int>>? _notifySub;

  bool _scanning = false;
  bool _connecting = false;
  bool _connected = false;
  bool _authed = false;
  bool _busy = false;

  String _status = 'Not connected';
  String _deviceInfo = '';

  // ---- request/response ----
  Completer<String>? _waiting;
  final List<_Sched> _incoming = [];

  // ---- schedules ----
  List<_Sched> _schedules = [];

  // ---- add form ----
  DateTime? _pickedDate;
  TimeOfDay? _pickedTime;
  String _portion = 'small';

  static const Map<String, int> _angles = {
    'small': 45,
    'medium': 90,
    'full': 180,
  };


  @override
  void dispose() {
    _notifySub?.cancel();
    _connSub?.cancel();
    _device?.disconnect();
    super.dispose();
  }


  // ============================================================
  // HELPERS
  // ============================================================

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  String _two(int n) => n.toString().padLeft(2, '0');

  String _fmtDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${_two(d.month)}-${_two(d.day)}';

  String _fmtTime(TimeOfDay t) => '${_two(t.hour)}:${_two(t.minute)}';

 Future<bool> _ensurePermissions() async {
  if (!Platform.isAndroid) return true;

  final location = await Permission.locationWhenInUse.request();

  if (!location.isGranted) {
    return false;
  }

  return true;
}


  // ============================================================
  // CONNECT
  // ============================================================

  Future<void> _connect() async {
    final adapterState = await FlutterBluePlus.adapterState.first;

  if (adapterState != BluetoothAdapterState.on) {
  if (!mounted) return;
  setState(() => _status = 'Please turn on Bluetooth');
  return;
}

    if (FlutterBluePlus.adapterStateNow != BluetoothAdapterState.on) {
      setState(() => _status = 'Please turn on Bluetooth');
      return;
    }

    setState(() {
      _scanning = true;
      _status = 'Searching for SmartFeed...';
    });

    // ---- scan ----
    ScanResult? found;

    final scanSub = FlutterBluePlus.scanResults.listen((results) {
      for (final r in results) {
        final matches =
            r.advertisementData.serviceUuids.contains(Guid(_kService)) ||
                r.advertisementData.advName == _kDeviceName ||
                r.device.platformName == _kDeviceName;

        if (matches && (found == null || r.rssi > found!.rssi)) {
          found = r;
        }
      }
    });

    try {
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 8));

      final end = DateTime.now().add(const Duration(seconds: 8));
      while (found == null && DateTime.now().isBefore(end)) {
        await Future.delayed(const Duration(milliseconds: 200));
      }

      await FlutterBluePlus.stopScan();
    } catch (e) {
      await scanSub.cancel();
      if (!mounted) return;
      setState(() {
        _scanning = false;
        _status = 'Scan failed: $e';
      });
      return;
    }

    await scanSub.cancel();

    if (!mounted) return;

    if (found == null) {
      setState(() {
        _scanning = false;
        _status = 'SmartFeed not found. Bluetooth turns on about 20 seconds '
            'after the feeder loses WiFi. Make sure it is powered on and nearby.';
      });
      return;
    }

    // ---- connect ----
    setState(() {
      _scanning = false;
      _connecting = true;
      _status = 'Connecting...';
    });

    try {
      final device = found!.device;

      await device.connect(timeout: const Duration(seconds: 15));

      _device = device;

      _connSub = device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          _handleDisconnected();
        }
      });

      // ---- find the two characteristics ----
      final services = await device.discoverServices();

      for (final s in services) {
        if (s.uuid == Guid(_kService)) {
          for (final c in s.characteristics) {
            if (c.uuid == Guid(_kRx)) _rx = c;
            if (c.uuid == Guid(_kTx)) _tx = c;
          }
        }
      }

      if (_rx == null || _tx == null) {
        throw 'SmartFeed service not found';
      }

      await _tx!.setNotifyValue(true);

      _notifySub = _tx!.onValueReceived.listen(_onNotify);
      device.cancelWhenDisconnected(_notifySub!);

      if (!mounted) return;
      setState(() {
        _connecting = false;
        _connected = true;
        _status = 'Connected - logging in...';
      });

      await _login();
    } catch (e) {
      try {
        await _device?.disconnect();
      } catch (_) {}

      if (!mounted) return;
      setState(() {
        _connecting = false;
        _connected = false;
        _authed = false;
        _status = 'Could not connect: $e';
      });
    }
  }


  Future<void> _disconnect() async {
    try {
      await _device?.disconnect();
    } catch (_) {}
  }


  void _handleDisconnected() {
    _notifySub?.cancel();
    _connSub?.cancel();

    _rx = null;
    _tx = null;

    final w = _waiting;
    if (w != null && !w.isCompleted) w.complete('ERR,DISCONNECTED');

    if (!mounted) return;
    setState(() {
      _connected = false;
      _authed = false;
      _busy = false;
      _status = 'Disconnected';
    });
  }


  // ============================================================
  // LOGIN + TIME SYNC
  // ============================================================

  Future<void> _login() async {
    final auth = await _request('AUTH,$_kPin');

    if (auth != 'OK,AUTH') {
      if (!mounted) return;
      setState(() {
        _status = 'Wrong PIN (check the PIN in the ESP32 code)';
      });
      return;
    }

    // Send the phone's clock to the feeder, so schedules fire at the
    // right time even if the feeder's clock drifted or lost power.
    final now = DateTime.now();
    final timeReply = await _request(
      'TIME,${_fmtDate(now)},${_two(now.hour)}:${_two(now.minute)}:${_two(now.second)}',
    );

    if (!mounted) return;
    setState(() {
      _authed = true;
      _status = timeReply == 'OK,TIME'
          ? 'Connected - feeder clock synced'
          : 'Connected';
    });

    await _loadInfo();
    await _refreshList();
  }


  Future<void> _loadInfo() async {
    final reply = await _request('INFO');
    final parts = reply.split(',');

    if (parts.length >= 5 && parts[0] == 'INFO') {
      if (!mounted) return;
      setState(() {
        _deviceInfo = 'Feeder time: ${parts[1]}  •  '
            'Internet: ${parts[2] == '1' ? 'online' : 'offline'}';
      });
    }
  }


  // ============================================================
  // SENDING / RECEIVING
  // ============================================================

  // Sends one command and waits for the feeder's reply line.
  // (The ESP32 handles one command at a time, so we always wait.)
  Future<String> _request(String cmd) async {
    final rx = _rx;

    if (rx == null) return 'ERR,NOT_CONNECTED';

    _incoming.clear();

    final completer = Completer<String>();
    _waiting = completer;

    try {
      await rx.write(
        utf8.encode(cmd),
        withoutResponse: false,
        allowLongWrite: true,
      );
    } catch (e) {
      _waiting = null;
      return 'ERR,WRITE';
    }

    return completer.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        _waiting = null;
        return 'ERR,TIMEOUT';
      },
    );
  }


  // One line arrives per notification.
  void _onNotify(List<int> data) {
    final line = utf8.decode(data, allowMalformed: true).trim();

    if (line.startsWith('S,')) {
      final s = _parseSchedule(line);
      if (s != null) _incoming.add(s);
      return;
    }

    final w = _waiting;
    if (w != null && !w.isCompleted) {
      w.complete(line);
    }
  }


  // "S,<id>,<date>,<time>,<angle>,<enabled>,<R|L>"
  _Sched? _parseSchedule(String line) {
    final p = line.split(',');

    if (p.length < 7) return null;

    final id = int.tryParse(p[1]);
    final angle = int.tryParse(p[4]);

    if (id == null || angle == null) return null;

    return _Sched(
      id: id,
      date: p[2],
      time: p[3],
      angle: angle,
      isLocal: p[6] == 'L',
    );
  }


  Future<void> _refreshList() async {
    final reply = await _request('LIST');

    if (reply != 'END') {
      _snack('Could not read schedules ($reply)');
      return;
    }

    final list = List<_Sched>.of(_incoming);
    list.sort((a, b) => '${a.date} ${a.time}'.compareTo('${b.date} ${b.time}'));

    if (!mounted) return;
    setState(() => _schedules = list);
  }


  // ============================================================
  // ADD / DELETE
  // ============================================================

  Future<void> _pickDate() async {
    final now = DateTime.now();

    final d = await showDatePicker(
      context: context,
      initialDate: _pickedDate ?? now,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 365)),
    );

    if (d != null) setState(() => _pickedDate = d);
  }


  Future<void> _pickTime() async {
    final t = await showTimePicker(
      context: context,
      initialTime: _pickedTime ?? TimeOfDay.now(),
    );

    if (t != null) setState(() => _pickedTime = t);
  }


  String _errorText(String reply) {
    if (reply.endsWith(',-1')) return 'Invalid date, time or portion';
    if (reply.endsWith(',-2')) return 'The feeder is full (max 10 offline schedules)';
    if (reply.endsWith(',-3')) return 'A schedule at that date and time already exists';
    if (reply == 'ERR,TIMEOUT') return 'No answer from the feeder. Try again.';
    return 'Failed ($reply)';
  }


  Future<void> _addSchedule() async {
    if (!_authed || _busy) return;

    if (_pickedDate == null || _pickedTime == null) {
      _snack('Pick a date and a time first');
      return;
    }

    final d = _pickedDate!;
    final t = _pickedTime!;

    final when = DateTime(d.year, d.month, d.day, t.hour, t.minute);

    if (!when.isAfter(DateTime.now())) {
      _snack('Pick a time in the future');
      return;
    }

    setState(() => _busy = true);

    final angle = _angles[_portion]!;

    final reply = await _request('ADD,${_fmtDate(d)},${_fmtTime(t)},$angle');

    if (reply.startsWith('OK,ADD')) {
      _snack('Schedule saved on the feeder');
      await _refreshList();
    } else {
      _snack(_errorText(reply));
    }

    if (mounted) setState(() => _busy = false);
  }


  Future<void> _deleteSchedule(_Sched s) async {
    if (!_authed || _busy) return;

    setState(() => _busy = true);

    final reply = await _request('DEL,${s.id}');

    if (reply == 'OK,DEL') {
      await _refreshList();
    } else {
      _snack(_errorText(reply));
    }

    if (mounted) setState(() => _busy = false);
  }


  // ============================================================
  // UI
  // ============================================================

  Widget _card({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: _Palette.brownSoft.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }


  Widget _title(IconData icon, String text) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: _Palette.salmon.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 14, color: _Palette.salmon),
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: GoogleFonts.fraunces(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: _Palette.brownSoft,
          ),
        ),
      ],
    );
  }


  Widget _connectionCard() {
    final working = _scanning || _connecting;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_Palette.salmon, _Palette.peach],
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: _Palette.salmon.withOpacity(0.4),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.22),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _connected
                      ? Icons.bluetooth_connected_rounded
                      : Icons.bluetooth_searching_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _status,
                  style: GoogleFonts.dmSans(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    height: 1.3,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              working
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Colors.white,
                      ),
                    )
                  : Material(
                      color: Colors.white.withOpacity(0.22),
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: _connected ? _disconnect : _connect,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          child: Text(
                            _connected ? 'Disconnect' : 'Connect',
                            style: GoogleFonts.dmSans(
                              color: Colors.white,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ),
            ],
          ),
          if (_deviceInfo.isNotEmpty && _connected) ...[
            const SizedBox(height: 10),
            Text(
              _deviceInfo,
              style: GoogleFonts.dmSans(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: Colors.white.withOpacity(0.9),
              ),
            ),
          ],
        ],
      ),
    );
  }


  Widget _addCard() {
    final dateText = _pickedDate == null
        ? 'Pick date'
        : _fmtDate(_pickedDate!);

    final timeText = _pickedTime == null
        ? 'Pick time'
        : _pickedTime!.format(context);

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _title(Icons.add_alarm_rounded, 'Add a schedule'),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : _pickDate,
                  icon: const Icon(Icons.calendar_today_rounded, size: 16),
                  label: Text(dateText),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _Palette.brownSoft,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : _pickTime,
                  icon: const Icon(Icons.access_time_rounded, size: 16),
                  label: Text(timeText),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _Palette.brownSoft,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              for (final p in ['small', 'medium', 'full'])
                ChoiceChip(
                  label: Text(
                    '${p[0].toUpperCase()}${p.substring(1)}',
                    style: GoogleFonts.dmSans(fontWeight: FontWeight.w800),
                  ),
                  selected: _portion == p,
                  selectedColor: _Palette.blush,
                  onSelected: _busy ? null : (_) => setState(() => _portion = p),
                ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _busy ? null : _addSchedule,
              icon: _busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save_rounded, size: 18),
              label: Text(
                'Save to feeder',
                style: GoogleFonts.dmSans(fontWeight: FontWeight.w800),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: _Palette.salmon,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }


  Widget _listCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _title(Icons.event_note_rounded, 'On the feeder'),
              ),
              IconButton(
                onPressed: _busy ? null : _refreshList,
                icon: const Icon(Icons.refresh_rounded),
                color: _Palette.brownSoft,
                tooltip: 'Refresh',
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (_schedules.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'No upcoming schedules on the feeder.',
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _Palette.brownSoft.withOpacity(0.7),
                ),
              ),
            ),
          for (final s in _schedules)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
              decoration: BoxDecoration(
                color: _Palette.cream.withOpacity(0.6),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Icon(
                    s.isLocal
                        ? Icons.bluetooth_rounded
                        : Icons.cloud_done_rounded,
                    size: 20,
                    color: s.isLocal ? _Palette.amber : _Palette.leaf,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${s.date}  ${s.time}',
                          style: GoogleFonts.dmSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: _Palette.brown,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${s.portion} portion  •  '
                          '${s.isLocal ? 'Saved on feeder (uploads when online)' : 'Synced with cloud'}',
                          style: GoogleFonts.dmSans(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: _Palette.brownSoft.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _busy ? null : () => _deleteSchedule(s),
                    icon: const Icon(Icons.delete_outline_rounded),
                    color: _Palette.red,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
            children: [
              // ---- HEADER ----
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.maybePop(context),
                    icon: const Icon(Icons.arrow_back_rounded),
                    color: _Palette.brownSoft,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Offline Schedule',
                          style: GoogleFonts.fraunces(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: _Palette.brownSoft,
                            letterSpacing: -0.3,
                          ),
                        ),
                        Text(
                          'No internet? Set schedules over Bluetooth 🐾',
                          style: GoogleFonts.dmSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _Palette.brownSoft.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              _connectionCard(),

              if (_authed) ...[
                const SizedBox(height: 16),
                _addCard(),
                const SizedBox(height: 16),
                _listCard(),
              ],
            ],
          ),
        ),
      ),
    );
  }
}