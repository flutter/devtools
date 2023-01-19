// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:io';

import 'package:collection/collection.dart';
import 'package:flutter_driver/flutter_driver.dart';
import 'package:image/image.dart';
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
      final double diffTolerance = args?['diff_tolerance'] as double? ?? 0.0;
      final goldenFile = File('$_goldensDirectoryPath/$screenshotName.png');

      if (shouldUpdateGoldens) {
        if (!goldenFile.existsSync()) {
          // Create the goldens directory if it does not exist.
          Directory(_goldensDirectoryPath).createSync();
        }
        _writeImageToFile(goldenFile, screenshotBytes);

        print('Golden image updated: $screenshotName.png');
        return true;
      }

      bool equal = false;
      double percentDiff = 100.0;
      if (goldenFile.existsSync()) {
        final goldenImageBytes = goldenFile.readAsBytesSync();
        equal = const DeepCollectionEquality().equals(
          goldenImageBytes,
          screenshotBytes,
        );
        if (!equal) {
          percentDiff = _percentDiff(goldenImageBytes, screenshotBytes);
        }
      }

      if (!equal) {
        final percentDiffDisplay = '${(percentDiff * 100).toStringAsFixed(2)}%';
        if (percentDiff < diffTolerance) {
          print(
            'Warning: $screenshotName.png differed from the golden image by '
            '$percentDiffDisplay. Since this is less than the acceptable '
            'tolerance ${(diffTolerance * 100).toStringAsFixed(2)}%, the '
            'test still passes.',
          );
          return true;
        }

        print(
          'Golden image test failed: $screenshotName.png. The test image '
          'differed from the golden image by $percentDiffDisplay.',
        );

        // Create the goldens directory if it does not exist.
        Directory(_goldensDirectoryPath).createSync();

        const failuresDirectoryPath = '$_goldensDirectoryPath/failures';
        Directory(failuresDirectoryPath).createSync();
        final goldenFailure =
            File('$failuresDirectoryPath/$screenshotName.png');
        _writeImageToFile(goldenFailure, screenshotBytes);
      }

      return equal;
    },
  );
}

// This is the default image width that will be created by screenshot testing
// on the bots.
const _defaultImageWidth = 1600;

void _writeImageToFile(File file, List<int> originalBytes) {
  final originalImage = decodeImage(originalBytes);
  if (originalImage == null) {
    print('Cannot decode image at ${file.path}');
    file.writeAsBytesSync(originalBytes);
    return;
  }

  // Resize the image to a [_defaultImageWidth].
  final resizedImage = copyResize(originalImage, width: _defaultImageWidth);
  final resizedBytes = encodePng(resizedImage);

  // Overwrite the file with the new resized image bytes.
  file.writeAsBytesSync(resizedBytes);
}

double _percentDiff(List<int> imageA, List<int> imageB) {
  // This image diff calculation code is used by the Flutter test matcher
  // [matchesReferenceImage]. The small bit of code copied here is pulled out
  // for convenient reuse.
  assert(imageA.length == imageB.length);
  int delta = 0;
  for (int i = 0; i < imageA.length; i += 4) {
    if (imageA[i] != imageB[i] ||
        imageA[i + 1] != imageB[i + 1] ||
        imageA[i + 2] != imageB[i + 2] ||
        imageA[i + 3] != imageB[i + 3]) {
      delta++;
    }
  }
  return delta / imageA.length / 4;
}
