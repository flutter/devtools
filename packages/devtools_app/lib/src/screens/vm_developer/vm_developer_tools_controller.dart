// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';

import '../../shared/routing.dart';
import 'object_inspector/object_inspector_view_controller.dart';
import 'vm_developer_tools_screen.dart';

class VMDeveloperToolsController {
  VMDeveloperToolsController({
    DevToolsRouterDelegate? routerDelegate,
    ObjectInspectorViewController? objectInspectorViewController,
  }) : objectInspectorViewController =
            objectInspectorViewController ?? ObjectInspectorViewController() {
    if (routerDelegate != null) {
      this
          .objectInspectorViewController
          .subscribeToRouterEvents(routerDelegate);
    }
  }

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
