// Copyright 2021. The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';

class HistoryManager<T> {
  /// The currently selected historical item.
  ///
  /// Returns null if there is no historical items.
  ValueListenable<T?> get current => _current;

  final _current = ValueNotifier<T?>(null);
  final _history = <T>[];
  int _historyIndex = -1;

  void clear() {
    _history.clear();
    _historyIndex = -1;
    _current.value = null;
  }

  /// Returns true if there is a previous historical item available on the
  /// stack.
  bool get hasPrevious {
    return _history.isNotEmpty && _historyIndex > 0;
  }

  /// Returns true if there is a next historical item available on the stack.
  bool get hasNext {
    return _history.isNotEmpty && _historyIndex < _history.length - 1;
  }

  /// Move to next historical item on the stack.
  ///
  /// Throws [StateError] if there's no next item available.
  void moveForward() {
    if (!hasNext) throw StateError('no next history item');

    _historyIndex++;
    _current.value = _history[_historyIndex];
  }

  /// Move to previous historical item on the stack.
  ///
  /// Throws [StateError] if there's no previous item available.
  void moveBack() {
    if (!hasPrevious) throw StateError('no previous history item');

    _historyIndex--;
    _current.value = _history[_historyIndex];
  }

  /// Return the next value.
  ///
  /// Returns null if there is no next value.
  T? peekNext() => hasNext ? _history[_historyIndex + 1] : null;

  /// Remove the most recent historical item on the stack.
  ///
  /// If [current] is the last item on the stack when this method is called,
  /// [current] will be updated to return the new last item.
  ///
  /// Throws [StateError] if there's no historical items.
  void pop() {
    if (_history.isEmpty) throw StateError('no history available');

    _history.removeLast();

    // If the currently selected item was popped, update the selection to the
    // last element on the stack and notify the listeners.
    if (_history.length == _historyIndex) {
      --_historyIndex;
      _current.value = _history[_historyIndex];
    }
  }

  /// Insert a new historical item at the end of the stack and set [current] to
  /// point to the new item.
  void push(T value) {
    _history.add(value);
    _historyIndex = _history.length - 1;
    _current.value = _history[_historyIndex];
  }

  /// Replaces the [current] item with a provided value.
  void replaceCurrent(T value) {
    _history[_historyIndex] = value;
    _current.value = _history[_historyIndex];
  }
}
