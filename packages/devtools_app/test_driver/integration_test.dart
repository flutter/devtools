// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: avoid_print

import 'dart:io';
import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:flutter_driver/flutter_driver.dart';
import 'package:image/image.dart';
import 'package:integration_test/integration_test_driver_extended.dart';

const _goldensDirectoryPath = 'integration_test/test_infra/goldens';
const _failuresDirectoryPath = '$_goldensDirectoryPath/failures';
const _defaultDiffPercentage = 1.0;
const _defaultDiffTolerance = 0.003;

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
      double percentDiff = 1.0;
      if (goldenFile.existsSync()) {
        final goldenBytes = goldenFile.readAsBytesSync();
        equal = const DeepCollectionEquality().equals(
          goldenBytes,
          screenshotBytes,
        );
        if (!equal) {
          percentDiff = _percentDiff(goldenBytes, screenshotBytes);
        }
      }

      final failuresDirectory = Directory(_failuresDirectoryPath);

      if (!equal) {
        final percentDiffDisplay = '${(percentDiff * 100).toStringAsFixed(4)}%';
        if (percentDiff < _defaultDiffTolerance) {
          print(
            'Warning: $screenshotName.png differed from the golden image by '
            '$percentDiffDisplay. Since this is less than the acceptable '
            'tolerance ${(_defaultDiffTolerance * 100).toStringAsFixed(4)}%, '
            'the test still passes.',
          );
          return true;
        }
        print(
          'Golden image test failed: $screenshotName.png. The test image '
          'differed from the golden image by $percentDiffDisplay.',
        );

        // Create the goldens and failures directories if they do not exist.
        Directory(_goldensDirectoryPath).createSync();
        failuresDirectory.createSync();

        File('$_failuresDirectoryPath/$screenshotName.png')
            .writeAsBytesSync(screenshotBytes);
      }

      if (lastScreenshot &&
          failuresDirectory.existsSync() &&
          failuresDirectory.listSync().isNotEmpty) {
        return false;
      }

      return true;
    },
  );
}

double _percentDiff(Uint8List goldenBytes, List<int> screenshotBytes) {
  final goldenImage = decodeImage(goldenBytes);
  final screenshotImage = decodeImage(Uint8List.fromList(screenshotBytes));
  if (goldenImage == null || screenshotImage == null) {
    print('Cannot decode one or both of the golden images.');
    return _defaultDiffPercentage;
  }

  if (goldenImage.height != screenshotImage.height ||
      goldenImage.width != screenshotImage.width) {
    print(
      'The golden images have a different height or width. '
      'Golden: ${goldenImage.sizeDisplay}\n'
      'Screenshot: ${screenshotImage.sizeDisplay}\n',
    );
    return _defaultDiffPercentage;
  }

  final goldenImageBytes = goldenImage.getBytes();
  final screenshotImageBytes = screenshotImage.getBytes();
  if (goldenImageBytes.length != screenshotImageBytes.length) {
    print(
      'The golden images have a different byte lengths. '
      'Golden: ${goldenImageBytes.length} bytes\n'
      'Screenshot: ${screenshotImageBytes.length} bytes\n',
    );
    return _defaultDiffPercentage;
  }

  // This image diff calculation code is used by the Flutter test matcher
  // [matchesReferenceImage]. The small bit of code copied here is pulled out
  // for convenient reuse.
  int delta = 0;
  for (int i = 0; i < goldenImageBytes.length; i += 4) {
    if (goldenImageBytes[i] != screenshotImageBytes[i] ||
        goldenImageBytes[i + 1] != screenshotImageBytes[i + 1] ||
        goldenImageBytes[i + 2] != screenshotImageBytes[i + 2] ||
        goldenImageBytes[i + 3] != screenshotImageBytes[i + 3]) {
      delta++;
    }
  }
  return delta / goldenImageBytes.length / 4;
}

extension _ImageExtension on Image {
  String get sizeDisplay =>
      'Size(width: ${width.toDouble()}, height: ${height.toDouble()})';
}
