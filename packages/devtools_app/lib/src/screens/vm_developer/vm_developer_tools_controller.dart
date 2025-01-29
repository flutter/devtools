// Copyright 2020 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:flutter/foundation.dart';

import 'object_inspector/object_inspector_view_controller.dart';
import 'vm_developer_tools_screen.dart';

class VMDeveloperToolsController {
  VMDeveloperToolsController({
    ObjectInspectorViewController? objectInspectorViewController,
  }) : objectInspectorViewController =
           objectInspectorViewController ?? ObjectInspectorViewController();

  ValueListenable<int> get selectedIndex => _selectedIndex;
  final _selectedIndex = ValueNotifier<int>(0);

  final ObjectInspectorViewController objectInspectorViewController;

  void selectIndex(int index) {
    _selectedIndex.value = index;
    showIsolateSelector.value =
        VMDeveloperToolsScreenBody.views[index].showIsolateSelector;
  }

  static final showIsolateSelector = ValueNotifier<bool>(false);
}
