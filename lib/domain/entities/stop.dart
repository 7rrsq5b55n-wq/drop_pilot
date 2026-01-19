enum StopStatus { pending, delivered, failed, skipped }

class Stop {
  Stop({
    required this.id,
    required this.address,
    required this.lat,
    required this.lng,
    required this.orderIndex,
    this.name,
    this.notes,
    this.phone,
    this.parcelCount,
    this.status = StopStatus.pending,
    DateTime? createdAt,
    this.statusUpdatedAt,
  }) : createdAt = createdAt ?? DateTime.now();

  final String id;
  final String address;
  final String? name;
  final String? notes;
  final String? phone;
  final int? parcelCount;

  final double lat;
  final double lng;

  /// Planned sequence (0..n-1).
  final int orderIndex;

  final StopStatus status;
  final DateTime createdAt;
  final DateTime? statusUpdatedAt;

  bool get isDelivered => status == StopStatus.delivered;

  Stop copyWith({
    String? id,
    String? address,
    String? name,
    String? notes,
    String? phone,
    int? parcelCount,
    double? lat,
    double? lng,
    int? orderIndex,
    StopStatus? status,
    DateTime? createdAt,
    DateTime? statusUpdatedAt,
  }) {
    return Stop(
      id: id ?? this.id,
      address: address ?? this.address,
      name: name ?? this.name,
      notes: notes ?? this.notes,
      phone: phone ?? this.phone,
      parcelCount: parcelCount ?? this.parcelCount,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      orderIndex: orderIndex ?? this.orderIndex,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      statusUpdatedAt: statusUpdatedAt ?? this.statusUpdatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'address': address,
        'name': name,
        'notes': notes,
        'phone': phone,
        'parcelCount': parcelCount,
        'lat': lat,
        'lng': lng,
        'orderIndex': orderIndex,
        'status': status.name,
        'createdAt': createdAt.toIso8601String(),
        'statusUpdatedAt': statusUpdatedAt?.toIso8601String(),
      };

  static Stop fromJson(Map<dynamic, dynamic> json) {
    final statusStr = (json['status'] as String?) ?? StopStatus.pending.name;
    final status = StopStatus.values.firstWhere(
      (e) => e.name == statusStr,
      orElse: () => StopStatus.pending,
    );

    return Stop(
      id: json['id'] as String,
      address: json['address'] as String,
      name: json['name'] as String?,
      notes: json['notes'] as String?,
      phone: json['phone'] as String?,
      parcelCount: json['parcelCount'] as int?,
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      orderIndex: (json['orderIndex'] as num).toInt(),
      status: status,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      statusUpdatedAt: (json['statusUpdatedAt'] is String)
          ? DateTime.tryParse(json['statusUpdatedAt'] as String)
          : null,
    );
  }
}
