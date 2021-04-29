// Copyright 2021. The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class HistoryManager<T> extends ChangeNotifier
    implements ValueListenable<HistoryManager<T>> {
  final _history = <T>[];
  int _historyIndex = -1;

  /// Returns true if there is a previous historical item available on the
  /// stack.
  bool get hasPrevious {
    return _history.isNotEmpty && _historyIndex > 0;
  }

  /// Returns true if there is a next historical item available on the stack.
  bool get hasNext {
    return _history.isNotEmpty && _historyIndex < _history.length - 1;
  }

  /// Return the next historical item on the stack.
  ///
  /// Throws [StateError] if there's no next item available.
  T moveForward() {
    if (!hasNext) throw StateError('no next history item');

    _historyIndex++;

    notifyListeners();

    return current;
  }

  /// Return the previous historical item on the stack.
  ///
  /// Throws [StateError] if there's no previous item available.
  T moveBack() {
    if (!hasPrevious) throw StateError('no previous history item');

    _historyIndex--;

    notifyListeners();

    return current;
  }

  /// Remove and return the most recent historical item on the stack.
  ///
  /// If [current] is the last item on the stack when this method is called,
  /// [current] will be updated to return the new last item.
  ///
  /// Throws [StateError] if there's no historical items.
  T pop() {
    if (_history.isEmpty) throw StateError('no history available');

    final value = _history.removeLast();

    // If the currently selected item was popped, update the selection to the
    // last element on the stack and notify the listeners.
    if (_history.length == _historyIndex) {
      --_historyIndex;
      notifyListeners();
    }
    return value;
  }

  /// Insert a new historical item at the end of the stack and set [current] to
  /// point to the new item.
  void push(T value) {
    _history.add(value);
    _historyIndex = _history.length - 1;
    notifyListeners();
  }

  /// The currently selected historical item.
  ///
  /// Returns null if there is no historical items.
  T get current {
    return _history.isEmpty ? null : _history[_historyIndex];
  }

  @override
  HistoryManager<T> get value => this;
}
