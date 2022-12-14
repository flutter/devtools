import 'dart:io';

import 'package:collection/collection.dart';
import 'package:flutter_driver/flutter_driver.dart';
import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  final FlutterDriver driver = await FlutterDriver.connect();
  await integrationDriver(
    driver: driver,
    onScreenshot: (String screenshotName, List<int> screenshotBytes) async {
      // const shouldUpdateGoldens = bool.fromEnvironment('--update-goldens');
      // print('should update goldens? $shouldUpdateGoldens');
      // if (shouldUpdateGoldens) {
      //   final File image = File('$screenshotName.png');
      //   image.writeAsBytesSync(screenshotBytes);
      //   // overwrite file.
      //   return true;
      // }

      // print('grabbing current image file');
      // final currentImageFile =
      //     File('../test_infra/goldens/$screenshotName.png');
      // print('checking if exists?');
      // if (currentImageFile.existsSync()) {
      //   print('it does exist');
      //   final currentImageBytes = currentImageFile.readAsBytesSync();
      //   return const DeepCollectionEquality()
      //       .equals(currentImageBytes, screenshotBytes);
      // }
      // print('doesnt exist');
      // even when returning true
//       result {"result":"true","failureDetails":[],"data":{"screenshots":[{"bytes":[]}]}}
// Unhandled exception:
// type 'Null' is not a subtype of type 'String' in type cast
// #0      integrationDriver (package:integration_test/integration_test_driver_extended.dart:103:60)
// <asynchronous suspension>
// #1      main (file:///Users/kenzieschmoll/develop/devtools/packages/devtools_app/test_driver/integration_test.dart:9:3)
// <asynchronous suspension>
      return true;
    },
  );
}
