// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:vm_snapshot_analysis/treemap.dart';
import 'package:vm_snapshot_analysis/utils.dart';

import '../charts/treemap.dart';
import '../utils.dart';
import 'code_size_screen.dart';

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

  ValueListenable<DevToolsJsonFile> get snapshotJsonFile => _snapshotJsonFile;
  final _snapshotJsonFile = ValueNotifier<DevToolsJsonFile>(null);

  void changeSnapshotJsonFile(DevToolsJsonFile newJson) {
    _snapshotJsonFile.value = newJson;
  }

  void _clearSnapshot() {
    _snapshotRoot.value = null;
    _snapshotJsonFile.value = null;
  }

  /// The node set as the diff root.
  ///
  /// Used to build the treemap and the tree table for the diff tab.
  ValueListenable<TreemapNode> get diffRoot => _diffRoot;
  final _diffRoot = ValueNotifier<TreemapNode>(null);

  void changeDiffRoot(TreemapNode newRoot) {
    _diffRoot.value = newRoot;
  }

  ValueListenable<DevToolsJsonFile> get oldDiffSnapshotJsonFile {
    return _oldDiffSnapshotJsonFile;
  }

  final _oldDiffSnapshotJsonFile = ValueNotifier<DevToolsJsonFile>(null);
  void changeOldDiffSnapshotFile(DevToolsJsonFile newJsonFile) {
    _oldDiffSnapshotJsonFile.value = newJsonFile;
  }

  ValueListenable<DevToolsJsonFile> get newDiffSnapshotJsonFile {
    return _newDiffSnapshotJsonFile;
  }

  final _newDiffSnapshotJsonFile = ValueNotifier<DevToolsJsonFile>(null);
  void changeNewDiffSnapshotFile(DevToolsJsonFile newJsonFile) {
    _newDiffSnapshotJsonFile.value = newJsonFile;
  }

  void _clearDiff() {
    _diffRoot.value = null;
    _oldDiffSnapshotJsonFile.value = null;
    _newDiffSnapshotJsonFile.value = null;
  }

  void clear(Key activeTabKey) {
    if (activeTabKey == CodeSizeScreen.diffTabKey) {
      _clearDiff();
    } else if (activeTabKey == CodeSizeScreen.snapshotTabKey) {
      _clearSnapshot();
    }
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
      _oldDiffSnapshotJsonFile.value,
      _newDiffSnapshotJsonFile.value,
    );
  }

  // TODO(peterdjlee): Use user input data instead of hard coded data.
  void loadFakeTree(DevToolsJsonFile jsonFile) {
    changeSnapshotJsonFile(jsonFile);

    Map<String, dynamic> processedJson;
    if (jsonFile.isApkFile) {
      // APK analysis json should be processed already.a
      processedJson = jsonFile.data;
    } else {
      processedJson = treemapFromJson(jsonFile.data);
    }

    // Set name for root node.
    processedJson['n'] = 'Root';

    // Build a tree with [TreemapNode] from [processedJsonMap].
    final newRoot = generateTree(processedJson);

    changeSnapshotRoot(newRoot);
  }

  // TODO(peterdjlee): Use user input data instead of hard coded data.
  void loadFakeDiffTree(
    DevToolsJsonFile oldJsonFile,
    DevToolsJsonFile newJsonFile,
  ) {
    changeOldDiffSnapshotFile(oldJsonFile);
    changeNewDiffSnapshotFile(newJsonFile);

    final diffMap = buildComparisonTreemap(oldJsonFile.data, newJsonFile.data);
    diffMap['n'] = 'Root';
    final newRoot = generateDiffTree(diffMap);

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

extension CodeSizeJsonFileExtension on DevToolsJsonFile {
  bool get isApkFile => data['type'] == 'apk';

  String get displayText {
    return '$path - $formattedTime';
  }

  String get formattedTime {
    return DateFormat.yMd().add_jm().format(lastModifiedTime);
  }
}
