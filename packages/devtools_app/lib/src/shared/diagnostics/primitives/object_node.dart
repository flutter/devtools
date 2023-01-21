// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import '../../primitives/trees.dart';
import '../diagnostics_node.dart';

abstract class ObjectNode extends TreeNode<ObjectNode> {
  int get childCount;

  @override
  bool get isExpandable;

  GenericInstanceRef? ref;

  /// Selects the object in the Flutter Widget inspector.
  ///
  /// Returns whether the inspector selection was changed.
  Future<bool> inspectWidget();

  Future<bool> get isInspectable;
}
