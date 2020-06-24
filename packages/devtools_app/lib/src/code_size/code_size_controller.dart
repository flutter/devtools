// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart';

import '../charts/treemap.dart';
import 'vm_treemap.dart';

class CodeSizeController {
  ValueListenable<TreemapNode> get root => _root;
  final _root = ValueNotifier<TreemapNode>(null);

  Future<void> loadTree(String filename) async {
    final codeSizePath = current + '/lib/src/code_size/';
    final inputJson = File(codeSizePath + filename);

    await inputJson.readAsString().then((inputJsonString) {
      final inputJsonMap = json.decode(inputJsonString);

      // Build a [Map] object containing heirarchical information for [inputJsonMap].
      final processedJsonMap = treemapFromJson(inputJsonMap);
      
      // Set name for root node.
      processedJsonMap['n'] = 'Root';

      // Build a tree with [TreemapNode] from [processedJsonMap].
      final newRoot = generateTreemapNode(processedJsonMap);

      changeRoot(newRoot);
    });
  }

  /// Builds a tree with TreemapNode from [treeJson] which represents
  /// the hierarchical structure of the tree.
  TreemapNode generateTreemapNode(Map<String, dynamic> treeJson) {
    var treemapNodeName = treeJson['n'];
    if (treemapNodeName == '') treemapNodeName = 'Unnamed';
    final rawChildren = treeJson['children'];
    final treemapNodeChildren = <TreemapNode>[];

    int treemapNodeSize = 0;
    if (rawChildren != null) {
      // If not a leaf node, build all children then take the sum of the
      // children's sizes as its own size.
      for (dynamic child in rawChildren) {
        final childTreemapNode = generateTreemapNode(child);
        treemapNodeChildren.add(childTreemapNode);
        treemapNodeSize += childTreemapNode.byteSize;
      }
      treemapNodeSize = treemapNodeSize;
    } else {
      // If a leaf node, just take its own size.
      // Defaults to 0 if a leaf node has a size of null.
      treemapNodeSize = treeJson['value'] ?? 0;
    }

    final root = TreemapNode(name: treemapNodeName, byteSize: treemapNodeSize);
    root.addAllChildren(treemapNodeChildren);
    return root;
  }

  void clear() {
    _root.value = null;
  }

  void changeRoot(TreemapNode newRoot) {
    _root.value = newRoot;
  }
}
