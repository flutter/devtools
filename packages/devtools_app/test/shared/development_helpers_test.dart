// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/shared/development_helpers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('debug flags are false', () {
    expect(debugDevToolsExtensions, isFalse);
  });
}
