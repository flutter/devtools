// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';

import 'vm_developer_tools_screen.dart';

class VMDeveloperToolsController {
  ValueListenable<int> get selectedIndex => _selectedIndex;
  final _selectedIndex = ValueNotifier<int>(0);

  void selectIndex(int index) {
    _selectedIndex.value = index;
    _showIsolateSelector.value =
        VMDeveloperToolsScreenBody.views[index].showIsolateSelector;
  }

  ValueListenable<bool> get showIsolateSelector => _showIsolateSelector;
  final _showIsolateSelector = ValueNotifier<bool>(false);
}
