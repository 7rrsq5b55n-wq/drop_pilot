import 'package:flutter_test/flutter_test.dart';

import 'package:ecoroute_driver/core/import/stop_csv_parser.dart';

void main() {
  test('StopCsvParser parses header-based CSV', () {
    const csv = 'address,name,notes\n'
        '10 Downing St,PM,leave at door\n'
        '221B Baker St,Sherlock,ring bell\n';

    final parser = StopCsvParser();
    final drafts = parser.parse(csv);

    expect(drafts.length, 2);
    expect(drafts[0].address.contains('Downing'), true);
    expect(drafts[0].name, 'PM');
    expect(drafts[1].name, 'Sherlock');
  });

  test('StopCsvParser parses no-header CSV (first column as address)', () {
    const csv = '10 Downing St\n221B Baker St\n';
    final parser = StopCsvParser();
    final drafts = parser.parse(csv);

    expect(drafts.length, 2);
    expect(drafts[0].address.contains('Downing'), true);
  });
}
