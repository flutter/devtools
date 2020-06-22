// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';

import '../charts/treemap.dart';
import 'code_size_processor.dart';

class CodeSizeController {
  CodeSizeController() {
    processor = CodeSizeProcessor(this);
  }

  CodeSizeProcessor processor;

  ValueListenable<TreemapNode> get root => _root;
  final _root = ValueNotifier<TreemapNode>(null);

  void loadJson() {
    processor.loadJson();
  }
  
  void clear() {
    _root.value = null;
  }

  void changeRoot(TreemapNode newRoot) {
    _root.value = newRoot;
  }
}
