// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file.

import 'dart:io';

class HostPlatform {
  HostPlatform._();

  static final HostPlatform instance = HostPlatform._();

  bool get isMacOS => Platform.isMacOS;
}
