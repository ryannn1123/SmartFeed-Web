import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

// =========================
// SHARED PALETTE
// (matches servo_page.dart / schedule_page.dart / history_page.dart)
// =========================

class _Palette {
  static const Color salmon = Color(0xFFFA7268);
  static const Color peach = Color(0xFFFF9E89);
  static const Color cream = Color(0xFFFFEFC4);
  static const Color brown = Color(0xFF5B3A29);
  static const Color brownSoft = Color(0xFF7A3E2A);
  static const Color amber = Color(0xFFE0A438);
}

class VetPage extends StatefulWidget {
  const VetPage({super.key});

  @override
  State<VetPage> createState() => _VetPageState();
}

class _VetPageState extends State<VetPage> {
  Position? _position;
  bool _loadingLocation = false;

  String _locationStatus =
      'Tap "Use GPS" to find nearest clinics';

  // ============================================================
  // VETERINARY CLINICS
  // Coordinates verified against Google Maps listings for
  // accurate nearest-clinic sorting.
  // ============================================================

  static const List<Map<String, dynamic>> _clinics = [
    {
      'name': 'Cebu Northside Veterinary Clinic',
      'address':
          'Door 4, Brgy, Bogo MGF Franz Bldg, Gairan, Bogo City, 6010 Cebu',
      'phone': '09674592737',
      'hours': 'Mon-Sat: 9AM - 6PM',
      'type': 'Private',
      'color': _Palette.salmon,

      // Verified coordinate (Google Maps listing)
      'lat': 11.0524383,
      'lng': 124.0116599,
    },

    {
      'name': 'David Shepherd Veterinary Services',
      'address':
          'A.Mansueto St, Lourdes, Bogo City, 6010 Cebu',
      'phone': '09661456014',
      'hours': 'Mon-Sat: 9AM - 6PM',
      'type': 'Private',
      'color': _Palette.peach,

      // Verified coordinate (Google Maps listing)
      'lat': 11.0503442,
      'lng': 124.0065866,
    },

    {
      'name': 'Bogo Claws and Paws Animal Clinic',
      'address':
          '3225+M7X, Bogo City, Cebu',
      'phone': '(032) 406 0505',
      'hours': 'Daily: 8AM - 8PM',
      'type': 'Private',
      'color': _Palette.amber,

      // Verified coordinate (Google Maps listing)
      'lat': 11.0517469,
      'lng': 124.00823,
    },

  ];

  // ============================================================
  // GET USER LOCATION
  // ============================================================

  Future<void> _getLocation() async {
    setState(() {
      _loadingLocation = true;
      _locationStatus = 'Getting your location...';
    });

    try {
      // Check whether location service is enabled
      bool serviceEnabled =
          await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        setState(() {
          _locationStatus =
              'Please turn on Location/GPS on your phone';
          _loadingLocation = false;
        });
        return;
      }

      // Check permission
      LocationPermission permission =
          await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission =
            await Geolocator.requestPermission();

        if (permission == LocationPermission.denied) {
          setState(() {
            _locationStatus =
                'Location permission denied';
            _loadingLocation = false;
          });
          return;
        }
      }

      if (permission ==
          LocationPermission.deniedForever) {
        setState(() {
          _locationStatus =
              'Enable location permission in phone settings';
          _loadingLocation = false;
        });
        return;
      }

      // Get current position
      final position =
          await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _position = position;
        _locationStatus =
            'Showing nearest clinics first';
        _loadingLocation = false;
      });
    } catch (e) {
      setState(() {
        _locationStatus =
            'Could not get your location';
        _loadingLocation = false;
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Location error: $e',
          ),
        ),
      );
    }
  }

  // ============================================================
  // CALCULATE DISTANCE
  // ============================================================

  double _getDistance(Map<String, dynamic> clinic) {
  if (_position == null) {
    return 0.0;
  }

  final double clinicLat =
      double.parse(clinic['lat'].toString());

  final double clinicLng =
      double.parse(clinic['lng'].toString());

  final double distanceMeters =
      Geolocator.distanceBetween(
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

  List<Map<String, dynamic>>
      get _sortedClinics {
    if (_position == null) {
      return _clinics;
    }

    final sorted =
        List<Map<String, dynamic>>.from(
      _clinics,
    );

    sorted.sort(
      (a, b) =>
          _getDistance(a).compareTo(
        _getDistance(b),
      ),
    );

    return sorted;
  }

  // ============================================================
  // OPEN GOOGLE MAPS DIRECTIONS
  // ============================================================

  Future<void> _openMaps(Map<String, dynamic> clinic) async {
  final double lat =
      double.parse(clinic['lat'].toString());

  final double lng =
      double.parse(clinic['lng'].toString());

  final String clinicName =
      clinic['name'].toString();

  // Google Maps Directions URL
  //
  // The user's current location will be used
  // as the starting point.
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
    await launchUrl(
      url,
      mode: LaunchMode.externalApplication,
    );
  } catch (e) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Could not open directions for $clinicName',
        ),
      ),
    );

    debugPrint('Google Maps error: $e');
  }
}

  // ============================================================
  // CALL CLINIC
  // ============================================================

  Future<void> _callClinic(
      String phone) async {
    final cleaned =
        phone.replaceAll(
      RegExp(r'[^\d+]'),
      '',
    );

    final Uri url =
        Uri.parse('tel:$cleaned');

    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url);
      } else {
        if (!mounted) return;

        ScaffoldMessenger.of(context)
            .showSnackBar(
          const SnackBar(
            content:
                Text('Could not make the call'),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content:
              Text('Error making call: $e'),
        ),
      );
    }
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
        child: SafeArea(
          child: Column(
            children: [

              // ======================================================
              // HEADER
              // ======================================================

              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
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
                        Icons.health_and_safety_rounded,
                        color: Colors.white,
                        size: 17,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Vet Clinics',
                      style: GoogleFonts.fraunces(
                        color: _Palette.brownSoft,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),

              // ======================================================
              // GPS BANNER
              // ======================================================

              Container(
                padding:
                    const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),

                margin:
                    const EdgeInsets.all(16),

                decoration:
                    BoxDecoration(
                  gradient:
                      const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      _Palette.salmon,
                      _Palette.peach,
                    ],
                  ),

                  borderRadius:
                      BorderRadius.circular(20),

                  boxShadow: [
                    BoxShadow(
                      color: _Palette.salmon.withOpacity(0.35),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),

                child: Row(
                  children: [

                    Icon(
                      _position != null
                          ? Icons.location_on
                          : Icons.location_searching,

                      color: Colors.white,
                      size: 20,
                    ),

                    const SizedBox(width: 8),

                    Expanded(
                      child: Text(
                        _locationStatus,

                        style:
                            GoogleFonts.dmSans(
                          fontSize: 14,
                          color: Colors.white,
                          fontWeight:
                              FontWeight.w600,
                        ),
                      ),
                    ),

                    _loadingLocation
                        ? const SizedBox(
                            width: 20,
                            height: 20,

                            child:
                                CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )

                        : TextButton(
                            onPressed:
                                _getLocation,

                            child: Text(
                              _position != null
                                  ? 'Refresh'
                                  : 'Use GPS',

                              style:
                                  GoogleFonts.dmSans(
                                color: Colors.white,
                                fontWeight:
                                    FontWeight.w700,
                              ),
                            ),
                          ),
                  ],
                ),
              ),

              // ======================================================
              // CLINICS LIST
              // ======================================================

              Expanded(
                child:
                    ListView.builder(
                  padding:
                      const EdgeInsets.fromLTRB(
                    16,
                    0,
                    16,
                    100,
                  ),

                  itemCount:
                      clinics.length,

                  itemBuilder:
                      (context, index) {

                    final clinic =
                        clinics[index];

                    final distance =
                        _position != null
                            ? _getDistance(
                                clinic)
                            : null;

                    final color =
                        clinic['color']
                            as Color;

                    final phone =
                        clinic['phone']
                            as String;

                    final isClosest =
                        distance != null && index == 0;

                    return Container(
                      margin:
                          const EdgeInsets.only(
                        bottom: 16,
                      ),

                      decoration:
                          BoxDecoration(
                        color: Colors.white.withOpacity(0.94),

                        borderRadius:
                            BorderRadius.circular(
                          22,
                        ),

                        border:
                            Border.all(
                          color: isClosest
                              ? color
                              : color
                                  .withOpacity(0.4),
                          width: isClosest ? 2 : 1,
                        ),

                        boxShadow: [
                          BoxShadow(
                            color: _Palette.brownSoft
                                .withOpacity(
                              0.1,
                            ),

                            blurRadius: 16,

                            offset:
                                const Offset(
                              0,
                              6,
                            ),
                          ),
                        ],
                      ),

                      child: Padding(
                        padding:
                            const EdgeInsets.all(
                          16,
                        ),

                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment
                                  .start,

                          children: [

                            // ========================================
                            // CLINIC HEADER
                            // ========================================

                            Row(
                              children: [

                                Container(
                                  width: 48,
                                  height: 48,

                                  decoration:
                                      BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        color,
                                        color.withOpacity(0.7),
                                      ],
                                    ),

                                    borderRadius:
                                        BorderRadius
                                            .circular(
                                      14,
                                    ),
                                  ),

                                  child: const Icon(
                                    Icons
                                        .pets,

                                    color: Colors.white,

                                    size: 24,
                                  ),
                                ),

                                const SizedBox(
                                  width: 12,
                                ),

                                Expanded(
                                  child:
                                      Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment
                                            .start,

                                    children: [

                                      Text(
                                        clinic['name']
                                            as String,

                                        style:
                                            GoogleFonts.fraunces(
                                          fontWeight:
                                              FontWeight
                                                  .w700,

                                          fontSize:
                                              15,

                                          color: _Palette.brown,
                                        ),
                                      ),

                                      const SizedBox(
                                        height: 6,
                                      ),

                                      Wrap(
                                        crossAxisAlignment: WrapCrossAlignment.center,
                                        spacing: 6,
                                        runSpacing: 4,
                                        children: [

                                          Container(
                                            padding:
                                                const EdgeInsets
                                                    .symmetric(
                                              horizontal:
                                                  8,
                                              vertical:
                                                  3,
                                            ),

                                            decoration:
                                                BoxDecoration(
                                              color: color
                                                  .withOpacity(
                                                0.18,
                                              ),

                                              borderRadius:
                                                  BorderRadius
                                                      .circular(
                                                8,
                                              ),
                                            ),

                                            child:
                                                Text(
                                              clinic['type']
                                                  as String,

                                              style:
                                                  GoogleFonts.dmSans(
                                                fontSize:
                                                    11,

                                                color:
                                                    _Palette.brownSoft,

                                                fontWeight:
                                                    FontWeight
                                                        .w600,
                                              ),
                                            ),
                                          ),

                                          if (distance !=
                                              null)
                                            Container(
                                              padding:
                                                  const EdgeInsets
                                                      .symmetric(
                                                horizontal:
                                                    8,
                                                vertical:
                                                    3,
                                              ),

                                              decoration:
                                                  BoxDecoration(
                                                color: _Palette.cream,

                                                borderRadius:
                                                    BorderRadius
                                                        .circular(
                                                  8,
                                                ),
                                              ),

                                              child:
                                                  Text(
                                                '${distance.toStringAsFixed(1)} km',

                                                style:
                                                    GoogleFonts.dmSans(
                                                  fontSize:
                                                      11,

                                                  color: _Palette.brownSoft,

                                                  fontWeight:
                                                      FontWeight
                                                          .w600,
                                                ),
                                              ),
                                            ),

                                          if (isClosest)
                                            Container(
                                              padding:
                                                  const EdgeInsets
                                                      .symmetric(
                                                horizontal: 8,
                                                vertical: 3,
                                              ),
                                              decoration: BoxDecoration(
                                                gradient: const LinearGradient(
                                                  colors: [_Palette.salmon, _Palette.peach],
                                                ),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Icon(Icons.pets, size: 10, color: Colors.white),
                                                  const SizedBox(width: 3),
                                                  Text(
                                                    'Closest',
                                                    style: GoogleFonts.dmSans(
                                                      fontSize: 11,
                                                      color: Colors.white,
                                                      fontWeight: FontWeight.w700,
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

                            const SizedBox(
                              height: 14,
                            ),

                            // ========================================
                            // ADDRESS
                            // ========================================

                            Row(
                              crossAxisAlignment:
                                  CrossAxisAlignment
                                      .start,

                              children: [

                                Icon(
                                  Icons
                                      .location_on,

                                  size: 16,

                                  color:
                                      _Palette.brownSoft.withOpacity(0.55),
                                ),

                                const SizedBox(
                                  width: 6,
                                ),

                                Expanded(
                                  child: Text(
                                    clinic['address']
                                        as String,

                                    style:
                                        GoogleFonts.dmSans(
                                      fontSize:
                                          13,

                                      color:
                                          _Palette.brownSoft.withOpacity(0.75),
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(
                              height: 6,
                            ),

                            // ========================================
                            // PHONE
                            // ========================================

                            if (phone.isNotEmpty) ...[
                              Row(
                                children: [

                                  Icon(
                                    Icons.phone,

                                    size: 16,

                                    color:
                                        _Palette.brownSoft.withOpacity(0.55),
                                  ),

                                  const SizedBox(
                                    width: 6,
                                  ),

                                  Text(
                                    phone,

                                    style:
                                        GoogleFonts.dmSans(
                                      fontSize:
                                          13,

                                      color:
                                          _Palette.brownSoft.withOpacity(0.75),
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(
                                height: 6,
                              ),
                            ],

                            // ========================================
                            // HOURS
                            // ========================================

                            Row(
                              children: [

                                Icon(
                                  Icons.access_time,

                                  size: 16,

                                  color:
                                      _Palette.brownSoft.withOpacity(0.55),
                                ),

                                const SizedBox(
                                  width: 6,
                                ),

                                Text(
                                  clinic['hours']
                                      as String,

                                  style:
                                      GoogleFonts.dmSans(
                                    fontSize:
                                        13,

                                    color:
                                        _Palette.brownSoft.withOpacity(0.75),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(
                              height: 16,
                            ),

                            // ========================================
                            // BUTTONS
                            // ========================================

                            Row(
                              children: [

                                // CALL BUTTON
                                if (phone.isNotEmpty)
                                  Expanded(
                                    child:
                                        OutlinedButton
                                            .icon(
                                      onPressed:
                                          () =>
                                              _callClinic(
                                        phone,
                                      ),

                                      icon:
                                          Icon(
                                        Icons.phone,

                                        size:
                                            16,

                                        color:
                                            color.darken(
                                          0.2,
                                        ),
                                      ),

                                      label:
                                          Text(
                                        'Call',

                                        style:
                                            GoogleFonts.dmSans(
                                          fontWeight: FontWeight.w700,
                                          color:
                                              color.darken(
                                            0.2,
                                          ),
                                        ),
                                      ),

                                      style:
                                          OutlinedButton
                                              .styleFrom(
                                        side:
                                            BorderSide(
                                          color:
                                              color.darken(
                                            0.1,
                                          ),
                                        ),

                                        shape:
                                            RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius
                                                  .circular(
                                            14,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),

                                if (phone.isNotEmpty)
                                  const SizedBox(
                                    width: 10,
                                  ),

                                // DIRECTIONS BUTTON
                                Expanded(
                                  child:
                                      FilledButton
                                          .icon(
                                    onPressed:
                                        () =>
                                            _openMaps(
                                      clinic,
                                    ),

                                    icon:
                                        const Icon(
                                      Icons.directions,
                                      size: 16,
                                    ),

                                    label:
                                        Text(
                                      'Directions',
                                      style: GoogleFonts.dmSans(fontWeight: FontWeight.w700),
                                    ),

                                    style:
                                        FilledButton
                                            .styleFrom(
                                      backgroundColor:
                                          color,

                                      foregroundColor:
                                          Colors.white,

                                      shape:
                                          RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius
                                                .circular(
                                          14,
                                        ),
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
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ================================================================
// COLOR DARKEN EXTENSION
// ================================================================

extension ColorBrightness on Color {
  Color darken([
    double amount = .1,
  ]) {
    final hsl =
        HSLColor.fromColor(this);

    final hslDark =
        hsl.withLightness(
      (hsl.lightness - amount)
          .clamp(0.0, 1.0),
    );

    return hslDark.toColor();
  }
}