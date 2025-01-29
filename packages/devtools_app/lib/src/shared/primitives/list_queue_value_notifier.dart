// Copyright 2024 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'dart:collection';

import 'package:flutter/foundation.dart';

/// A [ChangeNotifier] that holds a [ListQueue] of data.
///
/// This class exposes methods to modify the underlying [ListQueue]. When the
/// [ListQueue] is modified, listeners are notified.
///
/// When using this class, you should NOT modify the underlying [ListQueue]
/// manually by calling [ListQueue] methods on this notifier's [value]. Doing so
/// will result in listeners not being notified for changes to the [ListQueue].
///
/// This class is not a full implementation of the [ListQueue] class, but it
/// exposes the majority of [ListQueue] methods that are useful for how this
/// class is used in DevTools. New methods can be added to this class as needed.
final class ListQueueValueNotifier<T> extends ChangeNotifier
    implements ValueListenable<ListQueue<T>> {
  /// Creates a [ListQueueValueNotifier] that wraps this value [_rawListQueue].
  ListQueueValueNotifier(this._rawListQueue);

  final ListQueue<T> _rawListQueue;

  @override
  ListQueue<T> get value => _rawListQueue;

  // Iterable interface (not a full implementation).

  bool get isEmpty => _rawListQueue.isEmpty;

  int get length => _rawListQueue.length;

  T get first => _rawListQueue.first;

  T get last => _rawListQueue.last;

  T get single => _rawListQueue.single;

  T elementAt(int index) => _rawListQueue.elementAt(index);

  void add(T value) {
    _rawListQueue.add(value);
    notifyListeners();
  }

  Iterable<T> where(bool Function(T element) test) => _rawListQueue.where(test);

  // Collection interface.

  void addAll(Iterable<T> elements) {
    _rawListQueue.addAll(elements);
    notifyListeners();
  }

  bool remove(Object? value) {
    final removed = _rawListQueue.remove(value);
    notifyListeners();
    return removed;
  }

  void removeWhere(bool Function(T element) test) {
    _rawListQueue.removeWhere(test);
    notifyListeners();
  }

  void retainWhere(bool Function(T element) test) {
    _rawListQueue.retainWhere(test);
    notifyListeners();
  }

  void clear() {
    _rawListQueue.clear();
    notifyListeners();
  }

  // Queue interface.

  void addLast(T value) {
    _rawListQueue.addLast(value);
    notifyListeners();
  }

  void addFirst(T value) {
    _rawListQueue.addFirst(value);
    notifyListeners();
  }

  T removeFirst() {
    final removed = _rawListQueue.removeFirst();
    notifyListeners();
    return removed;
  }

  T removeLast() {
    final removed = _rawListQueue.removeLast();
    notifyListeners();
    return removed;
  }
}
