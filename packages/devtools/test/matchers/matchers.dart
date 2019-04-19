// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

library matchers;

import 'dart:io' as io;

import 'package:devtools/src/inspector/diagnostics_node.dart';
import 'package:matcher/matcher.dart';

RemoteDiagnosticsNode findNodeMatching(
    RemoteDiagnosticsNode node, String text) {
  if (node.name?.startsWith(text) == true ||
      node.description?.startsWith(text) == true) {
    return node;
  }
  if (node.childrenNow == null) {
    return null;
  }
  for (var child in node.childrenNow) {
    final match = findNodeMatching(child, text);
    if (match != null) {
      return match;
    }
  }
  return null;
}

String treeToDebugString(RemoteDiagnosticsNode node) {
  return node.toDiagnosticsNode().toStringDeep();
}

String treeToDebugStringTruncated(RemoteDiagnosticsNode node, int maxLines) {
  List<String> lines = node.toDiagnosticsNode().toStringDeep().split('\n');
  if (lines.length > maxLines) {
    lines = lines.take(maxLines).toList()..add('...');
  }
  return lines.join('\n');
}

/// Asserts that a [path] matches a golden file after normalizing likely hash
/// codes.
///
/// Paths are assumed to reference files within the `test/goldens` directory.
///
/// To rebaseline all golden files run:
/// ```
/// tool/update_goldens.sh
/// ```
///
/// A `#` followed by 5 hexadecimal digits is assumed to be a short hash code
/// and is normalized to #00000.
///
/// See Also:
///
///  * [equalsIgnoringHashCodes], which does the same thing without the golden
///    file functionality.
Matcher equalsGoldenIgnoringHashCodes(String path) {
  return _EqualsGoldenIgnoringHashCodes(path);
}

class _EqualsGoldenIgnoringHashCodes extends Matcher {
  _EqualsGoldenIgnoringHashCodes(String pathWithinGoldenDirectory) {
    path = 'test/goldens$_goldensSuffix/$pathWithinGoldenDirectory';
    try {
      _value = io.File(path).readAsStringSync();
    } catch (e) {
      _value = 'Error reading $path: $e';
    }
  }
  String path;
  String _value;

  static final Object _mismatchedValueKey = Object();

  static bool _updateGoldens;
  static const String _goldensSuffix =
      String.fromEnvironment('GOLDENS_SUFFIX', defaultValue: '');

  static bool get updateGoldens {
    _updateGoldens ??=
        const String.fromEnvironment('UPDATE_GOLDENS', defaultValue: 'false') ==
            'true';
    return _updateGoldens;
  }

  static String _normalize(String s) {
    return s.replaceAll(RegExp(r'#[0-9a-f]{5}'), '#00000');
  }

  @override
  bool matches(dynamic object, Map<dynamic, dynamic> matchState) {
    final String description = _normalize(object);
    if (_value != description) {
      if (updateGoldens) {
        io.File(path).writeAsStringSync(description);
        print('Updated golden file $path\nto\n$description');
        // Act like the match succeeded so all goldens are updated instead of
        // just the first failure.
        return true;
      }

      matchState[_mismatchedValueKey] = description;
      return false;
    }
    return true;
  }

  @override
  Description describe(Description description) {
    return description.add('multi line description equals $_value');
  }

  @override
  Description describeMismatch(dynamic item, Description mismatchDescription,
      Map<dynamic, dynamic> matchState, bool verbose) {
    if (matchState.containsKey(_mismatchedValueKey)) {
      final String actualValue = matchState[_mismatchedValueKey];
      // Leading whitespace is added so that lines in the multi-line
      // description returned by addDescriptionOf are all indented equally
      // which makes the output easier to read for this case.
      return mismatchDescription
          .add('expected golden file \'$path\' with normalized value\n  ')
          .addDescriptionOf(_value)
          .add('\nbut got\n  ')
          .addDescriptionOf(actualValue)
          .add('\nTo update golden files run:\n')
          .add('  tool/update_goldens.sh"\n');
    }
    return null;
  }
}
