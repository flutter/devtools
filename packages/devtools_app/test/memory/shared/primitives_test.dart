// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/screens/memory/shared/primitives/simple_elements.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test_infra/utils/test_utils.dart';

void main() {
  for (final link in DocLinks.values) {
    test('$link is not broken', () async {
      final content = await loadPageHtmlContent(link.value);
      final hash = link.hash;
      expect(content, contains('href="#$hash"'));
    });
  }
}
