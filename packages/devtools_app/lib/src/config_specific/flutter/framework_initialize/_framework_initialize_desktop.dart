// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';

/// Return the url the application is launched from.
Future<String> initializePlatform() async {
  // When running in a desktop embedder, Flutter throws an error because the
  // platform is not officially supported. This is not needed for web.
  debugDefaultTargetPlatformOverride = TargetPlatform.fuchsia;

  // TODO(jacobr): we don't yet have a direct analog to the URL on flutter
  // desktop. Hard code to the dark theme as the majority of users are on the
  // dark theme.
  return '/?theme=dark';
}
