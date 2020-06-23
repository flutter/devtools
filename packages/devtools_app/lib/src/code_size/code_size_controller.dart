// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:vm_snapshot_analysis/program_info.dart';
import 'package:vm_snapshot_analysis/utils.dart';

import '../charts/treemap.dart';

class CodeSizeController {
  ValueListenable<TreemapNode> get root => _root;
  final _root = ValueNotifier<TreemapNode>(null);

  Future<void> loadJsonAsProgramInfo(String filename) async {
    final directoryPath = current + '/lib/src/code_size/';
    final json = File(directoryPath + filename);
    final programInfo = await loadProgramInfo(json);
    final root = programInfo.root.toTreemapNodeTree();

    changeRoot(root);
  }

  void clear() {
    _root.value = null;
  }

  void changeRoot(TreemapNode newRoot) {
    _root.value = newRoot;
  }
}

extension on ProgramInfoNode {
  /// Converts a tree built with [ProgramInfoNode] to a tree built with [TreemapNode].
  TreemapNode toTreemapNodeTree() {
    final treeemapNodeChildren = <TreemapNode>[];
    var treemapNodeSize = 0;

    children.values.toList().forEach((child) {
      final childTreemapNodeTree = child.toTreemapNodeTree();
      treeemapNodeChildren.add(childTreemapNodeTree);
      treemapNodeSize += childTreemapNodeTree.byteSize;
    });

    // If not a leaf node, set size to the sum of children sizes.
    if (children.isNotEmpty) size = treemapNodeSize;

    // Special case checking for when a leaf node has a size of null.
    size ??= 0;

    final treemapNode = TreemapNode.fromProgramInfoNode(this);
    treemapNode.addAllChildren(treeemapNodeChildren);
    return treemapNode;
  }
}