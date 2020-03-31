import 'package:flutter_test/flutter_test.dart';
import 'package:mp_chart/mp/core/utils/matrix4_utils.dart';

import 'package:mp_chart/mp_chart.dart';
import 'package:vector_math/vector_math_64.dart';

void main() {
  test('adds one to input values', () {
    final calculator = Calculator();
    expect(calculator.addOne(2), 3);
    expect(calculator.addOne(-7), -6);
    expect(calculator.addOne(0), 1);
    expect(() => calculator.addOne(null), throwsNoSuchMethodError);
  });

  /**
   * a test to see the print value equal to the same Android logic
   */
  test('test postScale', () {
    Matrix4 m = Matrix4.identity();
    print(m);
    print('\n');
    Matrix4Utils.postTranslate(m, 3, 5);
    print(m);
    print('\n');
    Matrix4Utils.postScale(m, 3, 0.5);
    print(m);
    print('\n');
    Matrix4Utils.postScaleByPoint(m, 0.4, 6, 2, 3);
    print(m);
  });
}
