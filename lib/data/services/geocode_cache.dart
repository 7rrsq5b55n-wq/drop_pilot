import 'package:hive/hive.dart';

import '../local/hive_boxes.dart';

class CachedGeocode {
  CachedGeocode({
    required this.lat,
    required this.lng,
    required this.formattedAddress,
    required this.updatedAt,
  });

  final double lat;
  final double lng;
  final String formattedAddress;
  final DateTime updatedAt;

  Map<String, dynamic> toJson() => {
        'lat': lat,
        'lng': lng,
        'formattedAddress': formattedAddress,
        'updatedAt': updatedAt.toIso8601String(),
      };

  static CachedGeocode? fromJson(Map<dynamic, dynamic> json) {
    final dt = DateTime.tryParse(json['updatedAt'] as String? ?? '');
    final lat = json['lat'];
    final lng = json['lng'];
    final formatted = json['formattedAddress'];

    if (dt == null || lat == null || lng == null || formatted == null) {
      return null;
    }
    return CachedGeocode(
      lat: (lat as num).toDouble(),
      lng: (lng as num).toDouble(),
      formattedAddress: formatted as String,
      updatedAt: dt,
    );
  }
}

class GeocodeCache {
  Box get _box => Hive.box(HiveBoxes.geocodeCache);

  /// Change this if you want a different cache lifetime.
  final Duration ttl = const Duration(days: 30);

  String _keyFor(String address) {
    final normalized =
        address.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    return normalized;
  }

  Future<CachedGeocode?> get(String address) async {
    final key = _keyFor(address);
    final raw = _box.get(key);
    if (raw is! Map) return null;

    final cached = CachedGeocode.fromJson(raw);
    if (cached == null) return null;

    if (DateTime.now().difference(cached.updatedAt) > ttl) {
      await _box.delete(key);
      return null;
    }
    return cached;
  }

  Future<void> set({
    required String address,
    required double lat,
    required double lng,
    required String formattedAddress,
  }) async {
    final key = _keyFor(address);
    final value = CachedGeocode(
      lat: lat,
      lng: lng,
      formattedAddress: formattedAddress,
      updatedAt: DateTime.now(),
    ).toJson();
    await _box.put(key, value);
  }
}
