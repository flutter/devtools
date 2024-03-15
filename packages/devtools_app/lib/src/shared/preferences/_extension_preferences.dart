// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

part of 'preferences.dart';

class ExtensionsPreferencesController extends DisposableController
    with AutoDisposeControllerMixin {
  final showOnlyEnabledExtensions = ValueNotifier<bool>(false);

  static final _showOnlyEnabledExtensionsId =
      '${gac.DevToolsExtensionEvents.extensionScreenId}.'
      '${gac.DevToolsExtensionEvents.showOnlyEnabledExtensionsSetting.name}';

  Future<void> init() async {
    addAutoDisposeListener(
      showOnlyEnabledExtensions,
      () {
        storage.setValue(
          _showOnlyEnabledExtensionsId,
          showOnlyEnabledExtensions.value.toString(),
        );
        ga.select(
          gac.DevToolsExtensionEvents.extensionScreenId.name,
          gac.DevToolsExtensionEvents.showOnlyEnabledExtensionsSetting.name,
          value: showOnlyEnabledExtensions.value ? 1 : 0,
        );
      },
    );
    // Default the value to false if it is not set.
    showOnlyEnabledExtensions.value =
        await storage.getValue(_showOnlyEnabledExtensionsId) == 'true';
  }
}
