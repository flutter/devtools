// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';

import 'package:devtools_app/src/memory/memory_heatmap.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../globals.dart';
import '../screen.dart';
import 'canned_data.dart';
import 'tree_map.dart';

/// This is an example implementation of a conditional screen that supports
/// offline mode and uses a provided controller [ExampleController].
///
/// This class exists solely as an example and should not be used in the
/// DevTools app.
class ExampleConditionalScreen extends Screen {
  const ExampleConditionalScreen()
      : super.conditional(
          id: id,
          conditionalLibrary: 'package:flutter/',
          title: 'Example',
          icon: Icons.palette,
        );

  static const id = 'example';

  @override
  Widget build(BuildContext context) {
    return const _ExampleConditionalScreenBody();
  }
}

class _ExampleConditionalScreenBody extends StatefulWidget {
  const _ExampleConditionalScreenBody();

  @override
  _ExampleConditionalScreenBodyState createState() =>
      _ExampleConditionalScreenBodyState();
}

class _ExampleConditionalScreenBodyState
    extends State<_ExampleConditionalScreenBody>
    with OfflineScreenMixin<_ExampleConditionalScreenBody, String> {
  ExampleController controller;
  DataReference rootNode;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final newController = Provider.of<ExampleController>(context);
    if (newController == controller) return;
    controller = newController;

    if (shouldLoadOfflineData()) {
      final json = offlineDataJson[ExampleConditionalScreen.id];
      if (json.isNotEmpty) {
        loadOfflineData(json['title']);
      }
    }
    initializeTree();
  }

  DataReference addChild(
    DataReference parent,
    String name,
    int size,
  ) {
    DataReference child = parent.getChildWithName(name);
    if (child == null) {
      parent.addChild(
        DataReference(
          name: name,
          byteSize: size,
        ),
      );

      child = parent.getChildWithName(name);
    } else {
      child.addSize(size);
    }
    return child;
  }

  void initializeTree() {
    final List data = jsonDecode(galleryJson);

    // Number of boxes at the library level we can see.
    const int debugChildrenNumberLimit = 100;

    final DataReference root = DataReference(
      name: 'Root',
      byteSize: 0,
    );

    // Can optimize look up / retrieve time with a hashmap

    for (dynamic memoryUsage in data) {

      String libraryName = memoryUsage['l'];
      if (libraryName == null || libraryName == '') {
        libraryName = 'Unnamed Library';
      }
      String className = memoryUsage['c'];
      if (className == null || className == '') {
        className = 'Unnamed Class';
      }
      String methodName = memoryUsage['n'];
      if (methodName == null || methodName == '') {
        methodName = 'Unnamed Method';
      }
      final int size = memoryUsage['s'];
      if (size == null) {
        throw 'Size was null for $memoryUsage';
      }
      root.addSize(size);

      DataReference libraryLevelChild;
      if (libraryName.startsWith('package:flutter/src/')) {
        final String package =
            libraryName.replaceAll('package:flutter/src/', '');
        final List<String> packageSplit = package.split('/');
        libraryLevelChild =
            addChild(root, 'package:flutter', size);
        for (String level in packageSplit) {
          libraryLevelChild =
              addChild(libraryLevelChild, level, size);
        }
      } else {
        libraryName = libraryName.split('/')[0];
        libraryLevelChild = addChild(root, libraryName, size);
      }
      final DataReference classLevelChild =
          addChild(libraryLevelChild, className, size);
      final DataReference methodLevelChild =
          addChild(classLevelChild, methodName, size);
    }
    rootNode = root;
  }

  @override
  Widget build(BuildContext context) {
    final exampleScreen = ValueListenableBuilder(
      valueListenable: controller.title,
      builder: (context, value, _) {
        return LayoutBuilder(
          builder: (context, constraints) {
            return TreeMap(
              rootNode: rootNode,
              levelsVisible: 2,
              width: constraints.maxWidth,
              height: constraints.maxHeight,
            );
          },
        );
      },
    );

    // We put these two items in a stack because the screen's UI needs to be
    // built before offline data is processed in order to initialize listeners
    // that respond to data processing events. The spinner hides the screen's
    // empty UI while data is being processed.
    return Stack(
      children: [
        exampleScreen,
        if (loadingOfflineData)
          Container(
            color: Colors.grey[50],
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          ),
      ],
    );
  }

  @override
  FutureOr<void> processOfflineData(String offlineData) async {
    await controller.processOfflineData(offlineData);
  }

  @override
  bool shouldLoadOfflineData() {
    return offlineMode &&
        offlineDataJson.isNotEmpty &&
        offlineDataJson[ExampleConditionalScreen.id] != null;
  }
}

class ExampleController {
  final ValueNotifier<String> title = ValueNotifier('Example screen');

  FutureOr<void> processOfflineData(String offlineData) {
    title.value = offlineData;
  }
}
