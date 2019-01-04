import 'fake_flutter/fake_flutter.dart';

String fontStyleToCss(TextStyle textStyle) {
  // We could support more features but this is all we need for the inspector.
  final sb = new StringBuffer();
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

String colorToCss(Color color) {
  final int rgbaColor = ((color.value & 0xffffff) << 8) | (color.alpha);
  return '#${rgbaColor.toRadixString(16).padLeft(8, '0')}';
}
