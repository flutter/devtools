// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:io';

import 'package:collection/collection.dart';
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
        // Resize the screenshot bytes to match the size we expect on the CI.
        final screenshotImageBytes = _resizeBytes(screenshotBytes);

        equal = const DeepCollectionEquality().equals(
          goldenImageBytes,
          screenshotImageBytes,
        );
        if (!equal) {
          percentDiff = _percentDiff(goldenImageBytes, screenshotImageBytes);
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

void _writeImageToFile(File file, List<int> bytes) {
  file.writeAsBytesSync(_resizeBytes(bytes));
}

List<int> _resizeBytes(List<int> bytes) {
  final image = decodeImage(bytes);
  if (image == null) {
    print('Cannot decode bytes to image.');
    return bytes;
  }

  // Resize the image to a [_defaultImageWidth].
  final resizedImage = copyResize(image, width: _defaultImageWidth);
  final resizedBytes = encodePng(resizedImage);
  return resizedBytes;
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
