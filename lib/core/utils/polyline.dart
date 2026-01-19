import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Decodes a Google encoded polyline string into a list of LatLng points.
List<LatLng> decodePolyline(String encoded) {
  final List<LatLng> points = [];
  int index = 0;
  int lat = 0;
  int lng = 0;

  while (index < encoded.length) {
    final resultLat = _decodeChunk(encoded, index);
    index = resultLat.nextIndex;
    lat += resultLat.value;

    final resultLng = _decodeChunk(encoded, index);
    index = resultLng.nextIndex;
    lng += resultLng.value;

    points.add(LatLng(lat / 1e5, lng / 1e5));
  }

  return points;
}

class _ChunkResult {
  _ChunkResult(this.value, this.nextIndex);
  final int value;
  final int nextIndex;
}

_ChunkResult _decodeChunk(String encoded, int startIndex) {
  int result = 0;
  int shift = 0;
  int index = startIndex;

  while (true) {
    final b = encoded.codeUnitAt(index++) - 63;
    result |= (b & 0x1f) << shift;
    shift += 5;
    if (b < 0x20) break;
  }

  final delta = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
  return _ChunkResult(delta, index);
}
