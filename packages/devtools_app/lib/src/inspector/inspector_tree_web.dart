// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:html';
import '../ui/html_elements.dart';
import 'inspector_tree.dart';

/// Base class for all inspector tree classes that can be used on the web.
mixin InspectorTreeWeb implements InspectorTreeController, CoreElementView {
  void addKeyboardListeners(CoreElement element) {
    element.onKeyDown.listen((KeyboardEvent e) {
      // TODO(jacobr): PgUp/PgDown/Home/End?
      switch (e.keyCode) {
        case KeyCode.UP:
          navigateUp();
          break;
        case KeyCode.DOWN:
          navigateDown();
          break;
        case KeyCode.LEFT:
          navigateLeft();
          break;
        case KeyCode.RIGHT:
          navigateRight();
          break;
        default:
          return;
      }
      e.preventDefault();
    });
  }
}
