// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:io';

import 'package:collection/collection.dart';
import 'package:flutter_driver/flutter_driver.dart';
import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  final FlutterDriver driver = await FlutterDriver.connect();
  await integrationDriver(
    driver: driver,
    onScreenshot: (
      String screenshotName,
      List<int> screenshotBytes, [
      Map<String, Object?>? args,
    ]) async {
      final bool shouldUpdateGoldens = args?['update_goldens'] == true;
      final goldenFile =
          File('integration_test/test_infra/goldens/$screenshotName.png');

      if (shouldUpdateGoldens) {
        if (!goldenFile.existsSync()) {
          goldenFile.createSync();
        }
        goldenFile.writeAsBytesSync(screenshotBytes);
        return true;
      }

      if (goldenFile.existsSync()) {
        final goldenImageBytes = goldenFile.readAsBytesSync();
        final equal = const DeepCollectionEquality().equals(
          goldenImageBytes,
          screenshotBytes,
        );
        if (!equal) {
          // TODO(kenz): store failure images in a failures directory.
        }
        return equal;
      }

      return false;
    },
  );
}
