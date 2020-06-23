// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:vm_snapshot_analysis/program_info.dart';
import 'package:vm_snapshot_analysis/utils.dart';

import '../charts/treemap.dart';
import 'code_size_processor.dart';

class CodeSizeController {
  CodeSizeController() {
    processor = CodeSizeProcessor();
  }

  CodeSizeProcessor processor;

  ValueListenable<ProgramInfoNode> get root => _root;
  final _root = ValueNotifier<ProgramInfoNode>(null);

  // Work in progress
  Future<void> loadJson() async {
    final directoryPath = current + '/lib/src/code_size/';
    final sizesJson = File(directoryPath + 'sizes.json');
    final v8Json = File(directoryPath + 'v8.json');
    final sizesProgramInfo = await loadProgramInfo(sizesJson);
    final v8ProgramInfo = await loadProgramInfo(v8Json);
    // addSizesToParentNodes(sizesProgramInfo.root);
    // sizesProgramInfo.root.children.values.toList().forEach((element) => print(element.details()));
    // print('\n');
    // v8ProgramInfo.root.children.values.toList().forEach((element) => print(element.details()));
    // changeRoot(sizesProgramInfo.root);
  }

  // void addSizesToParentNodes(ProgramInfoNode root) {
  //   if (root.children.isNotEmpty) {
  //     root.children.values.toList().forEach((child) {
  //       addSizesToParentNodes(child);
  //     });
  //   } else {
  //     root.size ??= 0;
  //     addSizeHelper(root);
  //   }
  // }

  // void addSizeHelper(ProgramInfoNode child) {
  //   if (child.parent == null) return;
  //   child.parent.size ??= 0;
  //   child.parent.size += child.size;
  //   addSizeHelper(child.parent);
  // }


  void clear() {
    _root.value = null;
  }

  void changeRoot(ProgramInfoNode newRoot) {
    _root.value = newRoot;
  }
}