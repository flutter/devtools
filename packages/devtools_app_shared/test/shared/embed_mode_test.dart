// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app_shared/shared.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('$EmbedMode', () {
    test('fromArgs', () {
      expect(EmbedMode.fromArgs({'embedMode': 'one'}), EmbedMode.embedOne);
      expect(EmbedMode.fromArgs({'embedMode': 'many'}), EmbedMode.embedMany);
      expect(EmbedMode.fromArgs({'embedMode': 'badInput'}), EmbedMode.none);
      expect(EmbedMode.fromArgs({}), EmbedMode.none);
    });

    test('fromArgs with legacy input', () {
      expect(EmbedMode.fromArgs({'embed': 'true'}), EmbedMode.embedOne);
      expect(EmbedMode.fromArgs({'embed': 'false'}), EmbedMode.none);
      // Defers to embedMode value when both new and legacy params are present.
      expect(
        EmbedMode.fromArgs({'embedMode': 'many', 'embed': 'true'}),
        EmbedMode.embedMany,
      );
      expect(
        EmbedMode.fromArgs({'embedMode': 'one', 'embed': 'false'}),
        EmbedMode.embedOne,
      );
    });

    test('embedded', () {
      expect(EmbedMode.embedOne.embedded, true);
      expect(EmbedMode.embedMany.embedded, true);
      expect(EmbedMode.none.embedded, false);
    });
  });
}
