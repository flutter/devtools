// Copyright 2020 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

/// Store and manipulate the expression evaluation history.
class EvalHistory {
  var _historyPosition = -1;

  /// Get the expression evaluation history.
  List<String> get evalHistory => _evalHistory.toList();

  final _evalHistory = <String>[];

  /// Push a new entry onto the expression evaluation history.
  void pushEvalHistory(String expression) {
    if (_evalHistory.isNotEmpty && _evalHistory.last == expression) {
      return;
    }

    _evalHistory.add(expression);
    _historyPosition = -1;
  }

  bool get canNavigateUp {
    return _evalHistory.isNotEmpty && _historyPosition != 0;
  }

  void navigateUp() {
    if (_historyPosition == -1) {
      _historyPosition = _evalHistory.length - 1;
    } else if (_historyPosition > 0) {
      _historyPosition--;
    }
  }

  bool get canNavigateDown {
    return _evalHistory.isNotEmpty && _historyPosition != -1;
  }

  void navigateDown() {
    if (_historyPosition != -1) {
      _historyPosition++;
    }
    if (_historyPosition >= _evalHistory.length) {
      _historyPosition = -1;
    }
  }

  String? get currentText {
    return _historyPosition == -1 ? null : _evalHistory[_historyPosition];
  }
}
