// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';

import '../charts/treemap.dart';
import 'canned_data.dart';
import 'code_size_controller.dart';

class CodeSizeProcessor {
  CodeSizeProcessor(this.codeSizeController);

  final CodeSizeController codeSizeController;

  void loadJson() {
    final TreemapNode root = buildTreeFromJson();
    codeSizeController.changeRoot(root);
  }

  TreemapNode addChildNode(TreemapNode parent, String name, int byteSize) {
    TreemapNode child = parent.childrenMap[name];
    if (child == null) {
      child = TreemapNode(
        name: name,
        byteSize: byteSize,
        childrenMap: <String, TreemapNode>{},
      );
      parent.childrenMap[child.name] = child;
      parent.addChild(child);
    } else {
      child.byteSize += byteSize;
    }
    return child;
  }

  TreemapNode buildTreeFromJson() {
    final List data = jsonDecode(sizesJson);

    final rootChildren = <String, TreemapNode>{};

    final TreemapNode root = TreemapNode(
      name: 'Root',
      childrenMap: rootChildren,
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
      final int byteSize = memoryUsage['s'];
      if (byteSize == null) {
        throw 'Size was null for $memoryUsage';
      }
      root.byteSize += byteSize;

      TreemapNode libraryLevelChild;
      if (libraryName.startsWith('package:flutter/src/')) {
        final String package =
            libraryName.replaceAll('package:flutter/src/', '');
        final List<String> flutterPackageSplit = package.split('/');
        libraryLevelChild = addChildNode(root, 'package:flutter', byteSize);
        for (String level in flutterPackageSplit) {
          libraryLevelChild = addChildNode(libraryLevelChild, level, byteSize);
        }
      } else {
        libraryName = libraryName.split('/')[0];
        libraryLevelChild = addChildNode(root, libraryName, byteSize);
      }
      final TreemapNode classLevelChild = addChildNode(
        libraryLevelChild,
        className,
        byteSize,
      );

      addChildNode(
        classLevelChild,
        methodName,
        byteSize,
      );
    }

    return root;
  }
}
