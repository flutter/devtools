// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:io';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart' hide Image;
import 'package:flutter_driver/flutter_driver.dart';
import 'package:image/image.dart';
import 'package:integration_test/integration_test_driver_extended.dart';

const _goldensDirectoryPath = 'integration_test/test_infra/goldens';
const _defaultDiffPercentage = 1.0;

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
      double percentDiff = _defaultDiffPercentage;
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

double _percentDiff(List<int> goldenBytes, List<int> screenshotBytes) {
  final goldenImage = decodeImage(goldenBytes);
  final screenshotImage = decodeImage(screenshotBytes);
  if (goldenImage == null || screenshotImage == null) {
    print('Cannot decode one or both of the golden images.');
    return _defaultDiffPercentage;
  }

  if (goldenImage.height != screenshotImage.height ||
      goldenImage.width != screenshotImage.width) {
    print(
      'The golden images have a different height or width. '
      'Golden: ${goldenImage.size}'
      'Screenshot: ${screenshotImage.size}',
    );
    return _defaultDiffPercentage;
  }

  // This image diff calculation code is used by the Flutter test matcher
  // [matchesReferenceImage]. The small bit of code copied here is pulled out
  // for convenient reuse.
  assert(goldenBytes.length == screenshotBytes.length);
  int delta = 0;
  for (int i = 0; i < goldenBytes.length; i += 4) {
    if (goldenBytes[i] != screenshotBytes[i] ||
        goldenBytes[i + 1] != screenshotBytes[i + 1] ||
        goldenBytes[i + 2] != screenshotBytes[i + 2] ||
        goldenBytes[i + 3] != screenshotBytes[i + 3]) {
      delta++;
    }
  }
  return delta / goldenBytes.length / 4;
}

extension _ImageExtension on Image {
  Size get size => Size(width.toDouble(), height.toDouble());
}
