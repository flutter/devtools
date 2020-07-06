// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:vm_snapshot_analysis/treemap.dart';
import 'package:vm_snapshot_analysis/utils.dart';

import '../charts/treemap.dart';

enum DiffTreeType {
  increaseOnly,
  decreaseOnly,
  combined,
}

class CodeSizeController {
  /// The node set as the current root.
  ValueListenable<TreemapNode> get currentRoot => _currentRoot;
  final _currentRoot = ValueNotifier<TreemapNode>(null);

  /// The active diff tree type.
  ValueListenable<DiffTreeType> get activeDiffTreeType {
    return _activeDiffTreeTypeNotifier;
  }

  final _activeDiffTreeTypeNotifier =
      ValueNotifier<DiffTreeType>(DiffTreeType.combined);

  /// The node set as the current root.
  ValueListenable<bool> get showDiffTreeTypeDropdown {
    return _showDiffTreeTypeDropdown;
  }

  final _showDiffTreeTypeDropdown = ValueNotifier<bool>(false);

  void toggleShowDiffTreeTypeDropdown(bool show) {
    _showDiffTreeTypeDropdown.value = show;
  }

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

  Future<void> loadFakeDiffData(
    String oldFilename,
    String newFilename,
    DiffTreeType diffTreeType,
  ) async {
    // TODO(peterdjlee): Use user input data instead of hard coded data.
    final pathToOldFile = '$current/lib/src/code_size/stub_data/$oldFilename';
    final oldInputJson = File(pathToOldFile);

    final pathToNewFile = '$current/lib/src/code_size/stub_data/$newFilename';
    final newInputJson = File(pathToNewFile);

    final diffMap = await buildComparisonTreemap(oldInputJson, newInputJson);
    diffMap['n'] = 'Root';
    final newRoot = generateDiffTree(diffMap, diffTreeType: diffTreeType);

    changeRoot(newRoot);
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
        if (childTreemapNode == null) {
          continue;
        }
        treemapNodeChildren.add(childTreemapNode);
        treemapNodeSize += childTreemapNode.byteSize;
      }
    } else {
      // If a leaf node, just take its own size.
      treemapNodeSize = treeJson['value'];

      // Only add nodes with a size.
      if (treemapNodeSize == null || treemapNodeSize == 0) {
        return null;
      }
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

  /// Builds a tree with [TreemapNode] from [treeJson] which represents
  /// the hierarchical structure of the tree.
  TreemapNode generateDiffTree(
    Map<String, dynamic> treeJson, {
    DiffTreeType diffTreeType = DiffTreeType.combined,
  }) {
    var treemapNodeName = treeJson['n'];
    if (treemapNodeName == '') treemapNodeName = 'Unnamed';
    final rawChildren = treeJson['children'];
    final treemapNodeChildren = <TreemapNode>[];

    int treemapNodeSize = 0;
    if (rawChildren != null) {
      // If not a leaf node, build all children then take the sum of the
      // children's sizes as its own size.
      for (dynamic child in rawChildren) {
        final childTreemapNode = generateDiffTree(
          child,
          diffTreeType: diffTreeType,
        );
        if (childTreemapNode == null) {
          continue;
        }
        treemapNodeChildren.add(childTreemapNode);
        treemapNodeSize += childTreemapNode.byteSize;
      }
    } else {
      // If a leaf node, just take its own size.
      treemapNodeSize = treeJson['value'];

      // Only add nodes with a size.
      if (treemapNodeSize == null || treemapNodeSize == 0) {
        return null;
      }

      // Only add nodes that match the diff tree type.
      switch (diffTreeType) {
        case DiffTreeType.increaseOnly:
          if (treemapNodeSize < 0) {
            return null;
          }
          break;
        case DiffTreeType.decreaseOnly:
          if (treemapNodeSize > 0) {
            return null;
          }
          break;
        case DiffTreeType.combined:
          break;
      }
    }

    final childrenMap = <String, TreemapNode>{};

    for (TreemapNode child in treemapNodeChildren) {
      childrenMap[child.name] = child;
    }

    return TreemapNode(
      name: treemapNodeName,
      byteSize: treemapNodeSize,
      childrenMap: childrenMap,
      showDiff: true,
    )..addAllChildren(treemapNodeChildren);
  }

  void clear() {
    _currentRoot.value = null;
  }

  void changeRoot(TreemapNode newRoot) {
    _currentRoot.value = newRoot;
  }

  void changeActiveDiffTreeType(DiffTreeType newDiffTreeType) {
    _activeDiffTreeTypeNotifier.value = newDiffTreeType;
    loadFakeDiffData(
      'old_v8.json',
      'new_v8.json',
      newDiffTreeType,
    );
  }
}
