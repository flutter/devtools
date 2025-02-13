// Copyright 2020 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'dart:io';

class HostPlatform {
  HostPlatform._();

  static final instance = HostPlatform._();

  bool get isMacOS => Platform.isMacOS;
}
