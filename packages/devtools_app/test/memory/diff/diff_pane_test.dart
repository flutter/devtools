// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/screens/memory/panes/diff/diff_pane.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Diff tab is off yet.', () {
    expect(shouldShowDiffPane, false);
  });
}
