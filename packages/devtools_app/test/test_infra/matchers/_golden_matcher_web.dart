// Copyright 2022 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:flutter_test/flutter_test.dart';

Matcher matchesDevToolsGolden(Object key) {
  return matchesGoldenFile(key);
}
