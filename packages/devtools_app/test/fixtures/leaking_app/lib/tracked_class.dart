// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:leak_tracking/leak_tracking.dart';

class MyTrackedClass {
  MyTrackedClass({required this.token, this.child}) {
    startObjectLeakTracking(this, token: token);
  }

  final Object token;
  final MyTrackedClass? child;

  void dispose() {
    child?.dispose();
    registerDisposal(this, token: token);
  }
}
