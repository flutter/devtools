import 'package:devtools_app/main.dart' as devtools_app;

import 'package:flutter_driver/driver_extension.dart' as flutter_driver;

void main() {
  flutter_driver.enableFlutterDriverExtension();
  devtools_app.main();
}
