import 'package:test/test.dart';

import 'package:devtools/src/ui/theme.dart';
import 'package:devtools/src/ui/fake_flutter/fake_flutter.dart';
import 'package:devtools/src/ui/flutter_html_shim.dart';

void main() {
  const Color customLight = Color.fromARGB(200, 202, 191, 69);
  const Color customDark = Color.fromARGB(100, 99, 101, 103);
  const Color customColor = ThemedColor(customLight, customDark);

  test('light theme', () {
    initializeTheme('light');
    expect(white.red, equals(255));
    expect(white.green, equals(255));
    expect(white.blue, equals(255));
    expect(white.alpha, equals(255));
    expect(colorToCss(white), equals('#ffffffff'));

    expect(black.red, equals(0));
    expect(black.green, equals(0));
    expect(black.blue, equals(0));
    expect(black.alpha, equals(255));
    expect(colorToCss(black), equals('#000000ff'));

    expect(customColor.value, equals(customLight.value));
    expect(customColor.alpha, equals(customLight.alpha));
    expect(customColor.red, equals(customLight.red));
    expect(customColor.green, equals(customLight.green));
    expect(customColor.blue, equals(customLight.blue));
    expect(colorToCss(customColor), colorToCss(customLight));
  });

  test('dark theme', () {
    initializeTheme('dark');
    expect(white.red, equals(0));
    expect(white.green, equals(0));
    expect(white.blue, equals(0));
    expect(white.alpha, equals(255));
    expect(colorToCss(white), equals('#000000ff'));

    expect(black.red, equals(187));
    expect(black.green, equals(187));
    expect(black.blue, equals(187));
    expect(black.alpha, equals(255));
    expect(colorToCss(black), equals('#bbbbbbff'));

    expect(customColor.value, equals(customDark.value));
    expect(customColor.alpha, equals(customDark.alpha));
    expect(customColor.red, equals(customDark.red));
    expect(customColor.green, equals(customDark.green));
    expect(customColor.blue, equals(customDark.blue));
    expect(colorToCss(customColor), colorToCss(customDark));
  });
}
