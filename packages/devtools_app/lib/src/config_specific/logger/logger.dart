// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

export 'logger_default.dart' if (dart.library.html) 'logger_html.dart';

enum LogLevel {
  debug,
  warning,
  error,
}
