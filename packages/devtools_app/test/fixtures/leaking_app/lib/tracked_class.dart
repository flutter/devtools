// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:memory_tools/lib_leak_detector.dart' as leak_detector;

class MyTrackedClass {
  MyTrackedClass({required this.token, this.child}) {
    leak_detector.startTracking(this, token: token);
  }

  final Object token;
  final MyTrackedClass? child;

  void dispose() {
    child?.dispose();
    leak_detector.registerDisposal(this, token: token);
  }
}
