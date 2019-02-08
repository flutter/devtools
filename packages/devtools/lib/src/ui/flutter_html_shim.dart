import 'fake_flutter/fake_flutter.dart';

String fontStyleToCss(TextStyle textStyle) {
  // We could support more features but this is all we need for the inspector.
  final sb = StringBuffer();
  if (textStyle.fontStyle == FontStyle.italic) {
    sb.write('italic ');
  }
  if (textStyle.fontWeight != null) {
    sb.write('${(textStyle.fontWeight.index + 1) * 100} ');
  }
  sb.write('${textStyle.fontSize ?? 14}px ');
  sb.write('${textStyle.fontFamily ?? 'Arial'} ');
  return sb.toString();
}

final Map<Color, String> cssColors = {};

String colorToCss(Color color) {
  if (cssColors.containsKey(color)) {
    return cssColors[color];
  }
  final int rgbaColor = ((color.value & 0xffffff) << 8) | (color.alpha);
  final String cssColor = '#${rgbaColor.toRadixString(16).padLeft(8, '0')}';
  cssColors[color] = cssColor;
  return cssColor;
}
