// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:vm_snapshot_analysis/treemap.dart';
import 'package:vm_snapshot_analysis/utils.dart';

import '../charts/treemap.dart';

enum DiffTreeType {
  increaseOnly,
  decreaseOnly,
  combined,
}

class CodeSizeController {
  /// The node set as the snapshot root.
  ///
  /// Used to build the treemap and the tree table for the snapshot tab.
  ValueListenable<TreemapNode> get snapshotRoot => _snapshotRoot;
  final _snapshotRoot = ValueNotifier<TreemapNode>(null);

  void changeSnapshotRoot(TreemapNode newRoot) {
    _snapshotRoot.value = newRoot;
  }

  void clearSnapshot() {
    _snapshotRoot.value = null;
    _snapshotRoot.value = null;
  }

  ValueListenable<String> get snapshotFile => _snapshotFile;
  final _snapshotFile = ValueNotifier<String>(null);

  void changeSnapshotFile(String filePath) {
    _snapshotFile.value = filePath;
  }

  /// The node set as the diff root.
  ///
  /// Used to build the treemap and the tree table for the diff tab.
  ValueListenable<TreemapNode> get diffRoot => _diffRoot;
  final _diffRoot = ValueNotifier<TreemapNode>(null);

  void changeDiffRoot(TreemapNode newRoot) {
    _diffRoot.value = newRoot;
  }

  void clearDiff() {
    _diffRoot.value = null;
    _oldDiffSnapshotFile.value = null;
    _newDiffSnapshotFile.value = null;
  }

  ValueListenable<String> get oldDiffSnapshotFile => _oldDiffSnapshotFile;
  final _oldDiffSnapshotFile = ValueNotifier<String>(null);

  void changeOldDiffSnapshotFile(String filePath) {
    _oldDiffSnapshotFile.value = filePath;
  }

  ValueListenable<String> get newDiffSnapshotFile => _newDiffSnapshotFile;
  final _newDiffSnapshotFile = ValueNotifier<String>(null);

  void changeNewDiffSnapshotFile(String filePath) {
    _newDiffSnapshotFile.value = filePath;
  }

  /// The active diff tree type used to build the diff treemap.
  ValueListenable<DiffTreeType> get activeDiffTreeType {
    return _activeDiffTreeType;
  }

  final _activeDiffTreeType =
      ValueNotifier<DiffTreeType>(DiffTreeType.combined);

  // TODO(peterdjlee): Cache each diff tree so that it's less expensive
  //                   to change bettween diff tree types.
  void changeActiveDiffTreeType(DiffTreeType newDiffTreeType) {
    _activeDiffTreeType.value = newDiffTreeType;
    loadFakeDiffTree(
      _oldDiffSnapshotFile.value,
      _newDiffSnapshotFile.value,
      diffTreeType: newDiffTreeType,
    );
  }

  Future<void> loadFakeTree(String pathToFile) async {
    // TODO(peterdjlee): Use user input data instead of hard coded data.
    changeSnapshotFile(pathToFile);
    final inputJson = File(pathToFile);

    await inputJson.readAsString().then((inputJsonString) async {
      final inputJsonMap = json.decode(inputJsonString);

      // Build a [Map] object containing heirarchical information for [inputJsonMap].
      final processedJsonMap = treemapFromJson(inputJsonMap);

      // Set name for root node.
      processedJsonMap['n'] = 'Root';

      // Build a tree with [TreemapNode] from [processedJsonMap].
      final newRoot = generateTree(processedJsonMap);

      changeSnapshotRoot(newRoot);
    });
  }

  Future<void> loadFakeDiffTree(
    String pathToOldFile,
    String pathToNewFile, {
    DiffTreeType diffTreeType = DiffTreeType.combined,
  }) async {
    changeOldDiffSnapshotFile(pathToOldFile);
    changeNewDiffSnapshotFile(pathToNewFile);

    // TODO(peterdjlee): Use user input data instead of hard coded data.
    final oldInputJson = File(pathToOldFile);
    final newInputJson = File(pathToNewFile);

    final diffMap = await buildComparisonTreemap(oldInputJson, newInputJson);
    diffMap['n'] = 'Root';
    final newRoot = generateDiffTree(diffMap, diffTreeType: diffTreeType);

    changeDiffRoot(newRoot);
  }

  TreemapNode generateTree(Map<String, dynamic> treeJson) {
    final isLeafNode = treeJson['children'] == null;
    if (!isLeafNode) {
      return _buildNodeWithChildren(treeJson);
    } else {
      // TODO(peterdjlee): Investigate why there are leaf nodes with size of null.
      final byteSize = treeJson['value'];
      if (byteSize == null) {
        return null;
      }
      return _buildNode(treeJson, byteSize);
    }
  }

  /// Recursively generates a diff tree from [treeJson] that contains the difference
  /// between an old snapshot and a new snapshot.
  ///
  /// Each node in the resulting tree represents a change in size for the given node.
  ///
  /// The tree can be filtered with different [DiffTreeType] values:
  /// * [DiffTreeType.increaseOnly]: returns a tree with nodes with positive [byteSize].
  /// * [DiffTreeType.decreaseOnly]: returns a tree with nodes with negative [byteSize].
  /// * [DiffTreeType.combined]: returns a tree with all nodes.
  TreemapNode generateDiffTree(
    Map<String, dynamic> treeJson, {
    DiffTreeType diffTreeType = DiffTreeType.combined,
  }) {
    final isLeafNode = treeJson['children'] == null;
    if (!isLeafNode) {
      return _buildNodeWithChildren(
        treeJson,
        showDiff: true,
        diffTreeType: diffTreeType,
      );
    } else {
      // TODO(peterdjlee): Investigate why there are leaf nodes with size of null.
      final byteSize = treeJson['value'];
      if (byteSize == null) {
        return null;
      }
      // Only add nodes that match the diff tree type.
      switch (diffTreeType) {
        case DiffTreeType.increaseOnly:
          if (byteSize < 0) {
            return null;
          }
          break;
        case DiffTreeType.decreaseOnly:
          if (byteSize > 0) {
            return null;
          }
          break;
        case DiffTreeType.combined:
          break;
      }
      return _buildNode(treeJson, byteSize, showDiff: true);
    }
  }

  /// Builds a node by recursively building all of its children first
  /// in order to calculate the sum of its children's sizes.
  TreemapNode _buildNodeWithChildren(
    Map<String, dynamic> treeJson, {
    bool showDiff = false,
    DiffTreeType diffTreeType = DiffTreeType.combined,
  }) {
    final rawChildren = treeJson['children'];
    final treemapNodeChildren = <TreemapNode>[];
    int totalByteSize = 0;

    // Given a child, build its subtree.
    for (Map<String, dynamic> child in rawChildren) {
      final childTreemapNode = showDiff
          ? generateDiffTree(child, diffTreeType: diffTreeType)
          : generateTree(child);
      if (childTreemapNode == null) {
        continue;
      }
      treemapNodeChildren.add(childTreemapNode);
      totalByteSize += childTreemapNode.byteSize;
    }

    // If none of the children matched the diff tree type
    if (totalByteSize == 0) {
      return null;
    } else {
      return _buildNode(
        treeJson,
        totalByteSize,
        children: treemapNodeChildren,
        showDiff: showDiff,
      );
    }
  }

  TreemapNode _buildNode(
    Map<String, dynamic> treeJson,
    int byteSize, {
    List<TreemapNode> children = const [],
    bool showDiff = false,
  }) {
    var name = treeJson['n'];
    if (name == '') {
      name = 'Unnamed';
    }
    final childrenMap = <String, TreemapNode>{};

    for (TreemapNode child in children) {
      childrenMap[child.name] = child;
    }

    return TreemapNode(
      name: name,
      byteSize: byteSize,
      childrenMap: childrenMap,
      showDiff: showDiff,
    )..addAllChildren(children);
  }
}
