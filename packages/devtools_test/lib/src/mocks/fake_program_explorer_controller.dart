// Copyright 2022 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'dart:async';

import 'package:devtools_app/devtools_app.dart';
import 'package:flutter/foundation.dart';
import 'package:vm_service/vm_service.dart';

class TestProgramExplorerController extends ProgramExplorerController {
  TestProgramExplorerController({required this.initializer});

  @override
  ValueListenable<bool> get initialized => _initialized;
  final _initialized = ValueNotifier<bool>(false);

  final FutureOr<void> Function(TestProgramExplorerController) initializer;

  @override
  Future<void> initialize() async {
    if (_initialized.value) {
      return;
    }
    await initializer(this);
    _initialized.value = true;
  }

  @override
  Future<void> populateNode(VMServiceObjectNode node) async {
    // Since the data is hard coded and fully populated, we can completely
    // bypass all the service related code. However, we need to still build
    // the child nodes, which is done by calling
    // `VMServiceObjectNode.updateObject`. We need to "force" the update since
    // there are optimizations to avoid re-building the nodes if the root node
    // already contains a full VM service object (i.e., not a reference type).
    node.updateObject(node.object as Obj, forceUpdate: true);
  }
}
