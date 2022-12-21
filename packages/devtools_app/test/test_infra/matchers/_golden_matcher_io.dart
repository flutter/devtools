// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:io' as io;

import 'package:flutter_test/flutter_test.dart';

import 'matchers.dart';

Matcher matchesDevToolsGolden(Object key) {
  if (io.Platform.isMacOS) {
    return matchesGoldenFile(key);
  }
  return const AlwaysTrueMatcher();
}
