// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import '../../../framework/framework_core.dart';

import '_framework_initialize_stub.dart'
    if (dart.library.html) '_framework_initialize_web.dart'
    if (dart.library.io) '_framework_initialize_desktop.dart';

void initializeFramework() {
  final url = initializePlatform();
  FrameworkCore.init(url);
}
