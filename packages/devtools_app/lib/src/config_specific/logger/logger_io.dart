// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'logger.dart';

void log(String message, [LogLevel level = LogLevel.debug]) {
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
