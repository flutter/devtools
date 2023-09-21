// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/devtools_app.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ScreenMetaData', () {
    test('values matches order of screens', () {
      final enumOrder = ScreenMetaData.values.map((s) => s.id).toList();
      final screenOrder =
          defaultScreens().map((screen) => screen.screen.screenId).toList();

      // Remove any items that don't exist in both - we can't verify
      // the order of those.
      enumOrder.removeWhereNot(screenOrder.toSet().contains);
      screenOrder.removeWhereNot(enumOrder.toSet().contains);

      expect(enumOrder, screenOrder);
    });
  });
}

extension _ListExtension<T> on List<T> {
  void removeWhereNot(bool Function(T) test) {
    removeWhere((item) => !test(item));
  }
}
