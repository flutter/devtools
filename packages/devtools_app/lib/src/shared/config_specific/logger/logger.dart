// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

export '_logger_io.dart'
    if (dart.library.js_interop) 'logger_html.dart';

enum LogLevel {
  debug,
  warning,
  error,
}
