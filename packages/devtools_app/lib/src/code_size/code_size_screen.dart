// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auto_dispose_mixin.dart';
import '../charts/treemap.dart';
import '../octicons.dart';
import '../screen.dart';
import '../split.dart';
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

class CodeSizeBodyState extends State<CodeSizeBody> with AutoDisposeMixin {
  @visibleForTesting
  static const treemapKey = Key('Treemap');

  static const initialFractionForTreemap = 0.67;
  static const initialFractionForTreeTable = 0.33;

  CodeSizeController controller;

  TreemapNode root;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final newController = Provider.of<CodeSizeController>(context);
    if (newController == controller) return;
    controller = newController;

    root = controller.currentRoot.value;
    addAutoDisposeListener(controller.currentRoot, () {
      setState(() {
        root = controller.currentRoot.value;
      });
    });

    controller.loadTree('v8.json');
  }

  @override
  Widget build(BuildContext context) {
    if (root != null) {
      return Split(
        axis: Axis.vertical,
        children: [
          _buildTreemap(),
          _buildTreeTable(),
        ],
        initialFractions: const [
          initialFractionForTreemap,
          initialFractionForTreeTable,
        ],
      );
    } else {
      return const SizedBox();
    }
  }

  CodeSizeTable _buildTreeTable() {
    return CodeSizeTable(
      rootNode: root,
      totalSize: controller.topRoot.byteSize,
    );
  }

  LayoutBuilder _buildTreemap() {
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
