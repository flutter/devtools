// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:vm_snapshot_analysis/precompiler_trace.dart';
import 'package:vm_snapshot_analysis/program_info.dart';
import 'package:vm_snapshot_analysis/treemap.dart';
import 'package:vm_snapshot_analysis/utils.dart';
import 'package:vm_snapshot_analysis/v8_profile.dart';

import '../../shared/charts/treemap.dart';
import '../../shared/primitives/utils.dart';
import '../../shared/table/table.dart';
import '../../shared/ui/colors.dart';
import 'app_size_screen.dart';

// Temporary feature flag for deferred loading.
bool deferredLoadingSupportEnabled = false;

const _artificialRootNodeName = 'ArtificialRoot';
const _entireAppNodeName = 'Entire App';
const _deferredNodeName = 'Deferred';
const _mainNodeName = 'Main';
const _rootNodeName = 'Root';

enum DiffTreeType {
  increaseOnly,
  decreaseOnly,
  combined;

  String get display {
    switch (this) {
      case DiffTreeType.increaseOnly:
        return 'Increase Only';
      case DiffTreeType.decreaseOnly:
        return 'Decrease Only';
      case DiffTreeType.combined:
      default:
        return 'Combined';
    }
  }
}

enum AppUnit {
  mainOnly,
  deferredOnly,
  entireApp;

  String get display {
    switch (this) {
      case AppUnit.deferredOnly:
        return _deferredNodeName;
      case AppUnit.mainOnly:
        return _mainNodeName;
      case AppUnit.entireApp:
      default:
        return _entireAppNodeName;
    }
  }
}

class DiffTreeMap {
  const DiffTreeMap({
    required this.combined,
    required this.increaseOnly,
    required this.decreaseOnly,
  });

  final TreemapNode? combined;

  final TreemapNode? increaseOnly;

  final TreemapNode? decreaseOnly;
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

  CallGraph? _analysisCallGraph;

  ValueListenable<CallGraphNode?> get analysisCallGraphRoot =>
      _analysisCallGraphRoot;
  final _analysisCallGraphRoot = ValueNotifier<CallGraphNode?>(null);

  CallGraph? _oldDiffCallGraph;

  CallGraph? _newDiffCallGraph;

  ValueListenable<CallGraphNode?> get diffCallGraphRoot => _diffCallGraphRoot;
  final _diffCallGraphRoot = ValueNotifier<CallGraphNode?>(null);

  /// The node set as the analysis tab root.
  ///
  /// Used to build the treemap and the tree table for the analysis tab.
  final analysisRoot =
      ValueNotifier<Selection<TreemapNode?>>(Selection.empty());

  ValueListenable<bool> get isDeferredApp => _isDeferredApp;
  final _isDeferredApp = ValueNotifier<bool>(false);

  void changeAnalysisRoot(TreemapNode? newAnalysisRoot) {
    if (newAnalysisRoot == null) {
      analysisRoot.value = Selection.empty();
      return;
    }

    analysisRoot.value = Selection(
      node: newAnalysisRoot,
      nodeIndexCalculator: nodeIndexCalculator,
      scrollIntoView: true,
    );

    final programInfoNode =
        _analysisCallGraph?.program.lookup(newAnalysisRoot.packagePath()) ??
            _analysisCallGraph?.program.root;

    // If [programInfoNode is null, we don't have any call graph information
    // about [newRoot].
    if (programInfoNode != null) {
      _analysisCallGraphRoot.value =
          _analysisCallGraph!.lookup(programInfoNode);
    }
  }

  int? nodeIndexCalculator(TreemapNode? newAnalysisRoot) {
    if (newAnalysisRoot == null) return null;
    bool searchCondition(TreemapNode? n) => n == newAnalysisRoot;
    if (!newAnalysisRoot.root.isExpanded) newAnalysisRoot.root.expand();
    final nodeIndex = newAnalysisRoot.root.childCountToMatchingNode(
      matchingNodeCondition: searchCondition,
      includeCollapsedNodes: false,
    );
    return isDeferredApp.value ? nodeIndex - 1 : nodeIndex;
  }

  ValueListenable<DevToolsJsonFile?> get analysisJsonFile => _analysisJsonFile;
  final _analysisJsonFile = ValueNotifier<DevToolsJsonFile?>(null);

  void changeAnalysisJsonFile(DevToolsJsonFile newJson) {
    _analysisJsonFile.value = newJson;
  }

  /// The node set as the diff root.
  ///
  /// Used to build the treemap and the tree table for the diff tab.
  ValueListenable<TreemapNode?> get diffRoot => _diffRoot;
  final _diffRoot = ValueNotifier<TreemapNode?>(null);

  void changeDiffRoot(TreemapNode? newRoot) {
    _diffRoot.value = newRoot;
    if (newRoot == null) return;

    final packagePath = newRoot.packagePath();
    final newProgramInfoNode = _newDiffCallGraph?.program.lookup(packagePath);
    final newProgramInfoNodeRoot = _newDiffCallGraph?.program.root;
    final oldProgramInfoNode = _oldDiffCallGraph?.program.lookup(packagePath);

    if (newProgramInfoNode != null) {
      _diffCallGraphRoot.value = _newDiffCallGraph!.lookup(newProgramInfoNode);
    } else if (oldProgramInfoNode != null) {
      _diffCallGraphRoot.value = _oldDiffCallGraph!.lookup(oldProgramInfoNode);
    } else if (newProgramInfoNodeRoot != null) {
      _diffCallGraphRoot.value =
          _newDiffCallGraph!.lookup(newProgramInfoNodeRoot);
    }
  }

  DiffTreeMap? get _activeDiffMap {
    final appUnit = _selectedAppUnit.value;

    switch (appUnit) {
      case AppUnit.mainOnly:
        return _mainDiffTreeMap;
      case AppUnit.deferredOnly:
        return _deferredDiffTreeMap;
      case AppUnit.entireApp:
      default:
        return _diffTreeMap;
    }
  }

  TreemapNode? get _activeDiffRoot {
    final diffTreeType = _activeDiffTreeType.value;
    final diffMap = _activeDiffMap;

    if (diffMap == null) {
      return null;
    }

    switch (diffTreeType) {
      case DiffTreeType.increaseOnly:
        return diffMap.increaseOnly;
      case DiffTreeType.decreaseOnly:
        return diffMap.decreaseOnly;
      case DiffTreeType.combined:
        return diffMap.combined;
      default:
        return diffMap.combined;
    }
  }

  DiffTreeMap? _diffTreeMap;
  DiffTreeMap? _mainDiffTreeMap;
  DiffTreeMap? _deferredDiffTreeMap;

  Map<String, dynamic>? get _dataForAppUnit {
    switch (_selectedAppUnit.value) {
      case AppUnit.deferredOnly:
        return _deferredOnly;
      case AppUnit.mainOnly:
        return _mainOnly;
      case AppUnit.entireApp:
      default:
        return _entireApp;
    }
  }

  Map<String, dynamic>? _deferredOnly;
  Map<String, dynamic>? _mainOnly;
  Map<String, dynamic>? _entireApp;

  ValueListenable<DevToolsJsonFile?> get oldDiffJsonFile => _oldDiffJsonFile;

  final _oldDiffJsonFile = ValueNotifier<DevToolsJsonFile?>(null);

  void changeOldDiffFile(DevToolsJsonFile newJsonFile) {
    _oldDiffJsonFile.value = newJsonFile;
  }

  ValueListenable<DevToolsJsonFile?> get newDiffJsonFile => _newDiffJsonFile;

  final _newDiffJsonFile = ValueNotifier<DevToolsJsonFile?>(null);

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
    _diffTreeMap = null;
    _mainDiffTreeMap = null;
    _deferredDiffTreeMap = null;
    _diffCallGraphRoot.value = null;
    _oldDiffCallGraph = null;
    _newDiffCallGraph = null;
  }

  void _clearAnalysis() {
    analysisRoot.value = Selection.empty();
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

  /// The selected app segment to analyze (for deferred apps only).
  ValueListenable<AppUnit> get selectedAppUnit => _selectedAppUnit;
  final _selectedAppUnit = ValueNotifier<AppUnit>(AppUnit.entireApp);

  void changeSelectedAppUnit(AppUnit appUnit, Key tabKey) {
    _selectedAppUnit.value = appUnit;
    if (tabKey == AppSizeScreen.analysisTabKey) {
      _loadApp(_dataForAppUnit!);
    } else {
      changeDiffRoot(_activeDiffRoot);
    }
  }

  /// Notifies that the json files are currently being processed.
  ValueListenable<bool> get processingNotifier => _processingNotifier;
  final _processingNotifier = ValueNotifier<bool>(false);

  void loadTreeFromJsonFile({
    required DevToolsJsonFile jsonFile,
    required void Function(String error) onError,
  }) async {
    _processingNotifier.value = true;

    // Free up the thread for the app size page to display the loading message.
    // Without passing in a high value, the value listenable builder in the app
    // size screen does not get updated.
    await delayToReleaseUiThread(micros: 10000);

    Map<String, dynamic> processedJson;
    if (jsonFile.isAnalyzeSizeFile) {
      // APK analysis json should be processed already.
      processedJson = jsonFile.data as Map<String, dynamic>;

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

    // Set deferred app flag.
    _isDeferredApp.value =
        deferredLoadingSupportEnabled && _hasDeferredInfo(processedJson);

    if (isDeferredApp.value) {
      _deferredOnly = _extractDeferredUnits(Map.from(processedJson));
      _mainOnly = _extractMainUnit(Map.from(processedJson));
      _entireApp = _includeEntireApp(Map.from(processedJson));
      _loadApp(_dataForAppUnit!);
    } else {
      // Set root name for non-deferred apps.
      processedJson['n'] = _rootNodeName;
      _loadApp(processedJson);
    }

    _processingNotifier.value = false;
  }

  void _loadApp(Map<String, dynamic> appData) {
    // Build a tree with [TreemapNode] from [appData].
    final appRoot = generateTree(appData)!;
    changeAnalysisRoot(appRoot);
  }

  bool _hasDeferredInfo(Map<String, dynamic> jsonFile) {
    return jsonFile['n'] == _artificialRootNodeName;
  }

  Map<String, dynamic> _extractMainUnit(Map<String, dynamic> jsonFile) {
    if (_hasDeferredInfo(jsonFile)) {
      final main = _extractChildren(jsonFile).firstWhere(
        (child) => child['n'] == _mainNodeName,
        orElse: () => jsonFile,
      );
      return main;
    }
    return jsonFile;
  }

  Map<String, dynamic> _extractDeferredUnits(
    Map<String, dynamic> jsonFile,
  ) {
    if (_hasDeferredInfo(jsonFile)) {
      jsonFile['children'] = _extractChildren(jsonFile)
          .where((child) => child['isDeferred'] == true)
          .toList();
      jsonFile['n'] = _deferredNodeName;
    }
    return jsonFile;
  }

  Map<String, dynamic> _includeEntireApp(Map<String, dynamic> jsonFile) {
    if (_hasDeferredInfo(jsonFile)) {
      jsonFile['n'] = _entireAppNodeName;
    }
    return jsonFile;
  }

  List<Map<String, dynamic>> _extractChildren(Map<String, dynamic> jsonFile) {
    return (jsonFile['children'] as Iterable)
        .whereType<Map<String, dynamic>>()
        .toList();
  }

  // TODO(peterdjlee): Spawn an isolate to run parts of this function to
  //                   prevent the UI from freezing and display a circular
  //                   progress indicator on app size screen. Needs flutter
  //                   web to support working with isolates. See #33577.
  void loadDiffTreeFromJsonFiles({
    required DevToolsJsonFile oldFile,
    required DevToolsJsonFile newFile,
    required void Function(String error) onError,
  }) async {
    if (oldFile.isAnalyzeSizeFile != newFile.isAnalyzeSizeFile ||
        oldFile.isV8Snapshot != newFile.isV8Snapshot) {
      onError(differentTypesError);
      return;
    }

    _processingNotifier.value = true;

    // Free up the thread for the app size page to display the loading message.
    // Without passing in a high value, the value listenable builder in the app
    // size screen does not get updated.
    await delayToReleaseUiThread(micros: 10000);

    Map<String, dynamic> diffMap;
    Map<String, dynamic>? mainDiffMap;
    Map<String, dynamic>? deferredDiffMap;

    if (oldFile.isAnalyzeSizeFile && newFile.isAnalyzeSizeFile) {
      final oldFileJson = oldFile.data as Map<String, dynamic>;
      final newFileJson = newFile.data as Map<String, dynamic>;

      if (!_hasDeferredInfo(oldFileJson) && !_hasDeferredInfo(newFileJson)) {
        diffMap = _generateDiffMapFromAnalyzeSizeFiles(
          oldFileJson: oldFileJson,
          newFileJson: newFileJson,
        );
      } else {
        _isDeferredApp.value = deferredLoadingSupportEnabled;
        Map<String, dynamic> oldEntireAppFileJson = oldFileJson;
        Map<String, dynamic> newEntireAppFileJson = newFileJson;

        if (!_hasDeferredInfo(oldFileJson)) {
          oldEntireAppFileJson = _wrapInArtificialRoot(oldFileJson);
        } else if (!_hasDeferredInfo(newFileJson)) {
          newEntireAppFileJson = _wrapInArtificialRoot(newFileJson);
        }

        final oldMainOnlyFileJson =
            _extractMainUnit(Map.from(oldEntireAppFileJson));
        final newMainOnlyFileJson =
            _extractMainUnit(Map.from(newEntireAppFileJson));

        final oldDeferredOnlyFileJson =
            _extractDeferredUnits(Map.from(oldEntireAppFileJson));
        final newDeferredOnlyFileJson =
            _extractDeferredUnits(Map.from(newEntireAppFileJson));

        diffMap = _generateDiffMapFromAnalyzeSizeFiles(
          oldFileJson: oldEntireAppFileJson,
          newFileJson: newEntireAppFileJson,
        );

        mainDiffMap = _generateDiffMapFromAnalyzeSizeFiles(
          oldFileJson: oldMainOnlyFileJson,
          newFileJson: newMainOnlyFileJson,
        );

        deferredDiffMap = _generateDiffMapFromAnalyzeSizeFiles(
          oldFileJson: oldDeferredOnlyFileJson,
          newFileJson: newDeferredOnlyFileJson,
        );
      }
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

    if ((diffMap['children'] as List).isEmpty) {
      onError(identicalFilesError);
      _processingNotifier.value = false;
      return;
    }

    changeOldDiffFile(oldFile);
    changeNewDiffFile(newFile);

    diffMap['n'] = isDeferredApp.value ? _entireAppNodeName : _rootNodeName;

    // TODO(peterdjlee): Try to move the non-active tree generation to separate isolates.
    // Entire app or root (for non-deferred):
    _diffTreeMap = _generateDiffTrees(diffMap);

    if (isDeferredApp.value) {
      // For main only.
      _mainDiffTreeMap = _generateDiffTrees(mainDiffMap!);

      // For deferred only.
      _deferredDiffTreeMap = _generateDiffTrees(deferredDiffMap!);
    }

    changeDiffRoot(_activeDiffRoot);

    _processingNotifier.value = false;
  }

  DiffTreeMap _generateDiffTrees(Map<String, dynamic> diffMap) {
    // TODO(peterdjlee): Try to move the non-active tree generation to separate isolates.
    return DiffTreeMap(
      combined: generateDiffTree(
        diffMap,
        DiffTreeType.combined,
        skipNodesWithNoByteSizeChange: !isDeferredApp.value,
      ),
      increaseOnly: generateDiffTree(
        diffMap,
        DiffTreeType.increaseOnly,
        skipNodesWithNoByteSizeChange: !isDeferredApp.value,
      ),
      decreaseOnly: generateDiffTree(
        diffMap,
        DiffTreeType.decreaseOnly,
        skipNodesWithNoByteSizeChange: !isDeferredApp.value,
      ),
    );
  }

  Map<String, dynamic> _generateDiffMapFromAnalyzeSizeFiles({
    required Map<String, dynamic> oldFileJson,
    required Map<String, dynamic> newFileJson,
  }) {
    final oldApkProgramInfo = ProgramInfo();
    _apkJsonToProgramInfo(
      program: oldApkProgramInfo,
      parent: oldApkProgramInfo.root,
      json: oldFileJson,
    );

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
      json: newFileJson,
    );

    // Extract the precompiler trace from the new file, if it exists, and
    // generate a call graph.
    final newPrecompilerTrace = newFileJson.remove('precompiler-trace');
    if (newPrecompilerTrace != null) {
      _newDiffCallGraph = generateCallGraphWithDominators(
        newPrecompilerTrace,
        NodeType.packageNode,
      );
    }

    return compareProgramInfo(oldApkProgramInfo, newApkProgramInfo);
  }

  Map<String, Object> _wrapInArtificialRoot(Map<String, dynamic> json) {
    json['n'] = _mainNodeName;
    return <String, Object>{
      'n': _artificialRootNodeName,
      'children': [json],
    };
  }

  ProgramInfoNode _apkJsonToProgramInfo({
    required ProgramInfo program,
    required ProgramInfoNode parent,
    required Map<String, dynamic> json,
  }) {
    final bool isLeafNode = json['children'] == null;
    final node = program.makeNode(
      name: json['n'],
      parent: parent,
      type: NodeType.other,
    );

    if (!isLeafNode) {
      final rawChildren = json['children'] as List<Object?>;
      for (final childJson in rawChildren.cast<Map<String, Object?>>()) {
        _apkJsonToProgramInfo(program: program, parent: node, json: childJson);
      }
    } else {
      node.size = json['value'] ?? 0;
    }
    return node;
  }

  TreemapNode? generateTree(Map<String, dynamic> treeJson) {
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

  /// Recursively generates a diff tree from [treeJson] that contains the
  /// difference between an old size analysis file and a new size analysis file.
  ///
  /// Each node in the resulting tree represents a change in size for the given
  /// node.
  ///
  /// The tree can be filtered with different [DiffTreeType] values:
  /// * [DiffTreeType.increaseOnly] - returns a tree with nodes with positive
  ///   [byteSize].
  /// * [DiffTreeType.decreaseOnly] - returns a tree with nodes with negative
  ///   [byteSize].
  /// * [DiffTreeType.combined] - returns a tree with all nodes.
  TreemapNode? generateDiffTree(
    Map<String, dynamic> treeJson,
    DiffTreeType diffTreeType, {
    bool skipNodesWithNoByteSizeChange = true,
  }) {
    final isLeafNode = treeJson['children'] == null;
    if (!isLeafNode) {
      return _buildNodeWithChildren(
        treeJson,
        showDiff: true,
        diffTreeType: diffTreeType,
        skipNodesWithNoByteSizeChange: skipNodesWithNoByteSizeChange,
      );
    } else {
      // TODO(peterdjlee): Investigate why there are leaf nodes with size of null.
      final byteSize = treeJson['value'] as int?;
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
  TreemapNode? _buildNodeWithChildren(
    Map<String, dynamic> treeJson, {
    bool showDiff = false,
    DiffTreeType? diffTreeType,
    bool skipNodesWithNoByteSizeChange = true,
  }) {
    assert(showDiff ? diffTreeType != null : true);
    final rawChildren = treeJson['children'];
    final treemapNodeChildren = <TreemapNode>[];
    int totalByteSize = 0;

    // Given a child, build its subtree.
    for (final Map<String, dynamic> child in rawChildren) {
      final childTreemapNode = showDiff
          ? generateDiffTree(child, diffTreeType!)
          : generateTree(child);
      if (childTreemapNode == null) {
        continue;
      }
      treemapNodeChildren.add(childTreemapNode);
      totalByteSize += childTreemapNode.byteSize;
    }

    // If none of the children matched the diff tree type
    return totalByteSize == 0 && skipNodesWithNoByteSizeChange
        ? null
        : _buildNode(
            treeJson,
            totalByteSize,
            children: treemapNodeChildren,
            showDiff: showDiff,
          );
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

    for (final TreemapNode child in children) {
      childrenMap[child.name] = child;
    }

    final bool isDeferred =
        treeJson['isDeferred'] != null && treeJson['isDeferred'];

    return TreemapNode(
      name: name,
      byteSize: byteSize,
      childrenMap: childrenMap,
      showDiff: showDiff,
      backgroundColor: isDeferred ? treemapDeferredColor : null,
      caption: isDeferred ? '(Deferred)' : null,
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
    'linux',
    'web',
  ];

  bool get isAnalyzeSizeFile {
    final data = this.data;
    if (data is Map<String, Object?>) {
      final type = data['type'] as String?;
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
