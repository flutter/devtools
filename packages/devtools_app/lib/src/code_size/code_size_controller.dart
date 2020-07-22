// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:vm_snapshot_analysis/treemap.dart';
import 'package:vm_snapshot_analysis/utils.dart';

import '../charts/treemap.dart';
import 'code_size_screen.dart';
import 'stub_data/app_size.dart';
import 'stub_data/new_v8.dart';
import 'stub_data/old_v8.dart';
import 'stub_data/sizes.dart';

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

  void _clearSnapshot() {
    _snapshotRoot.value = null;
    _snapshotFile.value = null;
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

  void _clearDiff() {
    _diffRoot.value = null;
    _oldDiffSnapshotFile.value = null;
    _newDiffSnapshotFile.value = null;
  }

  void clear(Key activeTabKey) {
    if (activeTabKey == CodeSizeBodyState.diffTabKey) {
      _clearDiff();
    } else if (activeTabKey == CodeSizeBodyState.snapshotTabKey) {
      _clearSnapshot();
    }
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
    );
  }

  void loadFakeTree(String pathToFile) {
    // TODO(peterdjlee): Use user input data instead of hard coded data.
    changeSnapshotFile(pathToFile);

    final json = _jsonForFile(pathToFile);
    Map<String, dynamic> processedJson;
    if (json['type'] == 'apk') {
      // App size file should be processed already.
      processedJson = json;
    } else {
      processedJson = treemapFromJson(json);
    }

    // Set name for root node.
    processedJson['n'] = 'Root';

    // Build a tree with [TreemapNode] from [processedJsonMap].
    final newRoot = generateTree(processedJson);

    changeSnapshotRoot(newRoot);
  }

  void loadFakeDiffTree(String pathToOldFile, String pathToNewFile) {
    if (pathToOldFile == null || pathToNewFile == null) {
      return;
    }
    changeOldDiffSnapshotFile(pathToOldFile);
    changeNewDiffSnapshotFile(pathToNewFile);

    // TODO(peterdjlee): Use user input data instead of hard coded data.
    final oldInputJson = _jsonForFile(pathToOldFile);
    final newInputJson = _jsonForFile(pathToNewFile);

    final diffMap = buildComparisonTreemap(oldInputJson, newInputJson);
    diffMap['n'] = 'Root';
    final newRoot = generateDiffTree(diffMap);

    changeDiffRoot(newRoot);
  }

  // TODO(kenz): This is a hack - remove this once we have a file picker.
  Map<String, dynamic> _jsonForFile(String pathToFile) {
    if (pathToFile.contains('old_v8')) return jsonDecode(oldV8);
    if (pathToFile.contains('new_v8')) return jsonDecode(newV8);
    if (pathToFile.contains('sizes')) return jsonDecode(instructionSizes);
    if (pathToFile.contains('app_size')) return jsonDecode(appSize);
    return null;
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
  TreemapNode generateDiffTree(Map<String, dynamic> treeJson) {
    final isLeafNode = treeJson['children'] == null;
    if (!isLeafNode) {
      return _buildNodeWithChildren(treeJson, showDiff: true);
    } else {
      // TODO(peterdjlee): Investigate why there are leaf nodes with size of null.
      final byteSize = treeJson['value'];
      if (byteSize == null) {
        return null;
      }
      // Only add nodes that match the diff tree type.
      switch (activeDiffTreeType.value) {
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
      final childTreemapNode =
          showDiff ? generateDiffTree(child) : generateTree(child);
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
