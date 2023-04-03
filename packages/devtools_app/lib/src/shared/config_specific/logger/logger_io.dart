// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

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
