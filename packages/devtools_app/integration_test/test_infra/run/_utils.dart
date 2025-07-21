// Copyright 2023 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

// ignore_for_file: avoid_print

/// @docImport 'package:flutter_test/flutter_test.dart';
library;

import 'package:test/test.dart' show Timeout;

bool debugTestScript = false;

void debugLog(String log) {
  if (debugTestScript) {
    print(log);
  }
}

/// A timeout for a "short" integration test.
///
/// Adjust as needed; this is used to override the 10-minute or infinite timeout
/// in [testWidgets].
const Timeout shortTimeout = Timeout(Duration(minutes: 2));

/// A timeout for a "medium" integration test.
///
/// Adjust as needed; this is used to override the 10-minute or infinite timeout
/// in [testWidgets].
const Timeout mediumTimeout = Timeout(Duration(minutes: 3));

/// A timeout for a "long" integration test.
///
/// Adjust as needed; this is used to override the 10-minute or infinite timeout
/// in [testWidgets].
const Timeout longTimeout = Timeout(Duration(minutes: 4));
