// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:collection';
import 'dart:math';

import 'package:flutter/foundation.dart';

/// A [ChangeNotifier] that holds a list of data.
///
/// This class also exposes methods to interact with the data. By default,
/// listeners are notified whenever the data is modified, but notifying can be
/// optionally disabled.
final class ListValueNotifier<T> extends ChangeNotifier
    implements ValueListenable<List<T>> {
  /// Creates a [ListValueNotifier] that wraps this value [_rawList].
  ListValueNotifier(List<T> rawList) : _rawList = List<T>.of(rawList) {
    _currentList = ImmutableList(_rawList);
  }

  List<T> _rawList;

  late ImmutableList<T> _currentList;

  @override
  List<T> get value => _currentList;

  @override
  // This override is needed to change visibility of the method.
  // ignore: unnecessary_overrides
  void notifyListeners() {
    super.notifyListeners();
  }

  void _listChanged() {
    _currentList = ImmutableList(_rawList);
    notifyListeners();
  }

  set last(T value) {
    // TODO(jacobr): use a more sophisticated data structure such as
    // https://en.wikipedia.org/wiki/Rope_(data_structure) to make last more
    // efficient.
    _rawList = _rawList.toList();
    _rawList.last = value;
    _listChanged();
  }

  /// Adds an element to the list and notifies listeners.
  void add(T element) {
    _rawList.add(element);
    _listChanged();
  }

  /// Replaces the first occurrence of [value] in this list.
  ///
  /// Runtime is O(n).
  bool replace(T existing, T replacement) {
    final index = _rawList.indexOf(existing);
    if (index == -1) return false;
    _rawList = _rawList.toList();
    _rawList.removeAt(index);
    _rawList.insert(index, replacement);
    _listChanged();
    return true;
  }

  /// Replaces all elements in the list and notifies listeners. It's preferred
  /// to calling .clear() then .addAll(), because it only notifies listeners
  /// once.
  void replaceAll(Iterable<T> elements) {
    _rawList = <T>[];
    _rawList.addAll(elements);
    _listChanged();
  }

  /// Adds elements to the list and notifies listeners.
  void addAll(Iterable<T> elements) {
    _rawList.addAll(elements);
    _listChanged();
  }

  void removeAll(Iterable<T> elements) {
    elements.forEach(_rawList.remove);
    _listChanged();
  }

  /// Clears the list and notifies listeners.
  void clear() {
    _rawList = <T>[];
    _listChanged();
  }

  /// Truncates to just the elements between [start] and [end].
  ///
  /// If [end] is omitted, it defaults to the [length] of this list.
  ///
  /// The `start` and `end` positions must satisfy the relations
  /// 0 ≤ `start` ≤ `end` ≤ [length]
  /// If `end` is equal to `start`, then the returned list is empty.
  void trimToSublist(int start, [int? end]) {
    // TODO(jacobr): use a more sophisticated data structure such as
    // https://en.wikipedia.org/wiki/Rope_(data_structure) to make the
    // implementation of this method more efficient.
    _rawList = _rawList.sublist(start, end);
    _listChanged();
  }

  /// Removes the first occurrence of [value] from this list.
  ///
  /// Runtime is O(n).
  bool remove(T value) {
    final index = _rawList.indexOf(value);
    if (index == -1) return false;
    _rawList = _rawList.toList();
    _rawList.removeAt(index);
    _listChanged();
    return true;
  }

  /// Removes a range of elements from the list.
  ///
  /// https://api.flutter.dev/flutter/dart-core/List/removeRange.html
  void removeRange(int start, int end) {
    _rawList = _rawList.toList();
    _rawList.removeRange(start, end);
    _listChanged();
  }

  /// Removes the object at position `index` from this list.
  ///
  /// https://api.flutter.dev/flutter/dart-core/List/removeAt.html
  void removeAt(int index) {
    _rawList = _rawList.toList();
    _rawList.removeAt(index);
    _listChanged();
  }
}

/// Wrapper for a list that prevents any modification of the list's content.
///
/// This class should only be used as part of [ListValueNotifier].
@visibleForTesting
class ImmutableList<T> with ListMixin<T> implements List<T> {
  ImmutableList(this._rawList) : length = _rawList.length;

  final List<T> _rawList;

  @override
  int length;

  @override
  T operator [](int index) {
    if (index >= 0 && index < length) {
      return _rawList[index];
    } else {
      throw Exception('Index out of range [0-${length - 1}]: $index');
    }
  }

  @override
  void operator []=(int index, T value) {
    throw Exception('Cannot modify the content of ImmutableList');
  }

  @override
  void add(T element) {
    throw Exception('Cannot modify the content of ImmutableList');
  }

  @override
  void addAll(Iterable<T> iterable) {
    throw Exception('Cannot modify the content of ImmutableList');
  }

  @override
  bool remove(Object? element) {
    throw Exception('Cannot modify the content of ImmutableList');
  }

  @override
  T removeAt(int index) {
    throw Exception('Cannot modify the content of ImmutableList');
  }

  @override
  T removeLast() {
    throw Exception('Cannot modify the content of ImmutableList');
  }

  @override
  void removeRange(int start, int end) {
    throw Exception('Cannot modify the content of ImmutableList');
  }

  @override
  void removeWhere(bool Function(T element) test) {
    throw Exception('Cannot modify the content of ImmutableList');
  }

  @override
  void retainWhere(bool Function(T element) test) {
    throw Exception('Cannot modify the content of ImmutableList');
  }

  @override
  void insert(int index, T element) {
    throw Exception('Cannot modify the content of ImmutableList');
  }

  @override
  void insertAll(int index, Iterable<T> iterable) {
    throw Exception('Cannot modify the content of ImmutableList');
  }

  @override
  void clear() {
    throw Exception('Cannot modify the content of ImmutableList');
  }

  @override
  void fillRange(int start, int end, [T? fill]) {
    throw Exception('Cannot modify the content of ImmutableList');
  }

  @override
  void setRange(int start, int end, Iterable<T> iterable, [int skipCount = 0]) {
    throw Exception('Cannot modify the content of ImmutableList');
  }

  @override
  void replaceRange(int start, int end, Iterable<T> newContents) {
    throw Exception('Cannot modify the content of ImmutableList');
  }

  @override
  void setAll(int index, Iterable<T> iterable) {
    throw Exception('Cannot modify the content of ImmutableList');
  }

  @override
  void sort([int Function(T a, T b)? compare]) {
    throw Exception('Cannot modify the content of ImmutableList');
  }

  @override
  void shuffle([Random? random]) {
    throw Exception('Cannot modify the content of ImmutableList');
  }
}
