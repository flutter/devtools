// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore: avoid_web_libraries_in_flutter, as designed
import 'dart:html';

import 'logger.dart';

void printToConsole(Object message, [LogLevel level = LogLevel.debug]) {
  switch (level) {
    case LogLevel.debug:
      window.console.log(message);
      break;
    case LogLevel.warning:
      window.console.warn(message);
      break;
    case LogLevel.error:
      window.console.error(message);
  }
}
