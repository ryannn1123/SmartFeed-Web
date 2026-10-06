import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;

class VetClinic {
  final String name;
  final double lat;
  final double lng;
  final double distanceKm;
  final String? address;
  final String? phone;
  final String? openingHours;

  VetClinic({
    required this.name,
    required this.lat,
    required this.lng,
    required this.distanceKm,
    this.address,
    this.phone,
    this.openingHours,
  });
}

class VetService {
  // 1. Gets the current GPS position (handles permissions).
  static Future<Position> getPosition() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw 'Location services are turned off. Please enable GPS.';
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw 'Location permission denied.';
    }
    if (permission == LocationPermission.deniedForever) {
      throw 'Location permission permanently denied. Enable it in Settings.';
    }

    return Geolocator.getCurrentPosition(
  desiredAccuracy: LocationAccuracy.high,
  timeLimit: const Duration(seconds: 15),
);
  }

  // 2. Converts coordinates into a city name (for display only).
  static Future<String> getCityName(double lat, double lng) async {
    try {
      final p = await placemarkFromCoordinates(lat, lng);
      if (p.isEmpty) return 'Your area';
      final m = p.first;
      return [m.locality, m.administrativeArea, m.country]
          .where((e) => e != null && e.isNotEmpty)
          .join(', ');
    } catch (_) {
      return 'Your area';
    }
  }

  // 3. Finds clinics around the position, widening the radius if empty.
  static Future<List<VetClinic>> findClinics(Position pos) async {
    for (final radius in [5000, 10000, 25000, 50000]) {
      final clinics = await _query(pos, radius);
      if (clinics.isNotEmpty) return clinics;
    }
    return [];
  }

  static Future<List<VetClinic>> _query(Position pos, int radius) async {
    final q = '''
[out:json][timeout:25];
(
  node["amenity"="veterinary"](around:$radius,${pos.latitude},${pos.longitude});
  way["amenity"="veterinary"](around:$radius,${pos.latitude},${pos.longitude});
  relation["amenity"="veterinary"](around:$radius,${pos.latitude},${pos.longitude});
);
out center tags;
''';

    final res = await http
        .post(
          Uri.parse('https://overpass-api.de/api/interpreter'),
          body: {'data': q},
        )
        .timeout(const Duration(seconds: 30));

    if (res.statusCode != 200) {
      throw 'Clinic search failed (${res.statusCode}).';
    }

    final elements = jsonDecode(res.body)['elements'] as List;
    final clinics = <VetClinic>[];

    for (final e in elements) {
      // Nodes have lat/lon; ways/relations have a "center".
      final lat = (e['lat'] ?? e['center']?['lat'])?.toDouble();
      final lng = (e['lon'] ?? e['center']?['lon'])?.toDouble();
      if (lat == null || lng == null) continue;

      final tags = (e['tags'] ?? {}) as Map;
      final address = [
        tags['addr:housenumber'],
        tags['addr:street'],
        tags['addr:city'],
      ].where((x) => x != null && x.toString().isNotEmpty).join(' ');

      clinics.add(VetClinic(
        name: tags['name'] ?? 'Veterinary Clinic',
        lat: lat,
        lng: lng,
        distanceKm: Geolocator.distanceBetween(
              pos.latitude, pos.longitude, lat, lng) /
            1000,
        address: address.isEmpty ? null : address,
        phone: tags['phone'] ?? tags['contact:phone'],
        openingHours: tags['opening_hours'],
      ));
    }

    clinics.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
    return clinics;
  }
}