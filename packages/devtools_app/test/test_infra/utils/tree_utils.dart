// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/shared/primitives/trees.dart';

extension TreeNodeList<T extends TreeNode<T>> on List<T> {
  int get numNodes {
    return fold<int>(0, (prev, next) {
      int count = 0;
      breadthFirstTraversal<T>(
        next,
        action: (node) => count++,
      );
      return prev + count;
    });
  }
}
