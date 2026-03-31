import 'package:devtools_app/src/screens/network/utils/http_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('formatBytes', () {
    // Verifies correct formatting across different unit ranges.
    test('formats bytes correctly', () {
      expect(formatBytes(512), '512 B'); // bytes
      expect(formatBytes(2000), '2.0 kB'); // kilobytes (base-10)
      expect(formatBytes(1000000), '1.0 MB'); // megabytes (base-10)
    });

    // Ensures handling of invalid or missing values.
    test('handles null and negative values', () {
      expect(formatBytes(null), '-');
      expect(formatBytes(-1), '-');
    });
  });
}
