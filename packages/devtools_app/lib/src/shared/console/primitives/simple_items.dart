// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

enum FlutterTreeType {
  widget, // ('Widget'),
  renderObject // ('Render');
// TODO(jacobr): add semantics, and layer trees.
}

class ConsoleVariableAssignment {
  ConsoleVariableAssignment._(this.consoleItemIndex, this.variableName);

  final int consoleItemIndex;
  final String variableName;

  static ConsoleVariableAssignment? tryParse(String expression) {
    if (expression != 'var x=\$0') return null; //var x=$0

    return ConsoleVariableAssignment._(0, 'x');
  }
}
