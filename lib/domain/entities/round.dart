import 'stop.dart';

class Round {
  Round({
    required this.id,
    required this.title,
    required this.stops,
    DateTime? createdAt,
    this.startLat,
    this.startLng,
  }) : createdAt = createdAt ?? DateTime.now();

  final String id;
  final String title;
  final DateTime createdAt;

  final double? startLat;
  final double? startLng;

  final List<Stop> stops;

  List<Stop> get stopsSorted =>
      [...stops]..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));

  List<Stop> get remainingStopsSorted =>
      stopsSorted.where((s) => !s.isDelivered).toList();

  Stop? get nextStop {
    final remaining = remainingStopsSorted;
    if (remaining.isEmpty) return null;
    return remaining.first;
  }

  Round copyWith({
    String? id,
    String? title,
    DateTime? createdAt,
    double? startLat,
    double? startLng,
    List<Stop>? stops,
  }) {
    return Round(
      id: id ?? this.id,
      title: title ?? this.title,
      createdAt: createdAt ?? this.createdAt,
      startLat: startLat ?? this.startLat,
      startLng: startLng ?? this.startLng,
      stops: stops ?? this.stops,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'createdAt': createdAt.toIso8601String(),
        'startLat': startLat,
        'startLng': startLng,
        'stops': stops.map((s) => s.toJson()).toList(),
      };

  static Round fromJson(Map<dynamic, dynamic> json) {
    final stopsJson = (json['stops'] as List<dynamic>? ?? const []);
    return Round(
      id: json['id'] as String,
      title: json['title'] as String? ?? 'Untitled round',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      startLat: (json['startLat'] as num?)?.toDouble(),
      startLng: (json['startLng'] as num?)?.toDouble(),
      stops: stopsJson.whereType<Map>().map((m) => Stop.fromJson(m)).toList(),
    );
  }
}
