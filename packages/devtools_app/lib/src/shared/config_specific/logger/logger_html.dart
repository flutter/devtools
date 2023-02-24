// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:html';

import 'package:logging/logging.dart';

import 'logger.dart';

final _log = Logger('main_log');

void log(Object message, [LogLevel level = LogLevel.debug]) {
  switch (level) {
    case LogLevel.debug:
      window.console.log(message);
      _log.info(message);
      break;
    case LogLevel.warning:
      window.console.warn(message);
      _log.warning(message);
      break;
    case LogLevel.error:
      window.console.error(message);
      _log.shout(message);
  }
}
