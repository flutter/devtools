// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auto_dispose_mixin.dart';
import '../charts/treemap.dart';
import '../common_widgets.dart';
import '../config_specific/drag_and_drop/drag_and_drop.dart';
import '../octicons.dart';
import '../screen.dart';
import '../split.dart';
import '../theme.dart';
import 'code_size_controller.dart';
import 'code_size_table.dart';
import 'file_import_container.dart';

bool codeSizeScreenEnabled = true;

const initialFractionForTreemap = 0.67;
const initialFractionForTreeTable = 0.33;

class CodeSizeScreen extends Screen {
  const CodeSizeScreen()
      : super.conditional(
          id: id,
          requiresDartVm: true,
          title: 'Code Size',
          icon: Octicons.fileZip,
        );

  static const id = 'codeSize';

  static const snapshotTabKey = Key('Snapshot Tab');
  static const diffTabKey = Key('Diff Tab');

  @visibleForTesting
  static const clearButtonKey = Key('Clear Button');
  @visibleForTesting
  static const dropdownKey = Key('Diff Tree Type Dropdown');
  @visibleForTesting
  static const snapshotViewTreemapKey = Key('Snapshot View Treemap');
  @visibleForTesting
  static const diffViewTreemapKey = Key('Diff View Treemap');

  @override
  String get docPageId => id;

  @override
  Widget build(BuildContext context) {
    // Since `handleDrop` is not specified for this [DragAndDrop] widget, drag
    // and drop events will be absorbed by it, meaning drag and drop actions
    // will be a no-op if they occur over this area. [DragAndDrop] widgets
    // lower in the tree will have priority over this one.
    return const DragAndDrop(child: CodeSizeBody());
  }
}

class CodeSizeBody extends StatefulWidget {
  const CodeSizeBody();

  @override
  _CodeSizeBodyState createState() => _CodeSizeBodyState();
}

class _CodeSizeBodyState extends State<CodeSizeBody>
    with AutoDisposeMixin, SingleTickerProviderStateMixin {
  static const tabs = [
    Tab(text: 'Snapshot', key: CodeSizeScreen.snapshotTabKey),
    Tab(text: 'Diff', key: CodeSizeScreen.diffTabKey),
  ];

  CodeSizeController controller;

  TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: tabs.length, vsync: this);
    addAutoDisposeListener(_tabController);
  }

  @override
  void dispose() {
    super.dispose();
    _tabController.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final newController = Provider.of<CodeSizeController>(context);
    if (newController == controller) return;
    controller = newController;

    addAutoDisposeListener(controller.activeDiffTreeType);
  }

  @override
  Widget build(BuildContext context) {
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
                if (currentTab.key == CodeSizeScreen.diffTabKey)
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
              SnapshotView(),
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
      key: CodeSizeScreen.dropdownKey,
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
    return clearButton(
      key: CodeSizeScreen.clearButtonKey,
      onPressed: () => controller.clear(activeTabKey),
    );
  }
}

class SnapshotView extends StatefulWidget {
  const SnapshotView();

  // TODO(kenz): add links to documentation on how to generate these files, and
  // mention the import file button once it is hooked up to a file picker.
  static const importInstructions = 'Drag and drop an AOT snapshot or'
      ' "apk-analysis.json" file for code size debugging';

  @override
  _SnapshotViewState createState() => _SnapshotViewState();
}

class _SnapshotViewState extends State<SnapshotView> with AutoDisposeMixin {
  CodeSizeController controller;

  TreemapNode snapshotRoot;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final newController = Provider.of<CodeSizeController>(context);
    if (newController == controller) return;
    controller = newController;

    snapshotRoot = controller.snapshotRoot.value;
    addAutoDisposeListener(controller.snapshotRoot, () {
      setState(() {
        snapshotRoot = controller.snapshotRoot.value;
      });
    });

    addAutoDisposeListener(controller.snapshotJsonFile);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: snapshotRoot != null
              ? _buildTreemapAndTableSplitView()
              : _buildImportSnapshotView(),
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
                CodeSizeSnapshotTable(rootNode: snapshotRoot),
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
    String output =
        controller.snapshotJsonFile.value.isApkFile ? 'APK: ' : 'Snapshot: ';
    output += controller.snapshotJsonFile.value.displayText;
    return output;
  }

  Widget _buildTreemap() {
    return LayoutBuilder(
      key: CodeSizeScreen.snapshotViewTreemapKey,
      builder: (context, constraints) {
        return Treemap.fromRoot(
          rootNode: snapshotRoot,
          levelsVisible: 2,
          isOutermostLevel: true,
          height: constraints.maxHeight,
          onRootChangedCallback: controller.changeSnapshotRoot,
        );
      },
    );
  }

  Widget _buildImportSnapshotView() {
    return Column(
      children: [
        Flexible(
          child: FileImportContainer(
            title: 'Snapshot / APK analysis',
            instructions: SnapshotView.importInstructions,
            actionText: 'Analyze Snapshot / APK',
            onAction: controller.loadTreeFromJsonFile,
          ),
        ),
      ],
    );
  }
}

class DiffView extends StatefulWidget {
  const DiffView();

  // TODO(kenz): add links to documentation on how to generate these files, and
  // mention the import file button once it is hooked up to a file picker.
  static const importOldInstructions = 'Drag and drop an original (old) AOT '
      'snapshot or "apk-analysis.json" file for code size debugging';
  static const importNewInstructions = 'Drag and drop a modified (new) AOT '
      'snapshot or "apk-analysis.json" file for code size debugging';

  @override
  _DiffViewState createState() => _DiffViewState();
}

class _DiffViewState extends State<DiffView> with AutoDisposeMixin {
  CodeSizeController controller;

  TreemapNode diffRoot;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final newController = Provider.of<CodeSizeController>(context);
    if (newController == controller) return;
    controller = newController;

    diffRoot = controller.diffRoot.value;
    addAutoDisposeListener(controller.diffRoot, () {
      setState(() {
        diffRoot = controller.diffRoot.value;
      });
    });

    addAutoDisposeListener(controller.activeDiffTreeType);

    addAutoDisposeListener(controller.oldDiffSnapshotJsonFile);
    addAutoDisposeListener(controller.newDiffSnapshotJsonFile);
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
                CodeSizeDiffTable(rootNode: diffRoot),
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
    output += controller.oldDiffSnapshotJsonFile.value.isApkFile
        ? 'APKs: '
        : 'Snapshots: ';
    output += controller.oldDiffSnapshotJsonFile.value.displayText;
    output += ' (OLD)    vs    (NEW) ';
    output += controller.newDiffSnapshotJsonFile.value.displayText;
    return output;
  }

  Widget _buildImportDiffView() {
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
            onAction: controller.loadDiffTreeFromJsonFiles,
          ),
        ),
      ],
    );
  }

  Widget _buildTreemap() {
    return LayoutBuilder(
      key: CodeSizeScreen.snapshotViewTreemapKey,
      builder: (context, constraints) {
        return Treemap.fromRoot(
          rootNode: diffRoot,
          levelsVisible: 2,
          isOutermostLevel: true,
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
