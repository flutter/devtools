// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

@TestOn('browser')
library;

import 'package:devtools_extensions/devtools_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Global managers', () {
    test('accessing early throws error', () {
      expect(() => serviceManager, throwsStateError);
      expect(() => extensionManager, throwsStateError);
      expect(() => dtdManager, throwsStateError);
    });

    testWidgets(
      'building $DevToolsExtension initializes globals',
      (tester) async {
        await tester.pumpWidget(const DevToolsExtension(child: SizedBox()));
        expect(serviceManager, isNotNull);
        expect(extensionManager, isNotNull);
        expect(dtdManager, isNotNull);
      },
    );
  });
}
