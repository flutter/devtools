// Copyright 2020 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:flutter/foundation.dart';

import '../../shared/framework/screen_controllers.dart';
import 'object_inspector/object_inspector_view_controller.dart';
import 'vm_developer_tools_screen.dart';

/// Screen controller for the VM Tools screen.
///
/// This controller can be accessed from anywhere in DevTools, as long as it was
/// first registered, by calling
/// `screenControllers.lookup<VMDeveloperToolsController>()`.
///
/// The controller lifecycle is managed by the [ScreenControllers] class. The
/// `init` method is called lazily upon the first controller access from
/// `screenControllers`. The `dispose` method is called by `screenControllers`
/// when DevTools is destroying a set of DevTools screen controllers.
class VMDeveloperToolsController extends DevToolsScreenController {
  VMDeveloperToolsController({
    @visibleForTesting
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

  @override
  void dispose() {
    _selectedIndex.dispose();
    objectInspectorViewController.dispose();
    super.dispose();
  }
}
