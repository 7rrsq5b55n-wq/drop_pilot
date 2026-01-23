import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../core/env.dart';
import '../../core/utils/polyline.dart';
import '../../presentation/models/app_settings.dart';

class GeocodeResult {
  GeocodeResult({
    required this.lat,
    required this.lng,
    required this.formattedAddress,
  });

  final double lat;
  final double lng;
  final String formattedAddress;
}

class RouteResult {
  RouteResult({
    required this.polylinePoints,
    required this.totalDistanceMeters,
    required this.totalDurationSeconds,
    this.totalDurationInTrafficSeconds,
  });

  final List<LatLng> polylinePoints;
  final int totalDistanceMeters;
  final int totalDurationSeconds;
  final int? totalDurationInTrafficSeconds;
}

class GoogleMapsApi {
  GoogleMapsApi(this._client);

  final http.Client _client;

  static const _geocodeBase =
      'https://maps.googleapis.com/maps/api/geocode/json';
  static const _directionsBase =
      'https://maps.googleapis.com/maps/api/directions/json';

  String get _key => Env.googleMapsApiKey.trim();

  void _validateLatLng(LatLng p, {required String label}) {
    if (p.latitude.isNaN || p.longitude.isNaN) {
      throw Exception('Invalid coordinates ($label): NaN');
    }
    if (p.latitude < -90 ||
        p.latitude > 90 ||
        p.longitude < -180 ||
        p.longitude > 180) {
      throw Exception(
          'Invalid coordinates ($label): ${p.latitude},${p.longitude}');
    }
    // Common bad default that causes ZERO_RESULTS downstream
    if (p.latitude == 0.0 && p.longitude == 0.0) {
      throw Exception(
          'Invalid coordinates ($label): 0,0 (likely not geocoded yet)');
    }
  }

  Future<GeocodeResult> geocodeAddress(String address) async {
    if (!Env.hasGoogleMapsApiKey) {
      throw Exception(
        'Missing GOOGLE_MAPS_API_KEY dart-define (used for Geocoding/Directions).',
      );
    }

    final uri = Uri.parse(_geocodeBase).replace(queryParameters: {
      'address': address,
      'key': _key,
    });

    final resp = await _client.get(uri);
    if (resp.statusCode != 200) {
      throw Exception('Geocoding failed (${resp.statusCode}).');
    }

    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final status = data['status'] as String?;
    if (status != 'OK') {
      final err = data['error_message'] as String?;
      throw Exception(
          'Geocoding error: $status${err != null ? ' - $err' : ''}');
    }

    final results = (data['results'] as List<dynamic>);
    if (results.isEmpty) throw Exception('No geocoding results.');
    final first = results.first as Map<String, dynamic>;
    final formatted = first['formatted_address'] as String? ?? address;
    final location = ((first['geometry'] as Map<String, dynamic>)['location']
        as Map<String, dynamic>);
    final lat = (location['lat'] as num).toDouble();
    final lng = (location['lng'] as num).toDouble();

    return GeocodeResult(lat: lat, lng: lng, formattedAddress: formatted);
  }

  /// Build a multi-stop route with chunking to avoid waypoint limits.
  ///
  /// - origin: current location or depot
  /// - stopsInOrder: remaining stops (not delivered), already ordered
  Future<RouteResult> buildMultiStopRoute({
    required LatLng origin,
    required List<LatLng> stopsInOrder,
    required AppSettings settings,
  }) async {
    if (stopsInOrder.isEmpty) {
      return RouteResult(
        polylinePoints: const [],
        totalDistanceMeters: 0,
        totalDurationSeconds: 0,
      );
    }

    _validateLatLng(origin, label: 'origin');
    for (var i = 0; i < stopsInOrder.length; i++) {
      _validateLatLng(stopsInOrder[i], label: 'stop[$i]');
    }

    // Conservative chunk size: 20 intermediate waypoints.
    const maxIntermediateWaypoints = 20;

    final segments = <List<LatLng>>[];
    var cursor = 0;
    while (cursor < stopsInOrder.length) {
      final remaining = stopsInOrder.length - cursor;
      if (remaining <= maxIntermediateWaypoints + 1) {
        segments.add(stopsInOrder.sublist(cursor));
        break;
      }
      final endIndex = cursor + maxIntermediateWaypoints + 1;
      segments.add(stopsInOrder.sublist(cursor, endIndex));
      cursor = endIndex;
    }

    var segmentOrigin = origin;

    final allPolylinePoints = <LatLng>[];
    var distanceTotal = 0;
    var durationTotal = 0;
    int? durationTrafficTotal;

    for (final segmentStops in segments) {
      final destination = segmentStops.last;
      final intermediates = segmentStops.length > 1
          ? segmentStops.sublist(0, segmentStops.length - 1)
          : <LatLng>[];

      final segmentResult = await _directions(
        origin: segmentOrigin,
        destination: destination,
        intermediates: intermediates,
        settings: settings,
      );

      distanceTotal += segmentResult.totalDistanceMeters;
      durationTotal += segmentResult.totalDurationSeconds;
      if (segmentResult.totalDurationInTrafficSeconds != null) {
        durationTrafficTotal ??= 0;
        durationTrafficTotal = durationTrafficTotal! +
            segmentResult.totalDurationInTrafficSeconds!;
      }

      if (allPolylinePoints.isEmpty) {
        allPolylinePoints.addAll(segmentResult.polylinePoints);
      } else {
        final toAdd = segmentResult.polylinePoints;
        if (toAdd.isNotEmpty) {
          allPolylinePoints.addAll(toAdd.skip(1)); // de-dupe join point
        }
      }

      segmentOrigin = destination;
    }

    return RouteResult(
      polylinePoints: allPolylinePoints,
      totalDistanceMeters: distanceTotal,
      totalDurationSeconds: durationTotal,
      totalDurationInTrafficSeconds: durationTrafficTotal,
    );
  }

  Future<RouteResult> _directions({
    required LatLng origin,
    required LatLng destination,
    required List<LatLng> intermediates,
    required AppSettings settings,
  }) async {
    if (!Env.hasGoogleMapsApiKey) {
      throw Exception(
        'Missing GOOGLE_MAPS_API_KEY dart-define (used for Directions).',
      );
    }

    _validateLatLng(origin, label: 'origin');
    _validateLatLng(destination, label: 'destination');

    final avoid = <String>[];
    if (settings.avoidTolls) avoid.add('tolls');
    if (settings.avoidHighways) avoid.add('highways');

    final waypoints = intermediates.isEmpty
        ? null
        : intermediates.map((p) => '${p.latitude},${p.longitude}').join('|');

    final query = <String, String>{
      'origin': '${origin.latitude},${origin.longitude}',
      'destination': '${destination.latitude},${destination.longitude}',
      'mode': 'driving',
      'departure_time': 'now',
      'traffic_model': 'best_guess',
      'key': _key,
    };

    if (avoid.isNotEmpty) query['avoid'] = avoid.join('|');
    if (waypoints != null) query['waypoints'] = waypoints;

    final uri = Uri.parse(_directionsBase).replace(queryParameters: query);

    final resp = await _client.get(uri);
    if (resp.statusCode != 200) {
      throw Exception('Directions failed (${resp.statusCode}).');
    }

    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final status = data['status'] as String?;

    if (status != 'OK') {
      final err = data['error_message'] as String?;
      final coords =
          'origin=${origin.latitude},${origin.longitude} dest=${destination.latitude},${destination.longitude}';
      throw Exception(
        'Directions error: $status${err != null ? ' - $err' : ''} ($coords)',
      );
    }

    final routes = (data['routes'] as List<dynamic>);
    if (routes.isEmpty) throw Exception('No directions routes.');

    final route0 = routes.first as Map<String, dynamic>;
    final overview = route0['overview_polyline'] as Map<String, dynamic>?;
    final pointsStr = overview?['points'] as String?;
    final polyPoints =
        (pointsStr == null) ? <LatLng>[] : decodePolyline(pointsStr);

    final legs = (route0['legs'] as List<dynamic>? ?? const []);
    var distance = 0;
    var duration = 0;
    int? durationTraffic;

    for (final legAny in legs) {
      final leg = legAny as Map<String, dynamic>;
      distance +=
          ((leg['distance'] as Map<String, dynamic>)['value'] as num).toInt();
      duration +=
          ((leg['duration'] as Map<String, dynamic>)['value'] as num).toInt();

      final dit = leg['duration_in_traffic'];
      if (dit is Map<String, dynamic> && dit['value'] != null) {
        durationTraffic ??= 0;
        durationTraffic = durationTraffic! + (dit['value'] as num).toInt();
      }
    }

    return RouteResult(
      polylinePoints: polyPoints,
      totalDistanceMeters: distance,
      totalDurationSeconds: duration,
      totalDurationInTrafficSeconds: durationTraffic,
    );
  }
}
