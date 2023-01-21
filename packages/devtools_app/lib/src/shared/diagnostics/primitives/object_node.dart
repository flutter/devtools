// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import '../../primitives/trees.dart';
import '../diagnostics_node.dart';

abstract class ObjectNode extends TreeNode<ObjectNode> {
  int get childCount;

  GenericInstanceRef? ref;
}
