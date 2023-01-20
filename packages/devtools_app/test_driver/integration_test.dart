// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:io';

import 'package:collection/collection.dart';
import 'package:flutter_driver/flutter_driver.dart';
import 'package:integration_test/integration_test_driver_extended.dart';

const _goldensDirectoryPath = 'integration_test/test_infra/goldens';
const _failuresDirectoryPath = '$_goldensDirectoryPath/failures';

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

      // TODO(https://github.com/flutter/flutter/issues/118470): remove this.
      // We need this to ensure all golden image checks run. Without this
      // workaround, the flutter integration test framework will crash on the
      // failed expectation.
      final bool lastScreenshot = args?['last_screenshot'] == true;

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
        final goldenBytes = goldenFile.readAsBytesSync();
        equal = const DeepCollectionEquality().equals(
          goldenBytes,
          screenshotBytes,
        );
      }

      final failuresDirectory = Directory(_failuresDirectoryPath);

      if (!equal) {
        print('Golden image test failed: $screenshotName.png.');

        // Create the goldens and failures directories if they do not exist.
        Directory(_goldensDirectoryPath).createSync();
        failuresDirectory.createSync();

        File('$_failuresDirectoryPath/$screenshotName.png')
            .writeAsBytesSync(screenshotBytes);
      }

      if (lastScreenshot && failuresDirectory.existsSync() &&
          failuresDirectory.listSync().isNotEmpty) {
        return false;
      }

      return true;
    },
  );
}
