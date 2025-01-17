// Copyright 2023 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:devtools_app/devtools_app.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vm_service/vm_service.dart';

class FakeObjectInspectorViewController extends Fake
    implements ObjectInspectorViewController {
  @override
  final classHierarchyController = ClassHierarchyExplorerController();

  @override
  Future<void> findAndSelectNodeForObject(ObjRef obj) async {}
}
