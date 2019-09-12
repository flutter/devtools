/// Library that falls back to dart:html where available and provides a fake
/// implementation of dart:html that always throws exceptions otherwise.
///
/// Use https://pub.dev/packages/universal_html instead if you actually want
/// to run html manipulation code in a context where dart:html isn't
/// available. This library is a footgun and should only be used as an
/// incremental step in porting code from using dart:html to package:flutter.
/// 
/// This library is unlikely to be updated to reflect changes to dart:html so
/// do not use it if the version of dart:html from Dart 2.5 is not sufficient
/// for your needs.
library html_shim;

import 'src/_conversion_io.dart'
    if (dart.library.html) 'src/_conversion_html.dart' as conversion;
import 'src/_html_io.dart' if (dart.library.html) 'src/real_html.dart'
    show Element;

export 'src/_html_io.dart' if (dart.library.html) 'src/real_html.dart'
    hide VoidCallback;

bool get isHtmlSupported {
  double oneDouble = 1.0;
  int oneInt = 1;
  // TODO(jacobr): use actual config specific imports instead of checking if
  // this is JavaScript or not.
  return !identical(oneDouble, oneInt);
}

/// Use this method to convert an [Element] to a type suitable for a package
/// dependency that uses only `dart:html`.
///
/// This method exists as workaround for limitations in how the analyzer handles
/// conditional imports and exports.  The return type of this method would be
/// Element if that didn't cause analysis errors.
///
/// Use this method very carefully as it is a foot gun only intended to help
/// users port code from dart:html to flutter.
dynamic toDartHtmlElement(Element e) => conversion.toDartHtmlElement(e);

/// Use this method to convert a [List<Element>] to a type suitable for package
/// dependencies that require dart:html.
///
/// This method exists as workaround for limitations in how the analyzer handles
/// conditional imports and exports. The return type of this method would be
/// [List<Element>] if that did not cause analysis errors.
///
/// Use this method very carefully as it is a foot gun only intended to help
/// users port code from dart:html to flutter.
List toDartHtmlElementList(List<Element> list) =>
    conversion.toDartHtmlElementList(list);
