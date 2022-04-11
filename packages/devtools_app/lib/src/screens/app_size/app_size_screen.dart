// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_shared/devtools_shared.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../analytics/analytics.dart' as ga;
import '../../charts/treemap.dart';
import '../../config_specific/drag_and_drop/drag_and_drop.dart';
import '../../config_specific/server/server.dart' as server;
import '../../config_specific/url/url.dart';
import '../../primitives/auto_dispose_mixin.dart';
import '../../primitives/utils.dart';
import '../../shared/common_widgets.dart';
import '../../shared/file_import.dart';
import '../../shared/globals.dart';
import '../../shared/notifications.dart';
import '../../shared/screen.dart';
import '../../shared/split.dart';
import '../../shared/theme.dart';
import '../../ui/icons.dart';
import '../../ui/tab.dart';
import 'app_size_controller.dart';
import 'app_size_table.dart';
import 'code_size_attribution.dart';

const initialFractionForTreemap = 0.67;
const initialFractionForTreeTable = 0.33;

class AppSizeScreen extends Screen {
  const AppSizeScreen()
      : super.conditional(
          id: id,
          requiresDartVm: true,
          title: 'App Size',
          icon: Octicons.fileZip,
        );

  static const analysisTabKey = Key('Analysis Tab');
  static const diffTabKey = Key('Diff Tab');

  /// The ID (used in routing) for the tabbed app-size page.
  ///
  /// This must be different to the top-level appSizePageId which is also used
  /// in routing when to ensure they have unique URLs.
  static const id = 'app-size';

  @visibleForTesting
  static const dropdownKey = Key('Diff Tree Type Dropdown');

  @visibleForTesting
  static const analysisViewTreemapKey = Key('Analysis View Treemap');

  @visibleForTesting
  static const diffViewTreemapKey = Key('Diff View Treemap');

  static const loadingMessage =
      'Loading data...\nPlease do not refresh or leave this page.';

  @override
  String get docPageId => id;

  @override
  Widget build(BuildContext context) {
    // Since `handleDrop` is not specified for this [DragAndDrop] widget, drag
    // and drop events will be absorbed by it, meaning drag and drop actions
    // will be a no-op if they occur over this area. [DragAndDrop] widgets
    // lower in the tree will have priority over this one.
    return const DragAndDrop(child: AppSizeBody());
  }
}

class AppSizeBody extends StatefulWidget {
  const AppSizeBody();

  @override
  _AppSizeBodyState createState() => _AppSizeBodyState();
}

class _AppSizeBodyState extends State<AppSizeBody>
    with AutoDisposeMixin, SingleTickerProviderStateMixin {
  static const _gaPrefix = 'appSizeTab';
  static final diffTab = DevToolsTab.create(
    tabName: 'Diff',
    gaPrefix: _gaPrefix,
    key: AppSizeScreen.diffTabKey,
  );
  static final analysisTab = DevToolsTab.create(
    tabName: 'Analysis',
    gaPrefix: _gaPrefix,
    key: AppSizeScreen.analysisTabKey,
  );
  static final tabs = [analysisTab, diffTab];

  late AppSizeController _controller;

  bool _controllerInitialized = false;

  late final TabController _tabController;

  bool _preLoadingData = false;

  @override
  void initState() {
    super.initState();
    ga.screen(AppSizeScreen.id);
    _tabController = TabController(length: tabs.length, vsync: this);
    addAutoDisposeListener(_tabController);
  }

  Future<void> maybeLoadAppSizeFiles() async {
    final queryParams = loadQueryParams();
    final baseFilePath = queryParams[baseAppSizeFilePropertyName];
    if (baseFilePath != null) {
      // TODO(kenz): does this have to be in a setState()?
      _preLoadingData = true;
      final baseAppSizeFile = await server.requestBaseAppSizeFile(baseFilePath);
      DevToolsJsonFile? testAppSizeFile;
      final testFilePath = queryParams[testAppSizeFilePropertyName];
      if (testFilePath != null) {
        testAppSizeFile = await server.requestTestAppSizeFile(testFilePath);
      }

      // TODO(kenz): add error handling if the files are null
      if (baseAppSizeFile != null) {
        if (testAppSizeFile != null) {
          _controller.loadDiffTreeFromJsonFiles(
            oldFile: baseAppSizeFile,
            newFile: testAppSizeFile,
            onError: _pushErrorMessage,
          );
          _tabController.animateTo(tabs.indexOf(diffTab));
        } else {
          _controller.loadTreeFromJsonFile(
            jsonFile: baseAppSizeFile,
            onError: _pushErrorMessage,
          );
          _tabController.animateTo(tabs.indexOf(analysisTab));
        }
      }
    }
    if (_preLoadingData) {
      setState(() {
        _preLoadingData = false;
      });
    }
  }

  @override
  void dispose() {
    super.dispose();
    _tabController.dispose();
  }

  void _pushErrorMessage(String error) {
    if (mounted) Notifications.of(context)!.push(error);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final newController = Provider.of<AppSizeController>(context);
    if (_controllerInitialized && newController == _controller) return;
    _controller = newController;
    _controllerInitialized = true;

    maybeLoadAppSizeFiles();

    addAutoDisposeListener(_controller.activeDiffTreeType);
  }

  @override
  Widget build(BuildContext context) {
    if (_preLoadingData) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              devToolsExtensionPoints.loadingAppSizeDataMessage(),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: defaultSpacing),
            const CircularProgressIndicator(),
          ],
        ),
      );
    }
    final currentTab = tabs[_tabController.index];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: defaultButtonHeight,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TabBar(
                labelColor: Theme.of(context).textTheme.bodyText1!.color,
                isScrollable: true,
                controller: _tabController,
                tabs: tabs,
              ),
              Row(
                children: [
                  if (currentTab.key == AppSizeScreen.diffTabKey)
                    _buildDiffTreeTypeDropdown(),
                  const SizedBox(width: defaultSpacing),
                  _buildClearButton(currentTab.key!),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            physics: defaultTabBarViewPhysics,
            children: const [
              AnalysisView(),
              DiffView(),
            ],
            controller: _tabController,
          ),
        ),
      ],
    );
  }

  DropdownButtonHideUnderline _buildDiffTreeTypeDropdown() {
    return DropdownButtonHideUnderline(
      key: AppSizeScreen.dropdownKey,
      child: DropdownButton<DiffTreeType>(
        value: _controller.activeDiffTreeType.value,
        items: [
          _buildMenuItem(DiffTreeType.combined),
          _buildMenuItem(DiffTreeType.increaseOnly),
          _buildMenuItem(DiffTreeType.decreaseOnly),
        ],
        onChanged: (newDiffTreeType) {
          _controller.changeActiveDiffTreeType(newDiffTreeType!);
        },
      ),
    );
  }

  DropdownMenuItem<DiffTreeType> _buildMenuItem(DiffTreeType diffTreeType) {
    return DropdownMenuItem<DiffTreeType>(
      value: diffTreeType,
      child: Text(diffTreeType.display),
    );
  }

  Widget _buildClearButton(Key activeTabKey) {
    return ClearButton(
      onPressed: () => _controller.clear(activeTabKey),
    );
  }
}

class AnalysisView extends StatefulWidget {
  const AnalysisView();

  // TODO(kenz): add links to documentation on how to generate these files, and
  // mention the import file button once it is hooked up to a file picker.
  static const importInstructions = 'Drag and drop an AOT snapshot or'
      ' size analysis file for debugging';

  @override
  _AnalysisViewState createState() => _AnalysisViewState();
}

class _AnalysisViewState extends State<AnalysisView> with AutoDisposeMixin {
  late AppSizeController _controller;

  bool _controllerInitialized = false;

  TreemapNode? analysisRoot;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final newController = Provider.of<AppSizeController>(context);
    if (_controllerInitialized && newController == _controller) return;
    _controller = newController;
    _controllerInitialized = true;

    analysisRoot = _controller.analysisRoot.value;
    addAutoDisposeListener(_controller.analysisRoot, () {
      setState(() {
        analysisRoot = _controller.analysisRoot.value;
      });
    });

    addAutoDisposeListener(_controller.analysisJsonFile);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: analysisRoot != null
              ? _buildTreemapAndTableSplitView()
              : _buildImportFileView(),
        ),
      ],
    );
  }

  Widget _buildTreemapAndTableSplitView() {
    final analysisCallGraphRoot = _controller.analysisCallGraphRoot.value;
    return OutlineDecoration(
      child: Column(
        children: [
          AreaPaneHeader(
            title: Text(_generateSingleFileHeaderText()),
            maxLines: 2,
            needsTopBorder: false,
          ),
          Expanded(
            child: Split(
              axis: Axis.vertical,
              children: [
                _buildTreemap(),
                Row(
                  children: [
                    Flexible(
                      child: AppSizeAnalysisTable(rootNode: analysisRoot!),
                    ),
                    if (analysisCallGraphRoot != null)
                      Flexible(
                        child: CallGraphWithDominators(
                          callGraphRoot: analysisCallGraphRoot,
                        ),
                      ),
                  ],
                ),
              ],
              initialFractions: const [
                initialFractionForTreemap,
                initialFractionForTreeTable,
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _generateSingleFileHeaderText() {
    final analysisFile = _controller.analysisJsonFile.value!;
    String output = analysisFile.isAnalyzeSizeFile
        ? 'Total size analysis: '
        : 'Dart AOT snapshot: ';
    output += analysisFile.displayText;
    return output;
  }

  Widget _buildTreemap() {
    return LayoutBuilder(
      key: AppSizeScreen.analysisViewTreemapKey,
      builder: (context, constraints) {
        return Treemap.fromRoot(
          rootNode: analysisRoot,
          levelsVisible: 2,
          isOutermostLevel: true,
          width: constraints.maxWidth,
          height: constraints.maxHeight,
          onRootChangedCallback: _controller.changeAnalysisRoot,
        );
      },
    );
  }

  Widget _buildImportFileView() {
    return ValueListenableBuilder<bool>(
      valueListenable: _controller.processingNotifier,
      builder: (context, processing, _) {
        if (processing) {
          return Center(
            child: Text(
              AppSizeScreen.loadingMessage,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).textTheme.headline1!.color,
              ),
            ),
          );
        } else {
          return Column(
            children: [
              Flexible(
                child: FileImportContainer(
                  title: 'Size analysis',
                  instructions: AnalysisView.importInstructions,
                  actionText: 'Analyze Size',
                  onAction: (jsonFile) {
                    _controller.loadTreeFromJsonFile(
                      jsonFile: jsonFile,
                      onError: (error) {
                        if (mounted) Notifications.of(context)!.push(error);
                      },
                    );
                  },
                ),
              ),
            ],
          );
        }
      },
    );
  }
}

class DiffView extends StatefulWidget {
  const DiffView();

  // TODO(kenz): add links to documentation on how to generate these files, and
  // mention the import file button once it is hooked up to a file picker.
  static const importOldInstructions = 'Drag and drop an original (old) AOT '
      'snapshot or size analysis file for debugging';
  static const importNewInstructions = 'Drag and drop a modified (new) AOT '
      'snapshot or size analysis file for debugging';

  @override
  _DiffViewState createState() => _DiffViewState();
}

class _DiffViewState extends State<DiffView> with AutoDisposeMixin {
  late AppSizeController _controller;

  bool _controllerInitialized = false;

  TreemapNode? diffRoot;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final newController = Provider.of<AppSizeController>(context);
    if (_controllerInitialized && newController == _controller) return;
    _controller = newController;
    _controllerInitialized = true;

    diffRoot = _controller.diffRoot.value;
    addAutoDisposeListener(_controller.diffRoot, () {
      setState(() {
        diffRoot = _controller.diffRoot.value;
      });
    });

    addAutoDisposeListener(_controller.activeDiffTreeType);

    addAutoDisposeListener(_controller.oldDiffJsonFile);
    addAutoDisposeListener(_controller.newDiffJsonFile);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: diffRoot != null
              ? _buildTreemapAndTableSplitView()
              : _buildImportDiffView(),
        ),
      ],
    );
  }

  Widget _buildTreemapAndTableSplitView() {
    final diffCallGraphRoot = _controller.diffCallGraphRoot.value;
    return OutlineDecoration(
      child: Column(
        children: [
          AreaPaneHeader(
            title: Text(_generateDualFileHeaderText()),
            maxLines: 2,
            needsTopBorder: false,
          ),
          Expanded(
            child: Split(
              axis: Axis.vertical,
              children: [
                _buildTreemap(),
                Row(
                  children: [
                    Flexible(
                      child: AppSizeDiffTable(rootNode: diffRoot!),
                    ),
                    if (diffCallGraphRoot != null)
                      Flexible(
                        child: CallGraphWithDominators(
                          callGraphRoot: diffCallGraphRoot,
                        ),
                      ),
                  ],
                ),
              ],
              initialFractions: const [
                initialFractionForTreemap,
                initialFractionForTreeTable,
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _generateDualFileHeaderText() {
    final oldFile = _controller.oldDiffJsonFile.value!;
    final newFile = _controller.newDiffJsonFile.value!;
    String output = 'Diffing ';
    output += oldFile.isAnalyzeSizeFile
        ? 'total size analyses: '
        : 'Dart AOT snapshots: ';
    output += oldFile.displayText;
    output += ' (OLD)    vs    (NEW) ';
    output += newFile.displayText;
    return output;
  }

  Widget _buildImportDiffView() {
    return ValueListenableBuilder<bool>(
      valueListenable: _controller.processingNotifier,
      builder: (context, processing, _) {
        if (processing) {
          return _buildLoadingMessage();
        } else {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: DualFileImportContainer(
                  firstFileTitle: 'Old',
                  secondFileTitle: 'New',
                  // TODO(kenz): perhaps bold "original" and "modified".
                  firstInstructions: DiffView.importOldInstructions,
                  secondInstructions: DiffView.importNewInstructions,
                  actionText: 'Analyze Diff',
                  onAction: (oldFile, newFile, onError) =>
                      _controller.loadDiffTreeFromJsonFiles(
                    oldFile: oldFile,
                    newFile: newFile,
                    onError: onError,
                  ),
                ),
              ),
            ],
          );
        }
      },
    );
  }

  Widget _buildLoadingMessage() {
    return Center(
      child: Text(
        AppSizeScreen.loadingMessage,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Theme.of(context).textTheme.headline1!.color,
        ),
      ),
    );
  }

  Widget _buildTreemap() {
    return LayoutBuilder(
      key: AppSizeScreen.diffViewTreemapKey,
      builder: (context, constraints) {
        return Treemap.fromRoot(
          rootNode: diffRoot,
          levelsVisible: 2,
          isOutermostLevel: true,
          width: constraints.maxWidth,
          height: constraints.maxHeight,
          onRootChangedCallback: _controller.changeDiffRoot,
        );
      },
    );
  }
}

extension DiffTreeTypeExtension on DiffTreeType {
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
