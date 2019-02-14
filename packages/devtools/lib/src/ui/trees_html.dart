// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:html';

import 'trees.dart';

/// Provides functionality for navigating around a tree with HTML keypresses.
mixin HtmlTreeNavigator<T> on TreeNavigator<T> {
  void handleKeyPress(KeyboardEvent e) {
    if (e.keyCode == KeyCode.DOWN) {
      moveDown();
    } else if (e.keyCode == KeyCode.UP) {
      moveUp();
    } else if (e.keyCode == KeyCode.RIGHT) {
      moveRight();
    } else if (e.keyCode == KeyCode.LEFT) {
      moveLeft();
    } else {
      return; // don't preventDefault if we were anything else.
    }

    e.preventDefault();
  }
}
