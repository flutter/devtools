// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:io';

import 'package:collection/collection.dart';
import 'package:flutter_driver/flutter_driver.dart';
import 'package:integration_test/integration_test_driver_extended.dart';

const _goldensDirectoryPath = 'integration_test/test_infra/goldens';

Future<void> main() async {
  final driver = await FlutterDriver.connect();
  await integrationDriver(
    driver: driver,
    onScreenshot: (
      String screenshotName,
      List<int> screenshotBytes, [
      Map<String, Object?>? args,
    ]) async {
      final bool shouldUpdateGoldens = args?['update_goldens'] == true;
      final goldenFile = File('$_goldensDirectoryPath/$screenshotName.png');

      if (shouldUpdateGoldens) {
        if (!goldenFile.existsSync()) {
          // Create the goldens directory if it does not exist.
          Directory(_goldensDirectoryPath).createSync();
        }
        goldenFile.writeAsBytesSync(screenshotBytes);

        print('Golden image updated: $screenshotName.png');
        return true;
      }

      bool equal = false;
      if (goldenFile.existsSync()) {
        final goldenImageBytes = goldenFile.readAsBytesSync();
        equal = const DeepCollectionEquality().equals(
          goldenImageBytes,
          screenshotBytes,
        );
      }
      if (!equal) {
        print('Golden image test failed: $screenshotName.png');

        // Create the goldens directory if it does not exist.
        Directory(_goldensDirectoryPath)..createSync();

        const failuresDirectoryPath = '$_goldensDirectoryPath/failures';
        Directory(failuresDirectoryPath)..createSync();
        final failedGoldenFile =
            File('$failuresDirectoryPath/$screenshotName.png')..createSync();
        failedGoldenFile.writeAsBytesSync(screenshotBytes);
      }

      return equal;
    },
  );
}
