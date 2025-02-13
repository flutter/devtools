// Copyright 2022 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'dart:io' as io;

import 'package:flutter_test/flutter_test.dart';

import 'matchers.dart';

Matcher matchesDevToolsGolden(Object key) {
  if (io.Platform.isMacOS) {
    return matchesGoldenFile(key);
  }
  return const AlwaysTrueMatcher();
}
