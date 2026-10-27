import 'package:flutter_test/flutter_test.dart';
import 'package:postintime/logic/post_list_params.dart';

void main() {
  group('postListParams', () {
    test('defaults invalid page values to zero', () {
      expect(parsePageParam(null), 0);
      expect(parsePageParam('-1'), 0);
      expect(parsePageParam('abc'), 0);
      expect(parsePageParam('2'), 2);
    });

    test('defaults invalid size values to the fallback', () {
      expect(parseSizeParam(null), 20);
      expect(parseSizeParam('0'), 20);
      expect(parseSizeParam('101'), 20);
      expect(parseSizeParam('10'), 10);
    });
  });
}
