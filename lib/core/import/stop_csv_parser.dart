import 'package:csv/csv.dart';

class StopDraft {
  StopDraft({
    required this.address,
    this.name,
    this.notes,
    this.phone,
    this.parcelCount,
  });

  final String address;
  final String? name;
  final String? notes;
  final String? phone;
  final int? parcelCount;
}

class StopCsvParser {
  /// Parse CSV content into stop drafts.
  ///
  /// Expected header names (case-insensitive, spaces/underscores ignored):
  /// - address (required)
  /// - name (optional)
  /// - notes (optional)
  /// - phone (optional)
  /// - parcelCount / parcel_count (optional)
  ///
  /// If no header row is detected, the first column is treated as address.
  List<StopDraft> parse(String csvContent) {
    final converter = const CsvToListConverter(eol: '\n');
    final rows = converter.convert(csvContent);

    if (rows.isEmpty) return [];

    final firstRow = rows.first.map((e) => (e ?? '').toString()).toList();
    final headerMap = _tryBuildHeaderMap(firstRow);

    final startIndex = headerMap == null ? 0 : 1;
    final drafts = <StopDraft>[];

    for (var i = startIndex; i < rows.length; i++) {
      final row = rows[i].map((e) => (e ?? '').toString()).toList();
      String address = '';

      String? name;
      String? notes;
      String? phone;
      int? parcelCount;

      if (headerMap == null) {
        if (row.isEmpty) continue;
        address = row[0].trim();
      } else {
        address = _getByHeader(row, headerMap, 'address')?.trim() ?? '';
        name = _getByHeader(row, headerMap, 'name')?.trim();
        notes = _getByHeader(row, headerMap, 'notes')?.trim();
        phone = _getByHeader(row, headerMap, 'phone')?.trim();

        final pcStr = _getByHeader(row, headerMap, 'parcelcount')?.trim();
        if (pcStr != null && pcStr.isNotEmpty) {
          final parsed = int.tryParse(pcStr);
          if (parsed != null) parcelCount = parsed;
        }
      }

      if (address.isEmpty) continue;

      drafts.add(StopDraft(
        address: address,
        name: name?.isEmpty == true ? null : name,
        notes: notes?.isEmpty == true ? null : notes,
        phone: phone?.isEmpty == true ? null : phone,
        parcelCount: parcelCount,
      ));
    }

    return drafts;
  }

  Map<String, int>? _tryBuildHeaderMap(List<String> firstRow) {
    final normalized = firstRow.map(_norm).toList();

    if (!normalized.contains('address')) return null;

    final map = <String, int>{};
    for (var i = 0; i < normalized.length; i++) {
      map[normalized[i]] = i;
    }
    return map;
  }

  String? _getByHeader(
      List<String> row, Map<String, int> headerMap, String key) {
    final idx = headerMap[key];
    if (idx == null) return null;
    if (idx < 0 || idx >= row.length) return null;
    return row[idx];
  }

  String _norm(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'[_\s-]+'), '').trim();
}
