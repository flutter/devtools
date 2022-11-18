// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter_test/flutter_test.dart';

Matcher matchesDevToolsGolden(Object key) {
  return matchesGoldenFile(key);
}
