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
import '../ui/label.dart';
import 'code_size_controller.dart';
import 'code_size_table.dart';

bool codeSizeScreenEnabled = true;

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

  static const initialFractionForTreemap = 0.67;
  static const initialFractionForTreeTable = 0.33;

  CodeSizeController controller;

  TreemapNode snapshotRoot;

  TreemapNode diffRoot;

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

    snapshotRoot = controller.snapshotRoot.value;
    addAutoDisposeListener(controller.snapshotRoot, () {
      setState(() {
        snapshotRoot = controller.snapshotRoot.value;
      });
    });

    diffRoot = controller.diffRoot.value;
    addAutoDisposeListener(controller.diffRoot, () {
      setState(() {
        diffRoot = controller.diffRoot.value;
      });
    });

    addAutoDisposeListener(controller.activeDiffTreeType);

    addAutoDisposeListener(controller.snapshotFile);

    addAutoDisposeListener(controller.diffOldSnapshotFile);

    addAutoDisposeListener(controller.diffNewSnapshotFile);
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
              // onTap: onTabSelected,
            ),
            if (currentTab.key == diffTabKey && diffRoot != null)
              _buildDiffTreeTypeDropdown(),
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (currentTab.key == snapshotTabKey && snapshotRoot == null ||
                currentTab.key == diffTabKey && diffRoot == null)
              OutlineButton(
                onPressed: currentTab.key == snapshotTabKey
                    ? analyzeSingleSnapshot
                    : analyzeSnapshotDiff,
                child: const MaterialIconLabel(
                  Icons.highlight,
                  'Analyze',
                ),
              ),
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
  }

  void analyzeSingleSnapshot() {
    final snapshotFile = controller.snapshotFile.value;
    if (snapshotFile != null) {
      controller.loadFakeTree(snapshotFile);
    }
  }

  void analyzeSnapshotDiff() {
    final diffOldSnapshotFile = controller.diffOldSnapshotFile.value;
    final diffNewSnapshotFile = controller.diffNewSnapshotFile.value;
    if (diffOldSnapshotFile != null && diffNewSnapshotFile != null) {
      controller.loadFakeDiffTree(
        diffOldSnapshotFile,
        diffNewSnapshotFile,
      );
    }
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

  List<Widget> _buildTabViews() {
    return [
      snapshotRoot == null
          ? _buildSnapshotTabBody()
          : _buildTreemapAndTableSplitView(showDiff: false),
      diffRoot == null
          ? _buildDiffTabBody()
          : _buildTreemapAndTableSplitView(showDiff: true),
    ];
  }

  Widget _buildSnapshotTabBody() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: FileImportContainer(
              title: 'Snapshot',
              onImport: () {
                controller.loadSnapshotFile(
                  '$current/lib/src/code_size/stub_data/new_v8.json',
                );
              },
              importedFile: controller.snapshotFile.value,
            ),
          ),
          const SizedBox(height: 16.0),
          _builHelpText(),
        ],
      ),
    );
  }

  Widget _buildDiffTabBody() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: FileImportContainer(
                    title: 'Old Snapshot',
                    onImport: () {
                      controller.loadOldDiffSnapshotFile(
                        '$current/lib/src/code_size/stub_data/old_v8.json',
                      );
                    },
                    importedFile: controller.diffOldSnapshotFile.value,
                  ),
                ),
                const SizedBox(width: 16.0),
                Expanded(
                  child: FileImportContainer(
                    title: 'New Snapshot',
                    onImport: () {
                      controller.loadNewDiffSnapshotFile(
                        '$current/lib/src/code_size/stub_data/new_v8.json',
                      );
                    },
                    importedFile: controller.diffNewSnapshotFile.value,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16.0),
          _builHelpText(),
        ],
      ),
    );
  }

  Column _builHelpText() {
    return Column(
      children: const [
        Text(
          'We currently only support instruction sizes and v8 snapshot profile outputs.',
          style: TextStyle(color: Colors.white70),
        ),
        Text(
          'For detailed instructions, see this article.',
          style: TextStyle(color: Colors.white70),
        ),
      ],
    );
  }

  Widget _buildTreemapAndTableSplitView({@required bool showDiff}) {
    return Split(
      axis: Axis.vertical,
      children: [
        // TODO(peterdjlee): Try to reuse the same treemap widget and only swap
        //                   tables in Diff mode.
        _buildTreemap(showDiff: showDiff),
        showDiff
            ? CodeSizeDiffTable(rootNode: diffRoot)
            : CodeSizeSnapshotTable(rootNode: snapshotRoot),
      ],
      initialFractions: const [
        initialFractionForTreemap,
        initialFractionForTreeTable,
      ],
    );
  }

  Widget _buildTreemap({@required bool showDiff}) {
    return LayoutBuilder(
      key: treemapKey,
      builder: (context, constraints) {
        return Treemap.fromRoot(
          rootNode: showDiff ? diffRoot : snapshotRoot,
          levelsVisible: 2,
          isOutermostLevel: true,
          height: constraints.maxHeight,
          onRootChangedCallback: showDiff
              ? controller.changeDiffRoot
              : controller.changeSnapshotRoot,
        );
      },
    );
  }
}

class FileImportContainer extends StatelessWidget {
  const FileImportContainer({
    @required this.title,
    @required this.onImport,
    this.importedFile,
    Key key,
  }) : super(key: key);

  final String title;

  final VoidCallback onImport;

  final String importedFile;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 18.0),
        ),
        const SizedBox(height: 8.0),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15.0),
              color: Colors.white10,
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  buildImportButton(),
                  const SizedBox(height: 12.0),
                  if (importedFile != null) buildImportedFileDisplay()
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Column buildImportedFileDisplay() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // const Text('Imported file:'),
        // const SizedBox(height: 8.0),
        Text(
          importedFile,
          style: const TextStyle(color: Colors.white54),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Column buildImportButton() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.file_upload),
        RaisedButton(
          // TODO(peterdjlee): Prompt file picker to choose a snapshot file.
          onPressed: onImport,
          child: const Text('Import file'),
        ),
      ],
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
