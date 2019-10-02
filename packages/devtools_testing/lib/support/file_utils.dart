import 'dart:async';
import 'dart:io';

import 'package:package_resolver/package_resolver.dart';

/// Loads the widgets.json file that describes the widgets [Catalog].
Future<String> widgetsJson() async {
  final devtoolsWebPackage =
      await (PackageResolver.current).packagePath('devtools_web');
  return await File('$devtoolsWebPackage/web/widgets.json').readAsString();
}
