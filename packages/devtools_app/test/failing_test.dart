@TestOn('browser')
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('I must fail', () async {
    expect(1, 2);
  });
}
