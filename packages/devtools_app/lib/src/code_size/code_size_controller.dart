// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:vm_snapshot_analysis/program_info.dart';
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

  TreemapNode get _activeDiffRoot {
    switch (_activeDiffTreeType.value) {
      case DiffTreeType.increaseOnly:
        assert(_increasedDiffTreeRoot != null);
        return _increasedDiffTreeRoot;
      case DiffTreeType.decreaseOnly:
        assert(_decreasedDiffTreeRoot != null);
        return _decreasedDiffTreeRoot;
      case DiffTreeType.combined:
      default:
        assert(_combinedDiffTreeRoot != null);
        return _combinedDiffTreeRoot;
    }
  }

  TreemapNode _increasedDiffTreeRoot;
  TreemapNode _decreasedDiffTreeRoot;
  TreemapNode _combinedDiffTreeRoot;

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
    _increasedDiffTreeRoot = null;
    _decreasedDiffTreeRoot = null;
    _combinedDiffTreeRoot = null;
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

  void changeActiveDiffTreeType(DiffTreeType newDiffTreeType) {
    _activeDiffTreeType.value = newDiffTreeType;
    changeDiffRoot(_activeDiffRoot);
  }

  void loadTreeFromJsonFile(DevToolsJsonFile jsonFile) {
    changeSnapshotJsonFile(jsonFile);

    Map<String, dynamic> processedJson;
    if (jsonFile.isApkFile) {
      // APK analysis json should be processed already.
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

  void loadDiffTreeFromJsonFiles(
    DevToolsJsonFile oldFile,
    DevToolsJsonFile newFile,
  ) {
    if (oldFile == null || newFile == null) return;

    changeOldDiffSnapshotFile(oldFile);
    changeNewDiffSnapshotFile(newFile);

    Map<String, dynamic> diffMap;
    if (oldFile.isApkFile && newFile.isApkFile) {
      final oldApkProgramInfo = ProgramInfo();
      _apkJsonToProgramInfo(
        program: oldApkProgramInfo,
        parent: oldApkProgramInfo.root,
        json: oldFile.data,
      );

      final newApkProgramInfo = ProgramInfo();
      _apkJsonToProgramInfo(
        program: newApkProgramInfo,
        parent: newApkProgramInfo.root,
        json: newFile.data,
      );

      diffMap = compareProgramInfo(oldApkProgramInfo, newApkProgramInfo);
    } else {
      diffMap = buildComparisonTreemap(oldFile.data, newFile.data);
    }

    diffMap['n'] = 'Root';

    // TODO(peterdjlee): Try to move the non-active tree generation to separate isolates.
    _combinedDiffTreeRoot = generateDiffTree(
      diffMap,
      DiffTreeType.combined,
    );
    _increasedDiffTreeRoot = generateDiffTree(
      diffMap,
      DiffTreeType.increaseOnly,
    );
    _decreasedDiffTreeRoot = generateDiffTree(
      diffMap,
      DiffTreeType.decreaseOnly,
    );

    changeDiffRoot(_activeDiffRoot);
  }

  ProgramInfoNode _apkJsonToProgramInfo({
    @required ProgramInfo program,
    @required ProgramInfoNode parent,
    @required Map<String, dynamic> json,
  }) {
    final bool isLeafNode = json['children'] == null;
    final node = program.makeNode(
      name: json['n'],
      parent: parent,
      type: NodeType.other,
    );

    if (!isLeafNode) {
      final List<dynamic> rawChildren = json['children'] as List<dynamic>;
      for (Map<String, dynamic> childJson in rawChildren) {
        _apkJsonToProgramInfo(program: program, parent: node, json: childJson);
      }
    } else {
      node.size = json['value'] ?? 0;
    }
    return node;
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
    Map<String, dynamic> treeJson,
    DiffTreeType diffTreeType,
  ) {
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
    DiffTreeType diffTreeType,
  }) {
    final rawChildren = treeJson['children'];
    final treemapNodeChildren = <TreemapNode>[];
    int totalByteSize = 0;

    // Given a child, build its subtree.
    for (Map<String, dynamic> child in rawChildren) {
      final childTreemapNode = showDiff
          ? generateDiffTree(child, diffTreeType)
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

extension CodeSizeJsonFileExtension on DevToolsJsonFile {
  bool get isApkFile {
    if (data is Map<String, dynamic>) {
      final dataMap = data as Map<String, dynamic>;
      return dataMap['type'] == 'apk';
    }
    return false;
  }

  String get displayText {
    return '$path - $formattedTime';
  }

  String get formattedTime {
    return DateFormat.yMd().add_jm().format(lastModifiedTime);
  }
}
