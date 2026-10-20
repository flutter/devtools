// Copyright 2026 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:devtools_app_shared/src/service/isolate_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RootInfo', () {
    test('handles package URIs', () {
      final info = RootInfo('package:my_package/main.dart');
      expect(info.library, 'package:my_package/main.dart');
      expect(info.package, 'package:my_package');
    });

    test('handles package URIs without path', () {
      final info = RootInfo('package:my_package');
      expect(info.library, 'package:my_package');
      expect(info.package, 'package:my_package');
    });

    test('handles null library', () {
      final info = RootInfo(null);
      expect(info.library, isNull);
      expect(info.package, isNull);
    });

    test('handles file URIs (non-package)', () {
      final info = RootInfo(
        'file:///Users/viktor/Projects/tests/gui_1/gui_1_server/bin/main.dart',
      );
      expect(
        info.library,
        'file:///Users/viktor/Projects/tests/gui_1/gui_1_server/bin/main.dart',
      );
      expect(info.package, isNull);
    });

    test('handles dart: URIs (non-package)', () {
      final info = RootInfo('dart:core');
      expect(info.library, 'dart:core');
      expect(info.package, isNull);
    });
  });
}
