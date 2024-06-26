// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:devtools_app_shared/utils.dart';
import 'package:flutter/foundation.dart';
import 'package:vm_service/vm_service.dart' hide VmService;

import '../../../service/vm_service_wrapper.dart';
import '../../../shared/charts/treemap.dart';
import '../../../shared/globals.dart';

/// Stores process memory usage state for the [VMProcessMemoryView].
class VMProcessMemoryViewController extends DisposableController {
  VMProcessMemoryViewController() {
    unawaited(refresh());
  }

  /// Fetches the most up-to-date process memory information.
  Future<void> refresh() async {
    final processMemoryUsage = await _service.getProcessMemoryUsage();

    TreemapNode processNode(ProcessMemoryItem memoryItem) {
      final node = TreemapNode(
        name: memoryItem.name!,
        byteSize: memoryItem.size!,
        caption: memoryItem.description,
      );
      for (final child in memoryItem.children ?? const <ProcessMemoryItem>[]) {
        node.addChild(processNode(child));
      }
      return node;
    }

    final currentRoot = processNode(processMemoryUsage.root!);

    // Insert a synthetic node for memory that isn't accounted for by the VM.
    // This value includes memory allocated through malloc and other mechanisms
    // that aren't explicitly tracked by the VM.
    currentRoot.addChild(
      TreemapNode(
        name: 'Other',
        byteSize: currentRoot.byteSize -
            currentRoot.children.fold<int>(
              0,
              (sum, e) => sum + e.byteSize,
            ),
      ),
    );

    // Expand the tree by default since the tree should be relatively small.
    currentRoot.expandCascading();

    _treeRoot.value = currentRoot;
    _treeMapRoot.value = currentRoot;
  }

  VmServiceWrapper get _service => serviceConnection.serviceManager.service!;

  /// The root of the process memory tree, used by the tree view.
  ValueListenable<TreemapNode?> get treeRoot => _treeRoot;
  final _treeRoot = ValueNotifier<TreemapNode?>(null);

  /// The current root of the process memory tree being used by the tree map
  /// viewer.
  ValueListenable<TreemapNode?> get treeMapRoot => _treeMapRoot;
  final _treeMapRoot = ValueNotifier<TreemapNode?>(null);

  /// Called when a user interacts with the tree map viewer that results in the
  /// displayed root of the tree map being updated.
  void setTreeMapRoot(TreemapNode? newRoot) {
    _treeMapRoot.value = newRoot;
  }

  /// Expands all the entries in the tree viewer.
  void expandTree() {
    _treeRoot.value?.expandCascading();
  }

  /// Collapses all the entries in the tree viewer.
  void collapseTree() {
    _treeRoot.value?.collapseCascading();
  }
}
