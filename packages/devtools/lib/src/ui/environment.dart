// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:html';

import 'package:meta/meta.dart';

num get devicePixelRatio => _devicePixelRatio;

num _devicePixelRatio = window.devicePixelRatio;

@visibleForTesting
void overrideDevicePixelRatio(num value) {
  _devicePixelRatio = value;
}
