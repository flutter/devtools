// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Library that falls back to dart:js where available and provides a fake
/// implementation of dart:js that always throws exceptions otherwise.
///
/// This library is a footgun and should only be used as an incremental step
/// in porting code from using dart:html to package:flutter.
library js;

export 'src/_js_io.dart' if (dart.library.html) 'src/real_js.dart';
