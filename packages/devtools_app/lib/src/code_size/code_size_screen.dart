// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
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
  @visibleForTesting
  static const treemapKey = Key('Code Size Treemap');
  @visibleForTesting
  static const Key snapshotTabKey = Key('Code Size Snapshot Tab');
  @visibleForTesting
  static const Key diffTabKey = Key('Code Size Diff Tab');

  static const tabs = [
    Tab(text: 'Snapshot', key: snapshotTabKey),
    Tab(text: 'Diff', key: diffTabKey),
  ];

  CodeSizeController controller;

  TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: tabs.length, vsync: this)
      ..addListener(() {
        setState(() {});
      });
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
  }

  @override
  Widget build(BuildContext context) {
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
          ],
        ),
        Expanded(
          child: TabBarView(
            physics: defaultTabBarViewPhysics,
            children: [
              SnapshotView(),
              DiffView(),
            ],
            controller: _tabController,
          ),
        ),
      ],
    );
  }
}

class SnapshotView extends StatefulWidget {
  @override
  _SnapshotViewState createState() => _SnapshotViewState();
}

class _SnapshotViewState extends State<SnapshotView> with AutoDisposeMixin {
  @visibleForTesting
  static const treemapKey = Key('Code Size Treemap');

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
        buildSnapshotViewControls(),
        Expanded(
          child: snapshotRoot != null
              ? _buildTreemapAndTableSplitView()
              : _buildImportSnapshotView(),
        ),
      ],
    );
  }

  Row buildSnapshotViewControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        clearButton(
          busy: snapshotRoot == null,
          onPressed: controller.clearSnapshot,
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
  @override
  _DiffViewState createState() => _DiffViewState();
}

class _DiffViewState extends State<DiffView> with AutoDisposeMixin {
  @visibleForTesting
  static const treemapKey = Key('Code Size Treemap');

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
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // TODO(peterdjlee): Move the controls to be aligned with the
        //                   tab bar to save vertical space.
        _buildDiffViewControls(),
        Expanded(
          child: diffRoot != null
              ? _buildTreemapAndTableSplitView()
              : _buildImportDiffView(),
        ),
      ],
    );
  }

  Row _buildDiffViewControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        _buildDiffTreeTypeDropdown(),
        const SizedBox(width: defaultSpacing),
        clearButton(
          busy: diffRoot == null,
          onPressed: controller.clearDiff,
        ),
      ],
    );
  }

  DropdownButtonHideUnderline _buildDiffTreeTypeDropdown() {
    return DropdownButtonHideUnderline(
      child: DropdownButton<DiffTreeType>(
        value: controller.activeDiffTreeType.value,
        items: [
          _buildMenuItem(DiffTreeType.combined),
          _buildMenuItem(DiffTreeType.increaseOnly),
          _buildMenuItem(DiffTreeType.decreaseOnly),
        ],
        onChanged: controller.diffRoot.value == null
            ? null
            : (newDiffTreeType) {
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
          style:
              TextStyle(color: Theme.of(context).colorScheme.chartAccentColor),
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
