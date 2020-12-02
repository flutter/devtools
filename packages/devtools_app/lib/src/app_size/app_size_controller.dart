// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:vm_snapshot_analysis/precompiler_trace.dart';
import 'package:vm_snapshot_analysis/program_info.dart';
import 'package:vm_snapshot_analysis/treemap.dart';
import 'package:vm_snapshot_analysis/utils.dart';
import 'package:vm_snapshot_analysis/v8_profile.dart';

import '../charts/treemap.dart';
import '../utils.dart';
import 'app_size_screen.dart';

enum DiffTreeType {
  increaseOnly,
  decreaseOnly,
  combined,
}

class AppSizeController {
  static const unsupportedFileTypeError =
      'Failed to load size analysis file: file type not supported.\n\n'
      'The app size tool supports Dart AOT v8 snapshots, instruction sizes, '
      'and size-analysis files. See documentation for how to generate these files.';

  static const differentTypesError =
      'Failed to load diff: OLD and NEW files are different types.';

  static const identicalFilesError =
      'Failed to load diff: OLD and NEW files are identical.';

  CallGraph _analysisCallGraph;

  ValueListenable<CallGraphNode> get analysisCallGraphRoot =>
      _analysisCallGraphRoot;
  final _analysisCallGraphRoot = ValueNotifier<CallGraphNode>(null);

  CallGraph _oldDiffCallGraph;

  CallGraph _newDiffCallGraph;

  ValueListenable<CallGraphNode> get diffCallGraphRoot => _diffCallGraphRoot;
  final _diffCallGraphRoot = ValueNotifier<CallGraphNode>(null);

  /// The node set as the analysis tab root.
  ///
  /// Used to build the treemap and the tree table for the analysis tab.
  ValueListenable<TreemapNode> get analysisRoot => _analysisRoot;
  final _analysisRoot = ValueNotifier<TreemapNode>(null);

  void changeAnalysisRoot(TreemapNode newRoot) {
    _analysisRoot.value = newRoot;

    final programInfoNode =
        _analysisCallGraph?.program?.lookup(newRoot.packagePath()) ??
            _analysisCallGraph?.program?.root;

    // If [programInfoNode is null, we don't have any call graph information
    // about [newRoot].
    if (programInfoNode != null) {
      _analysisCallGraphRoot.value = _analysisCallGraph.lookup(programInfoNode);
    }
  }

  ValueListenable<DevToolsJsonFile> get analysisJsonFile => _analysisJsonFile;
  final _analysisJsonFile = ValueNotifier<DevToolsJsonFile>(null);

  void changeAnalysisJsonFile(DevToolsJsonFile newJson) {
    _analysisJsonFile.value = newJson;
  }

  /// The node set as the diff root.
  ///
  /// Used to build the treemap and the tree table for the diff tab.
  ValueListenable<TreemapNode> get diffRoot => _diffRoot;
  final _diffRoot = ValueNotifier<TreemapNode>(null);

  void changeDiffRoot(TreemapNode newRoot) {
    _diffRoot.value = newRoot;

    final packagePath = newRoot.packagePath();
    final newProgramInfoNode = _newDiffCallGraph?.program?.lookup(packagePath);
    final newProgramInfoNodeRoot = _newDiffCallGraph?.program?.root;
    final oldProgramInfoNode = _oldDiffCallGraph?.program?.lookup(packagePath);

    if (newProgramInfoNode != null) {
      _diffCallGraphRoot.value = _newDiffCallGraph.lookup(newProgramInfoNode);
    } else if (oldProgramInfoNode != null) {
      _diffCallGraphRoot.value = _oldDiffCallGraph.lookup(oldProgramInfoNode);
    } else if (newProgramInfoNodeRoot != null) {
      _diffCallGraphRoot.value =
          _newDiffCallGraph.lookup(newProgramInfoNodeRoot);
    }
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

  ValueListenable<DevToolsJsonFile> get oldDiffJsonFile => _oldDiffJsonFile;

  final _oldDiffJsonFile = ValueNotifier<DevToolsJsonFile>(null);

  void changeOldDiffFile(DevToolsJsonFile newJsonFile) {
    _oldDiffJsonFile.value = newJsonFile;
  }

  ValueListenable<DevToolsJsonFile> get newDiffJsonFile => _newDiffJsonFile;

  final _newDiffJsonFile = ValueNotifier<DevToolsJsonFile>(null);

  void changeNewDiffFile(DevToolsJsonFile newJsonFile) {
    _newDiffJsonFile.value = newJsonFile;
  }

  void clear(Key activeTabKey) {
    if (activeTabKey == AppSizeScreen.diffTabKey) {
      _clearDiff();
    } else if (activeTabKey == AppSizeScreen.analysisTabKey) {
      _clearAnalysis();
    }
  }

  void _clearDiff() {
    _diffRoot.value = null;
    _oldDiffJsonFile.value = null;
    _newDiffJsonFile.value = null;
    _increasedDiffTreeRoot = null;
    _decreasedDiffTreeRoot = null;
    _combinedDiffTreeRoot = null;
    _diffCallGraphRoot.value = null;
    _oldDiffCallGraph = null;
    _newDiffCallGraph = null;
  }

  void _clearAnalysis() {
    _analysisRoot.value = null;
    _analysisJsonFile.value = null;
    _analysisCallGraphRoot.value = null;
    _analysisCallGraph = null;
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

  /// Notifies that the json files are currently being processed.
  ValueListenable get processingNotifier => _processingNotifier;
  final _processingNotifier = ValueNotifier<bool>(false);

  void loadTreeFromJsonFile({
    @required DevToolsJsonFile jsonFile,
    @required void Function(String error) onError,
  }) async {
    _processingNotifier.value = true;

    // Free up the thread for the app size page to display the loading message.
    // Without passing in a high value, the value listenable builder in the app
    // size screen does not get updated.
    await delayForBatchProcessing(micros: 10000);

    Map<String, dynamic> processedJson;
    if (jsonFile.isAnalyzeSizeFile) {
      // APK analysis json should be processed already.
      processedJson = jsonFile.data;

      // Extract the precompiler trace, if it exists, and generate a call graph.
      final precompilerTrace = processedJson.remove('precompiler-trace');
      if (precompilerTrace != null) {
        _analysisCallGraph = generateCallGraphWithDominators(
          precompilerTrace,
          NodeType.packageNode,
        );
      }
    } else {
      try {
        processedJson = treemapFromJson(jsonFile.data);
      } catch (error) {
        // TODO(peterdjlee): Include link to docs when hyperlink support is added to the
        //                   Notifications class. See #2268.\
        onError(unsupportedFileTypeError);
        _processingNotifier.value = false;
        return;
      }
    }

    changeAnalysisJsonFile(jsonFile);

    // Set name for root node.
    processedJson['n'] = 'Root';

    // Build a tree with [TreemapNode] from [processedJsonMap].
    final newRoot = generateTree(processedJson);

    changeAnalysisRoot(newRoot);

    _processingNotifier.value = false;
  }

  // TODO(peterdjlee): Spawn an isolate to run parts of this function to
  //                   prevent the UI from freezing and display a circular
  //                   progress indicator on app size screen. Needs flutter
  //                   web to support working with isolates. See #33577.
  void loadDiffTreeFromJsonFiles({
    @required DevToolsJsonFile oldFile,
    @required DevToolsJsonFile newFile,
    @required void Function(String error) onError,
  }) async {
    if (oldFile == null || newFile == null) {
      return;
    }

    if (oldFile.isAnalyzeSizeFile != newFile.isAnalyzeSizeFile ||
        oldFile.isV8Snapshot != newFile.isV8Snapshot) {
      onError(differentTypesError);
      return;
    }

    _processingNotifier.value = true;

    // Free up the thread for the app size page to display the loading message.
    // Without passing in a high value, the value listenable builder in the app
    // size screen does not get updated.
    await delayForBatchProcessing(micros: 10000);

    Map<String, dynamic> diffMap;
    if (oldFile.isAnalyzeSizeFile && newFile.isAnalyzeSizeFile) {
      final oldApkProgramInfo = ProgramInfo();
      _apkJsonToProgramInfo(
        program: oldApkProgramInfo,
        parent: oldApkProgramInfo.root,
        json: oldFile.data,
      );

      final Map<String, dynamic> oldFileJson = oldFile.data;
      // Extract the precompiler trace from the old file, if it exists, and
      // generate a call graph.
      final oldPrecompilerTrace = oldFileJson.remove('precompiler-trace');
      if (oldPrecompilerTrace != null) {
        _oldDiffCallGraph = generateCallGraphWithDominators(
          oldPrecompilerTrace,
          NodeType.packageNode,
        );
      }

      final newApkProgramInfo = ProgramInfo();
      _apkJsonToProgramInfo(
        program: newApkProgramInfo,
        parent: newApkProgramInfo.root,
        json: newFile.data,
      );

      final Map<String, dynamic> newFileJson = newFile.data;
      // Extract the precompiler trace from the new file, if it exists, and
      // generate a call graph.
      final newPrecompilerTrace = newFileJson.remove('precompiler-trace');
      if (newPrecompilerTrace != null) {
        _newDiffCallGraph = generateCallGraphWithDominators(
          newPrecompilerTrace,
          NodeType.packageNode,
        );
      }

      diffMap = compareProgramInfo(oldApkProgramInfo, newApkProgramInfo);
    } else {
      try {
        diffMap = buildComparisonTreemap(oldFile.data, newFile.data);
      } catch (error) {
        // TODO(peterdjlee): Include link to docs when hyperlink support is added to the
        //                    Notifications class. See #2268.
        onError(unsupportedFileTypeError);
        _processingNotifier.value = false;
        return;
      }
    }

    if (diffMap == null || (diffMap['children'] as List).isEmpty) {
      onError(identicalFilesError);
      _processingNotifier.value = false;
      return;
    }

    changeOldDiffFile(oldFile);
    changeNewDiffFile(newFile);

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

    _processingNotifier.value = false;
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
  /// between an old size analysis file and a new size analysis file.
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

extension AppSizeJsonFileExtension on DevToolsJsonFile {
  static const _supportedAnalyzeSizePlatforms = [
    'apk',
    'aab',
    'ios',
    'macos',
    'windows',
    'linux'
  ];

  bool get isAnalyzeSizeFile {
    if (data is Map<String, dynamic>) {
      final dataMap = data as Map<String, dynamic>;
      final type = dataMap['type'];
      return AppSizeJsonFileExtension._supportedAnalyzeSizePlatforms
          .contains(type);
    }
    return false;
  }

  bool get isV8Snapshot => Snapshot.isV8HeapSnapshot(data);

  String get displayText {
    return '$path - $formattedTime';
  }

  String get formattedTime {
    return DateFormat.yMd().add_jm().format(lastModifiedTime);
  }
}
