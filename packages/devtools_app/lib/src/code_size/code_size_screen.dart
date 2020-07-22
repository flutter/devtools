// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:path/path.dart' hide context;
import 'package:provider/provider.dart';

import '../auto_dispose_mixin.dart';
import '../charts/treemap.dart';
import '../common_widgets.dart';
import '../octicons.dart';
import '../screen.dart';
import '../split.dart';
import '../theme.dart';
import 'code_size_controller.dart';
import 'code_size_table.dart';
import 'file_import_container.dart';

bool codeSizeScreenEnabled = false;

const initialFractionForTreemap = 0.67;
const initialFractionForTreeTable = 0.33;

class CodeSizeScreen extends Screen {
  const CodeSizeScreen() : super(id, title: 'Code Size', icon: Octicons.rss);

  static const id = 'codeSize';

  @override
  String get docPageId => id;

  @override
  Widget build(BuildContext context) {
    return const CodeSizeBody();
  }
}

class CodeSizeBody extends StatefulWidget {
  const CodeSizeBody();

  @override
  CodeSizeBodyState createState() => CodeSizeBodyState();
}

class CodeSizeBodyState extends State<CodeSizeBody>
    with AutoDisposeMixin, SingleTickerProviderStateMixin {
  static const snapshotTabKey = Key('Snapshot Tab');
  static const diffTabKey = Key('Diff Tab');
  
  @visibleForTesting
  static const clearButtonKey = Key('Clear Button');
  @visibleForTesting
  static const dropdownKey = Key('Diff Tree Type Dropdown');

  static const tabs = [
    Tab(text: 'Snapshot', key: snapshotTabKey),
    Tab(text: 'Diff', key: diffTabKey),
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
                if (currentTab.key == diffTabKey) _buildDiffTreeTypeDropdown(),
                const SizedBox(width: defaultSpacing),
                buildClearButton(currentTab.key),
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
      key: dropdownKey,
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

  Widget buildClearButton(Key activeTabKey) {
    return clearButton(
      key: clearButtonKey,
      onPressed: () => controller.clear(activeTabKey),
    );
  }
}

class SnapshotView extends StatefulWidget {
  const SnapshotView();

  @override
  SnapshotViewState createState() => SnapshotViewState();
}

class SnapshotViewState extends State<SnapshotView> with AutoDisposeMixin {
  @visibleForTesting
  static const treemapKey = Key('Snapshot View Treemap');

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
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // TODO(peterdjlee): Move the controls to be aligned with the
        //                   tab bar to save vertical space.
        Expanded(
          child: snapshotRoot != null
              ? _buildTreemapAndTableSplitView()
              : _buildImportSnapshotView(),
        ),
      ],
    );
  }

  Widget _buildTreemapAndTableSplitView() {
    return Split(
      axis: Axis.vertical,
      children: [
        _buildTreemap(),
        CodeSizeSnapshotTable(rootNode: snapshotRoot),
      ],
      initialFractions: const [
        initialFractionForTreemap,
        initialFractionForTreeTable,
      ],
    );
  }

  Widget _buildTreemap() {
    return LayoutBuilder(
      key: treemapKey,
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
    return Padding(
      padding: const EdgeInsets.all(defaultSpacing),
      child: Column(
        children: [
          Flexible(
            child: FileImportContainer(
              title: 'Snapshot',
              actionText: 'Analyze Snapshot',
              onAction: controller.loadFakeTree,
              // TODO(peterdjlee): Remove once the file picker is implemented.
              fileToBeImported:
                  '$current/lib/src/code_size/stub_data/app_size.dart',
            ),
          ),
          const SizedBox(height: defaultSpacing),
          _buildHelpText(),
        ],
      ),
    );
  }

  Column _buildHelpText() {
    return Column(
      children: [
        Text(
          'We currently only support instruction sizes and v8 snapshot profile outputs.',
          style:
              TextStyle(color: Theme.of(context).colorScheme.chartAccentColor),
        ),
      ],
    );
  }
}

class DiffView extends StatefulWidget {
  const DiffView();

  @override
  DiffViewState createState() => DiffViewState();
}

class DiffViewState extends State<DiffView> with AutoDisposeMixin {
  @visibleForTesting
  static const treemapKey = Key('Diff View Treemap');

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
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // TODO(peterdjlee): Move the controls to be aligned with the
        //                   tab bar to save vertical space.
        Expanded(
          child: diffRoot != null
              ? _buildTreemapAndTableSplitView()
              : _buildImportDiffView(),
        ),
      ],
    );
  }

  Widget _buildTreemapAndTableSplitView() {
    return Split(
      axis: Axis.vertical,
      children: [
        _buildTreemap(),
        CodeSizeDiffTable(rootNode: diffRoot),
      ],
      initialFractions: const [
        initialFractionForTreemap,
        initialFractionForTreeTable,
      ],
    );
  }

  Widget _buildImportDiffView() {
    return Padding(
      padding: const EdgeInsets.all(defaultSpacing),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: DualFileImportContainer(
              firstFileTitle: 'Old',
              secondFileTitle: 'New',
              actionText: 'Analyze Diff',
              onAction: controller.loadFakeDiffTree,
            ),
          ),
          const SizedBox(height: defaultSpacing),
          _buildHelpText(),
        ],
      ),
    );
  }

  Column _buildHelpText() {
    return Column(
      children: [
        Text(
          'We currently only support instruction sizes and v8 snapshot profile outputs.',
          style: TextStyle(
            color: Theme.of(context).colorScheme.chartAccentColor,
          ),
        ),
      ],
    );
  }

  Widget _buildTreemap() {
    return LayoutBuilder(
      key: treemapKey,
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
