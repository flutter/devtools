// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import '../primitives/trees.dart';
import 'primitives/object_node.dart';

/// This is placeholder, that will be replaced with concrete implementations.
class ReferencesObjectNode extends ObjectNode {
  @override
  int get childCount => 0;

  @override
  TreeNode<ObjectNode> shallowCopy() {
    throw StateError('Should not be invoked');
  }
}
