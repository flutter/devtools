// Copyright 2020 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

// ignore_for_file: avoid_print

import 'logger.dart';

void printToConsole(Object message, [LogLevel level = LogLevel.debug]) {
  switch (level) {
    case LogLevel.debug:
      print(message);
      break;
    case LogLevel.warning:
      print('[WARNING]: $message');
      break;
    case LogLevel.error:
      print('[ERROR]: $message');
  }
}
