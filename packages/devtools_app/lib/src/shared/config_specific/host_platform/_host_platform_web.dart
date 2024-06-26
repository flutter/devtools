// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file.

import 'package:web/web.dart';

class HostPlatform {
  HostPlatform._() {
    _isMacOS = window.navigator.userAgent.contains('Macintosh');
  }

  static final instance = HostPlatform._();

  late final bool _isMacOS;

  bool get isMacOS => _isMacOS;
}
