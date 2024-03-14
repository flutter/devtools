// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'adapted_heap_object.dart';
import 'simple_items.dart';

/// Mark the object as deeply immutable.
///
/// There is no strong protection from mutation, just some asserts.
mixin Sealable {
  /// See doc for the mixin [Sealable].
  void seal() {
    _isSealed = true;
  }

  /// See doc for the mixin [Sealable].
  bool get isSealed => _isSealed;
  bool _isSealed = false;
}

/// Statistical size-information about objects.
class ObjectSetStats with Sealable {
  static ObjectSetStats? subtract({
    required ObjectSetStats? subtract,
    required ObjectSetStats? from,
  }) {
    from ??= _empty;
    subtract ??= _empty;

    final result = ObjectSetStats()
      ..instanceCount = from.instanceCount - subtract.instanceCount
      ..shallowSize = from.shallowSize - subtract.shallowSize
      ..retainedSize = from.retainedSize - subtract.retainedSize;

    if (result.isZero) return null;
    return result;
  }

  static final _empty = ObjectSetStats()..seal();

  int instanceCount = 0;
  int shallowSize = 0;
  int retainedSize = 0;

  bool get isZero =>
      shallowSize == 0 && retainedSize == 0 && instanceCount == 0;

  void countInstance(
    AdaptedHeapObject object, {
    required bool excludeFromRetained,
  }) {
    assert(!isSealed);
    if (!excludeFromRetained) retainedSize += object.retainedSize!;
    shallowSize += object.shallowSize;
    instanceCount++;
  }

  void uncountInstance(
    AdaptedHeapObject object, {
    required bool excludeFromRetained,
  }) {
    assert(!isSealed);
    if (!excludeFromRetained) retainedSize -= object.retainedSize!;
    shallowSize -= object.shallowSize;
    instanceCount--;
  }
}

/// Statistical and detailed size-information about objects.
class ObjectSet extends ObjectSetStats {
  static ObjectSet empty = ObjectSet()..seal();

  final objectsByCodes = <IdentityHashCode, AdaptedHeapObject>{};

  /// Subset of objects that are excluded from the retained size
  /// calculation for this set.
  ///
  /// See [countInstance].
  final objectsExcludedFromRetainedSize = <IdentityHashCode>{};

  @override
  bool get isZero => objectsByCodes.isEmpty;

  @override
  void countInstance(
    AdaptedHeapObject object, {
    required bool excludeFromRetained,
  }) {
    if (objectsByCodes.containsKey(object.code)) return;
    super.countInstance(object, excludeFromRetained: excludeFromRetained);
    objectsByCodes[object.code] = object;
    if (excludeFromRetained) objectsExcludedFromRetainedSize.add(object.code);
  }

  @override
  void uncountInstance(
    AdaptedHeapObject object, {
    required bool excludeFromRetained,
  }) {
    throw AssertionError('uncountInstance is not valid for $ObjectSet');
  }
}
