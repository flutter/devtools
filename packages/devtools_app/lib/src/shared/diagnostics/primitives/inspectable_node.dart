// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import '../../primitives/trees.dart';

abstract class InspectableNode<T extends InspectableNode<T>>
    extends TreeNode<T> {
  int get childCount;

  @override
  bool get isExpandable;

  String? get displayValue;

  /// Selects the object in the Flutter Widget inspector.
  ///
  /// Returns whether the inspector selection was changed.
  Future<bool> inspectWidget();

  Future<bool> get isInspectable;
}
