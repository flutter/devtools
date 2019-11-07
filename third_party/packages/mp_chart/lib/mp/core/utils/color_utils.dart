import 'package:flutter/painting.dart';

abstract class ColorUtils {
  static final Color BLUE = Color(0xFF0000FF);
  static final Color COLOR_SKIP = Color(0x00112234);
  static final Color COLOR_NONE = Color(0x00112233);
  static final Color DKGRAY = Color(0xFF444444);
  static final Color GRAY = Color(0xFF999999);
  static final Color YELLOW = Color(0xFFFFFF00);
  static final Color BLACK = Color(0xFF000000);
  static final Color LTGRAY = Color(0xFFCCCCCC);
  static final Color RED = FADE_RED_END;
  static final Color HOLO_BLUE = Color.fromARGB(255, 51, 181, 229);
  static final Color WHITE = Color(0xFFFFFFFF);
  static final Color PURPLE = Color(0xFF512DA8);
  static final Color FADE_RED_START = Color(0x00FF0000);
  static final Color FADE_RED_END = Color(0xFFFF0000);

  static final Color HOLO_ORANGE_LIGHT = Color(0xffffbb33);
  static final Color HOLO_BLUE_LIGHT = Color(0xff33b5e5);
  static final Color HOLO_GREEN_LIGHT = Color(0xff99cc00);
  static final Color HOLO_RED_LIGHT = Color(0xffff4444);
  static final Color HOLO_BLUE_DARK = Color(0xff0099cc);
  static final Color HOLO_PURPLE = Color(0xffaa66cc);
  static final Color HOLO_GREEN_DARK = Color(0xff669900);
  static final Color HOLO_RED_DARK = Color(0xffcc0000);
  static final Color HOLO_ORANGE_DARK = Color(0xffff8800);

  static final List<Color> VORDIPLOM_COLORS = List()
    ..add(Color.fromARGB(255, 192, 255, 140))
    ..add(Color.fromARGB(255, 255, 247, 140))
    ..add(Color.fromARGB(255, 255, 208, 140))
    ..add(Color.fromARGB(255, 140, 234, 255))
    ..add(Color.fromARGB(255, 255, 140, 157));

  static final List<Color> JOYFUL_COLORS = List()
    ..add(Color.fromARGB(255, 217, 80, 138))
    ..add(Color.fromARGB(255, 254, 149, 7))
    ..add(Color.fromARGB(255, 254, 247, 120))
    ..add(Color.fromARGB(255, 106, 167, 134))
    ..add(Color.fromARGB(255, 53, 194, 209));

  static final List<Color> MATERIAL_COLORS = List()
    ..add(Color(0xFF2ecc71))
    ..add(Color(0xFFf1c40f))
    ..add(Color(0xFFe74c3c))
    ..add(Color(0xFF3498db));

  static final List<Color> COLORFUL_COLORS = List()
    ..add(Color.fromARGB(255, 193, 37, 82))
    ..add(Color.fromARGB(255, 255, 102, 0))
    ..add(Color.fromARGB(255, 245, 199, 0))
    ..add(Color.fromARGB(255, 106, 150, 31))
    ..add(Color.fromARGB(255, 179, 100, 53));

  static final List<Color> LIBERTY_COLORS = List()
    ..add(Color.fromARGB(255, 207, 248, 246))
    ..add(Color.fromARGB(255, 148, 212, 212))
    ..add(Color.fromARGB(255, 136, 180, 187))
    ..add(Color.fromARGB(255, 118, 174, 175))
    ..add(Color.fromARGB(255, 42, 109, 130));

  static final List<Color> PASTEL_COLORS = List()
    ..add(Color.fromARGB(255, 64, 89, 128))
    ..add(Color.fromARGB(255, 149, 165, 124))
    ..add(Color.fromARGB(255, 217, 184, 162))
    ..add(Color.fromARGB(255, 191, 134, 134))
    ..add(Color.fromARGB(255, 179, 48, 80));

  static Color colorWithAlpha(Color strokeColor, int alpha) {
    return Color.fromARGB(
        alpha, strokeColor.red, strokeColor.green, strokeColor.blue);
  }

  static Color getHoloBlue() {
    return Color.fromARGB(255, 51, 181, 229);
  }
}
