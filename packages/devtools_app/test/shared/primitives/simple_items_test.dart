// Copyright 2022 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:devtools_app/src/shared/primitives/simple_items.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test_infra/utils/test_utils.dart';

void main() {
  for (final link in DocLinks.values) {
    test('$link is not broken', () async {
      final content = await loadPageHtmlContent(link.value);
      final hash = link.hash;
      if (hash != null) {
        expect(content, contains('href="#$hash"'));
      }
    });
  }
}
