// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: implementation_imports
import 'package:devtools_app/src/screens/vm_developer/object_inspector/class_hierarchy_explorer_controller.dart';
import 'package:devtools_app/src/screens/vm_developer/object_inspector/object_inspector_view_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vm_service/vm_service.dart';

class FakeObjectInspectorViewController extends Fake
    implements ObjectInspectorViewController {
  @override
  final classHierarchyController = ClassHierarchyExplorerController();

  @override
  Future<void> findAndSelectNodeForObject(ObjRef obj) async {}
}
