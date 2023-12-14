// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import '../../../framework/framework_core.dart';
import '_framework_initialize_desktop.dart'
    if (dart.library.js_interop) '_framework_initialize_web.dart';

Future<void> initializeFramework() async {
  FrameworkCore.initGlobals();
  await initializePlatform();
  FrameworkCore.init();
}
