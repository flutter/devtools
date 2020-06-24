// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auto_dispose_mixin.dart';
import '../charts/treemap.dart';
import '../octicons.dart';
import '../screen.dart';
import 'code_size_controller.dart';

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
  @visibleForTesting
  static const emptyKey = Key('Empty');

  CodeSizeController controller;

  TreemapNode root;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final newController = Provider.of<CodeSizeController>(context);
    if (newController == controller) return;
    controller = newController;

    root = controller.root.value;
    addAutoDisposeListener(controller.root, () {
      setState(() {
        root = controller.root.value;
      });
    });

    controller.loadTree('sizes.json');
  }

  @override
  Widget build(BuildContext context) {
    if (root != null) {
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
    } else {
      return const SizedBox();
    }
  }
}
