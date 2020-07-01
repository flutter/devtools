// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:vm_snapshot_analysis/treemap.dart';

import '../charts/treemap.dart';
import 'stub_data/fake_data.dart';

class CodeSizeController {
  /// The node set as the current root.
  ValueListenable<TreemapNode> get currentRoot => _currentRoot;
  final _currentRoot = ValueNotifier<TreemapNode>(null);

  Future<void> loadTree(String filename) async {
    // TODO(peterdjlee): Use user input data instead of hard coded data.
    final pathToFile = '$current/lib/src/code_size/stub_data/$filename';
    final inputJson = File(pathToFile);

    await inputJson.readAsString().then((inputJsonString) async {
      final inputJsonMap = json.decode(inputJsonString);

      // Build a [Map] object containing heirarchical information for [inputJsonMap].
      final processedJsonMap = treemapFromJson(inputJsonMap);

      // Set name for root node.
      processedJsonMap['n'] = 'Root';

      // Build a tree with [TreemapNode] from [processedJsonMap].
      final newRoot = generateTree(processedJsonMap);

      changeRoot(newRoot);
    });
  }

  void loadFakeDiffData() {
    changeRoot(fakeRoot);
  }

  /// Builds a tree with [TreemapNode] from [treeJson] which represents
  /// the hierarchical structure of the tree.
  TreemapNode generateTree(Map<String, dynamic> treeJson) {
    var treemapNodeName = treeJson['n'];
    if (treemapNodeName == '') treemapNodeName = 'Unnamed';
    final rawChildren = treeJson['children'];
    final treemapNodeChildren = <TreemapNode>[];

    int treemapNodeSize = 0;
    if (rawChildren != null) {
      // If not a leaf node, build all children then take the sum of the
      // children's sizes as its own size.
      for (dynamic child in rawChildren) {
        final childTreemapNode = generateTree(child);
        treemapNodeChildren.add(childTreemapNode);
        treemapNodeSize += childTreemapNode.byteSize;
      }
    } else {
      // If a leaf node, just take its own size.
      // Defaults to 0 if a leaf node has a size of null.
      treemapNodeSize = treeJson['value'] ?? 0;
    }

    final childrenMap = <String, TreemapNode>{};

    for (TreemapNode child in treemapNodeChildren) {
      childrenMap[child.name] = child;
    }

    return TreemapNode(
      name: treemapNodeName,
      byteSize: treemapNodeSize,
      childrenMap: childrenMap,
    )..addAllChildren(treemapNodeChildren);
  }

  void clear() {
    _currentRoot.value = null;
  }

  void changeRoot(TreemapNode newRoot) {
    _currentRoot.value = newRoot;
  }
}
