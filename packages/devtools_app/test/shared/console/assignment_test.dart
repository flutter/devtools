// Copyright 2023 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:devtools_app/src/shared/console/primitives/assignment.dart';
import 'package:flutter_test/flutter_test.dart';

class _AssignmentParsingTest {
  _AssignmentParsingTest(this.name, this.input, this.variableName, this.index)
    : assert((variableName == null) == (index == null));

  final String name;
  final String input;
  final String? variableName;
  final int? index;

  void verify(ConsoleVariableAssignment? output) {
    if (variableName == null) {
      expect(output, isNull);
      return;
    }

    expect(output!.variableName, variableName);
    expect(output.consoleItemIndex, index);
  }
}

final _tests = [
  _AssignmentParsingTest('empty', '', null, null),
  _AssignmentParsingTest('no var', r'x=$1', null, null),
  _AssignmentParsingTest('zero', r'var x=$0', 'x', 0),
  _AssignmentParsingTest('five', r'var x=$5', 'x', 5),
  _AssignmentParsingTest('underscore', r'var x=$_', 'x', 0),
  _AssignmentParsingTest('spaces', r'   var   x   =   $1   ', 'x', 1),
  _AssignmentParsingTest('no spaces', r'varx=$_', null, null),
  _AssignmentParsingTest('complex name', r'var _0x=$1', '_0x', 1),
];

void main() {
  for (final t in _tests) {
    test('$ConsoleVariableAssignment parsing, ${t.name}', () {
      final output = ConsoleVariableAssignment.tryParse(t.input);
      t.verify(output);
    });
  }
}
