// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

library matchers;

import 'package:devtools/inspector/diagnostics_node.dart';

RemoteDiagnosticsNode findNodeMatching(
    RemoteDiagnosticsNode node, String text) {
  if (node.name?.startsWith(text) == true ||
      node.description?.startsWith(text) == true) {
    return node;
  }
  if (node.childrenNow == null) {
    return null;
  }
  for (var child in node.childrenNow) {
    var match = findNodeMatching(child, text);
    if (match != null) {
      return match;
    }
  }
  return null;
}

String treeToDebugString(RemoteDiagnosticsNode node) {
  return node.toDiagnosticsNode().toStringDeep();
}
