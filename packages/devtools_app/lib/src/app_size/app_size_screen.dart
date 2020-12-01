// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_shared/devtools_shared.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../analytics/analytics_stub.dart'
    if (dart.library.html) '../analytics/analytics.dart' as ga;
import '../auto_dispose_mixin.dart';
import '../charts/treemap.dart';
import '../common_widgets.dart';
import '../config_specific/drag_and_drop/drag_and_drop.dart';
import '../config_specific/server/server.dart' as server;
import '../config_specific/url/url.dart';
import '../notifications.dart';
import '../octicons.dart';
import '../screen.dart';
import '../split.dart';
import '../theme.dart';
import '../utils.dart';
import 'app_size_controller.dart';
import 'app_size_table.dart';
import 'code_size_attribution.dart';
import 'file_import_container.dart';

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
  static const diffTab = Tab(text: 'Diff', key: AppSizeScreen.diffTabKey);
  static const analysisTab =
      Tab(text: 'Analysis', key: AppSizeScreen.analysisTabKey);
  static const tabs = [analysisTab, diffTab];

  AppSizeController controller;

  TabController _tabController;

  bool preLoadingData = false;

  @override
  void initState() {
    super.initState();
    ga.screen(AppSizeScreen.id);
    _tabController = TabController(length: tabs.length, vsync: this);
    addAutoDisposeListener(_tabController);
  }

  Future<void> maybeLoadAppSizeFiles() async {
    final queryParams = loadQueryParams();
    if (queryParams.containsKey(baseAppSizeFilePropertyName)) {
      // TODO(kenz): does this have to be in a setState()?
      preLoadingData = true;
      final baseAppSizeFile = await server
          .requestBaseAppSizeFile(queryParams[baseAppSizeFilePropertyName]);
      DevToolsJsonFile testAppSizeFile;
      if (queryParams.containsKey(testAppSizeFilePropertyName)) {
        testAppSizeFile = await server
            .requestTestAppSizeFile(queryParams[testAppSizeFilePropertyName]);
      }

      // TODO(kenz): add error handling if the files are null
      if (baseAppSizeFile != null) {
        if (testAppSizeFile != null) {
          controller.loadDiffTreeFromJsonFiles(
            oldFile: baseAppSizeFile,
            newFile: testAppSizeFile,
            onError: _pushErrorMessage,
          );
          _tabController.animateTo(tabs.indexOf(diffTab));
        } else {
          controller.loadTreeFromJsonFile(
            jsonFile: baseAppSizeFile,
            onError: _pushErrorMessage,
          );
          _tabController.animateTo(tabs.indexOf(analysisTab));
        }
      }
    }
    if (preLoadingData) {
      setState(() {
        preLoadingData = false;
      });
    }
  }

  @override
  void dispose() {
    super.dispose();
    _tabController.dispose();
  }

  void _pushErrorMessage(String error) {
    if (mounted) Notifications.of(context).push(error);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final newController = Provider.of<AppSizeController>(context);
    if (newController == controller) return;
    controller = newController;

    maybeLoadAppSizeFiles();

    addAutoDisposeListener(controller.activeDiffTreeType);
  }

  @override
  Widget build(BuildContext context) {
    if (preLoadingData) {
      return const CenteredCircularProgressIndicator();
    }
    final currentTab = tabs[_tabController.index];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TabBar(
              labelColor: Theme.of(context).textTheme.bodyText1.color,
              isScrollable: true,
              controller: _tabController,
              tabs: tabs,
            ),
            Row(
              children: [
                if (currentTab.key == AppSizeScreen.diffTabKey)
                  _buildDiffTreeTypeDropdown(),
                const SizedBox(width: defaultSpacing),
                _buildClearButton(currentTab.key),
              ],
            ),
          ],
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
        value: controller.activeDiffTreeType.value,
        items: [
          _buildMenuItem(DiffTreeType.combined),
          _buildMenuItem(DiffTreeType.increaseOnly),
          _buildMenuItem(DiffTreeType.decreaseOnly),
        ],
        onChanged: (newDiffTreeType) {
          controller.changeActiveDiffTreeType(newDiffTreeType);
        },
      ),
    );
  }

  DropdownMenuItem _buildMenuItem(DiffTreeType diffTreeType) {
    return DropdownMenuItem<DiffTreeType>(
      value: diffTreeType,
      child: Text(diffTreeType.display),
    );
  }

  Widget _buildClearButton(Key activeTabKey) {
    return ClearButton(
      onPressed: () => controller.clear(activeTabKey),
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
  AppSizeController controller;

  TreemapNode analysisRoot;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final newController = Provider.of<AppSizeController>(context);
    if (newController == controller) return;
    controller = newController;

    analysisRoot = controller.analysisRoot.value;
    addAutoDisposeListener(controller.analysisRoot, () {
      setState(() {
        analysisRoot = controller.analysisRoot.value;
      });
    });

    addAutoDisposeListener(controller.analysisJsonFile);
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
    return OutlineDecoration(
      child: Column(
        children: [
          areaPaneHeader(
            context,
            title: _generateSingleFileHeaderText(),
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
                      child: AppSizeAnalysisTable(rootNode: analysisRoot),
                    ),
                    if (controller.analysisCallGraphRoot.value != null)
                      Flexible(
                        child: CallGraphWithDominators(
                          callGraphRoot: controller.analysisCallGraphRoot.value,
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
    String output = controller.analysisJsonFile.value.isAnalyzeSizeFile
        ? 'Total size analysis: '
        : 'Dart AOT snapshot: ';
    output += controller.analysisJsonFile.value.displayText;
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
          onRootChangedCallback: controller.changeAnalysisRoot,
        );
      },
    );
  }

  Widget _buildImportFileView() {
    return ValueListenableBuilder(
        valueListenable: controller.processingNotifier,
        builder: (context, processing, _) {
          if (processing) {
            return Center(
              child: Text(
                AppSizeScreen.loadingMessage,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).textTheme.headline1.color,
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
                      controller.loadTreeFromJsonFile(
                        jsonFile: jsonFile,
                        onError: (error) {
                          if (mounted) Notifications.of(context).push(error);
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          }
        });
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
  AppSizeController controller;

  TreemapNode diffRoot;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final newController = Provider.of<AppSizeController>(context);
    if (newController == controller) return;
    controller = newController;

    diffRoot = controller.diffRoot.value;
    addAutoDisposeListener(controller.diffRoot, () {
      setState(() {
        diffRoot = controller.diffRoot.value;
      });
    });

    addAutoDisposeListener(controller.activeDiffTreeType);

    addAutoDisposeListener(controller.oldDiffJsonFile);
    addAutoDisposeListener(controller.newDiffJsonFile);
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
    return OutlineDecoration(
      child: Column(
        children: [
          areaPaneHeader(
            context,
            title: _generateDualFileHeaderText(),
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
                      child: AppSizeDiffTable(rootNode: diffRoot),
                    ),
                    if (controller.diffCallGraphRoot.value != null)
                      Flexible(
                        child: CallGraphWithDominators(
                          callGraphRoot: controller.diffCallGraphRoot.value,
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
    String output = 'Diffing ';
    output += controller.oldDiffJsonFile.value.isAnalyzeSizeFile
        ? 'total size analyses: '
        : 'Dart AOT snapshots: ';
    output += controller.oldDiffJsonFile.value.displayText;
    output += ' (OLD)    vs    (NEW) ';
    output += controller.newDiffJsonFile.value.displayText;
    return output;
  }

  Widget _buildImportDiffView() {
    return ValueListenableBuilder(
      valueListenable: controller.processingNotifier,
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
                      controller.loadDiffTreeFromJsonFiles(
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
          color: Theme.of(context).textTheme.headline1.color,
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
          onRootChangedCallback: controller.changeDiffRoot,
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
