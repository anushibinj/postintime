import 'package:flutter_test/flutter_test.dart';
import 'package:postintime/logic/bulk_publish_interval.dart';

void main() {
  group('bulk publish interval', () {
    test('snaps to 5 minute steps between 5 and 30', () {
      expect(normalizeInterval(5), 5);
      expect(normalizeInterval(12), 10);
      expect(normalizeInterval(13), 15);
      expect(normalizeInterval(0), 5);
      expect(normalizeInterval(45), 30);
      expect(normalizeInterval(double.nan), 5);
    });

    test('labels every slider step', () {
      expect(intervalMarks().keys.toList(), [5, 10, 15, 20, 25, 30]);
      expect(intervalMarks()[15], '15m');
    });
  });
}
