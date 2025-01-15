// Copyright 2023 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

/// Assignment of an item in console to a named variable.
class ConsoleVariableAssignment {
  ConsoleVariableAssignment._(this.consoleItemIndex, this.variableName);

  /// Zero based bottom up index for items in console.
  final int consoleItemIndex;

  final String variableName;

  /// Parses expressions like `var x=$2`.
  ///
  /// Treats $_ as $0.
  static ConsoleVariableAssignment? tryParse(String expression) {
    const variableNameGroup = '([_a-zA-Z][_a-zA-Z0-9]{0,30})';
    const indexGroup = '([_012345])';

    final regex = RegExp(
      r'var\s+'
      '$variableNameGroup'
      r'\s*=\s*\$'
      '$indexGroup',
    );

    final matches = regex.allMatches(expression);
    if (matches.length != 1) return null;
    final match = matches.first;
    assert(match.groupCount == 2);
    final varName = match.group(1)!;
    var indexChar = match.group(2)!;
    if (indexChar == '_') indexChar = '0';
    final index = int.parse(indexChar);

    return ConsoleVariableAssignment._(index, varName);
  }
}
