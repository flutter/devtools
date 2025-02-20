// Copyright 2020 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'dart:async';

import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:flutter/material.dart';
import 'package:vm_snapshot_analysis/precompiler_trace.dart';

import '../../shared/analytics/analytics.dart' as ga;
import '../../shared/analytics/constants.dart' as gac;
import '../../shared/charts/treemap.dart';
import '../../shared/config_specific/drag_and_drop/drag_and_drop.dart';
import '../../shared/framework/screen.dart';
import '../../shared/globals.dart';
import '../../shared/primitives/query_parameters.dart';
import '../../shared/primitives/utils.dart';
import '../../shared/server/server.dart' as server;
import '../../shared/ui/common_widgets.dart';
import '../../shared/ui/file_import.dart';
import '../../shared/ui/tab.dart';
import 'app_size_controller.dart';
import 'app_size_table.dart';
import 'code_size_attribution.dart';

const initialFractionForTreemap = 0.67;
const initialFractionForTreeTable = 0.33;

class AppSizeScreen extends Screen {
  AppSizeScreen() : super.fromMetaData(ScreenMetaData.appSize);

  static const analysisTabKey = Key('Analysis Tab');
  static const diffTabKey = Key('Diff Tab');

  static final id = ScreenMetaData.appSize.id;

  @visibleForTesting
  static const diffTypeDropdownKey = Key('Diff Tree Type Dropdown');

  @visibleForTesting
  static const appUnitDropdownKey = Key('App Segment Dropdown');

  @visibleForTesting
  static const analysisViewTreemapKey = Key('Analysis View Treemap');

  @visibleForTesting
  static const diffViewTreemapKey = Key('Diff View Treemap');

  static const loadingMessage =
      'Loading data...\nPlease do not refresh or leave this page.';

  @override
  String get docPageId => id;

  @override
  Widget buildScreenBody(BuildContext context) {
    // Since `handleDrop` is not specified for this [DragAndDrop] widget, drag
    // and drop events will be absorbed by it, meaning drag and drop actions
    // will be a no-op if they occur over this area. [DragAndDrop] widgets
    // lower in the tree will have priority over this one.
    return const DragAndDrop(child: AppSizeBody());
  }
}

class AppSizeBody extends StatefulWidget {
  const AppSizeBody({super.key});

  @override
  State<AppSizeBody> createState() => _AppSizeBodyState();
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

  late AppSizeController controller;

  late final TabController _tabController;

  bool _preLoadingData = false;

  @override
  void initState() {
    super.initState();
    ga.screen(gac.appSize);
    controller = screenControllers.lookup<AppSizeController>();
    _tabController = TabController(length: tabs.length, vsync: this);
    addAutoDisposeListener(_tabController);
    unawaited(maybeLoadAppSizeFiles());
    addAutoDisposeListener(controller.activeDiffTreeType);
  }

  Future<void> maybeLoadAppSizeFiles() async {
    final queryParams = DevToolsQueryParams.load();
    final baseFilePath = queryParams.appSizeBaseFilePath;
    if (baseFilePath != null) {
      // TODO(kenz): does this have to be in a setState()?
      _preLoadingData = true;
      final baseAppSizeFile = await server.requestBaseAppSizeFile(baseFilePath);
      DevToolsJsonFile? testAppSizeFile;
      final testFilePath = queryParams.appSizeTestFilePath;
      if (testFilePath != null) {
        testAppSizeFile = await server.requestTestAppSizeFile(testFilePath);
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
    if (mounted) notificationService.pushError(error);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: controller.isDeferredApp,
      builder: (context, isDeferredApp, _) {
        if (_preLoadingData) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  devToolsEnvironmentParameters.loadingAppSizeDataMessage(),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: defaultSpacing),
                const CircularProgressIndicator(),
              ],
            ),
          );
        }
        final currentTab = tabs[_tabController.index];
        return RoundedOutlinedBorder(
          clip: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AreaPaneHeader(
                leftPadding: 0,
                tall: true,
                includeTopBorder: false,
                roundedTopBorder: false,
                title: TabBar(
                  labelColor: Theme.of(context).regularTextStyle.color,
                  isScrollable: true,
                  controller: _tabController,
                  tabs: tabs,
                ),
                actions: [
                  if (isDeferredApp)
                    AppUnitDropdown(
                      value: controller.selectedAppUnit.value,
                      onChanged: (newAppUnit) {
                        setState(() {
                          controller.changeSelectedAppUnit(
                            newAppUnit!,
                            currentTab.key!,
                          );
                        });
                      },
                    ),
                  if (currentTab.key == AppSizeScreen.diffTabKey) ...[
                    const SizedBox(width: defaultSpacing),
                    DiffTreeTypeDropdown(
                      value: controller.activeDiffTreeType.value,
                      onChanged: (newDiffTreeType) {
                        controller.changeActiveDiffTreeType(newDiffTreeType!);
                      },
                    ),
                  ],
                  const SizedBox(width: defaultSpacing),
                  ClearButton(
                    gaScreen: gac.appSize,
                    gaSelection: gac.clear,
                    onPressed: () => controller.clear(currentTab.key!),
                  ),
                ],
              ),
              Expanded(
                child: TabBarView(
                  physics: defaultTabBarViewPhysics,
                  controller: _tabController,
                  children: const [AnalysisView(), DiffView()],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class AppUnitDropdown extends StatelessWidget {
  const AppUnitDropdown({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final AppUnit value;
  final ValueChanged<AppUnit?>? onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: defaultButtonHeight,
      child: RoundedDropDownButton<AppUnit>(
        key: AppSizeScreen.appUnitDropdownKey,
        value: value,
        items: [
          _buildAppUnitMenuItem(AppUnit.entireApp),
          _buildAppUnitMenuItem(AppUnit.mainOnly),
          _buildAppUnitMenuItem(AppUnit.deferredOnly),
        ],
        onChanged: onChanged,
      ),
    );
  }

  DropdownMenuItem<AppUnit> _buildAppUnitMenuItem(AppUnit appUnit) {
    return DropdownMenuItem<AppUnit>(
      value: appUnit,
      child: Text(appUnit.display),
    );
  }
}

class DiffTreeTypeDropdown extends StatelessWidget {
  const DiffTreeTypeDropdown({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final DiffTreeType value;
  final ValueChanged<DiffTreeType?>? onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: defaultButtonHeight,
      child: RoundedDropDownButton<DiffTreeType>(
        key: AppSizeScreen.diffTypeDropdownKey,
        isDense: true,
        items: [
          _buildDiffTreeTypeMenuItem(DiffTreeType.combined),
          _buildDiffTreeTypeMenuItem(DiffTreeType.increaseOnly),
          _buildDiffTreeTypeMenuItem(DiffTreeType.decreaseOnly),
        ],
        onChanged: onChanged,
      ),
    );
  }

  DropdownMenuItem<DiffTreeType> _buildDiffTreeTypeMenuItem(
    DiffTreeType diffTreeType,
  ) {
    return DropdownMenuItem<DiffTreeType>(
      value: diffTreeType,
      child: Text(diffTreeType.display),
    );
  }
}

class AnalysisView extends StatefulWidget {
  const AnalysisView({super.key});

  // TODO(kenz): add links to documentation on how to generate these files, and
  // mention the import file button once it is hooked up to a file picker.
  static const importInstructions =
      'Drag and drop an AOT snapshot or'
      ' size analysis file for debugging';

  @override
  State<AnalysisView> createState() => _AnalysisViewState();
}

class _AnalysisViewState extends State<AnalysisView> with AutoDisposeMixin {
  late AppSizeController controller;

  TreemapNode? analysisRoot;

  @override
  void initState() {
    super.initState();
    controller = screenControllers.lookup<AppSizeController>();
    analysisRoot = controller.analysisRoot.value.node;

    addAutoDisposeListener(controller.analysisRoot, () {
      setState(() {
        analysisRoot = controller.analysisRoot.value.node;
      });
    });

    addAutoDisposeListener(controller.analysisJsonFile);
  }

  @override
  Widget build(BuildContext context) {
    final analysisRootLocal = analysisRoot;
    return Column(
      children: [
        Expanded(
          child:
              analysisRootLocal == null
                  ? _buildImportFileView()
                  : _AppSizeView(
                    title: _generateSingleFileHeaderText(),
                    treemapKey: AppSizeScreen.analysisViewTreemapKey,
                    treemapRoot: analysisRootLocal,
                    onRootChangedCallback: controller.changeAnalysisRoot,
                    analysisTable: AppSizeAnalysisTable(
                      rootNode: analysisRootLocal.root,
                      controller: controller,
                    ),
                    callGraphRoot: controller.analysisCallGraphRoot.value,
                  ),
        ),
      ],
    );
  }

  String _generateSingleFileHeaderText() {
    final analysisFile = controller.analysisJsonFile.value!;
    String output =
        analysisFile.isAnalyzeSizeFile
            ? 'Total size analysis: '
            : 'Dart AOT snapshot: ';
    output += analysisFile.displayText;
    return output;
  }

  Widget _buildImportFileView() {
    return ValueListenableBuilder<bool>(
      valueListenable: controller.processingNotifier,
      builder: (context, processing, _) {
        return processing
            ? const CenteredMessage(message: AppSizeScreen.loadingMessage)
            : Column(
              children: [
                Flexible(
                  child: FileImportContainer(
                    instructions: AnalysisView.importInstructions,
                    actionText: 'Analyze Size',
                    gaScreen: gac.appSize,
                    gaSelectionImport: gac.importFileSingle,
                    gaSelectionAction: gac.analyzeSingle,
                    onAction: (jsonFile) {
                      controller.loadTreeFromJsonFile(
                        jsonFile: jsonFile,
                        onError: (error) {
                          if (mounted) notificationService.push(error);
                        },
                      );
                    },
                  ),
                ),
              ],
            );
      },
    );
  }
}

class DiffView extends StatefulWidget {
  const DiffView({super.key});

  // TODO(kenz): add links to documentation on how to generate these files, and
  // mention the import file button once it is hooked up to a file picker.
  static const importOldInstructions =
      'Drag and drop an original (old) AOT '
      'snapshot or size analysis file for debugging';
  static const importNewInstructions =
      'Drag and drop a modified (new) AOT '
      'snapshot or size analysis file for debugging';

  @override
  State<DiffView> createState() => _DiffViewState();
}

class _DiffViewState extends State<DiffView> with AutoDisposeMixin {
  late AppSizeController controller;

  TreemapNode? diffRoot;

  @override
  void initState() {
    super.initState();
    controller = screenControllers.lookup<AppSizeController>();

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
    final diffRootLocal = diffRoot;
    return Column(
      children: [
        Expanded(
          child:
              diffRootLocal == null
                  ? _buildImportDiffView()
                  : _AppSizeView(
                    title: _generateDualFileHeaderText(),
                    treemapKey: AppSizeScreen.diffViewTreemapKey,
                    treemapRoot: diffRootLocal,
                    onRootChangedCallback: controller.changeDiffRoot,
                    analysisTable: AppSizeDiffTable(rootNode: diffRootLocal),
                    callGraphRoot: controller.diffCallGraphRoot.value,
                  ),
        ),
      ],
    );
  }

  String _generateDualFileHeaderText() {
    final oldFile = controller.oldDiffJsonFile.value!;
    final newFile = controller.newDiffJsonFile.value!;
    String output = 'Diffing ';
    output +=
        oldFile.isAnalyzeSizeFile
            ? 'total size analyses: '
            : 'Dart AOT snapshots: ';
    output += oldFile.displayText;
    output += ' (OLD)    vs    (NEW) ';
    output += newFile.displayText;
    return output;
  }

  Widget _buildImportDiffView() {
    return ValueListenableBuilder<bool>(
      valueListenable: controller.processingNotifier,
      builder: (context, processing, _) {
        return processing
            ? const CenteredMessage(message: AppSizeScreen.loadingMessage)
            : Column(
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
                    gaScreen: gac.appSize,
                    gaSelectionImportFirst: gac.importFileDiffFirst,
                    gaSelectionImportSecond: gac.importFileDiffSecond,
                    gaSelectionAction: gac.analyzeDiff,
                    onAction:
                        (oldFile, newFile, onError) =>
                            controller.loadDiffTreeFromJsonFiles(
                              oldFile: oldFile,
                              newFile: newFile,
                              onError: onError,
                            ),
                  ),
                ),
              ],
            );
      },
    );
  }
}

class _AppSizeView extends StatelessWidget {
  const _AppSizeView({
    required this.title,
    required this.treemapKey,
    required this.treemapRoot,
    required this.onRootChangedCallback,
    required this.analysisTable,
    required this.callGraphRoot,
  });

  final String title;

  final Key treemapKey;

  final TreemapNode treemapRoot;

  final void Function(TreemapNode?) onRootChangedCallback;

  final Widget analysisTable;

  final CallGraphNode? callGraphRoot;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: intermediateSpacing),
      child: RoundedOutlinedBorder(
        clip: true,
        child: Column(
          children: [
            AreaPaneHeader(
              title: Text(title),
              maxLines: 2,
              roundedTopBorder: false,
              includeTopBorder: false,
            ),
            Expanded(
              child: SplitPane(
                axis: Axis.vertical,
                initialFractions: const [
                  initialFractionForTreemap,
                  initialFractionForTreeTable,
                ],
                children: [
                  LayoutBuilder(
                    key: treemapKey,
                    builder: (context, constraints) {
                      return Treemap.fromRoot(
                        rootNode: treemapRoot,
                        levelsVisible: 2,
                        isOutermostLevel: true,
                        width: constraints.maxWidth,
                        height: constraints.maxHeight,
                        onRootChangedCallback: onRootChangedCallback,
                      );
                    },
                  ),
                  OutlineDecoration.onlyTop(
                    child: Row(
                      children: [
                        Flexible(child: analysisTable),
                        if (callGraphRoot != null)
                          Flexible(
                            child: OutlineDecoration.onlyLeft(
                              child: CallGraphWithDominators(
                                callGraphRoot: callGraphRoot!,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
