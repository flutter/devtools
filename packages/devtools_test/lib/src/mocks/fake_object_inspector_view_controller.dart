// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/devtools_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vm_service/vm_service.dart';

class FakeObjectInspectorViewController extends Fake
    implements ObjectInspectorViewController {
  @override
  final classHierarchyController = ClassHierarchyExplorerController();

  @override
  Future<void> findAndSelectNodeForObject(
      BuildContext context, ObjRef obj) async {}
}
