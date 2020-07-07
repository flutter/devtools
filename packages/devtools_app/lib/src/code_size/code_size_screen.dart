// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:path/path.dart' hide context;
import 'package:provider/provider.dart';

import '../auto_dispose_mixin.dart';
import '../charts/treemap.dart';
import '../octicons.dart';
import '../screen.dart';
import '../split.dart';
import '../theme.dart';
import 'code_size_controller.dart';
import 'code_size_table.dart';

bool codeSizeScreenEnabled = false;

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
  static const diffTreeTypeDropdownKey = Key('Code Size Diff Tree Type Dropdown');
  @visibleForTesting
  static const snapshotTableKey = Key('Code Size Snapshot Table');
  @visibleForTesting
  static const diffTableKey = Key('Code Size Diff Table');

  static const initialFractionForTreemap = 0.67;
  static const initialFractionForTreeTable = 0.33;

  CodeSizeController controller;

  TreemapNode root;

  TabController _tabController;

  @visibleForTesting
  static const Key snapshotTabKey = Key('Code Size Snapshot Tab');
  @visibleForTesting
  static const Key diffTabKey = Key('Code Size Diff Tab');

  static const tabs = [
    Tab(text: 'Snapshot', key: snapshotTabKey),
    Tab(text: 'Diff', key: diffTabKey),
  ];

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

    root = controller.currentRoot.value;
    addAutoDisposeListener(controller.currentRoot, () {
      setState(() {
        print('changing root');
        root = controller.currentRoot.value;
      });
    });

    addAutoDisposeListener(controller.activeDiffTreeType);

    controller.loadTree('$current/lib/src/code_size/stub_data/new_v8.json');
  }

  @override
  Widget build(BuildContext context) {
    final currentTab = tabs[_tabController.index];
    if (root != null) {
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
                onTap: onTabSelected,
              ),
              if (currentTab.key == diffTabKey) _buildDiffTreeTypeDropdown(),
            ],
          ),
          Expanded(
            child: TabBarView(
              physics: defaultTabBarViewPhysics,
              children: _buildTabViews(),
              controller: _tabController,
            ),
          ),
        ],
      );
    } else {
      return const SizedBox();
    }
  }

  DropdownButtonHideUnderline _buildDiffTreeTypeDropdown() {
    return DropdownButtonHideUnderline(
      key: diffTreeTypeDropdownKey,
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

  void onTabSelected(int index) {
    final selected = tabs[index].text;
    // TODO(peterdjlee): Import user file instead of using hard coded data.
    switch (selected) {
      case 'Snapshot':
        controller.loadTree('new_v8.json');
        return;
      case 'Diff':
        controller.loadFakeDiffData(
          '$current/lib/src/code_size/stub_data/old_v8.json',
          '$current/lib/src/code_size/stub_data/new_v8.json',
          controller.activeDiffTreeType.value,
        );
        return;
    }
  }

  List<Widget> _buildTabViews() {
    return [
      _buildTreemapAndTableSplitView(showDiff: false),
      _buildTreemapAndTableSplitView(showDiff: true),
    ];
  }

  Widget _buildTreemapAndTableSplitView({@required bool showDiff}) {
    return Split(
      axis: Axis.vertical,
      children: [
        // TODO(peterdjlee): Try to reuse the same treemap widget and only swap
        //                   tables in Diff mode.
        _buildTreemap(),
        showDiff
            ? CodeSizeDiffTable(rootNode: root, key: diffTableKey)
            : CodeSizeSnapshotTable(rootNode: root, key: snapshotTableKey),
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
          rootNode: root,
          levelsVisible: 2,
          isOutermostLevel: true,
          height: constraints.maxHeight,
          onRootChangedCallback: controller.changeRoot,
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
