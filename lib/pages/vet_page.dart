import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';
import 'dart:math';
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
  static const Color amber = Color(0xFFE0A438);
  static const Color leaf = Color(0xFF6FAE7C);
}

class VetPage extends StatefulWidget {
  const VetPage({super.key});

  @override
  State<VetPage> createState() => _VetPageState();
}



class _VetPageState extends State<VetPage> {
  Position? _position;
  bool _loadingLocation = false;

  // Clinics you know about. These always appear when the user is within
// 50 km, even if OpenStreetMap has no data for the area.
static const List<Map<String, dynamic>> _localClinics = [
  {
    'name': 'Cebu Northside Veterinary Clinic',
    'address':
        'Door 4, Brgy, Bogo MGF Franz Bldg, Gairan, Bogo City, 6010 Cebu',
    'phone': '09674592737',
    'hours': 'Mon-Sat: 9AM - 6PM',
    'type': 'Private',
    'color': _Palette.salmon,
    'lat': 11.0524383,
    'lng': 124.0116599,
  },
  {
    'name': 'David Shepherd Veterinary Services',
    'address': 'A.Mansueto St, Lourdes, Bogo City, 6010 Cebu',
    'phone': '09661456014',
    'hours': 'Mon-Sat: 9AM - 6PM',
    'type': 'Private',
    'color': _Palette.peach,
    'lat': 11.0503442,
    'lng': 124.0065866,
  },
  {
    'name': 'Bogo Claws and Paws Animal Clinic',
    'address': '3225+M7X, Bogo City, Cebu',
    'phone': '(032) 406 0505',
    'hours': 'Daily: 8AM - 8PM',
    'type': 'Private',
    'color': _Palette.amber,
    'lat': 11.0517469,
    'lng': 124.00823,
  },
];

  // NEW: City name found from the GPS coordinates (display only).
  String _city = '';

  // NEW: True once at least one search has finished, so the list can
  // tell "not searched yet" apart from "searched, nothing found".
  bool _hasSearched = false;

  String _locationStatus = 'Tap "Use GPS" to find nearest clinics';

  // ============================================================
  // VETERINARY CLINICS
  // ============================================================
  // CHANGED: This used to be a hardcoded list of Bogo City clinics.
  // It is now filled automatically from OpenStreetMap, based on the
  // user's GPS position, so it works in any city/country.
  //
  // Each clinic keeps the same keys the UI already uses:
  // name, address, phone, hours, type, color, lat, lng
  List<Map<String, dynamic>> _clinics = [];

  // Colors are cycled so the cards keep the app's colorful look.
  static const List<Color> _cardColors = [
    _Palette.salmon,
    _Palette.peach,
    _Palette.amber,
    _Palette.leaf,
  ];

  // Overpass API servers. The second one is a backup if the first
  // is busy or down.
  static const List<String> _overpassServers = [
  'https://overpass-api.de/api/interpreter',
  'https://overpass.kumi.systems/api/interpreter',
  'https://overpass.private.coffee/api/interpreter',
  'https://maps.mail.ru/osm/tools/overpass/api/interpreter',
];

  // Search radii in meters. If nothing is found at 5 km, it widens
  // the search automatically (important for small towns).
  static const List<int> _radii = [5000, 10000, 25000, 50000];

  // ============================================================
  // GET USER LOCATION + FIND CLINICS
  // ============================================================

  Future<void> _getLocation() async {
    setState(() {
      _loadingLocation = true;
      _locationStatus = 'Getting your location...';
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        if (!mounted) return;
        setState(() {
          _locationStatus = 'Please turn on Location/GPS on your phone';
          _loadingLocation = false;
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();

        if (permission == LocationPermission.denied) {
          if (!mounted) return;
          setState(() {
            _locationStatus = 'Location permission denied';
            _loadingLocation = false;
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        setState(() {
          _locationStatus = 'Enable location permission in phone settings';
          _loadingLocation = false;
        });
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (!mounted) return;
      setState(() {
        _position = position;
        _locationStatus = 'Searching clinics near you...';
      });

      // NEW: Find the city name (display only) and the clinics.
      final city = await _getCityName(position.latitude, position.longitude);
      final clinics = await _findClinics(position);

      if (!mounted) return;
      setState(() {
        _city = city;
        _clinics = clinics;
        _hasSearched = true;
        _loadingLocation = false;

        final where = city.isNotEmpty ? city : 'your location';
        _locationStatus = clinics.isEmpty
            ? 'No clinics found near $where'
            : 'Showing nearest clinics in $where';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _locationStatus = 'Could not find clinics. Tap Refresh to retry';
        _loadingLocation = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Location error: $e')),
      );
    }
  }

  // ============================================================
  // NEW: CITY NAME FROM COORDINATES
  // ============================================================
  // Converts GPS coordinates to something like "Bogo City, Cebu".
  // Used for display only; the search itself uses coordinates.
  Future<String> _getCityName(double lat, double lng) async {
    try {
      final placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isEmpty) return '';

      final m = placemarks.first;
      final parts = <String>[];

      final city = (m.locality?.isNotEmpty ?? false)
          ? m.locality!
          : (m.subAdministrativeArea ?? '');
      if (city.isNotEmpty) parts.add(city);

      if ((m.administrativeArea ?? '').isNotEmpty &&
          m.administrativeArea != city) {
        parts.add(m.administrativeArea!);
      }

      return parts.join(', ');
    } catch (_) {
      // Geocoding can fail without internet; the clinics search can
      // still work, so just skip the city name.
      return '';
    }
  }

  // ============================================================
  // NEW: FIND CLINICS AROUND A POSITION
  // ============================================================
  // Tries a small radius first, then widens until clinics are found.
  Future<List<Map<String, dynamic>>> _findClinics(Position pos) async {
  final all = <Map<String, dynamic>>[];

  // 1. Your known clinics within 50 km of the user.
  for (final c in _localClinics) {
    final km = Geolocator.distanceBetween(
          pos.latitude,
          pos.longitude,
          c['lat'] as double,
          c['lng'] as double,
        ) /
        1000;
    if (km <= 50) all.add(c);
  }

  // 2. Clinics from OpenStreetMap (never crashes the page if it fails).
  try {
    for (final radius in _radii) {
      var found = await _queryOverpass(pos, radius);

      if (found.isEmpty) {
        try {
          found = await _queryNominatim(pos, radius);
        } catch (_) {}
      }

      if (found.isNotEmpty) {
        for (final c in found) {
          if (!_isDuplicate(all, c)) all.add(c);
        }
        break;
      }
    }
  } catch (_) {
    // OpenStreetMap unavailable: local clinics are still shown.
  }

  return all;
}

// True if a clinic with the same name, or within ~150 m, is already listed.
bool _isDuplicate(List<Map<String, dynamic>> list, Map<String, dynamic> c) {
  for (final e in list) {
    final sameName = e['name'].toString().toLowerCase() ==
        c['name'].toString().toLowerCase();
    final meters = Geolocator.distanceBetween(
      e['lat'] as double,
      e['lng'] as double,
      c['lat'] as double,
      c['lng'] as double,
    );
    if (sameName || meters < 150) return true;
  }
  return false;
}

  Future<List<Map<String, dynamic>>> _queryOverpass(
  Position pos,
  int radius,
) {
  final lat = pos.latitude;
  final lng = pos.longitude;

  // Lighter query: one statement instead of three.
  // "nwr" = node + way + relation.
  final query = '''
[out:json][timeout:15];
nwr["amenity"="veterinary"](around:$radius,$lat,$lng);
out center tags;
''';

  final completer = Completer<List<Map<String, dynamic>>>();
  int failed = 0;
  Object? lastError;

  // Ask ALL servers at the same time; the first good answer wins.
  for (final server in _overpassServers) {
    http
        .post(
          Uri.parse(server),
          headers: {'User-Agent': 'SmartFeed/1.0'},
          body: {'data': query},
        )
        .timeout(const Duration(seconds: 15))
        .then((res) {
      if (completer.isCompleted) return;

      if (res.statusCode != 200) {
        throw 'Server returned ${res.statusCode}';
      }

      final elements = (jsonDecode(res.body)['elements'] as List?) ?? [];
      completer.complete(_parseClinics(elements));
    }).catchError((e) {
      lastError = e;
      failed++;
      if (failed == _overpassServers.length && !completer.isCompleted) {
        completer.completeError('Clinic search failed: $lastError');
      }
    });
  }

  return completer.future;
}


/////
Future<List<Map<String, dynamic>>> _queryNominatim(
  Position pos,
  int radius,
) async {
  // Converts the radius (meters) into a bounding box around the user.
  final dLat = radius / 111320.0;
  final dLng = radius / (111320.0 * cos(pos.latitude * pi / 180));

  final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
    'q': 'veterinary',
    'format': 'jsonv2',
    'limit': '40',
    'bounded': '1',
    // left, top, right, bottom
    'viewbox': '${pos.longitude - dLng},${pos.latitude + dLat},'
        '${pos.longitude + dLng},${pos.latitude - dLat}',
    'extratags': '1',
    'addressdetails': '1',
  });

  final res = await http
      .get(uri, headers: {'User-Agent': 'SmartFeed/1.0'})
      .timeout(const Duration(seconds: 15));

  if (res.statusCode != 200) {
    throw 'Nominatim returned ${res.statusCode}';
  }

  final results = jsonDecode(res.body) as List;
  final clinics = <Map<String, dynamic>>[];

  for (final r in results) {
    final lat = double.tryParse(r['lat'].toString());
    final lng = double.tryParse(r['lon'].toString());
    if (lat == null || lng == null) continue;

    final extra = Map<String, dynamic>.from(r['extratags'] ?? {});
    final addr = Map<String, dynamic>.from(r['address'] ?? {});

    final name = (r['name'] ?? '').toString().isNotEmpty
        ? r['name'].toString()
        : 'Veterinary Clinic';

    final address = [
      addr['house_number'],
      addr['road'],
      addr['suburb'],
      addr['city'] ?? addr['town'] ?? addr['village'],
      addr['state'],
    ].where((x) => x != null && x.toString().isNotEmpty).join(', ');

    clinics.add({
      'name': name,
      'address': address.isEmpty ? 'Address not listed' : address,
      'phone': (extra['phone'] ?? extra['contact:phone'] ?? '').toString(),
      'hours': (extra['opening_hours'] ?? 'Hours not listed').toString(),
      'type': 'Veterinary',
      'color': _cardColors[clinics.length % _cardColors.length],
      'lat': lat,
      'lng': lng,
    });
  }

  return clinics;
}
  // Converts raw OpenStreetMap elements into the clinic maps
  // the UI already knows how to display.
  List<Map<String, dynamic>> _parseClinics(List elements) {
    final clinics = <Map<String, dynamic>>[];
    final seen = <String>{};

    for (final e in elements) {
      // Nodes have lat/lon; ways/relations have a "center".
      final lat = (e['lat'] ?? e['center']?['lat'])?.toDouble();
      final lng = (e['lon'] ?? e['center']?['lon'])?.toDouble();
      if (lat == null || lng == null) continue;

      final tags = Map<String, dynamic>.from(e['tags'] ?? {});

      final name = (tags['name'] ?? tags['name:en'] ?? 'Veterinary Clinic')
          .toString();

      // Skip duplicates (same name at almost the same spot).
      final key = '${name.toLowerCase()}_${lat.toStringAsFixed(4)}'
          '_${lng.toStringAsFixed(4)}';
      if (!seen.add(key)) continue;

      // Build a readable address from whatever tags exist.
      final street = [tags['addr:housenumber'], tags['addr:street']]
          .where((x) => x != null && x.toString().isNotEmpty)
          .join(' ');
      final address = [
        street,
        tags['addr:suburb'],
        tags['addr:city'] ?? tags['addr:town'] ?? tags['addr:village'],
        tags['addr:province'] ?? tags['addr:state'],
      ].where((x) => x != null && x.toString().isNotEmpty).join(', ');

      final phone =
          (tags['phone'] ?? tags['contact:phone'] ?? tags['contact:mobile'])
                  ?.toString() ??
              '';

      final hours = tags['opening_hours']?.toString() ?? 'Hours not listed';

      final opType = tags['operator:type']?.toString();
      final type = (opType == null || opType.isEmpty)
          ? 'Veterinary'
          : '${opType[0].toUpperCase()}${opType.substring(1)}';

      clinics.add({
        'name': name,
        'address': address.isEmpty ? 'Address not listed' : address,
        'phone': phone,
        'hours': hours,
        'type': type,
        'color': _cardColors[clinics.length % _cardColors.length],
        'lat': lat,
        'lng': lng,
      });
    }

    return clinics;
  }

  // ============================================================
  // CALCULATE DISTANCE
  // ============================================================

  double _getDistance(Map<String, dynamic> clinic) {
    if (_position == null) return 0.0;

    final double clinicLat = double.parse(clinic['lat'].toString());
    final double clinicLng = double.parse(clinic['lng'].toString());

    final double distanceMeters = Geolocator.distanceBetween(
      _position!.latitude,
      _position!.longitude,
      clinicLat,
      clinicLng,
    );

    return distanceMeters / 1000.0;
  }

  // ============================================================
  // SORT CLINICS BY DISTANCE
  // ============================================================

  List<Map<String, dynamic>> get _sortedClinics {
    if (_position == null) return _clinics;

    final sorted = List<Map<String, dynamic>>.from(_clinics);
    sorted.sort((a, b) => _getDistance(a).compareTo(_getDistance(b)));
    return sorted;
  }

  // ============================================================
  // OPEN GOOGLE MAPS DIRECTIONS
  // ============================================================

  Future<void> _openMaps(Map<String, dynamic> clinic) async {
    final double lat = double.parse(clinic['lat'].toString());
    final double lng = double.parse(clinic['lng'].toString());
    final String clinicName = clinic['name'].toString();

    final Uri url = Uri.https(
      'www.google.com',
      '/maps/dir/',
      {
        'api': '1',
        'destination': '$lat,$lng',
        'travelmode': 'driving',
      },
    );

    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open directions for $clinicName')),
      );
      debugPrint('Google Maps error: $e');
    }
  }

  // ============================================================
  // CALL CLINIC
  // ============================================================

  Future<void> _callClinic(String phone) async {
    final cleaned = phone.replaceAll(RegExp(r'[^\d+]'), '');
    final Uri url = Uri.parse('tel:$cleaned');

    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not make the call')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error making call: $e')),
      );
    }
  }

  // ============================================================
  // NEW: EMPTY STATE
  // ============================================================
  // Shown before the first search, or when no clinics were found.
  Widget _buildEmptyState() {
    final searched = _hasSearched;

    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(32, 0, 32, 100),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.7),
                shape: BoxShape.circle,
              ),
              child: Icon(
                searched
                    ? Icons.search_off_rounded
                    : Icons.location_searching_rounded,
                size: 34,
                color: _Palette.salmon,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              searched ? 'No clinics found nearby' : 'Find clinics near you',
              textAlign: TextAlign.center,
              style: GoogleFonts.fraunces(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: _Palette.brownSoft,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              searched
                  ? 'The map data for this area may be incomplete. '
                      'Try Refresh, or open Google Maps and search '
                      '"veterinary clinic".'
                  : 'Tap "Use GPS" above and SmartFeed will show the '
                      'nearest veterinary clinics in your city.',
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.4,
                color: _Palette.brownSoft.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // BUILD UI
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final clinics = _sortedClinics;

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
            // ---- SOFT BLOBS ----
            Positioned(
              top: -50,
              right: -50,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      _Palette.salmon.withOpacity(0.28),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: -60,
              left: -60,
              child: Container(
                width: 240,
                height: 240,
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

            // ---- GHOST PAWS ----
            Positioned(
              top: 130,
              left: -6,
              child: Transform.rotate(
                angle: -0.4,
                child: Icon(
                  Icons.pets,
                  size: 42,
                  color: Colors.white.withOpacity(0.18),
                ),
              ),
            ),
            Positioned(
              top: 240,
              right: 0,
              child: Transform.rotate(
                angle: 0.5,
                child: Icon(
                  Icons.pets,
                  size: 30,
                  color: Colors.white.withOpacity(0.18),
                ),
              ),
            ),
            Positioned(
              bottom: 120,
              left: 20,
              child: Transform.rotate(
                angle: 0.2,
                child: Icon(
                  Icons.pets,
                  size: 34,
                  color: Colors.white.withOpacity(0.15),
                ),
              ),
            ),

            SafeArea(
              child: Column(
                children: [
                  // ======================================================
                  // HEADER
                  // ======================================================
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
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
                            Icons.health_and_safety_rounded,
                            color: Colors.white,
                            size: 21,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Vet Clinics',
                                style: GoogleFonts.fraunces(
                                  color: _Palette.brownSoft,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.3,
                                  height: 1.1,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                // CHANGED: shows the detected city when known.
                                _city.isNotEmpty
                                    ? 'Near $_city 🐾'
                                    : 'Nearby care for your furry friend 🐾',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
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
                  ),

                  // ======================================================
                  // GPS BANNER
                  // ======================================================
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 13,
                    ),
                    margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
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
                    child: Row(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.22),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _position != null
                                ? Icons.location_on_rounded
                                : Icons.location_searching_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _locationStatus,
                            style: GoogleFonts.dmSans(
                              fontSize: 13.5,
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              height: 1.3,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        _loadingLocation
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
                                  onTap: _getLocation,
                                  borderRadius: BorderRadius.circular(14),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    child: Text(
                                      _position != null ? 'Refresh' : 'Use GPS',
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
                  ),

                  // ======================================================
                  // CLINIC COUNT
                  // ======================================================
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: _Palette.salmon.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.local_hospital_rounded,
                            size: 13,
                            color: _Palette.salmon,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${clinics.length} clinics available',
                          style: GoogleFonts.fraunces(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                            color: _Palette.brownSoft,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const Spacer(),
                        if (_position != null && clinics.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _Palette.leaf.withOpacity(0.18),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.sort_rounded,
                                  size: 11,
                                  color: _Palette.leaf,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'By distance',
                                  style: GoogleFonts.dmSans(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w800,
                                    color: _Palette.leaf,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),

                  // ======================================================
                  // CLINICS LIST
                  // ======================================================
                  Expanded(
                    // CHANGED: shows an empty state when there are no clinics.
                    child: clinics.isEmpty
                        ? _buildEmptyState()
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                            itemCount: clinics.length,
                            itemBuilder: (context, index) {
                              final clinic = clinics[index];
                              final distance = _position != null
                                  ? _getDistance(clinic)
                                  : null;
                              final color = clinic['color'] as Color;
                              final phone = clinic['phone'] as String;
                              final isClosest = distance != null && index == 0;

                              return _ClinicCard(
                                clinic: clinic,
                                color: color,
                                distance: distance,
                                isClosest: isClosest,
                                phone: phone,
                                onCall: () => _callClinic(phone),
                                onDirections: () => _openMaps(clinic),
                              );
                            },
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

// ================================================================
// CLINIC CARD
// ================================================================

class _ClinicCard extends StatelessWidget {
  final Map<String, dynamic> clinic;
  final Color color;
  final double? distance;
  final bool isClosest;
  final String phone;
  final VoidCallback onCall;
  final VoidCallback onDirections;

  const _ClinicCard({
    required this.clinic,
    required this.color,
    required this.distance,
    required this.isClosest,
    required this.phone,
    required this.onCall,
    required this.onDirections,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.96),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isClosest ? color : color.withOpacity(0.28),
          width: isClosest ? 2 : 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.14),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: _Palette.brownSoft.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
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
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [color, color.withOpacity(0.4)],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ========================================
                  // CLINIC HEADER
                  // ========================================
                  Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [color, color.withOpacity(0.7)],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: color.withOpacity(0.35),
                              blurRadius: 12,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.pets,
                          color: Colors.white,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              clinic['name'] as String,
                              style: GoogleFonts.fraunces(
                                fontWeight: FontWeight.w800,
                                fontSize: 15.5,
                                color: _Palette.brown,
                                height: 1.25,
                                letterSpacing: -0.2,
                              ),
                            ),
                            const SizedBox(height: 7),
                            Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                // Type pill
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3.5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: color.withOpacity(0.16),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    clinic['type'] as String,
                                    style: GoogleFonts.dmSans(
                                      fontSize: 10.5,
                                      color: _Palette.brownSoft,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),

                                // Distance pill
                                if (distance != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3.5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _Palette.cream,
                                      borderRadius: BorderRadius.circular(999),
                                      border: Border.all(
                                        color: _Palette.amber.withOpacity(0.4),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.near_me_rounded,
                                          size: 10,
                                          color: _Palette.amber,
                                        ),
                                        const SizedBox(width: 3),
                                        Text(
                                          '${distance?.toStringAsFixed(1)} km',
                                          style: GoogleFonts.dmSans(
                                            fontSize: 10.5,
                                            color: _Palette.brownSoft,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                // Closest pill
                                if (isClosest)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3.5,
                                    ),
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [
                                          _Palette.salmon,
                                          _Palette.peach,
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(999),
                                      boxShadow: [
                                        BoxShadow(
                                          color: _Palette.salmon.withOpacity(0.4),
                                          blurRadius: 8,
                                          offset: const Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.pets,
                                          size: 10,
                                          color: Colors.white,
                                        ),
                                        const SizedBox(width: 3),
                                        Text(
                                          'Closest',
                                          style: GoogleFonts.dmSans(
                                            fontSize: 10.5,
                                            color: Colors.white,
                                            fontWeight: FontWeight.w800,
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

                  const SizedBox(height: 14),

                  // ========================================
                  // INFO ROWS
                  // ========================================
                  _InfoRow(
                    icon: Icons.location_on_rounded,
                    text: clinic['address'] as String,
                    color: color,
                  ),

                  if (phone.isNotEmpty) ...[
                    const SizedBox(height: 7),
                    _InfoRow(
                      icon: Icons.phone_rounded,
                      text: phone,
                      color: color,
                    ),
                  ],

                  const SizedBox(height: 7),
                  _InfoRow(
                    icon: Icons.access_time_rounded,
                    text: clinic['hours'] as String,
                    color: color,
                  ),

                  const SizedBox(height: 16),

                  // ========================================
                  // BUTTONS
                  // ========================================
                  Row(
                    children: [
                      if (phone.isNotEmpty)
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: onCall,
                            icon: Icon(
                              Icons.phone_rounded,
                              size: 16,
                              color: color.darken(0.2),
                            ),
                            label: Text(
                              'Call',
                              style: GoogleFonts.dmSans(
                                fontWeight: FontWeight.w800,
                                color: color.darken(0.2),
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              side: BorderSide(
                                color: color.darken(0.1).withOpacity(0.6),
                                width: 1.4,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ),

                      if (phone.isNotEmpty) const SizedBox(width: 10),

                      Expanded(
                        child: FilledButton.icon(
                          onPressed: onDirections,
                          icon: const Icon(Icons.directions_rounded, size: 16),
                          label: Text(
                            'Directions',
                            style: GoogleFonts.dmSans(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            backgroundColor: color,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
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
    );
  }
}

// ================================================================
// INFO ROW
// ================================================================

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _InfoRow({
    required this.icon,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Icon(icon, size: 12, color: color),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              text,
              style: GoogleFonts.dmSans(
                fontSize: 12.5,
                color: _Palette.brownSoft.withOpacity(0.78),
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ================================================================
// COLOR DARKEN EXTENSION
// ================================================================

extension ColorBrightness on Color {
  Color darken([double amount = .1]) {
    final hsl = HSLColor.fromColor(this);
    final hslDark = hsl.withLightness(
      (hsl.lightness - amount).clamp(0.0, 1.0),
    );
    return hslDark.toColor();
  }
}