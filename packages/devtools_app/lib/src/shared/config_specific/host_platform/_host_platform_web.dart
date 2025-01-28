// Copyright 2020 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:web/web.dart';

class HostPlatform {
  HostPlatform._() {
    _isMacOS = window.navigator.userAgent.contains('Macintosh');
  }

  static final instance = HostPlatform._();

  late final bool _isMacOS;

  bool get isMacOS => _isMacOS;
}
