// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:js_interop';

import 'package:web/web.dart';

import 'logger.dart';

void printToConsole(Object message, [LogLevel level = LogLevel.debug]) {
  final jsMessage = message.jsify();
  switch (level) {
    case LogLevel.debug:
      console.log(jsMessage);
      break;
    case LogLevel.warning:
      console.warn(jsMessage);
      break;
    case LogLevel.error:
      console.error(jsMessage);
  }
}
